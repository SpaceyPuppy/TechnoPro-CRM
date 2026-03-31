import { eq, sql, desc, and } from "drizzle-orm";
import { getDb, schema } from "../db/index";
import { generateId } from "../utils/id";
import { getSetting } from "./settings.service.js";
import type {
  CreateInvoiceRequest,
  CreateLineItemRequest,
  UpdateLineItemRequest,
  CreatePaymentRequest,
} from "@technopro/shared";

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

async function recalculateTotals(invoiceId: string) {
  const db = getDb();
  const items = await db
    .select({ total: schema.lineItems.total })
    .from(schema.lineItems)
    .where(eq(schema.lineItems.invoiceId, invoiceId));

  const subtotal = items.reduce((sum, i) => sum + parseFloat(i.total), 0);

  // Fetch current taxRate stored on the invoice (set at creation time from settings)
  const inv = await db
    .select({ taxRate: schema.invoices.taxRate })
    .from(schema.invoices)
    .where(eq(schema.invoices.id, invoiceId))
    .limit(1);
  const taxRate = parseFloat(inv[0]?.taxRate ?? "0");
  const taxAmount = (subtotal * taxRate) / 100;
  const total = subtotal + taxAmount;

  await db
    .update(schema.invoices)
    .set({
      subtotal: subtotal.toFixed(2),
      taxAmount: taxAmount.toFixed(2),
      total: total.toFixed(2),
    })
    .where(eq(schema.invoices.id, invoiceId));
}

async function getAmountPaid(invoiceId: string): Promise<number> {
  const db = getDb();
  const result = await db
    .select({ total: sql<number>`COALESCE(SUM(amount), 0)` })
    .from(schema.payments)
    .where(eq(schema.payments.invoiceId, invoiceId));
  return Number(result[0]?.total ?? 0);
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
      const balance = parseFloat(inv.total) - amountPaid;
      return { ...inv, amountPaid: amountPaid.toFixed(2), balance: balance.toFixed(2) };
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

  const amountPaid = payments.reduce((sum, p) => sum + parseFloat(p.amount), 0);
  const balance = parseFloat(inv.total) - amountPaid;

  return { ...inv, amountPaid: amountPaid.toFixed(2), balance: balance.toFixed(2), lineItems, payments };
}

export async function createInvoice(data: CreateInvoiceRequest & { type?: "invoice" | "quote" }) {
  const db = getDb();
  const id = generateId();
  const isQuote = data.type === "quote";
  const invoiceNumber = isQuote ? await nextQuoteNumber() : await nextInvoiceNumber();
  const taxRate = await getSetting("gst_rate");

  await db.insert(schema.invoices).values({
    id,
    invoiceNumber,
    ticketId: data.ticketId ?? null,
    type: isQuote ? "quote" : "invoice",
    quoteStatus: isQuote ? "draft" : null,
    subtotal: "0.00",
    taxRate,
    taxAmount: "0.00",
    total: "0.00",
    status: "draft",
  });

  return getInvoiceById(id);
}

export async function updateInvoiceStatus(id: string, status: "draft" | "open" | "paid" | "void") {
  const db = getDb();
  const existing = await getInvoiceById(id);
  if (!existing) return null;
  await db.update(schema.invoices).set({ status }).where(eq(schema.invoices.id, id));
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
    // Already converted — return existing ticket
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
  // (Quotes may not be linked to a ticket — we create the ticket with no customer initially)
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
    status: "open",
    priority: "medium",
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
) {
  const db = getDb();
  const id = generateId();
  const quantity = data.quantity ?? 1;
  const unitPrice = parseFloat(data.unitPrice);
  const discount = parseFloat(data.discount ?? "0");
  const total = (quantity * unitPrice * (1 - discount / 100)).toFixed(2);

  await db.insert(schema.lineItems).values({
    id,
    invoiceId,
    inventoryItemId: data.inventoryItemId ?? null,
    type: data.type,
    description: data.description,
    quantity,
    unitPrice: data.unitPrice,
    discount: discount.toFixed(2),
    total,
  });

  await recalculateTotals(invoiceId);
  return getInvoiceById(invoiceId);
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
) {
  const db = getDb();

  const existing = await db
    .select()
    .from(schema.lineItems)
    .where(eq(schema.lineItems.id, lineItemId))
    .limit(1);

  if (!existing[0] || existing[0].invoiceId !== invoiceId) return null;

  const quantity = data.quantity ?? existing[0].quantity;
  const unitPrice = parseFloat(data.unitPrice ?? existing[0].unitPrice);
  const total = (quantity * unitPrice).toFixed(2);

  await db
    .update(schema.lineItems)
    .set({
      ...(data.description !== undefined ? { description: data.description } : {}),
      quantity,
      unitPrice: data.unitPrice ?? existing[0].unitPrice,
      total,
    })
    .where(eq(schema.lineItems.id, lineItemId));

  await recalculateTotals(invoiceId);
  return getInvoiceById(invoiceId);
}

export async function removeLineItem(invoiceId: string, lineItemId: string) {
  const db = getDb();

  const existing = await db
    .select()
    .from(schema.lineItems)
    .where(eq(schema.lineItems.id, lineItemId))
    .limit(1);

  if (!existing[0] || existing[0].invoiceId !== invoiceId) return false;

  await db.delete(schema.lineItems).where(eq(schema.lineItems.id, lineItemId));
  await recalculateTotals(invoiceId);
  return true;
}

// --- Payments ---

export async function addPayment(
  invoiceId: string,
  data: CreatePaymentRequest & { type?: "deposit" | "payment" | "refund" },
  userId: string,
) {
  const db = getDb();

  const invoice = await getInvoiceById(invoiceId);
  if (!invoice) return null;

  const id = generateId();
  await db.insert(schema.payments).values({
    id,
    invoiceId,
    amount: data.amount,
    method: data.method,
    type: data.type ?? "payment",
    reference: data.reference ?? null,
    createdByUserId: userId,
    paidAt: data.paidAt ? new Date(data.paidAt) : new Date(),
  });

  // Auto-update invoice status (skip for deposits — they don't settle the invoice)
  if ((data.type ?? "payment") !== "deposit") {
    const amountPaid = parseFloat(invoice.amountPaid) + parseFloat(data.amount);
    const total = parseFloat(invoice.total);
    if (amountPaid >= total && invoice.status !== "void") {
      await db
        .update(schema.invoices)
        .set({ status: "paid" })
        .where(eq(schema.invoices.id, invoiceId));
    } else if (invoice.status === "draft") {
      await db
        .update(schema.invoices)
        .set({ status: "open" })
        .where(eq(schema.invoices.id, invoiceId));
    }
  }

  return getInvoiceById(invoiceId);
}
