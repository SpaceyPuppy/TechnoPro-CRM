import type { FastifyInstance } from "fastify";
import {
  startTimeEntry,
  createManualTimeEntry,
  stopTimeEntry,
  listTimeEntries,
  getRunningTimeEntryForUser,
  billTimeEntry,
  updateTimeEntryBillable,
} from "../services/time-entry.service.js";
import { InvoiceConflictError } from "../services/invoice.service.js";
import type {
  StartTimeEntryRequest,
  BillTimeEntryRequest,
  UpdateTimeEntryRequest,
} from "@technopro/shared";
import { recordAuditEvent } from "../services/audit.service.js";

const startTimeEntrySchema = {
  body: {
    type: "object",
    properties: {
      note: { type: "string", maxLength: 500 },
      labourRate: { type: "string", pattern: "^\\d+\\.\\d{2}$" },
      billable: { type: "boolean" },
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

const manualTimeEntrySchema = {
  body: {
    type: "object",
    required: ["durationSeconds"],
    properties: {
      durationSeconds: { type: "integer", minimum: 60, maximum: 604800 },
      note: { type: "string", maxLength: 500 },
      labourRate: { type: "string", pattern: "^\\d+\\.\\d{2}$" },
      billable: { type: "boolean" },
      startedAt: { type: "string", format: "date-time" },
    },
    additionalProperties: false,
  },
} as const;

const updateTimeEntrySchema = {
  body: {
    type: "object",
    required: ["billable"],
    properties: {
      billable: { type: "boolean" },
    },
    additionalProperties: false,
  },
} as const;

export async function timeEntryRoutes(app: FastifyInstance) {
  app.addHook("preHandler", app.authenticate);

  app.get("/time-entries/current", async (request, reply) => {
    const entry = await getRunningTimeEntryForUser(request.user.id);
    return reply.send({ data: entry });
  });

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

  // Start a timer — technicians and above
  app.post<{ Params: { ticketId: string }; Body: StartTimeEntryRequest }>(
    "/tickets/:ticketId/time-entries/start",
    { schema: startTimeEntrySchema, preHandler: app.requireRole("technician", "counter", "manager", "admin") },
    async (request, reply) => {
      try {
        const entry = await startTimeEntry(request.params.ticketId, request.user.id, {
          note: request.body.note,
          labourRate: request.body.labourRate,
          billable: request.body.billable,
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

  app.post<{
    Params: { ticketId: string };
    Body: { durationSeconds: number; note?: string; labourRate?: string; billable?: boolean; startedAt?: string };
  }>(
    "/tickets/:ticketId/time-entries/manual",
    { schema: manualTimeEntrySchema, preHandler: app.requireRole("technician", "counter", "manager", "admin") },
    async (request, reply) => {
      try {
        const entry = await createManualTimeEntry(
          request.params.ticketId,
          request.user.id,
          request.body,
        );
        return reply.code(201).send({ data: entry });
      } catch (error) {
        const message = error instanceof Error ? error.message : "Invalid manual time entry";
        const status = message.includes("not found") ? 404 : 400;
        return reply.code(status).send({
          error: { code: status === 404 ? "NOT_FOUND" : "INVALID_TIME_ENTRY", message },
        });
      }
    },
  );

  // Stop a timer — technicians and above
  app.post<{ Params: { id: string } }>("/time-entries/:id/stop", { preHandler: app.requireRole("technician", "counter", "manager", "admin") }, async (request, reply) => {
    try {
      const entry = await stopTimeEntry(
        request.params.id,
        request.user.id,
        request.user.role === "manager" || request.user.role === "admin",
      );
      return reply.send({ data: entry });
    } catch (err) {
      const message = err instanceof Error ? err.message : "Unknown error";
      if (message.includes("not found")) {
        return reply.code(404).send({ error: { code: "NOT_FOUND", message } });
      }
      if (message.includes("already stopped")) {
        return reply.code(400).send({ error: { code: "INVALID_STATE", message } });
      }
      if (message.includes("cannot stop")) {
        return reply.code(403).send({ error: { code: "FORBIDDEN", message } });
      }
      return reply.code(500).send({ error: { code: "INTERNAL_ERROR", message } });
    }
  });

  app.patch<{ Params: { id: string }; Body: UpdateTimeEntryRequest }>(
    "/time-entries/:id",
    { schema: updateTimeEntrySchema, preHandler: app.requireRole("technician", "counter", "manager", "admin") },
    async (request, reply) => {
      try {
        const entry = await updateTimeEntryBillable(
          request.params.id,
          request.user.id,
          request.body.billable,
          request.user.role === "manager" || request.user.role === "admin",
        );
        await recordAuditEvent("time_entry", request.params.id, "billable_changed", request.user.id, {
          billable: entry.billable,
        });
        return reply.send({ data: entry });
      } catch (err) {
        if (err instanceof InvoiceConflictError) {
          return reply.code(err.statusCode).send({
            error: { code: err.code, message: err.message },
          });
        }
        const message = err instanceof Error ? err.message : "Unknown error";
        if (message.includes("not found")) {
          return reply.code(404).send({ error: { code: "NOT_FOUND", message } });
        }
        if (message.includes("cannot change")) {
          return reply.code(403).send({ error: { code: "FORBIDDEN", message } });
        }
        return reply.code(500).send({ error: { code: "INTERNAL_ERROR", message } });
      }
    },
  );

  // Bill a time entry — technicians and above
  app.post<{ Params: { id: string }; Body: BillTimeEntryRequest }>(
    "/time-entries/:id/bill",
    { schema: billTimeEntrySchema, preHandler: app.requireRole("technician", "counter", "manager", "admin") },
    async (request, reply) => {
      try {
        const invoice = await billTimeEntry(request.params.id, undefined, request.body.description);
        if (invoice) {
          await recordAuditEvent("time_entry", request.params.id, "billed", request.user.id, {
            invoiceId: invoice.id,
          });
        }
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
