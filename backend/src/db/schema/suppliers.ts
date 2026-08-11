import { char, mysqlTable, varchar, text, int, decimal, timestamp, mysqlEnum, date } from "drizzle-orm/mysql-core";
import { inventoryItems } from "./inventory.js";
import { relations } from "drizzle-orm";

export const suppliers = mysqlTable("suppliers", {
  id: char("id", { length: 36 }).primaryKey(),
  name: varchar("name", { length: 255 }).notNull(),
  contactName: varchar("contact_name", { length: 255 }),
  email: varchar("email", { length: 255 }),
  phone: varchar("phone", { length: 50 }),
  accountNumber: varchar("account_number", { length: 100 }),
  leadTimeDays: int("lead_time_days"),
  notes: text("notes"),
  createdAt: timestamp("created_at").notNull().defaultNow(),
  updatedAt: timestamp("updated_at").notNull().defaultNow().onUpdateNow(),
});

export const supplierItems = mysqlTable("supplier_items", {
  id: char("id", { length: 36 }).primaryKey(),
  supplierId: char("supplier_id", { length: 36 }).notNull().references(() => suppliers.id),
  inventoryItemId: char("inventory_item_id", { length: 36 }).notNull().references(() => inventoryItems.id),
  supplierSku: varchar("supplier_sku", { length: 100 }),
  supplierUpc: varchar("supplier_upc", { length: 32 }),
  supplierPartNumber: varchar("supplier_part_number", { length: 100 }),
  productUrl: varchar("product_url", { length: 1000 }),
  packSize: int("pack_size").notNull().default(1),
  minimumOrderQty: int("minimum_order_qty").notNull().default(1),
  quotedUnitCost: decimal("quoted_unit_cost", { precision: 10, scale: 2 }),
  lastPaidUnitCost: decimal("last_paid_unit_cost", { precision: 10, scale: 2 }),
  leadTimeDays: int("lead_time_days"),
  preferred: int("preferred").notNull().default(0),
  active: int("active").notNull().default(1),
  createdAt: timestamp("created_at").notNull().defaultNow(),
  updatedAt: timestamp("updated_at").notNull().defaultNow().onUpdateNow(),
});

export const purchaseOrders = mysqlTable("purchase_orders", {
  id: char("id", { length: 36 }).primaryKey(),
  poNumber: varchar("po_number", { length: 50 }).notNull().unique(),
  supplierId: char("supplier_id", { length: 36 }).notNull().references(() => suppliers.id),
  status: mysqlEnum("status", ["draft", "ordered", "partially_received", "received", "cancelled"]).notNull().default("draft"),
  expectedDeliveryDate: date("expected_delivery_date"),
  totalCost: decimal("total_cost", { precision: 10, scale: 2 }).notNull().default("0.00"),
  notes: text("notes"),
  createdAt: timestamp("created_at").notNull().defaultNow(),
  updatedAt: timestamp("updated_at").notNull().defaultNow().onUpdateNow(),
});

export const poItems = mysqlTable("po_items", {
  id: char("id", { length: 36 }).primaryKey(),
  poId: char("po_id", { length: 36 }).notNull().references(() => purchaseOrders.id, { onDelete: "cascade" }),
  inventoryItemId: char("inventory_item_id", { length: 36 }).references(() => inventoryItems.id),
  supplierItemId: char("supplier_item_id", { length: 36 }).references(() => supplierItems.id),
  supplierSku: varchar("supplier_sku", { length: 100 }),
  description: text("description"), // Stores name/details for one-off items or snapshots
  quantity: int("quantity").notNull().default(1),
  receivedQty: int("received_qty").notNull().default(0),
  cancelledQty: int("cancelled_qty").notNull().default(0),
  unitCost: decimal("unit_cost", { precision: 10, scale: 2 }).notNull().default("0.00"),
  totalMarginCalc: decimal("total_margin_calc", { precision: 10, scale: 2 }),
  createdAt: timestamp("created_at").notNull().defaultNow(),
  updatedAt: timestamp("updated_at").notNull().defaultNow().onUpdateNow(),
});

/** Immutable confirmation for every PO-line receipt or cancellation. This
 * makes a supplier delivery reference idempotent even for non-tracked items. */
export const purchaseOrderReceiptLines = mysqlTable("purchase_order_receipt_lines", {
  id: char("id", { length: 36 }).primaryKey(),
  poItemId: char("po_item_id", { length: 36 }).notNull().references(() => poItems.id),
  receiptReference: varchar("receipt_reference", { length: 100 }).notNull(),
  receivedQty: int("received_qty").notNull().default(0),
  cancelledQty: int("cancelled_qty").notNull().default(0),
  createdAt: timestamp("created_at").notNull().defaultNow(),
});

export const suppliersRelations = relations(suppliers, ({ many }) => ({
  purchaseOrders: many(purchaseOrders),
}));

export const purchaseOrdersRelations = relations(purchaseOrders, ({ one, many }) => ({
  supplier: one(suppliers, {
    fields: [purchaseOrders.supplierId],
    references: [suppliers.id],
  }),
  items: many(poItems),
}));

export const poItemsRelations = relations(poItems, ({ one }) => ({
  purchaseOrder: one(purchaseOrders, {
    fields: [poItems.poId],
    references: [purchaseOrders.id],
  }),
  inventoryItem: one(inventoryItems, {
    fields: [poItems.inventoryItemId],
    references: [inventoryItems.id],
  }),
}));
