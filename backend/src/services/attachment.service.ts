import { eq } from "drizzle-orm";
import { createWriteStream, mkdirSync } from "node:fs";
import { unlink, stat } from "node:fs/promises";
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
  if (!ALLOWED_MIME_TYPES.has(file.mimetype)) {
    throw new Error(`File type not allowed: ${file.mimetype}`);
  }

  const id = generateId();
  const safeName = file.filename.replace(/[^a-zA-Z0-9._-]/g, "_");
  const storedName = `${id}-${safeName}`;
  const ticketDir = join(UPLOADS_DIR, ticketId);
  mkdirSync(ticketDir, { recursive: true });

  const destPath = join(ticketDir, storedName);
  await pipeline(file.file, createWriteStream(destPath));

  const fileStats = await stat(destPath);

  const db = getDb();
  await db.insert(schema.ticketAttachments).values({
    id,
    ticketId,
    uploadedById: userId,
    fileName: file.filename,
    filePath: `${ticketId}/${storedName}`,
    mimeType: file.mimetype,
    fileSize: fileStats.size,
  });

  const result = await db
    .select()
    .from(schema.ticketAttachments)
    .where(eq(schema.ticketAttachments.id, id))
    .limit(1);
  return result[0] ?? null;
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
