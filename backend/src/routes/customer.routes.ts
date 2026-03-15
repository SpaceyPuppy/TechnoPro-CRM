import type { FastifyInstance } from "fastify";
import {
  listCustomers,
  getCustomerById,
  createCustomer,
  updateCustomer,
  deleteCustomer,
} from "../services/customer.service";
import { parsePagination, paginationMeta } from "../utils/pagination";
import type { CreateCustomerRequest, UpdateCustomerRequest } from "@technopro/shared";

function toResponse(row: NonNullable<Awaited<ReturnType<typeof getCustomerById>>>) {
  return {
    id: row.id,
    name: row.name,
    email: row.email,
    phone: row.phone,
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
      email: { type: "string", format: "email", maxLength: 255 },
      phone: { type: "string", maxLength: 50 },
      notes: { type: "string", maxLength: 5000 },
    },
    additionalProperties: false,
  },
} as const;

const updateSchema = {
  body: {
    type: "object",
    properties: {
      name: { type: "string", minLength: 1, maxLength: 255 },
      email: { type: "string", format: "email", maxLength: 255 },
      phone: { type: "string", maxLength: 50 },
      notes: { type: "string", maxLength: 5000 },
    },
    additionalProperties: false,
  },
} as const;

export async function customerRoutes(app: FastifyInstance) {
  // All customer routes require authentication
  app.addHook("preHandler", app.authenticate);

  // List customers
  app.get<{
    Querystring: { page?: number; pageSize?: number; search?: string };
  }>("/customers", async (request, reply) => {
    const { page, pageSize } = parsePagination(request.query);
    const { rows, totalCount } = await listCustomers({
      page,
      pageSize,
      search: request.query.search,
    });
    return reply.send({
      data: rows.map(toResponse),
      pagination: paginationMeta(page, pageSize, totalCount),
    });
  });

  // Get customer by ID
  app.get<{ Params: { id: string } }>("/customers/:id", async (request, reply) => {
    const customer = await getCustomerById(request.params.id);
    if (!customer) {
      return reply.code(404).send({
        error: { code: "NOT_FOUND", message: "Customer not found" },
      });
    }
    return reply.send({ data: toResponse(customer) });
  });

  // Create customer
  app.post<{ Body: CreateCustomerRequest }>(
    "/customers",
    { schema: createSchema },
    async (request, reply) => {
      const customer = await createCustomer(request.body);
      return reply.code(201).send({ data: toResponse(customer!) });
    },
  );

  // Update customer
  app.patch<{ Params: { id: string }; Body: UpdateCustomerRequest }>(
    "/customers/:id",
    { schema: updateSchema },
    async (request, reply) => {
      const customer = await updateCustomer(request.params.id, request.body);
      if (!customer) {
        return reply.code(404).send({
          error: { code: "NOT_FOUND", message: "Customer not found" },
        });
      }
      return reply.send({ data: toResponse(customer) });
    },
  );

  // Delete customer
  app.delete<{ Params: { id: string } }>("/customers/:id", async (request, reply) => {
    const deleted = await deleteCustomer(request.params.id);
    if (!deleted) {
      return reply.code(404).send({
        error: { code: "NOT_FOUND", message: "Customer not found" },
      });
    }
    return reply.code(204).send();
  });
}
