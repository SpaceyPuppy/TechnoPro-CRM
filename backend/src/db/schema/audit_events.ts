import { char, mysqlTable, text, timestamp, varchar } from "drizzle-orm/mysql-core";

import { users } from "./users.js";

export const auditEvents = mysqlTable("audit_events", {
  id: char("id", { length: 36 }).primaryKey(),
  entityType: varchar("entity_type", { length: 40 }).notNull(),
  entityId: char("entity_id", { length: 36 }).notNull(),
  action: varchar("action", { length: 60 }).notNull(),
  userId: char("user_id", { length: 36 }).references(() => users.id),
  data: text("data"),
  createdAt: timestamp("created_at").notNull().defaultNow(),
});
