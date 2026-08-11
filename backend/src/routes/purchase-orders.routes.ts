import type { FastifyInstance } from "fastify";
import {
  listPurchaseOrders,
  getPurchaseOrderById,
  createPurchaseOrder,
  updatePurchaseOrder,
  receivePurchaseOrder,
} from "../services/purchase-orders.service.js";
import { parsePagination, paginationMeta } from "../utils/pagination.js";
import type { CreatePurchaseOrderRequest, UpdatePurchaseOrderRequest } from "@technopro/shared";
import { recordAuditEvent } from "../services/audit.service.js";
import { rolePolicies } from "../access-control.js";

function toResponse(row: NonNullable<Awaited<ReturnType<typeof getPurchaseOrderById>>>) {
  return {
    id: row.id,
    poNumber: row.poNumber,
    supplierId: row.supplierId,
    status: row.status as import("@technopro/shared").PurchaseOrderStatus,
    expectedDeliveryDate: row.expectedDeliveryDate ? (row.expectedDeliveryDate as Date).toISOString() : null,
    totalCost: row.totalCost,
    notes: row.notes,
    supplier: row.supplier ? { ...row.supplier, createdAt: row.supplier.createdAt.toISOString(), updatedAt: row.supplier.updatedAt.toISOString() } : undefined,
    createdAt: row.createdAt.toISOString(),
    updatedAt: row.updatedAt.toISOString(),
    items: row.items.map((i: any) => ({
      id: i.id,
      poId: i.poId,
      inventoryItemId: i.inventoryItemId,
      supplierItemId: i.supplierItemId,
      supplierSku: i.supplierSku,
      description: i.description,
      quantity: i.quantity,
      receivedQty: i.receivedQty,
      cancelledQty: i.cancelledQty,
      unitCost: i.unitCost,
      totalCost: (i.quantity * parseFloat(i.unitCost)).toFixed(2),
      totalMarginCalc: i.totalMarginCalc,
      createdAt: i.createdAt.toISOString(),
      inventoryItem: i.inventoryItem ? { ...i.inventoryItem, cost: i.inventoryItem.cost.toString(), price: i.inventoryItem.price.toString(), createdAt: i.inventoryItem.createdAt.toISOString(), updatedAt: i.inventoryItem.updatedAt.toISOString() } : null,
    }))
  };
}

const createSchema = {
  body: {
    type: "object",
    required: ["supplierId", "items"],
    properties: {
      supplierId: { type: "string" },
      expectedDeliveryDate: { type: "string", format: "date-time" },
      notes: { type: "string" },
      items: {
        type: "array",
        minItems: 1,
        items: {
          type: "object",
          required: ["quantity", "unitCost"],
          properties: {
            inventoryItemId: { type: "string" },
            supplierItemId: { type: "string" },
            description: { type: "string" },
            quantity: { type: "integer", minimum: 1 },
            unitCost: { type: "string" }
          },
          anyOf: [
            { required: ["inventoryItemId"] },
            { required: ["description"] }
          ]
        }
      }
    },
    additionalProperties: false,
  },
} as const;

const updateSchema = {
  body: {
    type: "object",
    properties: {
      // Receipt and cancellation status changes must use the reconciled
      // receiving endpoint so a PO can never bypass the stock ledger.
      status: { type: "string", enum: ["draft", "ordered"] },
      expectedDeliveryDate: { type: "string", format: "date-time" },
      notes: { type: "string" },
    },
    additionalProperties: false,
  },
} as const;

export async function purchaseOrderRoutes(app: FastifyInstance) {
  app.addHook("preHandler", app.authenticate);

  app.get<{ Querystring: { page?: number; pageSize?: number; search?: string } }>(
    "/purchase-orders",
    { preHandler: app.requireRole(...rolePolicies.manager) },
    async (request, reply) => {
      const { page, pageSize } = parsePagination(request.query);
      const { rows, totalCount } = await listPurchaseOrders({
        page,
        pageSize,
        search: request.query.search,
      });
      return reply.send({
        data: rows.map(r => ({
          id: r.id,
          poNumber: r.poNumber,
          supplierId: r.supplierId,
          supplierName: (r as any).supplierName,
          status: r.status as import("@technopro/shared").PurchaseOrderStatus,
          expectedDeliveryDate: r.expectedDeliveryDate ? (r.expectedDeliveryDate as Date).toISOString() : null,
          totalCost: r.totalCost,
          notes: r.notes,
          createdAt: r.createdAt.toISOString(),
          updatedAt: r.updatedAt.toISOString(),
        })),
        pagination: paginationMeta(page, pageSize, totalCount),
      });
    },
  );

  app.get<{ Params: { id: string } }>("/purchase-orders/:id", { preHandler: app.requireRole(...rolePolicies.manager) }, async (request, reply) => {
    const item = await getPurchaseOrderById(request.params.id);
    if (!item) {
      return reply.code(404).send({ error: { code: "NOT_FOUND", message: "Purchase Order not found" } });
    }
    return reply.send({ data: toResponse(item) });
  });

  app.post<{ Body: CreatePurchaseOrderRequest }>(
    "/purchase-orders",
    { schema: createSchema, preHandler: app.requireRole(...rolePolicies.manager) },
    async (request, reply) => {
      const item = await createPurchaseOrder(request.body);
      await recordAuditEvent("purchase_order", item.id, "created", request.user.id, {
        after: toResponse(item),
      });
      return reply.code(201).send({ data: toResponse(item) });
    },
  );

  app.patch<{ Params: { id: string }; Body: UpdatePurchaseOrderRequest }>(
    "/purchase-orders/:id",
    { schema: updateSchema, preHandler: app.requireRole(...rolePolicies.manager) },
    async (request, reply) => {
      try {
        const before = await getPurchaseOrderById(request.params.id);
        const item = await updatePurchaseOrder(request.params.id, request.body);
        if (!item) {
          return reply.code(404).send({ error: { code: "NOT_FOUND", message: "Purchase Order not found" } });
        }
        await recordAuditEvent("purchase_order", item.id, "updated", request.user.id, {
          before: before ? toResponse(before) : null,
          after: toResponse(item),
        });
        return reply.send({ data: toResponse(item) });
      } catch (err: any) {
        return reply.code(400).send({ error: { code: "BAD_REQUEST", message: err.message } });
      }
    },
  );

  app.post<{ Params: { id: string }; Body: import("@technopro/shared").ReceivePurchaseOrderRequest }>(
    "/purchase-orders/:id/receive", 
    { schema: { body: { type: "object", required: ["receiptReference", "lines"], properties: { receiptReference: { type: "string", minLength: 1, maxLength: 100 }, lines: { type: "array", minItems: 1, items: { type: "object", required: ["poItemId", "receivedQty"], properties: { poItemId: { type: "string" }, receivedQty: { type: "integer", minimum: 0 }, cancelledQty: { type: "integer", minimum: 0 }, unitCost: { type: "string", pattern: "^\\d+\\.\\d{2}$" }, reasonCode: { type: "string", maxLength: 100 }, reasonNote: { type: "string", maxLength: 2000 } } } } }, additionalProperties: false } }, preHandler: app.requireRole(...rolePolicies.manager) },
    async (request, reply) => {
      try {
        const before = await getPurchaseOrderById(request.params.id);
        const item = await receivePurchaseOrder(request.params.id, request.user.id, request.body);
        await recordAuditEvent("purchase_order", item.id, "received", request.user.id, {
          before: before ? toResponse(before) : null,
          after: toResponse(item),
        });
        return reply.send({ data: toResponse(item) });
      } catch (err: any) {
        return reply.code(400).send({ error: { code: "BAD_REQUEST", message: err.message } });
      }
  });
}
