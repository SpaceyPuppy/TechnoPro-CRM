import { eq, desc } from "drizzle-orm";
import { getDb, schema } from "../db/index";
import { generateId } from "../utils/id";
import { getSetting } from "./settings.service.js";
import { getTicketById } from "./ticket.service.js";
import { getInvoiceById, addLineItem, createInvoiceWithItems } from "./invoice.service.js";
import type { TimeEntryResponse } from "@technopro/shared";

// --- Time Entry CRUD ---

export async function startTimeEntry(
  ticketId: string,
  userId: string,
  options?: { note?: string; labourRate?: string },
): Promise<TimeEntryResponse> {
  const db = getDb();

  // Validate ticket exists
  const ticket = await getTicketById(ticketId);
  if (!ticket) throw new Error("Ticket not found");

  // Check for existing running entry
  const running = await db
    .select()
    .from(schema.timeEntries)
    .where(eq(schema.timeEntries.ticketId, ticketId))
    .where(eq(schema.timeEntries.stoppedAt, null));

  if (running.length > 0) {
    throw new Error("A timer is already running for this ticket");
  }

  // Get labour rate from settings if not overridden
  const labourRate = options?.labourRate ?? (await getSetting("labour_rate"));

  const id = generateId();
  const now = new Date();

  await db.insert(schema.timeEntries).values({
    id,
    ticketId,
    userId,
    startedAt: now,
    stoppedAt: null,
    durationSeconds: null,
    note: options?.note ?? null,
    labourRate,
  });

  const entry = await db
    .select()
    .from(schema.timeEntries)
    .where(eq(schema.timeEntries.id, id))
    .limit(1);

  return toTimeEntryResponse(entry[0]!);
}

export async function stopTimeEntry(timeEntryId: string): Promise<TimeEntryResponse> {
  const db = getDb();

  // Get entry
  const entry = await db
    .select()
    .from(schema.timeEntries)
    .where(eq(schema.timeEntries.id, timeEntryId))
    .limit(1);

  if (!entry[0]) throw new Error("Time entry not found");
  if (entry[0].stoppedAt) throw new Error("Time entry is already stopped");

  // Calculate duration
  const now = new Date();
  const startedAt = new Date(entry[0].startedAt);
  const durationSeconds = Math.floor((now.getTime() - startedAt.getTime()) / 1000);

  // Update entry
  await db
    .update(schema.timeEntries)
    .set({ stoppedAt: now, durationSeconds })
    .where(eq(schema.timeEntries.id, timeEntryId));

  // Fetch updated entry
  const updated = await db
    .select()
    .from(schema.timeEntries)
    .where(eq(schema.timeEntries.id, timeEntryId))
    .limit(1);

  return toTimeEntryResponse(updated[0]!);
}

export async function listTimeEntries(
  ticketId: string,
  includeOnlyRunning?: boolean,
): Promise<TimeEntryResponse[]> {
  const db = getDb();

  // Validate ticket exists
  const ticket = await getTicketById(ticketId);
  if (!ticket) throw new Error("Ticket not found");

  const conditions = [eq(schema.timeEntries.ticketId, ticketId)];
  if (includeOnlyRunning) {
    conditions.push(eq(schema.timeEntries.stoppedAt, null));
  }

  const entries = await db
    .select()
    .from(schema.timeEntries)
    .where(conditions.length === 1 ? conditions[0] : conditions[0]!)
    .orderBy(desc(schema.timeEntries.createdAt));

  return entries.map(toTimeEntryResponse);
}

export async function getTimeEntryById(timeEntryId: string): Promise<TimeEntryResponse | null> {
  const db = getDb();
  const entry = await db
    .select()
    .from(schema.timeEntries)
    .where(eq(schema.timeEntries.id, timeEntryId))
    .limit(1);
  return entry[0] ? toTimeEntryResponse(entry[0]) : null;
}

// --- Billing ---

export async function billTimeEntry(
  timeEntryId: string,
  invoiceId?: string,
  description?: string,
) {
  const db = getDb();

  // Get entry
  const entry = await db
    .select()
    .from(schema.timeEntries)
    .where(eq(schema.timeEntries.id, timeEntryId))
    .limit(1);

  if (!entry[0]) throw new Error("Time entry not found");
  if (!entry[0].stoppedAt || !entry[0].durationSeconds) {
    throw new Error("Cannot bill a running time entry");
  }
  if (entry[0].billedAs) throw new Error("Time entry already billed");

  // Calculate labour line item
  const hours = entry[0].durationSeconds / 3600;
  const labourRate = parseFloat(entry[0].labourRate);
  const unitPrice = (hours * labourRate).toFixed(2);
  const desc = description || `Labour (${hours.toFixed(2)} hours)`;

  // Get or create invoice
  let targetInvoiceId = invoiceId;
  if (!targetInvoiceId) {
    const inv = await createInvoiceWithItems(entry[0].ticketId, []);
    if (!inv) throw new Error("Failed to create invoice");
    targetInvoiceId = inv.data.id;
  }

  // Add line item
  const lineItemResult = await addLineItem(targetInvoiceId, {
    type: "service",
    description: desc,
    unitPrice,
    quantity: 1,
  });

  if (!lineItemResult || !lineItemResult.data || !lineItemResult.data.lineItems) {
    throw new Error("Failed to create line item");
  }

  // Get the line item ID (last added)
  const lineItemId = lineItemResult.data.lineItems[lineItemResult.data.lineItems.length - 1]?.id;
  if (!lineItemId) throw new Error("Line item ID not found");

  // Update time entry with billed_as
  await db
    .update(schema.timeEntries)
    .set({ billedAs: lineItemId })
    .where(eq(schema.timeEntries.id, timeEntryId));

  // Return updated invoice
  return getInvoiceById(targetInvoiceId);
}

// --- Helpers ---

function toTimeEntryResponse(entry: typeof schema.timeEntries.$inferSelect): TimeEntryResponse {
  return {
    id: entry.id,
    ticketId: entry.ticketId,
    userId: entry.userId,
    startedAt: entry.startedAt.toISOString(),
    stoppedAt: entry.stoppedAt ? entry.stoppedAt.toISOString() : null,
    durationSeconds: entry.durationSeconds,
    note: entry.note,
    labourRate: entry.labourRate.toString(),
    billedAs: entry.billedAs,
    createdAt: entry.createdAt.toISOString(),
    updatedAt: entry.updatedAt.toISOString(),
  };
}
