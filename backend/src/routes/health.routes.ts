import type { FastifyInstance } from "fastify";
import { getDb } from "../db/index.js";
import { sql } from "drizzle-orm";

export async function healthRoutes(app: FastifyInstance) {
  app.get("/health", async (_request, reply) => {
    try {
      const db = getDb();
      await db.execute(sql`SELECT 1`);
      return reply.send({ status: "ok", db: "connected" });
    } catch {
      return reply.code(503).send({ status: "error", db: "disconnected" });
    }
  });
}
