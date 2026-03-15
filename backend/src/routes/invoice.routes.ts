import type { FastifyInstance } from "fastify";
import {
  listInvoices,
  getInvoiceById,
  createInvoice,
  updateInvoiceStatus,
  addLineItem,
  updateLineItem,
  removeLineItem,
  addPayment,
} from "../services/invoice.service";
import { parsePagination, paginationMeta } from "../utils/pagination";
import type {
  CreateInvoiceRequest,
  CreateLineItemRequest,
  UpdateLineItemRequest,
  CreatePaymentRequest,
} from "@technopro/shared";

function invoiceToResponse(inv: NonNullable<Awaited<ReturnType<typeof getInvoiceById>>>) {
  return {
    id: inv.id,
    invoiceNumber: inv.invoiceNumber,
    ticketId: inv.ticketId,
    subtotal: inv.subtotal,
    tax: inv.tax,
    total: inv.total,
    status: inv.status,
    amountPaid: inv.amountPaid,
    balance: inv.balance,
    createdAt: inv.createdAt.toISOString(),
    updatedAt: inv.updatedAt.toISOString(),
    lineItems: inv.lineItems.map((li) => ({
      id: li.id,
      invoiceId: li.invoiceId,
      inventoryItemId: li.inventoryItemId,
      type: li.type,
      description: li.description,
      quantity: li.quantity,
      unitPrice: li.unitPrice,
      total: li.total,
      createdAt: li.createdAt.toISOString(),
    })),
    payments: inv.payments.map((p) => ({
      id: p.id,
      invoiceId: p.invoiceId,
      amount: p.amount,
      method: p.method,
      reference: p.reference,
      paidAt: p.paidAt.toISOString(),
      createdAt: p.createdAt.toISOString(),
    })),
  };
}

function listInvoiceToResponse(inv: Awaited<ReturnType<typeof listInvoices>>["rows"][number]) {
  return {
    id: inv.id,
    invoiceNumber: inv.invoiceNumber,
    ticketId: inv.ticketId,
    subtotal: inv.subtotal,
    tax: inv.tax,
    total: inv.total,
    status: inv.status,
    amountPaid: inv.amountPaid,
    balance: inv.balance,
    createdAt: inv.createdAt.toISOString(),
    updatedAt: inv.updatedAt.toISOString(),
  };
}

const createInvoiceSchema = {
  body: {
    type: "object",
    properties: {
      ticketId: { type: "string", minLength: 36, maxLength: 36 },
    },
    additionalProperties: false,
  },
} as const;

const statusSchema = {
  body: {
    type: "object",
    required: ["status"],
    properties: {
      status: { type: "string", enum: ["draft", "open", "paid", "void"] },
    },
    additionalProperties: false,
  },
} as const;

const lineItemSchema = {
  body: {
    type: "object",
    required: ["type", "description", "unitPrice"],
    properties: {
      type: { type: "string", enum: ["service", "part"] },
      description: { type: "string", minLength: 1, maxLength: 500 },
      quantity: { type: "integer", minimum: 1 },
      unitPrice: { type: "string", pattern: "^\\d+\\.\\d{2}$" },
      inventoryItemId: { type: "string", minLength: 36, maxLength: 36 },
    },
    additionalProperties: false,
  },
} as const;

const updateLineItemSchema = {
  body: {
    type: "object",
    properties: {
      description: { type: "string", minLength: 1, maxLength: 500 },
      quantity: { type: "integer", minimum: 1 },
      unitPrice: { type: "string", pattern: "^\\d+\\.\\d{2}$" },
    },
    additionalProperties: false,
  },
} as const;

const paymentSchema = {
  body: {
    type: "object",
    required: ["amount", "method"],
    properties: {
      amount: { type: "string", pattern: "^\\d+\\.\\d{2}$" },
      method: { type: "string", enum: ["cash", "card", "eftpos", "bank_transfer", "other"] },
      reference: { type: "string", maxLength: 255 },
      paidAt: { type: "string", format: "date-time" },
    },
    additionalProperties: false,
  },
} as const;

export async function invoiceRoutes(app: FastifyInstance) {
  app.addHook("preHandler", app.authenticate);

  // List invoices
  app.get<{
    Querystring: { page?: number; pageSize?: number; status?: string; ticketId?: string };
  }>("/invoices", async (request, reply) => {
    const { page, pageSize } = parsePagination(request.query);
    const { rows, totalCount } = await listInvoices({
      page,
      pageSize,
      status: request.query.status,
      ticketId: request.query.ticketId,
    });
    return reply.send({
      data: rows.map(listInvoiceToResponse),
      pagination: paginationMeta(page, pageSize, totalCount),
    });
  });

  // Get invoice by ID (includes line items + payments)
  app.get<{ Params: { id: string } }>("/invoices/:id", async (request, reply) => {
    const inv = await getInvoiceById(request.params.id);
    if (!inv) {
      return reply.code(404).send({ error: { code: "NOT_FOUND", message: "Invoice not found" } });
    }
    return reply.send({ data: invoiceToResponse(inv) });
  });

  // Create invoice
  app.post<{ Body: CreateInvoiceRequest }>(
    "/invoices",
    { schema: createInvoiceSchema },
    async (request, reply) => {
      const inv = await createInvoice(request.body);
      return reply.code(201).send({ data: invoiceToResponse(inv!) });
    },
  );

  // Update invoice status
  app.patch<{ Params: { id: string }; Body: { status: "draft" | "open" | "paid" | "void" } }>(
    "/invoices/:id/status",
    { schema: statusSchema },
    async (request, reply) => {
      const inv = await updateInvoiceStatus(request.params.id, request.body.status);
      if (!inv) {
        return reply.code(404).send({ error: { code: "NOT_FOUND", message: "Invoice not found" } });
      }
      return reply.send({ data: invoiceToResponse(inv) });
    },
  );

  // Add line item
  app.post<{ Params: { id: string }; Body: CreateLineItemRequest }>(
    "/invoices/:id/line-items",
    { schema: lineItemSchema },
    async (request, reply) => {
      const inv = await addLineItem(request.params.id, request.body);
      if (!inv) {
        return reply.code(404).send({ error: { code: "NOT_FOUND", message: "Invoice not found" } });
      }
      return reply.send({ data: invoiceToResponse(inv) });
    },
  );

  // Update line item
  app.patch<{ Params: { id: string; lineItemId: string }; Body: UpdateLineItemRequest }>(
    "/invoices/:id/line-items/:lineItemId",
    { schema: updateLineItemSchema },
    async (request, reply) => {
      const inv = await updateLineItem(
        request.params.id,
        request.params.lineItemId,
        request.body,
      );
      if (!inv) {
        return reply.code(404).send({ error: { code: "NOT_FOUND", message: "Line item not found" } });
      }
      return reply.send({ data: invoiceToResponse(inv) });
    },
  );

  // Remove line item
  app.delete<{ Params: { id: string; lineItemId: string } }>(
    "/invoices/:id/line-items/:lineItemId",
    async (request, reply) => {
      const removed = await removeLineItem(request.params.id, request.params.lineItemId);
      if (!removed) {
        return reply.code(404).send({ error: { code: "NOT_FOUND", message: "Line item not found" } });
      }
      return reply.code(204).send();
    },
  );

  // Add payment
  app.post<{ Params: { id: string }; Body: CreatePaymentRequest }>(
    "/invoices/:id/payments",
    { schema: paymentSchema },
    async (request, reply) => {
      const inv = await addPayment(request.params.id, request.body, request.user.id);
      if (!inv) {
        return reply.code(404).send({ error: { code: "NOT_FOUND", message: "Invoice not found" } });
      }
      return reply.send({ data: invoiceToResponse(inv) });
    },
  );
}
