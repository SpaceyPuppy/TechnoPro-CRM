import type { FastifyInstance } from "fastify";
import {
  listSuppliers,
  getSupplierById,
  createSupplier,
  updateSupplier,
  deleteSupplier,
} from "../services/suppliers.service.js";
import { parsePagination, paginationMeta } from "../utils/pagination.js";
import type { CreateSupplierRequest, UpdateSupplierRequest } from "@technopro/shared";
import { recordAuditEvent } from "../services/audit.service.js";
import { rolePolicies } from "../access-control.js";

function toResponse(row: NonNullable<Awaited<ReturnType<typeof getSupplierById>>>) {
  return {
    id: row.id,
    name: row.name,
    contactName: row.contactName,
    email: row.email,
    phone: row.phone,
    accountNumber: row.accountNumber,
    leadTimeDays: row.leadTimeDays,
    notes: row.notes,
    createdAt: row.createdAt.toISOString(),
    updatedAt: row.updatedAt.toISOString(),
  };
}

const createSchema = {
  body: {
    type: "object",
    required: ["name"],
    properties: {
      name: { type: "string", minLength: 1, maxLength: 255 },
      contactName: { type: "string", maxLength: 255 },
      email: { type: "string", format: "email", maxLength: 255 },
      phone: { type: "string", maxLength: 50 },
      accountNumber: { type: "string", maxLength: 100 },
      leadTimeDays: { type: ["integer", "null"] },
      notes: { type: "string" },
    },
    additionalProperties: false,
  },
} as const;

const updateSchema = {
  body: {
    type: "object",
    properties: {
      name: { type: "string", minLength: 1, maxLength: 255 },
      contactName: { type: "string", maxLength: 255 },
      email: { type: "string", format: "email", maxLength: 255 },
      phone: { type: "string", maxLength: 50 },
      accountNumber: { type: "string", maxLength: 100 },
      leadTimeDays: { type: ["integer", "null"] },
      notes: { type: "string" },
    },
    additionalProperties: false,
  },
} as const;

export async function supplierRoutes(app: FastifyInstance) {
  app.addHook("preHandler", app.authenticate);

  app.get<{ Querystring: { page?: number; pageSize?: number; search?: string } }>(
    "/suppliers",
    { preHandler: app.requireRole(...rolePolicies.manager) },
    async (request, reply) => {
      const { page, pageSize } = parsePagination(request.query);
      const { rows, totalCount } = await listSuppliers({
        page,
        pageSize,
        search: request.query.search,
      });
      return reply.send({
        data: rows.map(toResponse),
        pagination: paginationMeta(page, pageSize, totalCount),
      });
    },
  );

  app.get<{ Params: { id: string } }>("/suppliers/:id", { preHandler: app.requireRole(...rolePolicies.manager) }, async (request, reply) => {
    const item = await getSupplierById(request.params.id);
    if (!item) {
      return reply.code(404).send({ error: { code: "NOT_FOUND", message: "Supplier not found" } });
    }
    return reply.send({ data: toResponse(item) });
  });

  app.post<{ Body: CreateSupplierRequest }>(
    "/suppliers",
    { schema: createSchema, preHandler: app.requireRole(...rolePolicies.manager) },
    async (request, reply) => {
      const item = await createSupplier(request.body);
      await recordAuditEvent("supplier", item!.id, "created", request.user.id, {
        after: toResponse(item!),
      });
      return reply.code(201).send({ data: toResponse(item!) });
    },
  );

  app.patch<{ Params: { id: string }; Body: UpdateSupplierRequest }>(
    "/suppliers/:id",
    { schema: updateSchema, preHandler: app.requireRole(...rolePolicies.manager) },
    async (request, reply) => {
      const before = await getSupplierById(request.params.id);
      const item = await updateSupplier(request.params.id, request.body);
      if (!item) {
        return reply.code(404).send({ error: { code: "NOT_FOUND", message: "Supplier not found" } });
      }
      await recordAuditEvent("supplier", item.id, "updated", request.user.id, {
        before: before ? toResponse(before) : null,
        after: toResponse(item),
      });
      return reply.send({ data: toResponse(item) });
    },
  );

  app.delete<{ Params: { id: string } }>("/suppliers/:id", { preHandler: app.requireRole(...rolePolicies.manager) }, async (request, reply) => {
    const before = await getSupplierById(request.params.id);
    const deleted = await deleteSupplier(request.params.id);
    if (!deleted) {
      return reply.code(404).send({ error: { code: "NOT_FOUND", message: "Supplier not found" } });
    }
    await recordAuditEvent("supplier", request.params.id, "deleted", request.user.id, {
      before: before ? toResponse(before) : null,
    });
    return reply.code(204).send();
  });
}
