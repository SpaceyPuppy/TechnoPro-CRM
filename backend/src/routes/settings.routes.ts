import type { FastifyInstance } from "fastify";
import { eq } from "drizzle-orm";
import { getDb, schema } from "../db/index";
import { generateId } from "../utils/id";
import type {
  CreateDeviceModelRequest,
  UpdateDeviceModelRequest,
} from "@technopro/shared";

function toResponse(row: typeof schema.deviceModels.$inferSelect) {
  return {
    id: row.id,
    manufacturer: row.manufacturer,
    name: row.name,
    sortOrder: row.sortOrder,
  };
}

const createSchema = {
  body: {
    type: "object",
    required: ["manufacturer", "name"],
    properties: {
      manufacturer: { type: "string", minLength: 1, maxLength: 100 },
      name: { type: "string", minLength: 1, maxLength: 100 },
      sortOrder: { type: "integer", minimum: 0 },
    },
    additionalProperties: false,
  },
} as const;

const updateSchema = {
  body: {
    type: "object",
    properties: {
      manufacturer: { type: "string", minLength: 1, maxLength: 100 },
      name: { type: "string", minLength: 1, maxLength: 100 },
      sortOrder: { type: "integer", minimum: 0 },
    },
    additionalProperties: false,
  },
} as const;

export async function settingsRoutes(app: FastifyInstance) {
  app.addHook("preHandler", app.authenticate);

  // List all device models
  app.get("/settings/device-models", async (_request, reply) => {
    const db = getDb();
    const rows = await db
      .select()
      .from(schema.deviceModels)
      .orderBy(schema.deviceModels.manufacturer, schema.deviceModels.sortOrder, schema.deviceModels.name);
    return reply.send({ data: rows.map(toResponse) });
  });

  // Create device model
  app.post<{ Body: CreateDeviceModelRequest }>(
    "/settings/device-models",
    { schema: createSchema },
    async (request, reply) => {
      const db = getDb();
      const id = generateId();
      await db.insert(schema.deviceModels).values({
        id,
        manufacturer: request.body.manufacturer,
        name: request.body.name,
        sortOrder: request.body.sortOrder ?? 0,
      });
      const row = await db
        .select()
        .from(schema.deviceModels)
        .where(eq(schema.deviceModels.id, id))
        .limit(1);
      return reply.code(201).send({ data: toResponse(row[0]!) });
    },
  );

  // Update device model
  app.patch<{ Params: { id: string }; Body: UpdateDeviceModelRequest }>(
    "/settings/device-models/:id",
    { schema: updateSchema },
    async (request, reply) => {
      const db = getDb();
      const existing = await db
        .select()
        .from(schema.deviceModels)
        .where(eq(schema.deviceModels.id, request.params.id))
        .limit(1);
      if (!existing[0]) {
        return reply.code(404).send({ error: { code: "NOT_FOUND", message: "Device model not found" } });
      }
      const updates: Record<string, unknown> = {};
      if (request.body.manufacturer !== undefined) updates.manufacturer = request.body.manufacturer;
      if (request.body.name !== undefined) updates.name = request.body.name;
      if (request.body.sortOrder !== undefined) updates.sortOrder = request.body.sortOrder;
      if (Object.keys(updates).length > 0) {
        await db.update(schema.deviceModels).set(updates).where(eq(schema.deviceModels.id, request.params.id));
      }
      const row = await db
        .select()
        .from(schema.deviceModels)
        .where(eq(schema.deviceModels.id, request.params.id))
        .limit(1);
      return reply.send({ data: toResponse(row[0]!) });
    },
  );

  // Delete device model
  app.delete<{ Params: { id: string } }>(
    "/settings/device-models/:id",
    async (request, reply) => {
      const db = getDb();
      const existing = await db
        .select()
        .from(schema.deviceModels)
        .where(eq(schema.deviceModels.id, request.params.id))
        .limit(1);
      if (!existing[0]) {
        return reply.code(404).send({ error: { code: "NOT_FOUND", message: "Device model not found" } });
      }
      await db.delete(schema.deviceModels).where(eq(schema.deviceModels.id, request.params.id));
      return reply.code(204).send();
    },
  );
}
