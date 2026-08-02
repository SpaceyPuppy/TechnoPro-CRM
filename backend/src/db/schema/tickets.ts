import { char, mysqlTable, varchar, text, timestamp, int } from "drizzle-orm/mysql-core";
import { customers } from "./customers.js";
import { boolean } from "drizzle-orm/mysql-core";
import { devices } from "./devices.js";
import { users } from "./users.js";

export const tickets = mysqlTable("tickets", {
  id: char("id", { length: 36 }).primaryKey(),
  ticketNumber: varchar("ticket_number", { length: 20 }).notNull().unique(),
  customerId: char("customer_id", { length: 36 })
    .notNull()
    .references(() => customers.id),
  deviceId: char("device_id", { length: 36 }).references(() => devices.id),
  assignedToId: char("assigned_to_id", { length: 36 }).references(() => users.id),
  ticketType: varchar("ticket_type", { length: 20 })
    .notNull()
    .default("repair")
    .$type<"repair" | "onsite" | "remote">(),
  status: varchar("status", { length: 30 })
    .notNull()
    .default("new")
    .$type<
      | "new"
      | "triage"
      | "scheduled"
      | "in_progress"
      | "awaiting_customer"
      | "awaiting_parts"
      | "ready"
      | "resolved"
      | "closed"
      | "cancelled"
    >(),
  priority: varchar("priority", { length: 20 })
    .notNull()
    .default("normal")
    .$type<"low" | "normal" | "high" | "urgent">(),
  summary: varchar("summary", { length: 500 }).notNull(),
  description: text("description"),
  serviceLocation: varchar("service_location", { length: 500 }),
  diagnosis: text("diagnosis"),
  resolution: text("resolution"),
  scheduledAt: timestamp("scheduled_at"),
  dueDate: timestamp("due_date"),
  createdAt: timestamp("created_at").notNull().defaultNow(),
  updatedAt: timestamp("updated_at").notNull().defaultNow().onUpdateNow(),
});

export const ticketEvents = mysqlTable("ticket_events", {
  id: char("id", { length: 36 }).primaryKey(),
  ticketId: char("ticket_id", { length: 36 })
    .notNull()
    .references(() => tickets.id),
  userId: char("user_id", { length: 36 }).references(() => users.id),
  eventType: varchar("event_type", { length: 30 })
    .notNull()
    .$type<"status_change" | "note" | "assignment" | "system">(),
  content: text("content"),
  createdAt: timestamp("created_at").notNull().defaultNow(),
});

export const ticketAttachments = mysqlTable("ticket_attachments", {
  id: char("id", { length: 36 }).primaryKey(),
  ticketId: char("ticket_id", { length: 36 })
    .notNull()
    .references(() => tickets.id),
  uploadedById: char("uploaded_by_id", { length: 36 }).references(() => users.id),
  fileName: varchar("file_name", { length: 255 }).notNull(),
  filePath: varchar("file_path", { length: 500 }).notNull(),
  mimeType: varchar("mime_type", { length: 100 }).notNull(),
  fileSize: int("file_size").notNull(),
  createdAt: timestamp("created_at").notNull().defaultNow(),
});

export const ticketChecklistItems = mysqlTable("ticket_checklist_items", {
  id: char("id", { length: 36 }).primaryKey(),
  ticketId: char("ticket_id", { length: 36 })
    .notNull()
    .references(() => tickets.id),
  content: varchar("content", { length: 500 }).notNull(),
  completed: boolean("completed").notNull().default(false),
  sortOrder: int("sort_order").notNull().default(0),
  createdAt: timestamp("created_at").notNull().defaultNow(),
  updatedAt: timestamp("updated_at").notNull().defaultNow().onUpdateNow(),
});
