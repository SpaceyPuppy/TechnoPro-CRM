import type { FastifyInstance } from "fastify";
import { eq } from "drizzle-orm";
import { getDb, schema } from "../db/index";

export async function userRoutes(app: FastifyInstance) {
  app.addHook("preHandler", app.authenticate);

  // List active users (for assignment dropdowns etc.)
  app.get<{ Querystring: { role?: string } }>("/users", async (request, reply) => {
    const db = getDb();
    const rows = await db
      .select({
        id: schema.users.id,
        name: schema.users.name,
        email: schema.users.email,
        role: schema.users.role,
      })
      .from(schema.users)
      .where(eq(schema.users.active, true))
      .orderBy(schema.users.name);

    const filtered = request.query.role
      ? rows.filter((u) => u.role === request.query.role)
      : rows;

    return reply.send({ data: filtered });
  });
}
