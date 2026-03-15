import { char, mysqlTable, varchar, text, int, decimal, timestamp } from "drizzle-orm/mysql-core";

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
