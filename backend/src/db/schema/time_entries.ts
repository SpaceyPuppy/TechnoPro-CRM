import { char, mysqlTable, varchar, int, decimal, timestamp } from "drizzle-orm/mysql-core";
import { tickets } from "./tickets";
import { users } from "./users";
import { lineItems } from "./billing";

export const timeEntries = mysqlTable("time_entries", {
  id: char("id", { length: 36 }).primaryKey(),
  ticketId: char("ticket_id", { length: 36 })
    .notNull()
    .references(() => tickets.id),
  userId: char("user_id", { length: 36 })
    .notNull()
    .references(() => users.id),
  startedAt: timestamp("started_at").notNull(),
  stoppedAt: timestamp("stopped_at"),
  durationSeconds: int("duration_seconds"),
  note: varchar("note", { length: 500 }),
  labourRate: decimal("labour_rate", { precision: 10, scale: 2 }).notNull(),
  billedAs: char("billed_as", { length: 36 }).references(() => lineItems.id),
  createdAt: timestamp("created_at").notNull().defaultNow(),
  updatedAt: timestamp("updated_at").notNull().defaultNow().onUpdateNow(),
});
