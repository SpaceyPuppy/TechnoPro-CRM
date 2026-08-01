import type { FastifyInstance } from "fastify";
import {
  listTickets,
  getTicketById,
  getTicketDetails,
  createTicket,
  updateTicket,
  getTicketEvents,
  listTicketEvents,
  addTicketNote,
  listTicketChecklist,
  addTicketChecklistItem,
  updateTicketChecklistItem,
  deleteTicketChecklistItem,
} from "../services/ticket.service.js";
import { parsePagination, paginationMeta } from "../utils/pagination.js";
import type { CreateTicketRequest, UpdateTicketRequest, CreateTicketEventRequest } from "@technopro/shared";

function toResponse(row: NonNullable<Awaited<ReturnType<typeof getTicketById>>>) {
  return {
    id: row.id,
    ticketNumber: row.ticketNumber,
    customerId: row.customerId,
    deviceId: row.deviceId,
    assignedToId: row.assignedToId,
    ticketType: row.ticketType,
    status: row.status,
    priority: row.priority,
    summary: row.summary,
    description: row.description,
    serviceLocation: row.serviceLocation,
    diagnosis: row.diagnosis,
    resolution: row.resolution,
    scheduledAt: row.scheduledAt?.toISOString() ?? null,
    dueDate: row.dueDate?.toISOString() ?? null,
    createdAt: row.createdAt.toISOString(),
    updatedAt: row.updatedAt.toISOString(),
  };
}

function eventToResponse(row: Awaited<ReturnType<typeof getTicketEvents>>[number]) {
  return {
    id: row.id,
    ticketId: row.ticketId,
    userId: row.userId,
    eventType: row.eventType,
    content: row.content,
    createdAt: row.createdAt.toISOString(),
  };
}

function detailToResponse(row: NonNullable<Awaited<ReturnType<typeof getTicketDetails>>>) {
  return {
    ...toResponse(row),
    customer: {
      ...row.customer,
      createdAt: row.customer.createdAt.toISOString(),
      updatedAt: row.customer.updatedAt.toISOString(),
    },
    device: row.device?.id
      ? {
          ...row.device,
          createdAt: row.device.createdAt!.toISOString(),
          updatedAt: row.device.updatedAt!.toISOString(),
        }
      : null,
    assignedTo: row.assignedTo?.id
      ? {
          ...row.assignedTo,
          createdAt: row.assignedTo.createdAt!.toISOString(),
        }
      : null,
  };
}

function checklistToResponse(
  row: Awaited<ReturnType<typeof listTicketChecklist>>[number],
) {
  return {
    ...row,
    createdAt: row.createdAt.toISOString(),
    updatedAt: row.updatedAt.toISOString(),
  };
}

const createSchema = {
  body: {
    type: "object",
    required: ["customerId", "summary"],
    properties: {
      customerId: { type: "string", minLength: 36, maxLength: 36 },
      deviceId: { type: "string", minLength: 36, maxLength: 36 },
      device: {
        type: "object",
        properties: {
          brand: { type: "string", maxLength: 100 },
          model: { type: "string", maxLength: 100 },
          serial: { type: "string", maxLength: 255 },
          imei: { type: "string", maxLength: 20 },
          password: { type: "string", maxLength: 500 },
          patternLock: { type: "string", maxLength: 100 },
          storage: { type: "string", maxLength: 50 },
          color: { type: "string", maxLength: 50 },
          carrier: { type: "string", maxLength: 100 },
        },
        additionalProperties: false,
      },
      assignedToId: { type: "string", minLength: 36, maxLength: 36 },
      ticketType: { type: "string", enum: ["repair", "onsite", "remote"] },
      priority: { type: "string", enum: ["low", "normal", "high", "urgent"] },
      summary: { type: "string", minLength: 1, maxLength: 500 },
      description: { type: "string", maxLength: 10000 },
      serviceLocation: { type: "string", maxLength: 500 },
      scheduledAt: { type: "string", format: "date-time" },
      dueDate: { type: "string", format: "date-time" },
      repairs: {
        type: "array",
        items: {
          type: "object",
          required: ["type", "description", "unitPrice"],
          properties: {
            type: { type: "string", enum: ["service", "part"] },
            description: { type: "string", minLength: 1, maxLength: 500 },
            unitPrice: { type: "string", pattern: "^\\d+\\.\\d{2}$" },
            quantity: { type: "integer", minimum: 1 },
            discount: { type: "string", pattern: "^\\d+\\.\\d{2}$" },
            inventoryItemId: { type: "string", minLength: 36, maxLength: 36 },
          },
          additionalProperties: false,
        },
      },
    },
    additionalProperties: false,
  },
} as const;

const updateSchema = {
  body: {
    type: "object",
    properties: {
      status: {
        type: "string",
        enum: [
          "new",
          "triage",
          "scheduled",
          "in_progress",
          "awaiting_customer",
          "awaiting_parts",
          "ready",
          "resolved",
          "closed",
          "cancelled",
        ],
      },
      ticketType: { type: "string", enum: ["repair", "onsite", "remote"] },
      priority: { type: "string", enum: ["low", "normal", "high", "urgent"] },
      assignedToId: { type: ["string", "null"], minLength: 36, maxLength: 36 },
      summary: { type: "string", minLength: 1, maxLength: 500 },
      description: { type: "string", maxLength: 10000 },
      serviceLocation: { type: ["string", "null"], maxLength: 500 },
      diagnosis: { type: "string", maxLength: 10000 },
      resolution: { type: "string", maxLength: 10000 },
      scheduledAt: { type: ["string", "null"], format: "date-time" },
      dueDate: { type: ["string", "null"], format: "date-time" },
    },
    additionalProperties: false,
  },
} as const;

const noteSchema = {
  body: {
    type: "object",
    required: ["content"],
    properties: {
      content: { type: "string", minLength: 1, maxLength: 10000 },
    },
    additionalProperties: false,
  },
} as const;

const checklistCreateSchema = {
  body: {
    type: "object",
    required: ["content"],
    properties: {
      content: { type: "string", minLength: 1, maxLength: 500, pattern: ".*\\S.*" },
    },
    additionalProperties: false,
  },
} as const;

const checklistUpdateSchema = {
  body: {
    type: "object",
    minProperties: 1,
    properties: {
      content: { type: "string", minLength: 1, maxLength: 500, pattern: ".*\\S.*" },
      completed: { type: "boolean" },
    },
    additionalProperties: false,
  },
} as const;

export async function ticketRoutes(app: FastifyInstance) {
  // All ticket routes require authentication
  app.addHook("preHandler", app.authenticate);

  // Flat event feed used by the native client's read-through cache.
  app.get<{ Querystring: { page?: number; pageSize?: number } }>(
    "/ticket-events",
    async (request, reply) => {
      const { page, pageSize } = parsePagination(request.query);
      const events = await listTicketEvents(page, pageSize);
      return reply.send({ data: events.map(eventToResponse) });
    },
  );

  // List tickets
  app.get<{
    Querystring: {
      page?: number;
      pageSize?: number;
      search?: string;
      status?: string;
      assignedToId?: string;
      customerId?: string;
    };
  }>("/tickets", async (request, reply) => {
    const { page, pageSize } = parsePagination(request.query);
    const { rows, totalCount } = await listTickets({
      page,
      pageSize,
      search: request.query.search,
      status: request.query.status,
      assignedToId: request.query.assignedToId,
      customerId: request.query.customerId,
    });
    return reply.send({
      data: rows.map(toResponse),
      pagination: paginationMeta(page, pageSize, totalCount),
    });
  });

  // Get ticket by ID
  app.get<{ Params: { id: string } }>("/tickets/:id", async (request, reply) => {
    const ticket = await getTicketDetails(request.params.id);
    if (!ticket) {
      return reply.code(404).send({
        error: { code: "NOT_FOUND", message: "Ticket not found" },
      });
    }
    return reply.send({ data: detailToResponse(ticket) });
  });

  // Create ticket
  app.post<{ Body: CreateTicketRequest }>(
    "/tickets",
    { schema: createSchema },
    async (request, reply) => {
      const ticket = await createTicket(request.body, request.user.id);
      return reply.code(201).send({ data: toResponse(ticket!) });
    },
  );

  // Update ticket
  app.patch<{ Params: { id: string }; Body: UpdateTicketRequest }>(
    "/tickets/:id",
    { schema: updateSchema },
    async (request, reply) => {
      const ticket = await updateTicket(request.params.id, request.body, request.user.id);
      if (!ticket) {
        return reply.code(404).send({
          error: { code: "NOT_FOUND", message: "Ticket not found" },
        });
      }
      return reply.send({ data: toResponse(ticket) });
    },
  );

  // Get ticket events/history
  app.get<{ Params: { id: string } }>("/tickets/:id/events", async (request, reply) => {
    const ticket = await getTicketById(request.params.id);
    if (!ticket) {
      return reply.code(404).send({
        error: { code: "NOT_FOUND", message: "Ticket not found" },
      });
    }
    const events = await getTicketEvents(request.params.id);
    return reply.send({ data: events.map(eventToResponse) });
  });

  // Add note to ticket
  app.post<{ Params: { id: string }; Body: { content: string } }>(
    "/tickets/:id/notes",
    { schema: noteSchema },
    async (request, reply) => {
      const ticket = await getTicketById(request.params.id);
      if (!ticket) {
        return reply.code(404).send({
          error: { code: "NOT_FOUND", message: "Ticket not found" },
        });
      }
      await addTicketNote(request.params.id, request.user.id, request.body.content);
      return reply.code(201).send({ data: { message: "Note added" } });
    },
  );

  app.get<{ Params: { id: string } }>(
    "/tickets/:id/checklist",
    async (request, reply) => {
      if (!(await getTicketById(request.params.id))) {
        return reply.code(404).send({
          error: { code: "NOT_FOUND", message: "Ticket not found" },
        });
      }
      const items = await listTicketChecklist(request.params.id);
      return reply.send({ data: items.map(checklistToResponse) });
    },
  );

  app.post<{ Params: { id: string }; Body: { content: string } }>(
    "/tickets/:id/checklist",
    { schema: checklistCreateSchema },
    async (request, reply) => {
      if (!(await getTicketById(request.params.id))) {
        return reply.code(404).send({
          error: { code: "NOT_FOUND", message: "Ticket not found" },
        });
      }
      const item = await addTicketChecklistItem(
        request.params.id,
        request.user.id,
        request.body.content.trim(),
      );
      return reply.code(201).send({ data: checklistToResponse(item) });
    },
  );

  app.patch<{
    Params: { id: string; itemId: string };
    Body: { content?: string; completed?: boolean };
  }>(
    "/tickets/:id/checklist/:itemId",
    { schema: checklistUpdateSchema },
    async (request, reply) => {
      const item = await updateTicketChecklistItem(
        request.params.id,
        request.params.itemId,
        request.user.id,
        {
          ...request.body,
          ...(request.body.content === undefined
            ? {}
            : { content: request.body.content.trim() }),
        },
      );
      if (!item) {
        return reply.code(404).send({
          error: { code: "NOT_FOUND", message: "Checklist item not found" },
        });
      }
      return reply.send({ data: checklistToResponse(item) });
    },
  );

  app.delete<{ Params: { id: string; itemId: string } }>(
    "/tickets/:id/checklist/:itemId",
    async (request, reply) => {
      const deleted = await deleteTicketChecklistItem(
        request.params.id,
        request.params.itemId,
        request.user.id,
      );
      if (!deleted) {
        return reply.code(404).send({
          error: { code: "NOT_FOUND", message: "Checklist item not found" },
        });
      }
      return reply.code(204).send();
    },
  );
}
