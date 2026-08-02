import type { FastifyInstance } from "fastify";
import { eq } from "drizzle-orm";
import { getDb, schema } from "../db/index.js";
import { generateId } from "../utils/id.js";
import { getAllSettings, updateSettings } from "../services/settings.service.js";
import type {
  CreateDeviceModelRequest,
  UpdateDeviceModelRequest,
} from "@technopro/shared";
import { rolePolicies } from "../access-control.js";

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

  // â”€â”€ App settings (business details + GST) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  app.get("/settings", { preHandler: app.requireRole(...rolePolicies.counter) }, async (_request, reply) => {
    const settings = await getAllSettings();
    return reply.send({ data: settings });
  });

  app.patch<{ Body: Record<string, string> }>(
    "/settings",
    {
      schema: {
        body: {
          type: "object",
          additionalProperties: { type: "string" },
        },
      },
      preHandler: app.requireRole(...rolePolicies.manager),
    },
    async (request, reply) => {
      // Only allow known keys to prevent arbitrary key injection
      const allowed = new Set([
        "business_name", "business_abn", "business_address",
        "business_phone", "business_email", "gst_rate", "invoice_notes",
        "labour_rate",
      ]);
      const filtered = Object.fromEntries(
        Object.entries(request.body).filter(([k]) => allowed.has(k))
      );
      await updateSettings(filtered);
      const settings = await getAllSettings();
      return reply.send({ data: settings });
    },
  );

  // â”€â”€ Device models â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

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
    { schema: createSchema, preHandler: app.requireRole(...rolePolicies.manager) },
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
    { schema: updateSchema, preHandler: app.requireRole(...rolePolicies.manager) },
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

  // Bulk import device models
  app.post<{ Body: { rows: Array<{ manufacturer: string; name: string }> } }>(
    "/settings/device-models/import",
    {
      schema: {
        body: {
          type: "object",
          required: ["rows"],
          properties: {
            rows: {
              type: "array",
              maxItems: 2000,
              items: {
                type: "object",
                required: ["manufacturer", "name"],
                properties: {
                  manufacturer: { type: "string", minLength: 1, maxLength: 100 },
                  name: { type: "string", minLength: 1, maxLength: 100 },
                },
                additionalProperties: false,
              },
            },
          },
          additionalProperties: false,
        },
      },
      preHandler: app.requireRole(...rolePolicies.manager),
    },
    async (request, reply) => {
      const db = getDb();
      let imported = 0;
      const errors: Array<{ row: number; reason: string }> = [];

      for (let i = 0; i < request.body.rows.length; i++) {
        const row = request.body.rows[i]!;
        try {
          await db.insert(schema.deviceModels).values({
            id: generateId(),
            manufacturer: row.manufacturer.trim(),
            name: row.name.trim(),
            sortOrder: 0,
          });
          imported++;
        } catch (err) {
          const message = err instanceof Error ? err.message : "Unknown error";
          errors.push({ row: i + 1, reason: message.includes("Duplicate") ? "Duplicate entry" : message });
        }
      }

      return reply.send({ data: { imported, skipped: errors.length, errors } });
    },
  );

  // Delete device model
  app.delete<{ Params: { id: string } }>(
    "/settings/device-models/:id",
    { preHandler: app.requireRole(...rolePolicies.manager) },
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
