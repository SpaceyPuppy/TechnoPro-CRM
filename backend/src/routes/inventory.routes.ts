import type { FastifyInstance } from "fastify";
import {
  listInventory,
  getInventoryItemById,
  createInventoryItem,
  updateInventoryItem,
  deleteInventoryItem,
} from "../services/inventory.service.js";
import { parsePagination, paginationMeta } from "../utils/pagination.js";
import { getDb, schema } from "../db/index.js";
import { eq } from "drizzle-orm";
import { generateId } from "../utils/id.js";
import type { CreateInventoryItemRequest, UpdateInventoryItemRequest } from "@technopro/shared";
import { recordAuditEvent } from "../services/audit.service.js";

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
    upc: row.upc,
    manufacturerPartNumber: row.manufacturerPartNumber,
    itemType: row.itemType,
    category: row.category,
    subcategory: row.subcategory,
    brand: row.brand,
    compatibleModel: row.compatibleModel,
    condition: row.condition,
    reorderPoint: row.reorderPoint,
    targetStockLevel: row.targetStockLevel,
    warrantyMonths: row.warrantyMonths,
    internalNotes: row.internalNotes,
    active: row.active,
    posSellable: row.posSellable,
    serialized: row.serialized,
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
      upc: { type: "string", maxLength: 32 }, manufacturerPartNumber: { type: "string", maxLength: 100 }, itemType: { type: "string", maxLength: 40 },
      category: { type: "string", maxLength: 100 }, subcategory: { type: "string", maxLength: 100 }, brand: { type: "string", maxLength: 100 }, compatibleModel: { type: "string", maxLength: 150 }, condition: { type: "string", maxLength: 40 },
      reorderPoint: { type: ["integer", "null"], minimum: 0 }, targetStockLevel: { type: ["integer", "null"], minimum: 0 }, warrantyMonths: { type: ["integer", "null"], minimum: 0 }, internalNotes: { type: "string", maxLength: 5000 },
      active: { type: "boolean" }, posSellable: { type: "boolean" }, serialized: { type: "boolean" },
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
      upc: { type: "string", maxLength: 32 }, manufacturerPartNumber: { type: "string", maxLength: 100 }, itemType: { type: "string", maxLength: 40 },
      category: { type: "string", maxLength: 100 }, subcategory: { type: "string", maxLength: 100 }, brand: { type: "string", maxLength: 100 }, compatibleModel: { type: "string", maxLength: 150 }, condition: { type: "string", maxLength: 40 },
      reorderPoint: { type: ["integer", "null"], minimum: 0 }, targetStockLevel: { type: ["integer", "null"], minimum: 0 }, warrantyMonths: { type: ["integer", "null"], minimum: 0 }, internalNotes: { type: "string", maxLength: 5000 },
      active: { type: "boolean" }, posSellable: { type: "boolean" }, serialized: { type: "boolean" },
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
      await recordAuditEvent("inventory_item", item!.id, "created", request.user.id, {
        after: toResponse(item!),
      });
      return reply.code(201).send({ data: toResponse(item!) });
    },
  );

  app.patch<{ Params: { id: string }; Body: UpdateInventoryItemRequest }>(
    "/inventory/:id",
    { schema: updateSchema, preHandler: app.requireRole("manager", "admin") },
    async (request, reply) => {
      const before = await getInventoryItemById(request.params.id);
      const item = await updateInventoryItem(request.params.id, request.body);
      if (!item) {
        return reply.code(404).send({ error: { code: "NOT_FOUND", message: "Item not found" } });
      }
      await recordAuditEvent("inventory_item", item.id, "updated", request.user.id, {
        before: before ? toResponse(before) : null,
        after: toResponse(item),
      });
      return reply.send({ data: toResponse(item) });
    },
  );

  app.get<{ Params: { id: string } }>("/inventory/:id/supplier-items", { preHandler: app.requireRole("manager", "admin") }, async (request, reply) => {
    const rows = await getDb().select().from(schema.supplierItems).where(eq(schema.supplierItems.inventoryItemId, request.params.id));
    return reply.send({ data: rows.map((row) => ({ ...row, quotedUnitCost: row.quotedUnitCost?.toString() ?? null, lastPaidUnitCost: row.lastPaidUnitCost?.toString() ?? null, preferred: row.preferred === 1, active: row.active === 1, createdAt: row.createdAt.toISOString(), updatedAt: row.updatedAt.toISOString() })) });
  });

  app.post<{ Params: { id: string }; Body: { supplierId: string; supplierSku?: string; supplierUpc?: string; supplierPartNumber?: string; productUrl?: string; packSize?: number; minimumOrderQty?: number; quotedUnitCost?: string; leadTimeDays?: number; preferred?: boolean; active?: boolean } }>("/inventory/:id/supplier-items", { preHandler: app.requireRole("manager", "admin") }, async (request, reply) => {
    const body = request.body;
    if (!body.supplierId || (body.packSize !== undefined && body.packSize < 1) || (body.minimumOrderQty !== undefined && body.minimumOrderQty < 1)) return reply.code(400).send({ error: { code: "BAD_REQUEST", message: "Supplier, pack size and minimum order quantity are invalid" } });
    try {
      await getDb().transaction(async (tx) => {
        if (body.preferred) await tx.update(schema.supplierItems).set({ preferred: 0 }).where(eq(schema.supplierItems.inventoryItemId, request.params.id));
        await tx.insert(schema.supplierItems).values({ id: generateId(), supplierId: body.supplierId, inventoryItemId: request.params.id, supplierSku: body.supplierSku?.trim() || null, supplierUpc: body.supplierUpc?.trim() || null, supplierPartNumber: body.supplierPartNumber?.trim() || null, productUrl: body.productUrl?.trim() || null, packSize: body.packSize ?? 1, minimumOrderQty: body.minimumOrderQty ?? 1, quotedUnitCost: body.quotedUnitCost ?? null, leadTimeDays: body.leadTimeDays ?? null, preferred: body.preferred ? 1 : 0, active: body.active === false ? 0 : 1 });
      });
      return reply.code(201).send({ data: true });
    } catch (error) { return reply.code(400).send({ error: { code: "BAD_REQUEST", message: error instanceof Error ? error.message : "Unable to add supplier item" } }); }
  });

  // Bulk import inventory items â€” managers and admins only
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
    const before = await getInventoryItemById(request.params.id);
    const deleted = await deleteInventoryItem(request.params.id);
    if (!deleted) {
      return reply.code(404).send({ error: { code: "NOT_FOUND", message: "Item not found" } });
    }
    await recordAuditEvent("inventory_item", request.params.id, "deleted", request.user.id, {
      before: before ? toResponse(before) : null,
    });
    return reply.code(204).send();
  });
}
