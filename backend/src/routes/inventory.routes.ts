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
import { applyStockMovement } from "../services/stock.service.js";
import { applyStockMovementInTransaction } from "../services/stock.service.js";
import { decimalToHundredths } from "../utils/money.js";

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
      openingBalanceReason: { type: "string", maxLength: 100 },
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

  app.post<{ Body: CreateInventoryItemRequest & { openingBalanceReason?: string } }>(
    "/inventory",
    { schema: createSchema, preHandler: app.requireRole("manager", "admin") },
    async (request, reply) => {
      if (request.body.stockQty !== undefined && request.body.stockQty !== null && request.body.stockQty < 0) {
        return reply.code(400).send({ error: { code: "BAD_REQUEST", message: "Opening quantity cannot be negative" } });
      }
      if ((request.body.stockQty ?? 0) > 0 && !request.body.openingBalanceReason?.trim()) {
        return reply.code(400).send({ error: { code: "BAD_REQUEST", message: "An opening-balance reason is required" } });
      }
      let item = await createInventoryItem(request.body);
      if ((request.body.stockQty ?? 0) > 0) {
        await applyStockMovement({ inventoryItemId: item!.id, quantityDelta: request.body.stockQty!, unitCost: request.body.cost ?? "0.00", sourceType: "opening_balance", sourceReference: `item-opening:${item!.id}`, reasonCode: request.body.openingBalanceReason!, actorUserId: request.user.id });
        item = await getInventoryItemById(item!.id);
      }
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
      if ((request.body as Record<string, unknown>).stockQty !== undefined || (request.body as Record<string, unknown>).cost !== undefined) {
        return reply.code(400).send({ error: { code: "STOCK_MOVEMENT_REQUIRED", message: "Use a stock adjustment or receipt to change stock quantity or cost" } });
      }
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

  type ImportRow = { sku: string; name: string; price: string; cost?: string; stockQty?: number; description?: string; barcode?: string; upc?: string; brand?: string; category?: string; supplierId?: string; supplierSku?: string };
  const validateImportRows = (rows: ImportRow[]) => rows.map((row, index) => {
    const errors: string[] = [];
    const sku = row.sku?.trim(); const name = row.name?.trim();
    if (!sku) errors.push("SKU is required"); if (!name) errors.push("Name is required");
    try { decimalToHundredths(row.price); } catch { errors.push("Price must be a decimal with at most two places"); }
    try { if (row.cost) decimalToHundredths(row.cost); } catch { errors.push("Cost must be a decimal with at most two places"); }
    if (row.stockQty !== undefined && (!Number.isSafeInteger(row.stockQty) || row.stockQty < 0)) errors.push("Opening quantity must be a non-negative integer");
    return { row: index + 1, sku, name, errors };
  });

  app.get("/inventory/import/template", { preHandler: app.requireRole("manager", "admin") }, async (_request, reply) => reply.send({ data: { columns: ["sku", "name", "price", "cost", "stockQty", "description", "barcode", "upc", "brand", "category", "supplierId", "supplierSku"] } }));

  app.post<{ Body: { rows: ImportRow[] } }>("/inventory/import/preview", { preHandler: app.requireRole("manager", "admin") }, async (request, reply) => {
    if (!Array.isArray(request.body.rows) || request.body.rows.length > 2000) return reply.code(400).send({ error: { code: "BAD_REQUEST", message: "Provide up to 2,000 rows" } });
    const preview = validateImportRows(request.body.rows);
    const existing = await Promise.all(preview.filter((entry) => entry.sku).map(async (entry) => ({ row: entry.row, exists: !!(await getDb().select({ id: schema.inventoryItems.id }).from(schema.inventoryItems).where(eq(schema.inventoryItems.sku, entry.sku!)).limit(1))[0] })));
    return reply.send({ data: { rows: preview.map((entry) => ({ ...entry, action: existing.find((candidate) => candidate.row === entry.row)?.exists ? "update" : "create" })), valid: preview.every((entry) => entry.errors.length === 0) } });
  });

  app.post<{ Body: { rows: ImportRow[]; openingBalanceReason: string; confirmed: boolean; importReference: string } }>("/inventory/import", { preHandler: app.requireRole("manager", "admin") }, async (request, reply) => {
    const { rows, openingBalanceReason, confirmed, importReference } = request.body;
    if (!confirmed || !openingBalanceReason?.trim() || !importReference?.trim()) return reply.code(400).send({ error: { code: "BAD_REQUEST", message: "Confirmed import reference and opening-balance reason are required" } });
    if (!Array.isArray(rows) || rows.length > 2000) return reply.code(400).send({ error: { code: "BAD_REQUEST", message: "Provide up to 2,000 rows" } });
    const preview = validateImportRows(rows);
    if (preview.some((entry) => entry.errors.length)) return reply.code(400).send({ error: { code: "INVALID_IMPORT", message: "Fix all preview errors before importing", details: preview.filter((entry) => entry.errors.length) } });
    try {
      const result = await getDb().transaction(async (tx) => {
        let created = 0; let updated = 0;
        for (let index = 0; index < rows.length; index++) {
          const row = rows[index]!;
          const [existing] = await tx.select().from(schema.inventoryItems).where(eq(schema.inventoryItems.sku, row.sku.trim())).limit(1).for("update");
          const values = { name: row.name.trim(), description: row.description?.trim() || null, price: row.price, barcode: row.barcode?.trim() || null, upc: row.upc?.trim() || null, brand: row.brand?.trim() || null, category: row.category?.trim() || null };
          const itemId = existing?.id ?? generateId();
          if (existing) { await tx.update(schema.inventoryItems).set(values).where(eq(schema.inventoryItems.id, itemId)); updated++; }
          else { await tx.insert(schema.inventoryItems).values({ id: itemId, sku: row.sku.trim(), ...values, stockQty: row.stockQty === undefined ? null : 0, cost: "0.00" }); created++; }
          if ((row.stockQty ?? 0) > 0) await applyStockMovementInTransaction(tx, { inventoryItemId: itemId, quantityDelta: row.stockQty!, unitCost: row.cost ?? "0.00", sourceType: "opening_balance", sourceReference: `${importReference}:${index + 1}`, reasonCode: openingBalanceReason, actorUserId: request.user.id });
          if (row.supplierId) await tx.insert(schema.supplierItems).values({ id: generateId(), supplierId: row.supplierId, inventoryItemId: itemId, supplierSku: row.supplierSku?.trim() || null }).onDuplicateKeyUpdate({ set: { supplierSku: row.supplierSku?.trim() || null } });
        }
        return { created, updated };
      });
      await recordAuditEvent("inventory_import", importReference, "confirmed", request.user.id, result);
      return reply.code(201).send({ data: result });
    } catch (error) { return reply.code(400).send({ error: { code: "IMPORT_FAILED", message: error instanceof Error ? error.message : "Import failed" } }); }
  });

  app.delete<{ Params: { id: string } }>("/inventory/:id", { preHandler: app.requireRole("manager", "admin") }, async (request, reply) => {
    const before = await getInventoryItemById(request.params.id);
    const deleted = await deleteInventoryItem(request.params.id);
    if (!deleted) {
      return reply.code(404).send({ error: { code: "NOT_FOUND", message: "Item not found" } });
    }
    await recordAuditEvent("inventory_item", request.params.id, "archived", request.user.id, {
      before: before ? toResponse(before) : null,
    });
    return reply.code(204).send();
  });
}
