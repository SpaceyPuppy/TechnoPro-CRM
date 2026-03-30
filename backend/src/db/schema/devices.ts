import { char, mysqlTable, varchar, text, timestamp } from "drizzle-orm/mysql-core";
import { customers } from "./customers";

export const devices = mysqlTable("devices", {
  id: char("id", { length: 36 }).primaryKey(),
  customerId: char("customer_id", { length: 36 })
    .notNull()
    .references(() => customers.id),
  type: varchar("type", { length: 100 }),
  brand: varchar("brand", { length: 100 }),
  model: varchar("model", { length: 100 }),
  serial: varchar("serial", { length: 255 }),
  imei: varchar("imei", { length: 20 }),
  password: text("password"),
  patternLock: varchar("pattern_lock", { length: 100 }),
  storage: varchar("storage", { length: 50 }),
  color: varchar("color", { length: 50 }),
  carrier: varchar("carrier", { length: 100 }),
  notes: text("notes"),
  createdAt: timestamp("created_at").notNull().defaultNow(),
  updatedAt: timestamp("updated_at").notNull().defaultNow().onUpdateNow(),
});
