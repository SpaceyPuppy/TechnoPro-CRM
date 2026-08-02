import type { FastifyInstance } from "fastify";
import { createReadStream } from "node:fs";
import { stat } from "node:fs/promises";
import {
  attachmentDiskPath,
  AttachmentValidationError,
  getAttachment,
  listAttachments,
  uploadAttachment,
  deleteAttachment,
} from "../services/attachment.service.js";

type AttachmentRow = Awaited<ReturnType<typeof listAttachments>>[number];

function toResponse(att: AttachmentRow) {
  return {
    id: att.id,
    ticketId: att.ticketId,
    uploadedById: att.uploadedById,
    fileName: att.fileName,
    filePath: att.filePath,
    mimeType: att.mimeType,
    fileSize: att.fileSize,
    createdAt: att.createdAt.toISOString(),
  };
}

export async function attachmentRoutes(app: FastifyInstance) {
  app.addHook("preHandler", app.authenticate);

  // List attachments for a ticket
  app.get<{ Params: { id: string } }>("/tickets/:id/attachments", async (request, reply) => {
    const attachments = await listAttachments(request.params.id);
    return reply.send({ data: attachments.map(toResponse) });
  });

  // Customer and device photos are only available to authenticated staff.
  app.get<{ Params: { id: string; attachmentId: string } }>(
    "/tickets/:id/attachments/:attachmentId/file",
    async (request, reply) => {
      const attachment = await getAttachment(request.params.id, request.params.attachmentId);
      if (!attachment) {
        return reply.code(404).send({
          error: { code: "NOT_FOUND", message: "Attachment not found" },
        });
      }

      const diskPath = attachmentDiskPath(attachment.filePath);
      try {
        await stat(diskPath);
      } catch {
        return reply.code(404).send({
          error: { code: "NOT_FOUND", message: "Attachment file is missing" },
        });
      }

      const safeName = attachment.fileName.replace(/[\r\n"\\]/g, "_");
      return reply
        .type(attachment.mimeType)
        .header("Content-Disposition", `inline; filename="${safeName}"`)
        .send(createReadStream(diskPath));
    },
  );

  // Upload attachment
  app.post<{ Params: { id: string } }>("/tickets/:id/attachments", async (request, reply) => {
    const file = await request.file();
    if (!file) {
      return reply.code(400).send({
        error: { code: "ATTACHMENT_REQUIRED", message: "Choose a file to upload." },
      });
    }

    try {
      const attachment = await uploadAttachment(request.params.id, file, request.user.id);
      return reply.code(201).send({ data: toResponse(attachment!) });
    } catch (err: unknown) {
      if (err instanceof AttachmentValidationError) {
        return reply.code(err.statusCode).send({ error: { code: err.code, message: err.message } });
      }
      request.log.error(err, "Attachment upload failed");
      return reply.code(500).send({
        error: { code: "ATTACHMENT_UPLOAD_FAILED", message: "The attachment could not be saved. Please try again." },
      });
    }
  });

  // Delete attachment
  app.delete<{ Params: { id: string; attachmentId: string } }>(
    "/tickets/:id/attachments/:attachmentId",
    async (request, reply) => {
      const deleted = await deleteAttachment(
        request.params.id,
        request.params.attachmentId,
      );
      if (!deleted) {
        return reply.code(404).send({
          error: { code: "NOT_FOUND", message: "Attachment not found" },
        });
      }
      return reply.code(204).send();
    },
  );
}
