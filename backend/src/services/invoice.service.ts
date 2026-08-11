import { and, desc, eq, gt, isNotNull, isNull, sql } from "drizzle-orm";
import { getDb, schema } from "../db/index.js";
import { generateId } from "../utils/id.js";
import {
  addDecimals,
  calculateLineTotal,
  calculateTax,
  calculateTimedAmount,
  removeTax,
  decimalToHundredths,
  hundredthsToDecimal,
  subtractDecimals,
  sumDecimals,
} from "../utils/money.js";
import { getSetting } from "./settings.service.js";
import { applyStockMovementInTransaction } from "./stock.service.js";
import type {
  CreateInvoiceRequest,
  CreateLineItemRequest,
  UpdateLineItemRequest,
  CreatePaymentRequest,
} from "@technopro/shared";

export class InvoiceConflictError extends Error {
  readonly statusCode = 409;

  constructor(
    message: string,
    readonly code = "INVOICE_CONFLICT",
  ) {
    super(message);
    this.name = "InvoiceConflictError";
  }
}

function assertInvoiceEditable(invoice: { status: string }) {
  if (invoice.status !== "draft") {
    throw new InvoiceConflictError(
      "Finalised invoices cannot be edited; void or replace the invoice instead",
      "INVOICE_FINALISED",
    );
  }
}

// --- Number generation ---

async function nextInvoiceNumber(): Promise<string> {
  const db = getDb();
  const result = await db
    .select({ invoiceNumber: schema.invoices.invoiceNumber })
    .from(schema.invoices)
    .where(eq(schema.invoices.type, "invoice"))
    .orderBy(desc(schema.invoices.createdAt))
    .limit(1);
  if (result.length === 0) return "INV-00001";
  const last = result[0]!.invoiceNumber;
  if (!last.startsWith("INV-")) return "INV-00001";
  const num = parseInt(last.replace("INV-", ""), 10) + 1;
  return `INV-${String(num).padStart(5, "0")}`;
}

async function nextQuoteNumber(): Promise<string> {
  const db = getDb();
  const result = await db
    .select({ invoiceNumber: schema.invoices.invoiceNumber })
    .from(schema.invoices)
    .where(eq(schema.invoices.type, "quote"))
    .orderBy(desc(schema.invoices.createdAt))
    .limit(1);
  if (result.length === 0) return "QTE-00001";
  const last = result[0]!.invoiceNumber;
  if (!last.startsWith("QTE-")) return "QTE-00001";
  const num = parseInt(last.replace("QTE-", ""), 10) + 1;
  return `QTE-${String(num).padStart(5, "0")}`;
}

// --- Totals ---

type InvoiceDbExecutor = Pick<ReturnType<typeof getDb>, "select" | "update" | "insert">;

async function recalculateTotals(invoiceId: string, executor?: InvoiceDbExecutor) {
  const db = executor ?? getDb();
  const items = await db
    .select({ total: schema.lineItems.total })
    .from(schema.lineItems)
    .where(eq(schema.lineItems.invoiceId, invoiceId));

  const subtotal = sumDecimals(items.map((item) => item.total));

  // Fetch current taxRate stored on the invoice (set at creation time from settings)
  const inv = await db
    .select({ taxRate: schema.invoices.taxRate })
    .from(schema.invoices)
    .where(eq(schema.invoices.id, invoiceId))
    .limit(1);
  const taxRate = inv[0]?.taxRate ?? "0.00";
  const taxAmount = calculateTax(subtotal, taxRate);
  const total = addDecimals(subtotal, taxAmount);

  await db
    .update(schema.invoices)
    .set({
      subtotal,
      taxAmount,
      total,
    })
    .where(eq(schema.invoices.id, invoiceId));
}

async function getAmountPaid(invoiceId: string): Promise<string> {
  const db = getDb();
  const rows = await db
    .select({ amount: schema.payments.amount, type: schema.payments.type })
    .from(schema.payments)
    .where(eq(schema.payments.invoiceId, invoiceId));
  const total = rows.reduce((sum, payment) => {
    const amount = decimalToHundredths(payment.amount);
    return sum + (payment.type === "refund" ? -amount : amount);
  }, 0n);
  return hundredthsToDecimal(total);
}

async function attachBillableTimeToDraftInvoice(
  invoice: typeof schema.invoices.$inferSelect,
  executor: InvoiceDbExecutor,
) {
  if (invoice.type !== "invoice" || invoice.status !== "draft" || !invoice.ticketId) return;

  const entries = await executor
    .select()
    .from(schema.timeEntries)
    .where(
      and(
        eq(schema.timeEntries.ticketId, invoice.ticketId),
        eq(schema.timeEntries.billable, true),
        isNotNull(schema.timeEntries.stoppedAt),
        gt(schema.timeEntries.durationSeconds, 0),
        isNull(schema.timeEntries.billedAs),
      ),
    )
    .orderBy(schema.timeEntries.createdAt)
    .for("update");

  for (const entry of entries) {
    const durationSeconds = entry.durationSeconds!;
    const hours = durationSeconds / 3600;
    const note = entry.note?.trim();
    const description = `Labour (${hours.toFixed(2)} hours)${note ? ` — ${note}` : ""}`.slice(0, 500);
    const unitPrice = calculateTimedAmount(entry.labourRate.toString(), durationSeconds);
    const lineItemId = generateId();

    await executor.insert(schema.lineItems).values({
      id: lineItemId,
      ticketId: invoice.ticketId,
      invoiceId: invoice.id,
      type: "service",
      description,
      quantity: 1,
      unitPrice,
      discount: "0.00",
      taxTreatment: "exclusive",
      total: unitPrice,
    });
    await executor
      .update(schema.timeEntries)
      .set({ billedAs: lineItemId })
      .where(eq(schema.timeEntries.id, entry.id));
  }

  await recalculateTotals(invoice.id, executor);
}

async function insertDraftInvoice(
  ticketId: string,
  taxRate: string,
  executor: InvoiceDbExecutor,
) {
  const [last] = await executor
    .select({ invoiceNumber: schema.invoices.invoiceNumber })
    .from(schema.invoices)
    .where(eq(schema.invoices.type, "invoice"))
    .orderBy(desc(schema.invoices.createdAt))
    .limit(1)
    .for("update");
  const lastNumber = last?.invoiceNumber;
  const sequence = lastNumber?.startsWith("INV-")
    ? Number.parseInt(lastNumber.slice(4), 10) + 1
    : 1;
  const invoiceNumber = `INV-${String(sequence).padStart(5, "0")}`;
  const id = generateId();

  await executor.insert(schema.invoices).values({
    id,
    invoiceNumber,
    ticketId,
    type: "invoice",
    subtotal: "0.00",
    taxRate,
    taxAmount: "0.00",
    total: "0.00",
    status: "draft",
  });

  const [invoice] = await executor
    .select()
    .from(schema.invoices)
    .where(eq(schema.invoices.id, id))
    .limit(1)
    .for("update");
  return invoice!;
}

// --- Invoice CRUD ---

export async function listInvoices(options: {
  page: number;
  pageSize: number;
  status?: string;
  ticketId?: string;
  type?: "invoice" | "quote";
}) {
  const db = getDb();
  const { page, pageSize } = options;
  const offset = (page - 1) * pageSize;

  const filters = [];
  if (options.status) filters.push(eq(schema.invoices.status, options.status as "draft" | "open" | "paid" | "void"));
  if (options.ticketId) filters.push(eq(schema.invoices.ticketId, options.ticketId));
  if (options.type) filters.push(eq(schema.invoices.type, options.type));

  const condition = filters.length > 0 ? and(...filters) : undefined;

  const [rows, countResult] = await Promise.all([
    db
      .select()
      .from(schema.invoices)
      .where(condition)
      .orderBy(desc(schema.invoices.createdAt))
      .limit(pageSize)
      .offset(offset),
    db
      .select({ count: sql<number>`count(*)` })
      .from(schema.invoices)
      .where(condition),
  ]);

  const enriched = await Promise.all(
    rows.map(async (inv) => {
      const amountPaid = await getAmountPaid(inv.id);
      const balance = subtractDecimals(inv.total, amountPaid);
      return { ...inv, amountPaid, balance };
    }),
  );

  return { rows: enriched, totalCount: Number(countResult[0]?.count ?? 0) };
}

export async function getInvoiceById(id: string) {
  const db = getDb();
  const results = await db
    .select()
    .from(schema.invoices)
    .where(eq(schema.invoices.id, id))
    .limit(1);

  const inv = results[0];
  if (!inv) return null;

  const [lineItems, payments] = await Promise.all([
    db
      .select()
      .from(schema.lineItems)
      .where(eq(schema.lineItems.invoiceId, id))
      .orderBy(schema.lineItems.createdAt),
    db
      .select()
      .from(schema.payments)
      .where(eq(schema.payments.invoiceId, id))
      .orderBy(schema.payments.paidAt),
  ]);

  const amountPaid = hundredthsToDecimal(
    payments.reduce((sum, payment) => {
      const amount = decimalToHundredths(payment.amount);
      return sum + (payment.type === "refund" ? -amount : amount);
    }, 0n),
  );
  const balance = subtractDecimals(inv.total, amountPaid);

  return { ...inv, amountPaid, balance, lineItems, payments };
}

export async function createInvoice(data: CreateInvoiceRequest & { type?: "invoice" | "quote" }) {
  if (data.ticketId && data.type !== "quote") {
    return createTicketInvoice(data.ticketId);
  }

  const db = getDb();
  const id = generateId();
  const isQuote = data.type === "quote";
  const taxRate = await getSetting("gst_rate");

  await db.transaction(async (tx) => {
    const type = isQuote ? "quote" : "invoice";
    const prefix = isQuote ? "QTE-" : "INV-";
    const [last] = await tx
      .select({ invoiceNumber: schema.invoices.invoiceNumber })
      .from(schema.invoices)
      .where(eq(schema.invoices.type, type))
      .orderBy(desc(schema.invoices.createdAt))
      .limit(1)
      .for("update");
    const lastNumber = last?.invoiceNumber;
    const sequence = lastNumber?.startsWith(prefix)
      ? Number.parseInt(lastNumber.slice(prefix.length), 10) + 1
      : 1;
    const invoiceNumber = `${prefix}${String(sequence).padStart(5, "0")}`;

    await tx.insert(schema.invoices).values({
      id,
      invoiceNumber,
      ticketId: data.ticketId ?? null,
      type,
      quoteStatus: isQuote ? "draft" : null,
      subtotal: "0.00",
      taxRate,
      taxAmount: "0.00",
      total: "0.00",
      status: "draft",
    });
  });

  return getInvoiceById(id);
}

export async function createTicketInvoice(ticketId: string) {
  const db = getDb();
  const taxRate = await getSetting("gst_rate");
  let invoiceId: string | undefined;

  await db.transaction(async (tx) => {
    const [ticket] = await tx
      .select({ id: schema.tickets.id })
      .from(schema.tickets)
      .where(eq(schema.tickets.id, ticketId))
      .limit(1)
      .for("update");
    if (!ticket) throw new Error("Ticket not found");

    let [invoice] = await tx
      .select()
      .from(schema.invoices)
      .where(
        and(
          eq(schema.invoices.ticketId, ticketId),
          eq(schema.invoices.type, "invoice"),
          eq(schema.invoices.status, "draft"),
        ),
      )
      .orderBy(desc(schema.invoices.createdAt))
      .limit(1)
      .for("update");

    if (!invoice) invoice = await insertDraftInvoice(ticketId, taxRate, tx);
    await attachBillableTimeToDraftInvoice(invoice, tx);
    invoiceId = invoice.id;
  });

  return getInvoiceById(invoiceId!);
}

export async function updateInvoiceStatus(id: string, status: "draft" | "open" | "paid" | "void") {
  const db = getDb();
  const found = await db.transaction(async (tx) => {
    const [existing] = await tx
      .select()
      .from(schema.invoices)
      .where(eq(schema.invoices.id, id))
      .limit(1)
      .for("update");
    if (!existing) return false;

    if (existing.status === "void" && status !== "void") {
      throw new InvoiceConflictError("A void invoice cannot be reopened", "INVOICE_VOID");
    }
    if (existing.status === "paid" && status !== "paid" && status !== "void") {
      throw new InvoiceConflictError(
        "A paid invoice can only be voided or refunded",
        "INVOICE_PAID",
      );
    }
    if (existing.status === "open" && status === "draft") {
      throw new InvoiceConflictError(
        "A finalised invoice cannot be returned to draft",
        "INVOICE_FINALISED",
      );
    }
    if (status === "paid") {
      const payments = await tx
        .select({ amount: schema.payments.amount, type: schema.payments.type })
        .from(schema.payments)
        .where(eq(schema.payments.invoiceId, id));
      const paid = payments.reduce((sum, payment) => {
        const amount = decimalToHundredths(payment.amount);
        return sum + (payment.type === "refund" ? -amount : amount);
      }, 0n);
      if (decimalToHundredths(existing.total) - paid > 0n) {
        throw new InvoiceConflictError(
          "An invoice with an outstanding balance cannot be marked paid",
          "INVOICE_BALANCE_REMAINING",
        );
      }
    }

    if (existing.status === "draft" && status === "open") {
      await attachBillableTimeToDraftInvoice(existing, tx);
    }
    await tx.update(schema.invoices).set({ status }).where(eq(schema.invoices.id, id));
    return true;
  });
  if (!found) return null;
  return getInvoiceById(id);
}

export async function updateQuoteStatus(
  id: string,
  quoteStatus: "draft" | "sent" | "accepted" | "declined",
) {
  const db = getDb();
  const existing = await getInvoiceById(id);
  if (!existing || existing.type !== "quote") return null;
  await db.update(schema.invoices).set({ quoteStatus }).where(eq(schema.invoices.id, id));
  return getInvoiceById(id);
}

// Convert an accepted quote to a new ticket and link the invoice back to it.
// Returns { ticketId } on success, null if quote not found or not accepted.
export async function convertQuoteToTicket(
  quoteId: string,
  userId: string,
): Promise<{ ticketId: string; ticketNumber: string } | null> {
  const db = getDb();
  const quote = await getInvoiceById(quoteId);
  if (!quote || quote.type !== "quote" || quote.quoteStatus !== "accepted") return null;
  if (quote.convertedTicketId) {
    // Already converted â€” return existing ticket
    return { ticketId: quote.convertedTicketId, ticketNumber: "" };
  }

  const ticketId = generateId();

  // Derive ticket number
  const last = await db
    .select({ ticketNumber: schema.tickets.ticketNumber })
    .from(schema.tickets)
    .orderBy(desc(schema.tickets.createdAt))
    .limit(1);
  const lastNum = last[0]?.ticketNumber;
  let ticketNum = "TKT-00001";
  if (lastNum?.startsWith("TKT-")) {
    const n = parseInt(lastNum.replace("TKT-", ""), 10) + 1;
    ticketNum = `TKT-${String(n).padStart(5, "0")}`;
  }

  // Derive customerId from existing ticket if linked, else fall back to null
  // (Quotes may not be linked to a ticket â€” we create the ticket with no customer initially)
  const sourceTicketId = quote.ticketId;
  let customerId: string | null = null;
  if (sourceTicketId) {
    const [sourceTicket] = await db
      .select({ customerId: schema.tickets.customerId })
      .from(schema.tickets)
      .where(eq(schema.tickets.id, sourceTicketId))
      .limit(1);
    customerId = sourceTicket?.customerId ?? null;
  }

  if (!customerId) return null; // cannot create ticket without a customer

  const now = new Date();
  await db.insert(schema.tickets).values({
    id: ticketId,
    ticketNumber: ticketNum,
    customerId,
    status: "new",
    priority: "normal",
    summary: `Quote ${quote.invoiceNumber}`,
    createdAt: now,
    updatedAt: now,
  });

  await db
    .update(schema.invoices)
    .set({ convertedTicketId: ticketId, ticketId: ticketId })
    .where(eq(schema.invoices.id, quoteId));

  return { ticketId, ticketNumber: ticketNum };
}

// --- Line items ---

export async function addLineItem(
  invoiceId: string,
  data: CreateLineItemRequest & { discount?: string },
  actorUserId?: string,
) {
  const db = getDb();
  const id = generateId();
  const quantity = data.quantity ?? 1;
  const discount = data.discount ?? "0.00";
  const created = await db.transaction(async (tx) => {
    const [invoice] = await tx
      .select()
      .from(schema.invoices)
      .where(eq(schema.invoices.id, invoiceId))
      .limit(1)
      .for("update");
    if (!invoice) return false;
    assertInvoiceEditable(invoice);
    const taxTreatment = data.taxTreatment ?? "exclusive";
    const unitPrice = taxTreatment === "inclusive"
      ? removeTax(data.unitPrice, invoice.taxRate)
      : data.unitPrice;
    const total = calculateLineTotal(unitPrice, quantity, discount);

    let unitCost: string | null = null;
    if (data.inventoryItemId) {
      if (data.type !== "part") {
        throw new InvoiceConflictError(
          "An inventory item can only be attached to a part line",
          "INVALID_INVENTORY_LINE",
        );
      }
      const [inventoryItem] = await tx
        .select()
        .from(schema.inventoryItems)
        .where(eq(schema.inventoryItems.id, data.inventoryItemId))
        .limit(1)
        .for("update");
      if (!inventoryItem) {
        throw new InvoiceConflictError("Inventory item not found", "INVENTORY_NOT_FOUND");
      }
      unitCost = inventoryItem.cost;
      if (inventoryItem.stockQty !== null) {
        try { await applyStockMovementInTransaction(tx, { inventoryItemId: inventoryItem.id, quantityDelta: -quantity, unitCost: inventoryItem.cost.toString(), sourceType: "sale", sourceReference: `invoice-line:${id}`, reasonCode: "invoice_part", actorUserId }); }
        catch (error) { throw new InvoiceConflictError(error instanceof Error ? error.message : "Unable to deduct stock", "INSUFFICIENT_STOCK"); }
      }
    }

    await tx.insert(schema.lineItems).values({
      id,
      invoiceId,
      inventoryItemId: data.inventoryItemId ?? null,
      type: data.type,
      description: data.description,
      quantity,
      unitPrice,
      unitCost,
      taxTreatment,
      discount,
      total,
    });
    await recalculateTotals(invoiceId, tx);
    return true;
  });
  if (!created) return null;

  const invoiceResult = await getInvoiceById(invoiceId);
  return invoiceResult ? { invoice: invoiceResult, lineItemId: id } : null;
}

export async function createInvoiceWithItems(
  ticketId: string,
  repairs: Array<{
    type?: "service" | "part" | "labour";
    description: string;
    unitPrice: string;
    quantity?: number;
    discount?: string;
    inventoryItemId?: string;
  }>,
) {
  const db = getDb();
  const id = generateId();
  const invoiceNumber = await nextInvoiceNumber();
  const taxRate = await getSetting("gst_rate");

  await db.insert(schema.invoices).values({
    id,
    invoiceNumber,
    ticketId,
    type: "invoice",
    subtotal: "0.00",
    taxRate,
    taxAmount: "0.00",
    total: "0.00",
    status: "draft",
  });

  for (const repair of repairs) {
    await addLineItem(id, {
      type: (repair.type === "labour" ? "service" : repair.type) ?? "service",
      description: repair.description,
      unitPrice: repair.unitPrice,
      quantity: repair.quantity,
      discount: repair.discount,
      inventoryItemId: repair.inventoryItemId,
    });
  }

  return getInvoiceById(id);
}

export async function updateLineItem(
  invoiceId: string,
  lineItemId: string,
  data: UpdateLineItemRequest,
  actorUserId?: string,
) {
  const db = getDb();
  const updated = await db.transaction(async (tx) => {
    const [invoice] = await tx
      .select()
      .from(schema.invoices)
      .where(eq(schema.invoices.id, invoiceId))
      .limit(1)
      .for("update");
    if (!invoice) return false;
    assertInvoiceEditable(invoice);

    const [existing] = await tx
      .select()
      .from(schema.lineItems)
      .where(eq(schema.lineItems.id, lineItemId))
      .limit(1)
      .for("update");
    if (!existing || existing.invoiceId !== invoiceId) return false;

    const quantity = data.quantity ?? existing.quantity;
    const taxTreatment = data.taxTreatment ?? existing.taxTreatment;
    const enteredUnitPrice = data.unitPrice ?? existing.unitPrice;
    const unitPrice = data.unitPrice !== undefined && taxTreatment === "inclusive"
      ? removeTax(enteredUnitPrice, invoice.taxRate)
      : enteredUnitPrice;
    const total = calculateLineTotal(unitPrice, quantity, existing.discount);
    const stockDelta = quantity - existing.quantity;
    if (existing.inventoryItemId && stockDelta !== 0) {
      const [inventoryItem] = await tx
        .select()
        .from(schema.inventoryItems)
        .where(eq(schema.inventoryItems.id, existing.inventoryItemId))
        .limit(1)
        .for("update");
      if (!inventoryItem) {
        throw new InvoiceConflictError("Inventory item not found", "INVENTORY_NOT_FOUND");
      }
      if (inventoryItem.stockQty !== null) {
        try { await applyStockMovementInTransaction(tx, { inventoryItemId: inventoryItem.id, quantityDelta: -stockDelta, unitCost: inventoryItem.cost.toString(), sourceType: stockDelta > 0 ? "sale" : "sale_reversal", sourceReference: `invoice-line-adjust:${lineItemId}:${quantity}`, reasonCode: "invoice_quantity_changed", actorUserId }); }
        catch (error) { throw new InvoiceConflictError(error instanceof Error ? error.message : "Unable to adjust stock", "INSUFFICIENT_STOCK"); }
      }
    }

    await tx
      .update(schema.lineItems)
      .set({
        ...(data.description !== undefined ? { description: data.description } : {}),
        quantity,
        unitPrice,
        taxTreatment,
        total,
      })
      .where(eq(schema.lineItems.id, lineItemId));
    await recalculateTotals(invoiceId, tx);
    return true;
  });
  if (!updated) return null;
  return getInvoiceById(invoiceId);
}

export async function removeLineItem(invoiceId: string, lineItemId: string, actorUserId?: string) {
  const db = getDb();
  return db.transaction(async (tx) => {
    const [invoice] = await tx
      .select()
      .from(schema.invoices)
      .where(eq(schema.invoices.id, invoiceId))
      .limit(1)
      .for("update");
    if (!invoice) return false;
    assertInvoiceEditable(invoice);

    const [existing] = await tx
      .select()
      .from(schema.lineItems)
      .where(eq(schema.lineItems.id, lineItemId))
      .limit(1)
      .for("update");
    if (!existing || existing.invoiceId !== invoiceId) return false;

    if (existing.inventoryItemId) {
      const [inventoryItem] = await tx
        .select()
        .from(schema.inventoryItems)
        .where(eq(schema.inventoryItems.id, existing.inventoryItemId))
        .limit(1)
        .for("update");
      if (inventoryItem?.stockQty !== null && inventoryItem?.stockQty !== undefined) await applyStockMovementInTransaction(tx, { inventoryItemId: inventoryItem.id, quantityDelta: existing.quantity, unitCost: inventoryItem.cost.toString(), sourceType: "sale_reversal", sourceReference: `invoice-line-reversal:${lineItemId}`, reasonCode: "invoice_line_removed", actorUserId });
    }

    await tx.delete(schema.lineItems).where(eq(schema.lineItems.id, lineItemId));
    await recalculateTotals(invoiceId, tx);
    return true;
  });
}

// --- Payments ---

export function normalisePaymentRequest(
  data: CreatePaymentRequest & { type?: "deposit" | "payment" | "refund" },
) {
  const amountHundredths = decimalToHundredths(data.amount);
  if (amountHundredths <= 0n) {
    throw new InvoiceConflictError("Payment amount must be greater than zero", "INVALID_PAYMENT");
  }
  return {
    amountHundredths,
    amount: hundredthsToDecimal(amountHundredths),
    method: data.method,
    type: data.type ?? "payment",
    reference: data.reference?.trim() || null,
  };
}

export async function addPayment(
  invoiceId: string,
  data: CreatePaymentRequest & { type?: "deposit" | "payment" | "refund" },
  userId: string,
  idempotencyKey?: string,
) {
  const db = getDb();
  const key = idempotencyKey?.trim();
  if (!key) {
    throw new InvoiceConflictError(
      "Idempotency-Key is required when recording a payment or refund",
      "IDEMPOTENCY_KEY_REQUIRED",
    );
  }
  if (key.length > 128) {
    throw new InvoiceConflictError(
      "Idempotency-Key must be at most 128 characters",
      "INVALID_IDEMPOTENCY_KEY",
    );
  }

  const requestPayment = normalisePaymentRequest(data);
  const { amountHundredths, amount, reference, type: paymentType } = requestPayment;

  const matchesRequest = (storedPayment: typeof schema.payments.$inferSelect) =>
    storedPayment.invoiceId === invoiceId &&
    storedPayment.amount === amount &&
    storedPayment.method === requestPayment.method &&
    storedPayment.type === paymentType &&
    storedPayment.reference === reference;

  let outcome: { paymentId: string; replayed: boolean } | null;
  try {
    outcome = await db.transaction(async (tx) => {
      const invoiceRows = await tx
        .select()
        .from(schema.invoices)
        .where(eq(schema.invoices.id, invoiceId))
        .limit(1)
        .for("update");
      const invoice = invoiceRows[0];
      if (!invoice) return null;
      if (invoice.type === "quote") {
        throw new InvoiceConflictError("Payments cannot be recorded against quotes", "QUOTE_PAYMENT");
      }
      if (invoice.status === "void") {
        throw new InvoiceConflictError("Payments cannot be recorded against a void invoice", "INVOICE_VOID");
      }

      const existingRows = await tx
        .select()
        .from(schema.payments)
        .where(eq(schema.payments.idempotencyKey, key))
        .limit(1);
      const existing = existingRows[0];
      if (existing) {
        if (!matchesRequest(existing)) {
          throw new InvoiceConflictError(
            "Idempotency-Key was already used for a different payment",
            "IDEMPOTENCY_CONFLICT",
          );
        }
        return { paymentId: existing.id, replayed: true };
      }

      const priorPayments = await tx
        .select({ amount: schema.payments.amount, type: schema.payments.type })
        .from(schema.payments)
        .where(eq(schema.payments.invoiceId, invoiceId));
      const amountPaidBefore = priorPayments.reduce((sum, payment) => {
        const amount = decimalToHundredths(payment.amount);
        return sum + (payment.type === "refund" ? -amount : amount);
      }, 0n);
      const invoiceTotal = decimalToHundredths(invoice.total);

      if (paymentType === "refund") {
        if (amountHundredths > amountPaidBefore) {
          throw new InvoiceConflictError(
            "Refund cannot exceed the amount paid",
            "REFUND_EXCEEDS_PAID",
          );
        }
      } else if (amountHundredths > invoiceTotal - amountPaidBefore) {
        throw new InvoiceConflictError(
          "Payment cannot exceed the outstanding balance",
          "PAYMENT_EXCEEDS_BALANCE",
        );
      }

      const paymentId = generateId();
      await tx.insert(schema.payments).values({
        id: paymentId,
        invoiceId,
        amount,
        method: data.method,
        type: paymentType,
        reference,
        idempotencyKey: key,
        createdByUserId: userId,
        paidAt: data.paidAt ? new Date(data.paidAt) : new Date(),
      });

      const amountPaidAfter = paymentType === "refund"
        ? amountPaidBefore - amountHundredths
        : amountPaidBefore + amountHundredths;
      const nextStatus = invoiceTotal > 0n && amountPaidAfter >= invoiceTotal
        ? "paid"
        : "open";
      await tx
        .update(schema.invoices)
        .set({ status: nextStatus })
        .where(eq(schema.invoices.id, invoiceId));

      return { paymentId, replayed: false };
    });
  } catch (error) {
    const isDuplicate =
      typeof error === "object" &&
      error !== null &&
      "code" in error &&
      (error as { code?: string }).code === "ER_DUP_ENTRY";
    if (!isDuplicate || !key) throw error;

    const [existing] = await db
      .select()
      .from(schema.payments)
      .where(eq(schema.payments.idempotencyKey, key))
      .limit(1);
    if (!existing || !matchesRequest(existing)) {
      throw new InvoiceConflictError(
        "Idempotency-Key was already used for a different payment",
        "IDEMPOTENCY_CONFLICT",
      );
    }
    outcome = { paymentId: existing.id, replayed: true };
  }

  if (!outcome) return null;
  const invoice = await getInvoiceById(invoiceId);
  if (!invoice) return null;
  return { invoice, paymentId: outcome.paymentId, replayed: outcome.replayed };
}
