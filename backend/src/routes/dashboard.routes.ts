import type { FastifyInstance } from "fastify";
import { getDashboardStats } from "../services/dashboard.service.js";

export async function dashboardRoutes(app: FastifyInstance) {
  app.addHook("preHandler", app.authenticate);

  app.get("/dashboard/stats", async (request, reply) => {
    const stats = await getDashboardStats(request.user.id, request.user.role);
    return reply.send({ data: stats });
  });
}
