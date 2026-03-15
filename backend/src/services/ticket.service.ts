import { eq, like, and, or, sql, desc } from "drizzle-orm";
import { getDb, schema } from "../db/index";
import { generateId } from "../utils/id";
import type { CreateTicketRequest, UpdateTicketRequest, TicketStatus } from "@technopro/shared";

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

export async function createTicket(data: CreateTicketRequest, createdByUserId: string) {
  const db = getDb();
  const id = generateId();
  const ticketNumber = await nextTicketNumber();

  await db.insert(schema.tickets).values({
    id,
    ticketNumber,
    customerId: data.customerId,
    deviceId: data.deviceId ?? null,
    assignedToId: data.assignedToId ?? null,
    priority: data.priority ?? "normal",
    summary: data.summary,
    description: data.description ?? null,
    dueDate: data.dueDate ? new Date(data.dueDate) : null,
  });

  // Auto-create "ticket created" event
  await createTicketEvent(id, createdByUserId, "system", `Ticket ${ticketNumber} created`);

  if (data.assignedToId) {
    await createTicketEvent(
      id,
      createdByUserId,
      "assignment",
      `Ticket assigned to user ${data.assignedToId}`,
    );
  }

  return getTicketById(id);
}

export async function updateTicket(
  id: string,
  data: UpdateTicketRequest,
  updatedByUserId: string,
) {
  const db = getDb();
  const existing = await getTicketById(id);
  if (!existing) return null;

  const updates: Record<string, unknown> = {};
  if (data.summary !== undefined) updates.summary = data.summary;
  if (data.description !== undefined) updates.description = data.description;
  if (data.diagnosis !== undefined) updates.diagnosis = data.diagnosis;
  if (data.resolution !== undefined) updates.resolution = data.resolution;
  if (data.priority !== undefined) updates.priority = data.priority;
  if (data.dueDate !== undefined) updates.dueDate = data.dueDate ? new Date(data.dueDate) : null;

  // Status change — auto-create event
  if (data.status !== undefined && data.status !== existing.status) {
    updates.status = data.status;
    await createTicketEvent(
      id,
      updatedByUserId,
      "status_change",
      `Status changed from "${existing.status}" to "${data.status}"`,
    );
  }

  // Assignment change — auto-create event
  if (data.assignedToId !== undefined && data.assignedToId !== existing.assignedToId) {
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

export async function getTicketEvents(ticketId: string) {
  const db = getDb();
  return db
    .select()
    .from(schema.ticketEvents)
    .where(eq(schema.ticketEvents.ticketId, ticketId))
    .orderBy(desc(schema.ticketEvents.createdAt));
}

async function createTicketEvent(
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
