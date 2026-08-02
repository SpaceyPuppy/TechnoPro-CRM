import { eq } from "drizzle-orm";
import { createWriteStream, mkdirSync } from "node:fs";
import { rename, unlink, stat } from "node:fs/promises";
import { join, resolve, sep } from "node:path";
import { pipeline } from "node:stream/promises";
import type { MultipartFile } from "@fastify/multipart";
import { env } from "../config/env.js";
import { getDb, schema } from "../db/index.js";
import { generateId } from "../utils/id.js";

const UPLOADS_DIR = resolve(env.UPLOAD_DIR);

const ALLOWED_MIME_TYPES = new Set([
  "image/jpeg",
  "image/png",
  "image/gif",
  "image/webp",
  "application/pdf",
  "application/msword",
  "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
  "application/vnd.ms-excel",
  "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
  "text/plain",
]);

export class AttachmentValidationError extends Error {
  readonly statusCode = 400;

  constructor(
    readonly code: "UNSUPPORTED_ATTACHMENT_TYPE" | "ATTACHMENT_TOO_LARGE",
    message: string,
  ) {
    super(message);
    this.name = "AttachmentValidationError";
  }
}

export const maxAttachmentBytes = env.MAX_FILE_SIZE_MB * 1024 * 1024;

export function validateAttachmentMetadata(mimeType: string, size: number) {
  if (!ALLOWED_MIME_TYPES.has(mimeType)) {
    throw new AttachmentValidationError(
      "UNSUPPORTED_ATTACHMENT_TYPE",
      "This file type is not supported. Use an image, PDF, Office document, spreadsheet, or text file.",
    );
  }
  if (size > maxAttachmentBytes) {
    throw new AttachmentValidationError(
      "ATTACHMENT_TOO_LARGE",
      `Attachments must be ${env.MAX_FILE_SIZE_MB} MB or smaller.`,
    );
  }
}

export async function listAttachments(ticketId: string) {
  const db = getDb();
  return db
    .select()
    .from(schema.ticketAttachments)
    .where(eq(schema.ticketAttachments.ticketId, ticketId))
    .orderBy(schema.ticketAttachments.createdAt);
}

export async function getAttachment(ticketId: string, attachmentId: string) {
  const db = getDb();
  const rows = await db
    .select()
    .from(schema.ticketAttachments)
    .where(eq(schema.ticketAttachments.id, attachmentId))
    .limit(1);
  const attachment = rows[0];
  return attachment?.ticketId === ticketId ? attachment : null;
}

export function attachmentDiskPath(filePath: string) {
  const diskPath = resolve(UPLOADS_DIR, filePath);
  if (diskPath !== UPLOADS_DIR && !diskPath.startsWith(`${UPLOADS_DIR}${sep}`)) {
    throw new Error("Invalid attachment path");
  }
  return diskPath;
}

export async function uploadAttachment(
  ticketId: string,
  file: MultipartFile,
  userId: string,
) {
  try {
    validateAttachmentMetadata(file.mimetype, 0);
  } catch (error) {
    file.file.resume();
    throw error;
  }

  const id = generateId();
  const safeName = file.filename.replace(/[^a-zA-Z0-9._-]/g, "_");
  const storedName = `${id}-${safeName}`;
  const ticketDir = join(UPLOADS_DIR, ticketId);
  mkdirSync(ticketDir, { recursive: true });

  const destPath = join(ticketDir, storedName);
  const tempPath = join(UPLOADS_DIR, `.upload-${id}.tmp`);
  const db = getDb();
  let attachmentInserted = false;
  let attachmentStored = false;

  try {
    // Multipart writes to a temporary file first; rejected uploads never reach
    // the ticket attachment directory or its database record.
    await pipeline(file.file, createWriteStream(tempPath));
    const fileStats = await stat(tempPath);
    if (file.file.truncated) {
      throw new AttachmentValidationError(
        "ATTACHMENT_TOO_LARGE",
        `Attachments must be ${env.MAX_FILE_SIZE_MB} MB or smaller.`,
      );
    }
    validateAttachmentMetadata(file.mimetype, fileStats.size);

    await db.insert(schema.ticketAttachments).values({
      id,
      ticketId,
      uploadedById: userId,
      fileName: file.filename,
      filePath: `${ticketId}/${storedName}`,
      mimeType: file.mimetype,
      fileSize: fileStats.size,
    });
    attachmentInserted = true;
    await rename(tempPath, destPath);
    attachmentStored = true;

    const result = await db
      .select()
      .from(schema.ticketAttachments)
      .where(eq(schema.ticketAttachments.id, id))
      .limit(1);
    return result[0] ?? null;
  } catch (error) {
    await unlink(tempPath).catch(() => {});
    if (attachmentStored) await unlink(destPath).catch(() => {});
    if (attachmentInserted) {
      await db.delete(schema.ticketAttachments).where(eq(schema.ticketAttachments.id, id));
    }
    throw error;
  }
}

export async function deleteAttachment(ticketId: string, attachmentId: string) {
  const db = getDb();

  const result = await db
    .select()
    .from(schema.ticketAttachments)
    .where(eq(schema.ticketAttachments.id, attachmentId))
    .limit(1);

  const att = result[0];
  if (!att || att.ticketId !== ticketId) return false;

  const filePath = attachmentDiskPath(att.filePath);
  await unlink(filePath).catch(() => {}); // ignore if file already gone

  await db
    .delete(schema.ticketAttachments)
    .where(eq(schema.ticketAttachments.id, attachmentId));
  return true;
}
