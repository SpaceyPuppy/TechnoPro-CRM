import { char, mysqlEnum, mysqlTable, varchar, text, int, decimal, timestamp, index, uniqueIndex } from "drizzle-orm/mysql-core";
import { users } from "./users.js";

export const inventoryItems = mysqlTable("inventory_items", {
  id: char("id", { length: 36 }).primaryKey(),
  sku: varchar("sku", { length: 100 }).notNull().unique(),
  name: varchar("name", { length: 255 }).notNull(),
  description: text("description"),
  stockQty: int("stock_qty"), // null = stock not tracked; number = tracked quantity
  cost: decimal("cost", { precision: 10, scale: 2 }).notNull().default("0.00"),
  price: decimal("price", { precision: 10, scale: 2 }).notNull().default("0.00"),
  barcode: varchar("barcode", { length: 255 }),
  createdAt: timestamp("created_at").notNull().defaultNow(),
  updatedAt: timestamp("updated_at").notNull().defaultNow().onUpdateNow(),
});

/**
 * Append-only record of every confirmed quantity or value movement.  The
 * inventory item still keeps a cached balance for fast reads, but the ledger
 * is the source of truth for how that balance changed.
 */
export const stockMovements = mysqlTable("stock_movements", {
  id: char("id", { length: 36 }).primaryKey(),
  inventoryItemId: char("inventory_item_id", { length: 36 })
    .notNull()
    .references(() => inventoryItems.id),
  quantityDelta: int("quantity_delta").notNull(),
  unitCost: decimal("unit_cost", { precision: 10, scale: 2 }).notNull(),
  valueDelta: decimal("value_delta", { precision: 12, scale: 2 }).notNull(),
  balanceAfter: int("balance_after").notNull(),
  averageCostAfter: decimal("average_cost_after", { precision: 10, scale: 2 }).notNull(),
  sourceType: mysqlEnum("source_type", [
    "opening_balance",
    "po_receipt",
    "adjustment",
    "sale",
    "sale_reversal",
    "return_to_supplier",
    "stocktake",
    "transfer",
  ]).notNull(),
  /** A caller-supplied idempotency key such as `po-receipt:<line>:<receipt>`. */
  sourceReference: varchar("source_reference", { length: 191 }).notNull(),
  reasonCode: varchar("reason_code", { length: 100 }).notNull(),
  reasonNote: text("reason_note"),
  actorUserId: char("actor_user_id", { length: 36 }).references(() => users.id),
  occurredAt: timestamp("occurred_at").notNull().defaultNow(),
  createdAt: timestamp("created_at").notNull().defaultNow(),
}, (table) => [
  index("stock_movements_item_occurred_idx").on(table.inventoryItemId, table.occurredAt, table.id),
  uniqueIndex("stock_movements_source_reference_unique").on(table.sourceReference),
]);
