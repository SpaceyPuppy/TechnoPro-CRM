import { char, mysqlTable, varchar, text, int, decimal, timestamp } from "drizzle-orm/mysql-core";
import { tickets } from "./tickets";
import { inventoryItems } from "./inventory";
import { users } from "./users";

export const invoices = mysqlTable("invoices", {
  id: char("id", { length: 36 }).primaryKey(),
  invoiceNumber: varchar("invoice_number", { length: 20 }).notNull().unique(),
  ticketId: char("ticket_id", { length: 36 }).references(() => tickets.id),
  subtotal: decimal("subtotal", { precision: 10, scale: 2 }).notNull().default("0.00"),
  tax: decimal("tax", { precision: 10, scale: 2 }).notNull().default("0.00"),
  total: decimal("total", { precision: 10, scale: 2 }).notNull().default("0.00"),
  status: varchar("status", { length: 20 })
    .notNull()
    .default("draft")
    .$type<"draft" | "open" | "paid" | "void">(),
  createdAt: timestamp("created_at").notNull().defaultNow(),
  updatedAt: timestamp("updated_at").notNull().defaultNow().onUpdateNow(),
});

export const payments = mysqlTable("payments", {
  id: char("id", { length: 36 }).primaryKey(),
  invoiceId: char("invoice_id", { length: 36 })
    .notNull()
    .references(() => invoices.id),
  amount: decimal("amount", { precision: 10, scale: 2 }).notNull(),
  method: varchar("method", { length: 30 })
    .notNull()
    .$type<"cash" | "card" | "eftpos" | "bank_transfer" | "other">(),
  reference: varchar("reference", { length: 255 }),
  createdByUserId: char("created_by_user_id", { length: 36 }).references(() => users.id),
  paidAt: timestamp("paid_at").notNull().defaultNow(),
  createdAt: timestamp("created_at").notNull().defaultNow(),
});

export const lineItems = mysqlTable("line_items", {
  id: char("id", { length: 36 }).primaryKey(),
  ticketId: char("ticket_id", { length: 36 }).references(() => tickets.id),
  invoiceId: char("invoice_id", { length: 36 }).references(() => invoices.id),
  inventoryItemId: char("inventory_item_id", { length: 36 }).references(() => inventoryItems.id),
  type: varchar("type", { length: 20 })
    .notNull()
    .$type<"service" | "part">(),
  description: varchar("description", { length: 500 }).notNull(),
  quantity: int("quantity").notNull().default(1),
  unitPrice: decimal("unit_price", { precision: 10, scale: 2 }).notNull(),
  total: decimal("total", { precision: 10, scale: 2 }).notNull(),
  createdAt: timestamp("created_at").notNull().defaultNow(),
  updatedAt: timestamp("updated_at").notNull().defaultNow().onUpdateNow(),
});
