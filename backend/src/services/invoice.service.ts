import { eq, sql, desc, and } from "drizzle-orm";
import { getDb, schema } from "../db/index";
import { generateId } from "../utils/id";
import type {
  CreateInvoiceRequest,
  CreateLineItemRequest,
  UpdateLineItemRequest,
  CreatePaymentRequest,
} from "@technopro/shared";

// --- Invoice number generation ---

async function nextInvoiceNumber(): Promise<string> {
  const db = getDb();
  const result = await db
    .select({ invoiceNumber: schema.invoices.invoiceNumber })
    .from(schema.invoices)
    .orderBy(desc(schema.invoices.createdAt))
    .limit(1);
  if (result.length === 0) return "INV-00001";
  const last = result[0]!.invoiceNumber;
  const num = parseInt(last.replace("INV-", ""), 10) + 1;
  return `INV-${String(num).padStart(5, "0")}`;
}

// --- Totals helpers ---

async function recalculateTotals(invoiceId: string) {
  const db = getDb();
  const items = await db
    .select({ total: schema.lineItems.total })
    .from(schema.lineItems)
    .where(eq(schema.lineItems.invoiceId, invoiceId));

  const subtotal = items.reduce((sum, i) => sum + parseFloat(i.total), 0);
  const tax = 0; // Stage 6: subtotal * (taxRate / 100) from settings
  const total = subtotal + tax;

  await db
    .update(schema.invoices)
    .set({
      subtotal: subtotal.toFixed(2),
      tax: tax.toFixed(2),
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
  // mysql2 may return SUM as a string — coerce to number explicitly
  return Number(result[0]?.total ?? 0);
}

// --- Invoice CRUD ---

export async function listInvoices(options: {
  page: number;
  pageSize: number;
  status?: string;
  ticketId?: string;
}) {
  const db = getDb();
  const { page, pageSize } = options;
  const offset = (page - 1) * pageSize;

  const filters = [];
  if (options.status) filters.push(eq(schema.invoices.status, options.status as "draft" | "open" | "paid" | "void"));
  if (options.ticketId) filters.push(eq(schema.invoices.ticketId, options.ticketId));

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

  // Attach amountPaid and balance to each invoice
  const enriched = await Promise.all(
    rows.map(async (inv) => {
      const amountPaid = await getAmountPaid(inv.id);
      const balance = parseFloat(inv.total) - amountPaid;
      return { ...inv, amountPaid: amountPaid.toFixed(2), balance: balance.toFixed(2) };
    }),
  );

  return { rows: enriched, totalCount: countResult[0]?.count ?? 0 };
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

  return {
    ...inv,
    amountPaid: amountPaid.toFixed(2),
    balance: balance.toFixed(2),
    lineItems,
    payments,
  };
}

export async function createInvoice(data: CreateInvoiceRequest) {
  const db = getDb();
  const id = generateId();
  const invoiceNumber = await nextInvoiceNumber();

  await db.insert(schema.invoices).values({
    id,
    invoiceNumber,
    ticketId: data.ticketId ?? null,
    subtotal: "0.00",
    tax: "0.00",
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
    type: "service" | "part";
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

  await db.insert(schema.invoices).values({
    id,
    invoiceNumber,
    ticketId,
    subtotal: "0.00",
    tax: "0.00",
    total: "0.00",
    status: "draft",
  });

  for (const repair of repairs) {
    await addLineItem(id, repair);
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
      unitPrice: (data.unitPrice ?? existing[0].unitPrice),
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

export async function addPayment(invoiceId: string, data: CreatePaymentRequest, userId: string) {
  const db = getDb();

  const invoice = await getInvoiceById(invoiceId);
  if (!invoice) return null;

  const id = generateId();
  await db.insert(schema.payments).values({
    id,
    invoiceId,
    amount: data.amount,
    method: data.method,
    reference: data.reference ?? null,
    createdByUserId: userId,
    paidAt: data.paidAt ? new Date(data.paidAt) : new Date(),
  });

  // Auto-mark as paid if fully settled
  const amountPaid = parseFloat(invoice.amountPaid) + parseFloat(data.amount);
  const total = parseFloat(invoice.total);
  if (amountPaid >= total && invoice.status !== "void") {
    await db
      .update(schema.invoices)
      .set({ status: "paid" })
      .where(eq(schema.invoices.id, invoiceId));
  } else if (invoice.status === "draft") {
    // Move draft to open when first payment is recorded
    await db
      .update(schema.invoices)
      .set({ status: "open" })
      .where(eq(schema.invoices.id, invoiceId));
  }

  return getInvoiceById(invoiceId);
}
