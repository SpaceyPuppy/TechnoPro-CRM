import { eq, like, and, or, sql, desc } from "drizzle-orm";
import { getDb, schema } from "../db/index.js";
import { getTableColumns } from "drizzle-orm";
import { generateId } from "../utils/id.js";
import type { CreateTicketRequest, UpdateTicketRequest, TicketStatus, UserRole } from "@technopro/shared";
import { createInvoiceWithItems } from "./invoice.service.js";

// Generate sequential ticket numbers: TK-000001, TK-000002, etc.
async function nextTicketNumber(): Promise<string> {
  const db = getDb();
  const result = await db
    .select({ ticketNumber: schema.tickets.ticketNumber })
    .from(schema.tickets)
    .orderBy(desc(schema.tickets.createdAt))
    .limit(1);

  if (result.length === 0) return "TK-000001";

  const last = result[0]!.ticketNumber;
  const num = parseInt(last.replace("TK-", ""), 10) + 1;
  return `TK-${num.toString().padStart(6, "0")}`;
}

export async function listTickets(options: {
  page: number;
  pageSize: number;
  search?: string;
  status?: string;
  assignedToId?: string;
  customerId?: string;
}) {
  const db = getDb();
  const { page, pageSize, search, status, assignedToId, customerId } = options;
  const offset = (page - 1) * pageSize;

  const filters = [];
  if (search) {
    filters.push(
      or(
        like(schema.tickets.ticketNumber, `%${search}%`),
        like(schema.tickets.summary, `%${search}%`),
      ),
    );
  }
  if (status) filters.push(eq(schema.tickets.status, status as TicketStatus));
  if (assignedToId) filters.push(eq(schema.tickets.assignedToId, assignedToId));
  if (customerId) filters.push(eq(schema.tickets.customerId, customerId));

  const conditions = filters.length > 0 ? and(...filters) : undefined;

  const [rows, countResult] = await Promise.all([
    db
      .select()
      .from(schema.tickets)
      .where(conditions)
      .orderBy(desc(schema.tickets.createdAt))
      .limit(pageSize)
      .offset(offset),
    db
      .select({ count: sql<number>`count(*)` })
      .from(schema.tickets)
      .where(conditions),
  ]);

  return { rows, totalCount: countResult[0]?.count ?? 0 };
}

export async function getTicketById(id: string) {
  const db = getDb();
  const results = await db
    .select()
    .from(schema.tickets)
    .where(eq(schema.tickets.id, id))
    .limit(1);
  return results[0] ?? null;
}

export async function getTicketDetails(id: string) {
  const db = getDb();
  const [ticket] = await db
    .select({
      ...getTableColumns(schema.tickets),
      customer: {
        id: schema.customers.id,
        name: schema.customers.name,
        firstName: schema.customers.firstName,
        lastName: schema.customers.lastName,
        company: schema.customers.company,
        email: schema.customers.email,
        phone: schema.customers.phone,
        address: schema.customers.address,
        notes: schema.customers.notes,
        createdAt: schema.customers.createdAt,
        updatedAt: schema.customers.updatedAt,
      },
      device: {
        id: schema.devices.id,
        customerId: schema.devices.customerId,
        type: schema.devices.type,
        brand: schema.devices.brand,
        model: schema.devices.model,
        serial: schema.devices.serial,
        imei: schema.devices.imei,
        password: schema.devices.password,
        patternLock: schema.devices.patternLock,
        storage: schema.devices.storage,
        color: schema.devices.color,
        carrier: schema.devices.carrier,
        notes: schema.devices.notes,
        createdAt: schema.devices.createdAt,
        updatedAt: schema.devices.updatedAt,
      },
      assignedTo: {
        id: schema.users.id,
        email: schema.users.email,
        name: schema.users.name,
        role: schema.users.role,
        active: schema.users.active,
        createdAt: schema.users.createdAt,
      },
    })
    .from(schema.tickets)
    .innerJoin(schema.customers, eq(schema.tickets.customerId, schema.customers.id))
    .leftJoin(schema.devices, eq(schema.tickets.deviceId, schema.devices.id))
    .leftJoin(schema.users, eq(schema.tickets.assignedToId, schema.users.id))
    .where(eq(schema.tickets.id, id))
    .limit(1);
  return ticket ?? null;
}

export async function createTicket(data: CreateTicketRequest, createdByUserId: string) {
  const db = getDb();
  const id = generateId();
  const ticketNumber = await nextTicketNumber();

  // Optionally create a new device record
  let deviceId = data.deviceId ?? null;
  if (!deviceId && data.device) {
    deviceId = generateId();
    await db.insert(schema.devices).values({
      id: deviceId,
      customerId: data.customerId,
      brand: data.device.brand ?? null,
      model: data.device.model ?? null,
      serial: data.device.serial ?? null,
      imei: data.device.imei ?? null,
      password: data.device.password ?? null,
      patternLock: data.device.patternLock ?? null,
      storage: data.device.storage ?? null,
      color: data.device.color ?? null,
      carrier: data.device.carrier ?? null,
    });
  }

  await db.insert(schema.tickets).values({
    id,
    ticketNumber,
    customerId: data.customerId,
    deviceId,
    assignedToId: data.assignedToId ?? null,
    ticketType: data.ticketType ?? "repair",
    priority: data.priority ?? "normal",
    summary: data.summary,
    description: data.description ?? null,
    serviceLocation: data.serviceLocation ?? null,
    scheduledAt: data.scheduledAt ? new Date(data.scheduledAt) : null,
    dueDate: data.dueDate ? new Date(data.dueDate) : null,
  });

  await createTicketEvent(id, createdByUserId, "system", `Ticket ${ticketNumber} created`);

  if (data.assignedToId) {
    await createTicketEvent(
      id,
      createdByUserId,
      "assignment",
      `Ticket assigned to user ${data.assignedToId}`,
    );
  }

  // Optionally create invoice with repair line items
  if (data.repairs && data.repairs.length > 0) {
    await createInvoiceWithItems(id, data.repairs);
  }

  return getTicketById(id);
}

export async function updateTicket(
  id: string,
  data: UpdateTicketRequest,
  updatedByUserId: string,
  updatedByRole: UserRole,
) {
  const db = getDb();
  const existing = await getTicketById(id);
  if (!existing) return null;

  const updates: Record<string, unknown> = {};
  if (data.summary !== undefined) updates.summary = data.summary;
  if (data.description !== undefined) updates.description = data.description;
  if (data.serviceLocation !== undefined) updates.serviceLocation = data.serviceLocation;
  if (data.diagnosis !== undefined) updates.diagnosis = data.diagnosis;
  if (data.resolution !== undefined) updates.resolution = data.resolution;
  if (data.ticketType !== undefined) updates.ticketType = data.ticketType;
  if (data.priority !== undefined) updates.priority = data.priority;
  if (data.scheduledAt !== undefined) {
    updates.scheduledAt = data.scheduledAt ? new Date(data.scheduledAt) : null;
  }
  if (data.dueDate !== undefined) updates.dueDate = data.dueDate ? new Date(data.dueDate) : null;

  // Status change â€” auto-create event
  if (data.status !== undefined && data.status !== existing.status) {
    assertTicketStatusTransition(existing.status, data.status, updatedByRole);
    updates.status = data.status;
    await createTicketEvent(
      id,
      updatedByUserId,
      "status_change",
      `Status changed from "${existing.status}" to "${data.status}"`,
    );
  }

  // Assignment change â€” auto-create event
  if (data.assignedToId !== undefined && data.assignedToId !== existing.assignedToId) {
    if (updatedByRole !== "manager" && updatedByRole !== "admin") {
      throw new TicketConflictError("Only managers can change ticket assignments", "ASSIGNMENT_FORBIDDEN");
    }
    updates.assignedToId = data.assignedToId;
    const msg = data.assignedToId
      ? `Ticket reassigned to user ${data.assignedToId}`
      : "Ticket unassigned";
    await createTicketEvent(id, updatedByUserId, "assignment", msg);
  }

  if (Object.keys(updates).length > 0) {
    await db.update(schema.tickets).set(updates).where(eq(schema.tickets.id, id));
  }

  return getTicketById(id);
}

export class TicketConflictError extends Error {
  readonly statusCode = 409;

  constructor(message: string, readonly code: string) {
    super(message);
    this.name = "TicketConflictError";
  }
}

const allowedStatusTransitions: Record<TicketStatus, readonly TicketStatus[]> = {
  new: ["triage", "scheduled", "cancelled"],
  triage: ["scheduled", "in_progress", "awaiting_customer", "awaiting_parts", "cancelled"],
  scheduled: ["triage", "in_progress", "cancelled"],
  in_progress: ["awaiting_customer", "awaiting_parts", "ready", "resolved", "cancelled"],
  awaiting_customer: ["in_progress", "ready", "resolved", "cancelled"],
  awaiting_parts: ["in_progress", "ready", "cancelled"],
  ready: ["in_progress", "resolved", "closed", "cancelled"],
  resolved: ["in_progress", "ready", "closed"],
  closed: [],
  cancelled: [],
};

export function assertTicketStatusTransition(
  current: TicketStatus,
  next: TicketStatus,
  role: UserRole,
) {
  if (!allowedStatusTransitions[current].includes(next)) {
    throw new TicketConflictError(
      `Cannot change a ${current} ticket directly to ${next}`,
      "INVALID_STATUS_TRANSITION",
    );
  }
  if ((next === "closed" || next === "cancelled") && role !== "manager" && role !== "admin") {
    throw new TicketConflictError(
      "Only managers can close or cancel tickets",
      "TERMINAL_STATUS_FORBIDDEN",
    );
  }
}

export async function getTicketEvents(ticketId: string) {
  const db = getDb();
  return db
    .select()
    .from(schema.ticketEvents)
    .where(eq(schema.ticketEvents.ticketId, ticketId))
    .orderBy(desc(schema.ticketEvents.createdAt));
}

export async function listTicketEvents(page: number, pageSize: number) {
  const db = getDb();
  return db
    .select()
    .from(schema.ticketEvents)
    .orderBy(desc(schema.ticketEvents.createdAt))
    .limit(pageSize)
    .offset((page - 1) * pageSize);
}

export async function createTicketEvent(
  ticketId: string,
  userId: string,
  eventType: "status_change" | "note" | "assignment" | "system",
  content: string,
) {
  const db = getDb();
  await db.insert(schema.ticketEvents).values({
    id: generateId(),
    ticketId,
    userId,
    eventType,
    content,
  });
}

export async function addTicketNote(ticketId: string, userId: string, content: string) {
  await createTicketEvent(ticketId, userId, "note", content);
}

export async function listTicketChecklist(ticketId: string) {
  const db = getDb();
  return db
    .select()
    .from(schema.ticketChecklistItems)
    .where(eq(schema.ticketChecklistItems.ticketId, ticketId))
    .orderBy(schema.ticketChecklistItems.sortOrder, schema.ticketChecklistItems.createdAt);
}

export async function addTicketChecklistItem(
  ticketId: string,
  userId: string,
  content: string,
) {
  const db = getDb();
  const id = generateId();
  const [{ nextOrder }] = await db
    .select({
      nextOrder: sql<number>`COALESCE(MAX(${schema.ticketChecklistItems.sortOrder}), -1) + 1`,
    })
    .from(schema.ticketChecklistItems)
    .where(eq(schema.ticketChecklistItems.ticketId, ticketId));
  await db.insert(schema.ticketChecklistItems).values({
    id,
    ticketId,
    content,
    sortOrder: Number(nextOrder ?? 0),
  });
  await createTicketEvent(ticketId, userId, "system", `Checklist item added: ${content}`);
  const [created] = await db
    .select()
    .from(schema.ticketChecklistItems)
    .where(eq(schema.ticketChecklistItems.id, id))
    .limit(1);
  return created!;
}

export async function updateTicketChecklistItem(
  ticketId: string,
  itemId: string,
  userId: string,
  updates: { content?: string; completed?: boolean },
) {
  const db = getDb();
  const [existing] = await db
    .select()
    .from(schema.ticketChecklistItems)
    .where(
      and(
        eq(schema.ticketChecklistItems.id, itemId),
        eq(schema.ticketChecklistItems.ticketId, ticketId),
      ),
    )
    .limit(1);
  if (!existing) return null;
  await db
    .update(schema.ticketChecklistItems)
    .set(updates)
    .where(eq(schema.ticketChecklistItems.id, itemId));
  if (updates.completed !== undefined && updates.completed !== existing.completed) {
    await createTicketEvent(
      ticketId,
      userId,
      "system",
      `Checklist item ${updates.completed ? "completed" : "reopened"}: ${existing.content}`,
    );
  }
  const [updated] = await db
    .select()
    .from(schema.ticketChecklistItems)
    .where(eq(schema.ticketChecklistItems.id, itemId))
    .limit(1);
  return updated!;
}

export async function deleteTicketChecklistItem(
  ticketId: string,
  itemId: string,
  userId: string,
) {
  const db = getDb();
  const [existing] = await db
    .select()
    .from(schema.ticketChecklistItems)
    .where(
      and(
        eq(schema.ticketChecklistItems.id, itemId),
        eq(schema.ticketChecklistItems.ticketId, ticketId),
      ),
    )
    .limit(1);
  if (!existing) return false;
  await db
    .delete(schema.ticketChecklistItems)
    .where(eq(schema.ticketChecklistItems.id, itemId));
  await createTicketEvent(ticketId, userId, "system", `Checklist item removed: ${existing.content}`);
  return true;
}
