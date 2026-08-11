import { desc, eq } from "drizzle-orm";
import { getDb, schema } from "../db/index.js";
import { generateId } from "../utils/id.js";
import { decimalToHundredths, hundredthsToDecimal } from "../utils/money.js";

export type StockMovementSource =
  | "opening_balance"
  | "po_receipt"
  | "adjustment"
  | "sale"
  | "sale_reversal"
  | "return_to_supplier"
  | "stocktake"
  | "transfer";

export interface ApplyStockMovementInput {
  inventoryItemId: string;
  quantityDelta: number;
  unitCost: string;
  sourceType: StockMovementSource;
  sourceReference: string;
  reasonCode: string;
  reasonNote?: string;
  actorUserId?: string | null;
  occurredAt?: Date;
}

function assertMovementInput(input: ApplyStockMovementInput) {
  if (!Number.isSafeInteger(input.quantityDelta) || input.quantityDelta === 0) {
    throw new Error("Stock movement quantity must be a non-zero integer");
  }
  if (!input.sourceReference.trim() || !input.reasonCode.trim()) {
    throw new Error("Stock movements require a source reference and reason");
  }
  if (decimalToHundredths(input.unitCost) < 0n) {
    throw new Error("Stock movement unit cost cannot be negative");
  }
}

/**
 * Applies an append-only movement and the cached on-hand balance atomically.
 * Re-using a source reference returns the original movement, which makes
 * receipt/import retries safe.
 */
export async function applyStockMovement(input: ApplyStockMovementInput) {
  assertMovementInput(input);
  const db = getDb();
  return db.transaction(async (tx) => applyStockMovementInTransaction(tx, input));
}

/** Used by import and procurement transactions so the movement and its source
 * document commit or roll back together. */
export async function applyStockMovementInTransaction(tx: any, input: ApplyStockMovementInput) {
    assertMovementInput(input);
    const [existing] = await tx
      .select()
      .from(schema.stockMovements)
      .where(eq(schema.stockMovements.sourceReference, input.sourceReference))
      .limit(1)
      .for("update");
    if (existing) return existing;

    const [item] = await tx
      .select()
      .from(schema.inventoryItems)
      .where(eq(schema.inventoryItems.id, input.inventoryItemId))
      .limit(1)
      .for("update");
    if (!item) throw new Error("Inventory item not found");
    if (item.stockQty === null) throw new Error("This item does not track stock");

    const balanceAfter = item.stockQty + input.quantityDelta;
    if (balanceAfter < 0) throw new Error("Insufficient stock");

    const previousCost = decimalToHundredths(item.cost.toString());
    const movementCost = decimalToHundredths(input.unitCost);
    const valueDelta = movementCost * BigInt(input.quantityDelta);
    // A positive movement changes weighted average cost. Outbound movements
    // retain the existing average cost rather than revaluing stock.
    const averageCostAfter = input.quantityDelta > 0
      ? (previousCost * BigInt(item.stockQty) + movementCost * BigInt(input.quantityDelta)) / BigInt(balanceAfter)
      : previousCost;
    const id = generateId();
    const movement = {
      id,
      inventoryItemId: item.id,
      quantityDelta: input.quantityDelta,
      unitCost: hundredthsToDecimal(movementCost),
      valueDelta: hundredthsToDecimal(valueDelta),
      balanceAfter,
      averageCostAfter: hundredthsToDecimal(averageCostAfter),
      sourceType: input.sourceType,
      sourceReference: input.sourceReference.trim(),
      reasonCode: input.reasonCode.trim(),
      reasonNote: input.reasonNote?.trim() || null,
      actorUserId: input.actorUserId ?? null,
      occurredAt: input.occurredAt ?? new Date(),
    } as const;
    await tx.insert(schema.stockMovements).values(movement);
    await tx.update(schema.inventoryItems).set({
      stockQty: balanceAfter,
      cost: movement.averageCostAfter,
    }).where(eq(schema.inventoryItems.id, item.id));
    return { ...movement, createdAt: new Date() };
}

export async function listStockMovements(inventoryItemId: string, limit = 100) {
  return getDb().select().from(schema.stockMovements)
    .where(eq(schema.stockMovements.inventoryItemId, inventoryItemId))
    .orderBy(desc(schema.stockMovements.occurredAt), desc(schema.stockMovements.id))
    .limit(limit);
}
