import type { FastifyInstance } from "fastify";
import {
  listInventory,
  getInventoryItemById,
  createInventoryItem,
  updateInventoryItem,
  deleteInventoryItem,
} from "../services/inventory.service";
import { parsePagination, paginationMeta } from "../utils/pagination";
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
    { schema: createSchema },
    async (request, reply) => {
      const item = await createInventoryItem(request.body);
      return reply.code(201).send({ data: toResponse(item!) });
    },
  );

  app.patch<{ Params: { id: string }; Body: UpdateInventoryItemRequest }>(
    "/inventory/:id",
    { schema: updateSchema },
    async (request, reply) => {
      const item = await updateInventoryItem(request.params.id, request.body);
      if (!item) {
        return reply.code(404).send({ error: { code: "NOT_FOUND", message: "Item not found" } });
      }
      return reply.send({ data: toResponse(item) });
    },
  );

  app.delete<{ Params: { id: string } }>("/inventory/:id", async (request, reply) => {
    const deleted = await deleteInventoryItem(request.params.id);
    if (!deleted) {
      return reply.code(404).send({ error: { code: "NOT_FOUND", message: "Item not found" } });
    }
    return reply.code(204).send();
  });
}
