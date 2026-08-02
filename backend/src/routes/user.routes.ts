import type { FastifyInstance } from "fastify";
import { and, eq } from "drizzle-orm";
import { getDb, schema } from "../db/index.js";
import { hashPassword } from "../services/auth.service.js";
import { generateId } from "../utils/id.js";

type UserRole = "technician" | "counter" | "manager" | "admin";

const userProperties = {
  email: { type: "string", format: "email", maxLength: 255 },
  name: { type: "string", minLength: 1, maxLength: 255 },
  role: { type: "string", enum: ["technician", "counter", "manager", "admin"] },
  password: { type: "string", minLength: 12, maxLength: 200 },
  active: { type: "boolean" },
} as const;

const createUserSchema = {
  body: {
    type: "object",
    required: ["email", "name", "role", "password"],
    properties: userProperties,
    additionalProperties: false,
  },
} as const;

const updateUserSchema = {
  body: {
    type: "object",
    minProperties: 1,
    properties: userProperties,
    additionalProperties: false,
  },
} as const;

function toResponse(user: typeof schema.users.$inferSelect) {
  return {
    id: user.id,
    email: user.email,
    name: user.name,
    role: user.role,
    active: user.active,
    createdAt: user.createdAt.toISOString(),
    updatedAt: user.updatedAt.toISOString(),
  };
}

export async function userRoutes(app: FastifyInstance) {
  app.addHook("preHandler", app.authenticate);

  // Active users are visible for assignment dropdowns. Admins can request all.
  app.get<{ Querystring: { role?: string; includeInactive?: string } }>(
    "/users",
    async (request, reply) => {
      const db = getDb();
      const includeInactive =
        request.query.includeInactive === "true" && request.user.role === "admin";
      const conditions = [];
      if (!includeInactive) conditions.push(eq(schema.users.active, true));
      if (request.query.role) {
        conditions.push(eq(schema.users.role, request.query.role as UserRole));
      }

      const rows = await db
        .select()
        .from(schema.users)
        .where(conditions.length ? and(...conditions) : undefined)
        .orderBy(schema.users.name);
      return reply.send({ data: rows.map(toResponse) });
    },
  );

  app.post<{
    Body: { email: string; name: string; role: UserRole; password: string };
  }>(
    "/users",
    { schema: createUserSchema, preHandler: app.requireRole("admin") },
    async (request, reply) => {
      const db = getDb();
      const email = request.body.email.trim().toLowerCase();
      const [existing] = await db
        .select({ id: schema.users.id })
        .from(schema.users)
        .where(eq(schema.users.email, email))
        .limit(1);
      if (existing) {
        return reply.code(409).send({
          error: { code: "EMAIL_IN_USE", message: "A staff account already uses that email" },
        });
      }

      const id = generateId();
      await db.insert(schema.users).values({
        id,
        email,
        name: request.body.name.trim(),
        role: request.body.role,
        passwordHash: await hashPassword(request.body.password),
      });
      const [created] = await db
        .select()
        .from(schema.users)
        .where(eq(schema.users.id, id))
        .limit(1);
      return reply.code(201).send({ data: toResponse(created!) });
    },
  );

  app.patch<{
    Params: { id: string };
    Body: {
      email?: string;
      name?: string;
      role?: UserRole;
      password?: string;
      active?: boolean;
    };
  }>(
    "/users/:id",
    { schema: updateUserSchema, preHandler: app.requireRole("admin") },
    async (request, reply) => {
      const db = getDb();
      const [existing] = await db
        .select()
        .from(schema.users)
        .where(eq(schema.users.id, request.params.id))
        .limit(1);
      if (!existing) {
        return reply.code(404).send({
          error: { code: "NOT_FOUND", message: "Staff account not found" },
        });
      }
      if (
        existing.id === request.user.id &&
        (request.body.active === false ||
          (request.body.role !== undefined && request.body.role !== "admin"))
      ) {
        return reply.code(409).send({
          error: { code: "SELF_LOCKOUT", message: "You cannot disable or demote your own account" },
        });
      }

      const email = request.body.email?.trim().toLowerCase();
      if (email && email !== existing.email) {
        const [emailOwner] = await db
          .select({ id: schema.users.id })
          .from(schema.users)
          .where(eq(schema.users.email, email))
          .limit(1);
        if (emailOwner) {
          return reply.code(409).send({
            error: { code: "EMAIL_IN_USE", message: "A staff account already uses that email" },
          });
        }
      }

      await db
        .update(schema.users)
        .set({
          ...(email !== undefined ? { email } : {}),
          ...(request.body.name !== undefined ? { name: request.body.name.trim() } : {}),
          ...(request.body.role !== undefined ? { role: request.body.role } : {}),
          ...(request.body.active !== undefined ? { active: request.body.active } : {}),
          ...(request.body.password !== undefined
            ? { passwordHash: await hashPassword(request.body.password) }
            : {}),
        })
        .where(eq(schema.users.id, request.params.id));

      const [updated] = await db
        .select()
        .from(schema.users)
        .where(eq(schema.users.id, request.params.id))
        .limit(1);
      return reply.send({ data: toResponse(updated!) });
    },
  );
}
