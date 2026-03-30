import { char, mysqlTable, varchar, int, timestamp } from "drizzle-orm/mysql-core";

export const deviceModels = mysqlTable("device_models", {
  id: char("id", { length: 36 }).primaryKey(),
  manufacturer: varchar("manufacturer", { length: 100 }).notNull(),
  name: varchar("name", { length: 100 }).notNull(),
  sortOrder: int("sort_order").notNull().default(0),
  createdAt: timestamp("created_at").notNull().defaultNow(),
  updatedAt: timestamp("updated_at").notNull().defaultNow().onUpdateNow(),
});
