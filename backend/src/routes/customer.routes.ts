import type { FastifyInstance } from "fastify";
import {
  listCustomers,
  getCustomerById,
  createCustomer,
  updateCustomer,
  deleteCustomer,
} from "../services/customer.service.js";
import { parsePagination, paginationMeta } from "../utils/pagination.js";
import { getDb, schema } from "../db/index.js";
import { generateId } from "../utils/id.js";
import { desc } from "drizzle-orm";
import type { CreateCustomerRequest, UpdateCustomerRequest } from "@technopro/shared";

function toResponse(row: NonNullable<Awaited<ReturnType<typeof getCustomerById>>>) {
  return {
    id: row.id,
    name: row.name,
    firstName: row.firstName,
    lastName: row.lastName,
    company: row.company,
    email: row.email,
    phone: row.phone,
    address: row.address,
    notes: row.notes,
    createdAt: row.createdAt.toISOString(),
    updatedAt: row.updatedAt.toISOString(),
  };
}

const customerBodyProperties = {
  name: { type: "string", minLength: 1, maxLength: 255 },
  firstName: { type: "string", maxLength: 100 },
  lastName: { type: "string", maxLength: 100 },
  company: { type: "string", maxLength: 255 },
  email: { type: "string", format: "email", maxLength: 255 },
  phone: { type: "string", maxLength: 50 },
  address: { type: "string", maxLength: 500 },
  notes: { type: "string", maxLength: 5000 },
} as const;

const createSchema = {
  body: {
    type: "object",
    required: ["name"],
    properties: customerBodyProperties,
    additionalProperties: false,
  },
} as const;

const updateSchema = {
  body: {
    type: "object",
    properties: customerBodyProperties,
    additionalProperties: false,
  },
} as const;

export async function customerRoutes(app: FastifyInstance) {
  // All customer routes require authentication
  app.addHook("preHandler", app.authenticate);

  // Flat device feed used by the native client's read-through cache.
  app.get<{ Querystring: { page?: number; pageSize?: number } }>(
    "/devices",
    async (request, reply) => {
      const { page, pageSize } = parsePagination(request.query);
      const db = getDb();
      const rows = await db
        .select()
        .from(schema.devices)
        .orderBy(desc(schema.devices.updatedAt))
        .limit(pageSize)
        .offset((page - 1) * pageSize);
      return reply.send({
        data: rows.map((device) => ({
          ...device,
          createdAt: device.createdAt.toISOString(),
          updatedAt: device.updatedAt.toISOString(),
        })),
      });
    },
  );

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

  // Bulk import customers â€” managers and admins only
  app.post<{
    Body: {
      rows: Array<{ name: string; email?: string; phone?: string; notes?: string }>;
    };
  }>(
    "/customers/import",
    {
      schema: {
        body: {
          type: "object",
          required: ["rows"],
          properties: {
            rows: {
              type: "array",
              maxItems: 2000,
              items: {
                type: "object",
                required: ["name"],
                properties: {
                  name: { type: "string", minLength: 1, maxLength: 255 },
                  email: { type: "string", maxLength: 255 },
                  phone: { type: "string", maxLength: 50 },
                  notes: { type: "string", maxLength: 5000 },
                },
                additionalProperties: false,
              },
            },
          },
          additionalProperties: false,
        },
      },
      preHandler: app.requireRole("manager", "admin"),
    },
    async (request, reply) => {
      const db = getDb();
      let imported = 0;
      const errors: Array<{ row: number; reason: string }> = [];

      for (let i = 0; i < request.body.rows.length; i++) {
        const row = request.body.rows[i]!;
        try {
          const name = row.name.trim();
          if (!name) { errors.push({ row: i + 1, reason: "Name is required" }); continue; }
          await db.insert(schema.customers).values({
            id: generateId(),
            name,
            firstName: null,
            lastName: null,
            company: null,
            email: row.email?.trim() || null,
            phone: row.phone?.trim() || null,
            notes: row.notes?.trim() || null,
          });
          imported++;
        } catch (err) {
          const message = err instanceof Error ? err.message : "Unknown error";
          errors.push({ row: i + 1, reason: message.includes("Duplicate") ? "Duplicate entry" : message });
        }
      }

      return reply.send({ data: { imported, skipped: errors.length, errors } });
    },
  );

  // Delete customer â€” managers and admins only
  app.delete<{ Params: { id: string } }>("/customers/:id", { preHandler: app.requireRole("manager", "admin") }, async (request, reply) => {
    const deleted = await deleteCustomer(request.params.id);
    if (!deleted) {
      return reply.code(404).send({
        error: { code: "NOT_FOUND", message: "Customer not found" },
      });
    }
    return reply.code(204).send();
  });
}
