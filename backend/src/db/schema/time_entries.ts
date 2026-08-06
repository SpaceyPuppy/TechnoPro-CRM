import { boolean, char, mysqlTable, varchar, int, decimal, timestamp } from "drizzle-orm/mysql-core";
import { tickets } from "./tickets.js";
import { users } from "./users.js";
import { lineItems } from "./billing.js";

export const timeEntries = mysqlTable("time_entries", {
  id: char("id", { length: 36 }).primaryKey(),
  ticketId: char("ticket_id", { length: 36 })
    .notNull()
    .references(() => tickets.id),
  userId: char("user_id", { length: 36 })
    .notNull()
    .references(() => users.id),
  // MySQL permits multiple NULL values in a unique index. A running entry
  // stores its user ID here; stopping it clears the value atomically.
  runningUserId: char("running_user_id", { length: 36 })
    .unique()
    .references(() => users.id),
  startedAt: timestamp("started_at").notNull(),
  stoppedAt: timestamp("stopped_at"),
  durationSeconds: int("duration_seconds"),
  note: varchar("note", { length: 500 }),
  labourRate: decimal("labour_rate", { precision: 10, scale: 2 }).notNull(),
  billable: boolean("billable").notNull().default(true),
  billedAs: char("billed_as", { length: 36 }).references(() => lineItems.id),
  createdAt: timestamp("created_at").notNull().defaultNow(),
  updatedAt: timestamp("updated_at").notNull().defaultNow().onUpdateNow(),
});
