import { eq, like, or, sql } from "drizzle-orm";
import { getDb, schema } from "../db/index";
import { generateId } from "../utils/id";
import type { CreateCustomerRequest, UpdateCustomerRequest } from "@technopro/shared";

export async function listCustomers(options: {
  page: number;
  pageSize: number;
  search?: string;
}) {
  const db = getDb();
  const { page, pageSize, search } = options;
  const offset = (page - 1) * pageSize;

  const conditions = search
    ? or(
        like(schema.customers.name, `%${search}%`),
        like(schema.customers.email, `%${search}%`),
        like(schema.customers.phone, `%${search}%`),
      )
    : undefined;

  const [rows, countResult] = await Promise.all([
    db
      .select()
      .from(schema.customers)
      .where(conditions)
      .orderBy(schema.customers.name)
      .limit(pageSize)
      .offset(offset),
    db
      .select({ count: sql<number>`count(*)` })
      .from(schema.customers)
      .where(conditions),
  ]);

  return { rows, totalCount: countResult[0]?.count ?? 0 };
}

export async function getCustomerById(id: string) {
  const db = getDb();
  const results = await db
    .select()
    .from(schema.customers)
    .where(eq(schema.customers.id, id))
    .limit(1);
  return results[0] ?? null;
}

export async function createCustomer(data: CreateCustomerRequest) {
  const db = getDb();
  const id = generateId();
  await db.insert(schema.customers).values({
    id,
    name: data.name,
    email: data.email ?? null,
    phone: data.phone ?? null,
    notes: data.notes ?? null,
  });
  return getCustomerById(id);
}

export async function updateCustomer(id: string, data: UpdateCustomerRequest) {
  const db = getDb();
  const existing = await getCustomerById(id);
  if (!existing) return null;

  await db
    .update(schema.customers)
    .set({
      ...(data.name !== undefined && { name: data.name }),
      ...(data.email !== undefined && { email: data.email }),
      ...(data.phone !== undefined && { phone: data.phone }),
      ...(data.notes !== undefined && { notes: data.notes }),
    })
    .where(eq(schema.customers.id, id));

  return getCustomerById(id);
}

export async function deleteCustomer(id: string) {
  const db = getDb();
  const existing = await getCustomerById(id);
  if (!existing) return false;

  await db.delete(schema.customers).where(eq(schema.customers.id, id));
  return true;
}
