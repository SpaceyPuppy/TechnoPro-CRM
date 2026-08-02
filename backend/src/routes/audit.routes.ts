import type { FastifyInstance } from "fastify";
import { listAuditEvents } from "../services/audit.service.js";
import { parsePagination } from "../utils/pagination.js";

export async function auditRoutes(app: FastifyInstance) {
  app.addHook("preHandler", app.authenticate);

  // Audit records are append-only: this is deliberately the only API surface.
  app.get<{
    Querystring: { page?: number; pageSize?: number; entityType?: string; entityId?: string };
  }>(
    "/audit-events",
    { preHandler: app.requireRole("admin") },
    async (request, reply) => {
      const { page, pageSize } = parsePagination(request.query);
      const events = await listAuditEvents({
        page,
        pageSize,
        entityType: request.query.entityType,
        entityId: request.query.entityId,
      });
      return reply.send({
        data: events.map((event) => ({
          id: event.id,
          entityType: event.entityType,
          entityId: event.entityId,
          action: event.action,
          userId: event.userId,
          data: event.data ? JSON.parse(event.data) : null,
          createdAt: event.createdAt.toISOString(),
        })),
      });
    },
  );
}
