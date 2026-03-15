import { eq } from "drizzle-orm";
import { createWriteStream, mkdirSync } from "node:fs";
import { unlink, stat } from "node:fs/promises";
import { join } from "node:path";
import { pipeline } from "node:stream/promises";
import type { MultipartFile } from "@fastify/multipart";
import { getDb, schema } from "../db/index";
import { generateId } from "../utils/id";

const UPLOADS_DIR = join(process.cwd(), "uploads");

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

  const filePath = join(UPLOADS_DIR, att.filePath);
  await unlink(filePath).catch(() => {}); // ignore if file already gone

  await db
    .delete(schema.ticketAttachments)
    .where(eq(schema.ticketAttachments.id, attachmentId));
  return true;
}
