import type { FastifyInstance } from "fastify";
import { getInventoryItemById } from "../services/inventory.service.js";
import { applyStockMovement, listStockMovements, type StockMovementSource } from "../services/stock.service.js";
import { recordAuditEvent } from "../services/audit.service.js";

const sources = ["opening_balance", "adjustment", "return_to_supplier", "stocktake"] as const;

const adjustmentSchema = {
  body: {
    type: "object",
    required: ["quantityDelta", "unitCost", "reasonCode", "sourceReference"],
    properties: {
      quantityDelta: { type: "integer", minimum: -1000000, maximum: 1000000, not: { const: 0 } },
      unitCost: { type: "string", pattern: "^\\d+\\.\\d{2}$" },
      reasonCode: { type: "string", minLength: 1, maxLength: 100 },
      reasonNote: { type: "string", maxLength: 2000 },
      sourceReference: { type: "string", minLength: 1, maxLength: 191 },
      sourceType: { type: "string", enum: sources },
    },
    additionalProperties: false,
  },
} as const;

export async function stockRoutes(app: FastifyInstance) {
  app.get<{ Params: { id: string } }>("/inventory/:id/movements", { preHandler: app.requireRole("manager", "admin") }, async (request, reply) => {
    if (!await getInventoryItemById(request.params.id)) {
      return reply.code(404).send({ error: { code: "NOT_FOUND", message: "Item not found" } });
    }
    const movements = await listStockMovements(request.params.id);
    return reply.send({ data: movements.map((movement) => ({
      ...movement,
      unitCost: movement.unitCost.toString(),
      valueDelta: movement.valueDelta.toString(),
      averageCostAfter: movement.averageCostAfter.toString(),
      occurredAt: movement.occurredAt.toISOString(),
      createdAt: movement.createdAt.toISOString(),
    })) });
  });

  app.post<{ Params: { id: string }; Body: { quantityDelta: number; unitCost: string; reasonCode: string; reasonNote?: string; sourceReference: string; sourceType?: typeof sources[number] } }>(
    "/inventory/:id/adjustments",
    { schema: adjustmentSchema, preHandler: app.requireRole("manager", "admin") },
    async (request, reply) => {
      try {
        const movement = await applyStockMovement({
          inventoryItemId: request.params.id,
          quantityDelta: request.body.quantityDelta,
          unitCost: request.body.unitCost,
          sourceType: (request.body.sourceType ?? "adjustment") as StockMovementSource,
          sourceReference: request.body.sourceReference,
          reasonCode: request.body.reasonCode,
          reasonNote: request.body.reasonNote,
          actorUserId: request.user.id,
        });
        await recordAuditEvent("inventory_item", request.params.id, "stock_adjusted", request.user.id, {
          movementId: movement.id,
          sourceReference: movement.sourceReference,
        });
        return reply.code(201).send({ data: movement });
      } catch (error) {
        const message = error instanceof Error ? error.message : "Unable to adjust stock";
        return reply.code(message === "Inventory item not found" ? 404 : 400).send({ error: { code: "STOCK_ADJUSTMENT_FAILED", message } });
      }
    },
  );
}
