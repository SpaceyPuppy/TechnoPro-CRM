import type { FastifyInstance } from "fastify";
import {
  startTimeEntry,
  stopTimeEntry,
  listTimeEntries,
  billTimeEntry,
} from "../services/time-entry.service.js";
import type { StartTimeEntryRequest, BillTimeEntryRequest } from "@technopro/shared";

const startTimeEntrySchema = {
  body: {
    type: "object",
    properties: {
      note: { type: "string", maxLength: 500 },
      labourRate: { type: "string", pattern: "^\\d+\\.\\d{2}$" },
    },
    additionalProperties: false,
  },
} as const;

const billTimeEntrySchema = {
  body: {
    type: "object",
    properties: {
      description: { type: "string", maxLength: 500 },
    },
    additionalProperties: false,
  },
} as const;

export async function timeEntryRoutes(app: FastifyInstance) {
  app.addHook("preHandler", app.authenticate);

  // List time entries for a ticket
  app.get<{ Params: { ticketId: string } }>(
    "/tickets/:ticketId/time-entries",
    async (request, reply) => {
      try {
        const entries = await listTimeEntries(request.params.ticketId);
        return reply.send({ data: entries });
      } catch (err) {
        const message = err instanceof Error ? err.message : "Unknown error";
        return reply.code(404).send({ error: { code: "NOT_FOUND", message } });
      }
    },
  );

  // Start a timer
  app.post<{ Params: { ticketId: string }; Body: StartTimeEntryRequest }>(
    "/tickets/:ticketId/time-entries/start",
    { schema: startTimeEntrySchema },
    async (request, reply) => {
      try {
        const entry = await startTimeEntry(request.params.ticketId, request.user.id, {
          note: request.body.note,
          labourRate: request.body.labourRate,
        });
        return reply.code(201).send({ data: entry });
      } catch (err) {
        const message = err instanceof Error ? err.message : "Unknown error";
        if (message.includes("not found")) {
          return reply.code(404).send({ error: { code: "NOT_FOUND", message } });
        }
        if (message.includes("already running")) {
          return reply.code(400).send({ error: { code: "INVALID_STATE", message } });
        }
        return reply.code(500).send({ error: { code: "INTERNAL_ERROR", message } });
      }
    },
  );

  // Stop a timer
  app.post<{ Params: { id: string } }>("/time-entries/:id/stop", async (request, reply) => {
    try {
      const entry = await stopTimeEntry(request.params.id);
      return reply.send({ data: entry });
    } catch (err) {
      const message = err instanceof Error ? err.message : "Unknown error";
      if (message.includes("not found")) {
        return reply.code(404).send({ error: { code: "NOT_FOUND", message } });
      }
      if (message.includes("already stopped")) {
        return reply.code(400).send({ error: { code: "INVALID_STATE", message } });
      }
      return reply.code(500).send({ error: { code: "INTERNAL_ERROR", message } });
    }
  });

  // Bill a time entry
  app.post<{ Params: { id: string }; Body: BillTimeEntryRequest }>(
    "/time-entries/:id/bill",
    { schema: billTimeEntrySchema },
    async (request, reply) => {
      try {
        const invoice = await billTimeEntry(request.params.id, undefined, request.body.description);
        return reply.send({ data: invoice });
      } catch (err) {
        const message = err instanceof Error ? err.message : "Unknown error";
        if (message.includes("not found")) {
          return reply.code(404).send({ error: { code: "NOT_FOUND", message } });
        }
        if (message.includes("Cannot bill") || message.includes("already billed")) {
          return reply.code(400).send({ error: { code: "INVALID_STATE", message } });
        }
        return reply.code(500).send({ error: { code: "INTERNAL_ERROR", message } });
      }
    },
  );
}
