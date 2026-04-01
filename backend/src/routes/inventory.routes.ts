import type { FastifyInstance } from "fastify";
import {
  listInventory,
  getInventoryItemById,
  createInventoryItem,
  updateInventoryItem,
  deleteInventoryItem,
} from "../services/inventory.service";
import { parsePagination, paginationMeta } from "../utils/pagination";
import { getDb, schema } from "../db/index";
import { generateId } from "../utils/id";
import type { CreateInventoryItemRequest, UpdateInventoryItemRequest } from "@technopro/shared";

function toResponse(row: NonNullable<Awaited<ReturnType<typeof getInventoryItemById>>>) {
  return {
    id: row.id,
    sku: row.sku,
    name: row.name,
    description: row.description,
    stockQty: row.stockQty,
    cost: row.cost,
    price: row.price,
    barcode: row.barcode,
    createdAt: row.createdAt.toISOString(),
    updatedAt: row.updatedAt.toISOString(),
  };
}

const createSchema = {
  body: {
    type: "object",
    required: ["sku", "name", "price"],
    properties: {
      sku: { type: "string", minLength: 1, maxLength: 100 },
      name: { type: "string", minLength: 1, maxLength: 255 },
      description: { type: "string", maxLength: 5000 },
      stockQty: { type: ["integer", "null"] },
      cost: { type: "string", pattern: "^\\d+\\.\\d{2}$" },
      price: { type: "string", pattern: "^\\d+\\.\\d{2}$" },
      barcode: { type: "string", maxLength: 255 },
    },
    additionalProperties: false,
  },
} as const;

const updateSchema = {
  body: {
    type: "object",
    properties: {
      sku: { type: "string", minLength: 1, maxLength: 100 },
      name: { type: "string", minLength: 1, maxLength: 255 },
      description: { type: "string", maxLength: 5000 },
      stockQty: { type: ["integer", "null"] },
      cost: { type: "string", pattern: "^\\d+\\.\\d{2}$" },
      price: { type: "string", pattern: "^\\d+\\.\\d{2}$" },
      barcode: { type: "string", maxLength: 255 },
    },
    additionalProperties: false,
  },
} as const;

export async function inventoryRoutes(app: FastifyInstance) {
  app.addHook("preHandler", app.authenticate);

  app.get<{ Querystring: { page?: number; pageSize?: number; search?: string } }>(
    "/inventory",
    async (request, reply) => {
      const { page, pageSize } = parsePagination(request.query);
      const { rows, totalCount } = await listInventory({
        page,
        pageSize,
        search: request.query.search,
      });
      return reply.send({
        data: rows.map(toResponse),
        pagination: paginationMeta(page, pageSize, totalCount),
      });
    },
  );

  app.get<{ Params: { id: string } }>("/inventory/:id", async (request, reply) => {
    const item = await getInventoryItemById(request.params.id);
    if (!item) {
      return reply.code(404).send({ error: { code: "NOT_FOUND", message: "Item not found" } });
    }
    return reply.send({ data: toResponse(item) });
  });

  app.post<{ Body: CreateInventoryItemRequest }>(
    "/inventory",
    { schema: createSchema, preHandler: app.requireRole("manager", "admin") },
    async (request, reply) => {
      const item = await createInventoryItem(request.body);
      return reply.code(201).send({ data: toResponse(item!) });
    },
  );

  app.patch<{ Params: { id: string }; Body: UpdateInventoryItemRequest }>(
    "/inventory/:id",
    { schema: updateSchema, preHandler: app.requireRole("manager", "admin") },
    async (request, reply) => {
      const item = await updateInventoryItem(request.params.id, request.body);
      if (!item) {
        return reply.code(404).send({ error: { code: "NOT_FOUND", message: "Item not found" } });
      }
      return reply.send({ data: toResponse(item) });
    },
  );

  // Bulk import inventory items — managers and admins only
  app.post<{
    Body: {
      rows: Array<{ sku: string; name: string; price: string; cost?: string; stockQty?: string; description?: string }>;
    };
  }>(
    "/inventory/import",
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
                required: ["sku", "name", "price"],
                properties: {
                  sku: { type: "string", minLength: 1, maxLength: 100 },
                  name: { type: "string", minLength: 1, maxLength: 255 },
                  price: { type: "string" },
                  cost: { type: "string" },
                  stockQty: { type: "string" },
                  description: { type: "string", maxLength: 5000 },
                },
                additionalProperties: false,
              },
            },
          },
          additionalProperties: false,
        },
      },
      preHandler: app.requireRole("manager", "admin"),
    },
    async (request, reply) => {
      const db = getDb();
      let imported = 0;
      const errors: Array<{ row: number; reason: string }> = [];
      const decimalRe = /^\d+\.\d{2}$/;

      for (let i = 0; i < request.body.rows.length; i++) {
        const row = request.body.rows[i]!;
        try {
          const sku = row.sku.trim();
          const name = row.name.trim();
          const price = parseFloat(row.price).toFixed(2);
          const cost = row.cost ? parseFloat(row.cost).toFixed(2) : "0.00";
          const stockQtyRaw = row.stockQty?.trim();
          const stockQty = stockQtyRaw ? parseInt(stockQtyRaw, 10) : null;

          if (!sku || !name) { errors.push({ row: i + 1, reason: "SKU and name are required" }); continue; }
          if (!decimalRe.test(price)) { errors.push({ row: i + 1, reason: "Invalid price format" }); continue; }
          if (stockQtyRaw && isNaN(Number(stockQtyRaw))) { errors.push({ row: i + 1, reason: "Invalid stockQty" }); continue; }

          await db.insert(schema.inventoryItems).values({
            id: generateId(),
            sku,
            name,
            description: row.description?.trim() || null,
            stockQty,
            cost,
            price,
            barcode: null,
          });
          imported++;
        } catch (err) {
          const message = err instanceof Error ? err.message : "Unknown error";
          errors.push({ row: i + 1, reason: message.includes("Duplicate") ? `Duplicate SKU: ${row.sku}` : message });
        }
      }

      return reply.send({ data: { imported, skipped: errors.length, errors } });
    },
  );

  app.delete<{ Params: { id: string } }>("/inventory/:id", { preHandler: app.requireRole("manager", "admin") }, async (request, reply) => {
    const deleted = await deleteInventoryItem(request.params.id);
    if (!deleted) {
      return reply.code(404).send({ error: { code: "NOT_FOUND", message: "Item not found" } });
    }
    return reply.code(204).send();
  });
}
