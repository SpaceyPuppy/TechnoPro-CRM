import type { FastifyInstance } from "fastify";
import {
  listInvoices,
  getInvoiceById,
  createInvoice,
  updateInvoiceStatus,
  updateQuoteStatus,
  convertQuoteToTicket,
  addLineItem,
  updateLineItem,
  removeLineItem,
  addPayment,
} from "../services/invoice.service.js";
import { parsePagination, paginationMeta } from "../utils/pagination.js";
import { recordAuditEvent } from "../services/audit.service.js";
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
    type: inv.type,
    quoteStatus: inv.quoteStatus,
    convertedTicketId: inv.convertedTicketId,
    subtotal: inv.subtotal,
    taxRate: inv.taxRate,
    taxAmount: inv.taxAmount,
    total: inv.total,
    status: inv.status,
    notes: inv.notes,
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
      taxTreatment: li.taxTreatment,
      unitCost: li.unitCost,
      discount: li.discount,
      total: li.total,
      createdAt: li.createdAt.toISOString(),
    })),
    payments: inv.payments.map((p) => ({
      id: p.id,
      invoiceId: p.invoiceId,
      amount: p.amount,
      method: p.method,
      type: p.type,
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
    type: inv.type,
    quoteStatus: inv.quoteStatus,
    subtotal: inv.subtotal,
    taxRate: inv.taxRate,
    taxAmount: inv.taxAmount,
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
      type: { type: "string", enum: ["invoice", "quote"] },
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

const quoteStatusSchema = {
  body: {
    type: "object",
    required: ["quoteStatus"],
    properties: {
      quoteStatus: { type: "string", enum: ["draft", "sent", "accepted", "declined"] },
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
      taxTreatment: { type: "string", enum: ["inclusive", "exclusive"] },
      discount: { type: "string", pattern: "^\\d+\\.\\d{2}$" },
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
      taxTreatment: { type: "string", enum: ["inclusive", "exclusive"] },
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
      type: { type: "string", enum: ["deposit", "payment", "refund"] },
      reference: { type: "string", maxLength: 255 },
      paidAt: { type: "string", format: "date-time" },
    },
    additionalProperties: false,
  },
} as const;

export async function invoiceRoutes(app: FastifyInstance) {
  app.addHook("preHandler", app.authenticate);

  // List invoices/quotes
  app.get<{
    Querystring: { page?: number; pageSize?: number; status?: string; ticketId?: string; type?: string };
  }>("/invoices", async (request, reply) => {
    const { page, pageSize } = parsePagination(request.query);
    const { rows, totalCount } = await listInvoices({
      page,
      pageSize,
      status: request.query.status,
      ticketId: request.query.ticketId,
      type: request.query.type as "invoice" | "quote" | undefined,
    });
    return reply.send({
      data: rows.map(listInvoiceToResponse),
      pagination: paginationMeta(page, pageSize, totalCount),
    });
  });

  // Get invoice/quote by ID
  app.get<{ Params: { id: string } }>("/invoices/:id", async (request, reply) => {
    const inv = await getInvoiceById(request.params.id);
    if (!inv) {
      return reply.code(404).send({ error: { code: "NOT_FOUND", message: "Invoice not found" } });
    }
    return reply.send({ data: invoiceToResponse(inv) });
  });

  // Create invoice or quote â€” counter and above
  app.post<{ Body: CreateInvoiceRequest & { type?: "invoice" | "quote" } }>(
    "/invoices",
    { schema: createInvoiceSchema, preHandler: app.requireRole("counter", "manager", "admin") },
    async (request, reply) => {
      const inv = await createInvoice(request.body);
      await recordAuditEvent("invoice", inv!.id, "created", request.user.id, {
        type: inv!.type,
        ticketId: inv!.ticketId,
      });
      return reply.code(201).send({ data: invoiceToResponse(inv!) });
    },
  );

  // Update invoice status â€” managers and admins only
  app.patch<{ Params: { id: string }; Body: { status: "draft" | "open" | "paid" | "void" } }>(
    "/invoices/:id/status",
    { schema: statusSchema, preHandler: app.requireRole("manager", "admin") },
    async (request, reply) => {
      const inv = await updateInvoiceStatus(request.params.id, request.body.status);
      if (!inv) {
        return reply.code(404).send({ error: { code: "NOT_FOUND", message: "Invoice not found" } });
      }
      await recordAuditEvent("invoice", request.params.id, "status_changed", request.user.id, {
        status: request.body.status,
      });
      return reply.send({ data: invoiceToResponse(inv) });
    },
  );

  // Update quote status â€” counter and above
  app.patch<{ Params: { id: string }; Body: { quoteStatus: "draft" | "sent" | "accepted" | "declined" } }>(
    "/invoices/:id/quote-status",
    { schema: quoteStatusSchema, preHandler: app.requireRole("counter", "manager", "admin") },
    async (request, reply) => {
      const inv = await updateQuoteStatus(request.params.id, request.body.quoteStatus);
      if (!inv) {
        return reply.code(404).send({ error: { code: "NOT_FOUND", message: "Quote not found" } });
      }
      await recordAuditEvent("invoice", request.params.id, "quote_status_changed", request.user.id, {
        quoteStatus: request.body.quoteStatus,
      });
      return reply.send({ data: invoiceToResponse(inv) });
    },
  );

  // Convert accepted quote to a new ticket â€” managers and admins only
  app.patch<{ Params: { id: string } }>(
    "/invoices/:id/convert-to-ticket",
    { preHandler: app.requireRole("manager", "admin") },
    async (request, reply) => {
      const result = await convertQuoteToTicket(request.params.id, request.user.id);
      if (!result) {
        return reply.code(400).send({
          error: { code: "INVALID_STATE", message: "Quote must be accepted before converting to ticket" },
        });
      }
      await recordAuditEvent("invoice", request.params.id, "converted_to_ticket", request.user.id, {
        ticketId: result.ticketId,
      });
      return reply.send({ data: result });
    },
  );

  // Add line item â€” counter and above
  app.post<{ Params: { id: string }; Body: CreateLineItemRequest }>(
    "/invoices/:id/line-items",
    { schema: lineItemSchema, preHandler: app.requireRole("counter", "manager", "admin") },
    async (request, reply) => {
      const result = await addLineItem(request.params.id, request.body);
      if (!result) {
        return reply.code(404).send({ error: { code: "NOT_FOUND", message: "Invoice not found" } });
      }
      await recordAuditEvent("invoice", request.params.id, "line_item_added", request.user.id, {
        lineItemId: result.lineItemId,
        inventoryItemId: request.body.inventoryItemId ?? null,
      });
      return reply.code(201).send({
        data: {
          ...invoiceToResponse(result.invoice),
          lineItemId: result.lineItemId,
        },
      });
    },
  );

  // Update line item â€” counter and above
  app.patch<{ Params: { id: string; lineItemId: string }; Body: UpdateLineItemRequest }>(
    "/invoices/:id/line-items/:lineItemId",
    { schema: updateLineItemSchema, preHandler: app.requireRole("counter", "manager", "admin") },
    async (request, reply) => {
      const inv = await updateLineItem(
        request.params.id,
        request.params.lineItemId,
        request.body,
      );
      if (!inv) {
        return reply.code(404).send({ error: { code: "NOT_FOUND", message: "Line item not found" } });
      }
      await recordAuditEvent("invoice", request.params.id, "line_item_updated", request.user.id, {
        lineItemId: request.params.lineItemId,
      });
      return reply.send({ data: invoiceToResponse(inv) });
    },
  );

  // Remove line item â€” counter and above
  app.delete<{ Params: { id: string; lineItemId: string } }>(
    "/invoices/:id/line-items/:lineItemId",
    { preHandler: app.requireRole("counter", "manager", "admin") },
    async (request, reply) => {
      const removed = await removeLineItem(request.params.id, request.params.lineItemId);
      if (!removed) {
        return reply.code(404).send({ error: { code: "NOT_FOUND", message: "Line item not found" } });
      }
      await recordAuditEvent("invoice", request.params.id, "line_item_removed", request.user.id, {
        lineItemId: request.params.lineItemId,
      });
      return reply.code(204).send();
    },
  );

  // Add payment â€” counter and above
  app.post<{
    Params: { id: string };
    Headers: { "idempotency-key"?: string };
    Body: CreatePaymentRequest & { type?: string };
  }>(
    "/invoices/:id/payments",
    { schema: paymentSchema, preHandler: app.requireRole("counter", "manager", "admin") },
    async (request, reply) => {
      const result = await addPayment(
        request.params.id,
        request.body as CreatePaymentRequest & { type?: "deposit" | "payment" | "refund" },
        request.user.id,
        request.headers["idempotency-key"],
      );
      if (!result) {
        return reply.code(404).send({ error: { code: "NOT_FOUND", message: "Invoice not found" } });
      }
      await recordAuditEvent(
        "invoice",
        request.params.id,
        result.replayed
          ? "payment_replayed"
          : request.body.type === "refund"
            ? "payment_refunded"
            : "payment_recorded",
        request.user.id,
        {
          paymentId: result.paymentId,
          type: request.body.type ?? "payment",
          method: request.body.method,
          amount: request.body.amount,
          replayed: result.replayed,
        },
      );
      return reply.code(result.replayed ? 200 : 201).send({
        data: {
          ...invoiceToResponse(result.invoice),
          paymentId: result.paymentId,
          replayed: result.replayed,
        },
      });
    },
  );
}
