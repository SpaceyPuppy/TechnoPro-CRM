import type { FastifyInstance } from "fastify";
import {
  listTickets,
  getTicketById,
  createTicket,
  updateTicket,
  getTicketEvents,
  addTicketNote,
} from "../services/ticket.service";
import { parsePagination, paginationMeta } from "../utils/pagination";
import type { CreateTicketRequest, UpdateTicketRequest, CreateTicketEventRequest } from "@technopro/shared";

function toResponse(row: NonNullable<Awaited<ReturnType<typeof getTicketById>>>) {
  return {
    id: row.id,
    ticketNumber: row.ticketNumber,
    customerId: row.customerId,
    deviceId: row.deviceId,
    assignedToId: row.assignedToId,
    status: row.status,
    priority: row.priority,
    summary: row.summary,
    description: row.description,
    diagnosis: row.diagnosis,
    resolution: row.resolution,
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

const createSchema = {
  body: {
    type: "object",
    required: ["customerId", "summary"],
    properties: {
      customerId: { type: "string", minLength: 36, maxLength: 36 },
      deviceId: { type: "string", minLength: 36, maxLength: 36 },
      assignedToId: { type: "string", minLength: 36, maxLength: 36 },
      priority: { type: "string", enum: ["low", "normal", "high", "urgent"] },
      summary: { type: "string", minLength: 1, maxLength: 500 },
      description: { type: "string", maxLength: 10000 },
      dueDate: { type: "string", format: "date-time" },
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
          "open",
          "in_progress",
          "waiting_parts",
          "waiting_customer",
          "resolved",
          "closed",
          "cancelled",
        ],
      },
      priority: { type: "string", enum: ["low", "normal", "high", "urgent"] },
      assignedToId: { type: ["string", "null"], minLength: 36, maxLength: 36 },
      summary: { type: "string", minLength: 1, maxLength: 500 },
      description: { type: "string", maxLength: 10000 },
      diagnosis: { type: "string", maxLength: 10000 },
      resolution: { type: "string", maxLength: 10000 },
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

export async function ticketRoutes(app: FastifyInstance) {
  // All ticket routes require authentication
  app.addHook("preHandler", app.authenticate);

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
    const ticket = await getTicketById(request.params.id);
    if (!ticket) {
      return reply.code(404).send({
        error: { code: "NOT_FOUND", message: "Ticket not found" },
      });
    }
    return reply.send({ data: toResponse(ticket) });
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
}
