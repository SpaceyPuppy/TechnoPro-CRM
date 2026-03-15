import type { FastifyInstance } from "fastify";
import {
  listAttachments,
  uploadAttachment,
  deleteAttachment,
} from "../services/attachment.service";

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

  // Upload attachment
  app.post<{ Params: { id: string } }>("/tickets/:id/attachments", async (request, reply) => {
    const file = await request.file();
    if (!file) {
      return reply.code(400).send({
        error: { code: "BAD_REQUEST", message: "No file provided" },
      });
    }

    try {
      const attachment = await uploadAttachment(request.params.id, file, request.user.id);
      return reply.code(201).send({ data: toResponse(attachment!) });
    } catch (err: unknown) {
      const message = err instanceof Error ? err.message : "Upload failed";
      return reply.code(400).send({ error: { code: "BAD_REQUEST", message } });
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
