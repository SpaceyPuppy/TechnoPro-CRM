import { and, desc, eq, isNull } from "drizzle-orm";
import { getDb, schema } from "../db/index.js";
import { generateId } from "../utils/id.js";
import { getSetting } from "./settings.service.js";
import { getTicketById } from "./ticket.service.js";
import { getInvoiceById, InvoiceConflictError } from "./invoice.service.js";
import {
  addDecimals,
  calculateTax,
  calculateTimedAmount,
  sumDecimals,
} from "../utils/money.js";
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

  // A technician may only have one active timer across all tickets.
  const running = await db
    .select()
    .from(schema.timeEntries)
    .where(and(eq(schema.timeEntries.userId, userId), isNull(schema.timeEntries.stoppedAt)));

  if (running.length > 0) {
    throw new Error("You already have a running timer");
  }

  // Get labour rate from settings if not overridden
  const labourRate = options?.labourRate ?? (await getSetting("labour_rate"));

  const id = generateId();
  const now = new Date();

  try {
    await db.insert(schema.timeEntries).values({
      id,
      ticketId,
      userId,
      runningUserId: userId,
      startedAt: now,
      stoppedAt: null,
      durationSeconds: null,
      note: options?.note ?? null,
      labourRate,
    });
  } catch (error) {
    const duplicateRunningTimer =
      typeof error === "object" &&
      error !== null &&
      "code" in error &&
      (error as { code?: string }).code === "ER_DUP_ENTRY";
    if (duplicateRunningTimer) throw new Error("You already have a running timer");
    throw error;
  }

  const entry = await db
    .select()
    .from(schema.timeEntries)
    .where(eq(schema.timeEntries.id, id))
    .limit(1);

  return toTimeEntryResponse(entry[0]!);
}

export async function createManualTimeEntry(
  ticketId: string,
  userId: string,
  options: {
    durationSeconds: number;
    note?: string;
    labourRate?: string;
    startedAt?: string;
  },
): Promise<TimeEntryResponse> {
  const ticket = await getTicketById(ticketId);
  if (!ticket) throw new Error("Ticket not found");
  if (!Number.isSafeInteger(options.durationSeconds) || options.durationSeconds < 60) {
    throw new Error("Manual time must be at least one minute");
  }

  const stoppedAt = new Date();
  const startedAt = options.startedAt
    ? new Date(options.startedAt)
    : new Date(stoppedAt.getTime() - options.durationSeconds * 1000);
  if (Number.isNaN(startedAt.getTime()) || startedAt > stoppedAt) {
    throw new Error("Manual start time is invalid");
  }

  const db = getDb();
  const id = generateId();
  await db.insert(schema.timeEntries).values({
    id,
    ticketId,
    userId,
    runningUserId: null,
    startedAt,
    stoppedAt,
    durationSeconds: options.durationSeconds,
    note: options.note ?? null,
    labourRate: options.labourRate ?? (await getSetting("labour_rate")),
  });
  const [created] = await db
    .select()
    .from(schema.timeEntries)
    .where(eq(schema.timeEntries.id, id))
    .limit(1);
  return toTimeEntryResponse(created!);
}

export async function stopTimeEntry(
  timeEntryId: string,
  userId: string,
  canManage: boolean,
): Promise<TimeEntryResponse> {
  const db = getDb();
  const updated = await db.transaction(async (tx) => {
    const [entry] = await tx
      .select()
      .from(schema.timeEntries)
      .where(eq(schema.timeEntries.id, timeEntryId))
      .limit(1)
      .for("update");

    if (!entry) throw new Error("Time entry not found");
    if (entry.userId !== userId && !canManage) {
      throw new Error("You cannot stop another staff member's timer");
    }
    if (entry.stoppedAt) return entry;

    const now = new Date();
    const durationSeconds = Math.max(
      0,
      Math.floor((now.getTime() - entry.startedAt.getTime()) / 1000),
    );

    await tx
      .update(schema.timeEntries)
      .set({ stoppedAt: now, durationSeconds, runningUserId: null })
      .where(eq(schema.timeEntries.id, timeEntryId));

    const [result] = await tx
      .select()
      .from(schema.timeEntries)
      .where(eq(schema.timeEntries.id, timeEntryId))
      .limit(1);
    return result!;
  });

  return toTimeEntryResponse(updated);
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
    conditions.push(isNull(schema.timeEntries.stoppedAt));
  }

  const entries = await db
    .select()
    .from(schema.timeEntries)
    .where(and(...conditions))
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

export async function getRunningTimeEntryForUser(
  userId: string,
): Promise<TimeEntryResponse | null> {
  const db = getDb();
  const [entry] = await db
    .select()
    .from(schema.timeEntries)
    .where(eq(schema.timeEntries.runningUserId, userId))
    .limit(1);
  return entry ? toTimeEntryResponse(entry) : null;
}

// --- Billing ---

export async function billTimeEntry(
  timeEntryId: string,
  invoiceId?: string,
  description?: string,
) {
  const db = getDb();
  const defaultTaxRate = await getSetting("gst_rate");

  const resolvedInvoiceId = await db.transaction(async (tx) => {
    const [entry] = await tx
      .select()
      .from(schema.timeEntries)
      .where(eq(schema.timeEntries.id, timeEntryId))
      .limit(1)
      .for("update");

    if (!entry) throw new Error("Time entry not found");
    if (!entry.stoppedAt || !entry.durationSeconds) {
      throw new Error("Cannot bill a running or zero-duration time entry");
    }

    if (entry.billedAs) {
      const [existingLine] = await tx
        .select({ invoiceId: schema.lineItems.invoiceId })
        .from(schema.lineItems)
        .where(eq(schema.lineItems.id, entry.billedAs))
        .limit(1);
      if (!existingLine?.invoiceId) throw new Error("Billed line item is missing its invoice");
      return existingLine.invoiceId;
    }

    let targetInvoice: typeof schema.invoices.$inferSelect | undefined;
    if (invoiceId) {
      [targetInvoice] = await tx
        .select()
        .from(schema.invoices)
        .where(eq(schema.invoices.id, invoiceId))
        .limit(1)
        .for("update");
      if (!targetInvoice) throw new Error("Invoice not found");
    } else {
      [targetInvoice] = await tx
        .select()
        .from(schema.invoices)
        .where(
          and(
            eq(schema.invoices.ticketId, entry.ticketId),
            eq(schema.invoices.type, "invoice"),
            eq(schema.invoices.status, "draft"),
          ),
        )
        .orderBy(desc(schema.invoices.createdAt))
        .limit(1)
        .for("update");
    }

    if (!targetInvoice) {
      const [lastInvoice] = await tx
        .select({ invoiceNumber: schema.invoices.invoiceNumber })
        .from(schema.invoices)
        .where(eq(schema.invoices.type, "invoice"))
        .orderBy(desc(schema.invoices.createdAt))
        .limit(1)
        .for("update");
      const lastNumber = lastInvoice?.invoiceNumber;
      const nextNumber = lastNumber?.startsWith("INV-")
        ? `INV-${String(Number.parseInt(lastNumber.slice(4), 10) + 1).padStart(5, "0")}`
        : "INV-00001";
      const newInvoiceId = generateId();
      await tx.insert(schema.invoices).values({
        id: newInvoiceId,
        invoiceNumber: nextNumber,
        ticketId: entry.ticketId,
        type: "invoice",
        subtotal: "0.00",
        taxRate: defaultTaxRate,
        taxAmount: "0.00",
        total: "0.00",
        status: "draft",
      });
      [targetInvoice] = await tx
        .select()
        .from(schema.invoices)
        .where(eq(schema.invoices.id, newInvoiceId))
        .limit(1);
    }

    if (!targetInvoice || targetInvoice.status !== "draft") {
      throw new InvoiceConflictError(
        "Time can only be billed to a draft invoice",
        "INVOICE_FINALISED",
      );
    }

    const hours = entry.durationSeconds / 3600;
    const unitPrice = calculateTimedAmount(entry.labourRate, entry.durationSeconds);
    const lineItemId = generateId();
    await tx.insert(schema.lineItems).values({
      id: lineItemId,
      invoiceId: targetInvoice.id,
      type: "service",
      description: description || `Labour (${hours.toFixed(2)} hours)`,
      quantity: 1,
      unitPrice,
      discount: "0.00",
      total: unitPrice,
    });

    const totals = await tx
      .select({ total: schema.lineItems.total })
      .from(schema.lineItems)
      .where(eq(schema.lineItems.invoiceId, targetInvoice.id));
    const subtotal = sumDecimals(totals.map((item) => item.total));
    const taxAmount = calculateTax(subtotal, targetInvoice.taxRate);
    await tx
      .update(schema.invoices)
      .set({ subtotal, taxAmount, total: addDecimals(subtotal, taxAmount) })
      .where(eq(schema.invoices.id, targetInvoice.id));
    await tx
      .update(schema.timeEntries)
      .set({ billedAs: lineItemId })
      .where(eq(schema.timeEntries.id, timeEntryId));

    return targetInvoice.id;
  });

  return getInvoiceById(resolvedInvoiceId);
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
