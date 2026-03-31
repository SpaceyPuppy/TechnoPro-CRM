import { mysqlTable, varchar, text } from "drizzle-orm/mysql-core";

export const appSettings = mysqlTable("app_settings", {
  key: varchar("key", { length: 100 }).primaryKey(),
  value: text("value").notNull(),
});
