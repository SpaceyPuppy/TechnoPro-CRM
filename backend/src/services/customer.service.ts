import { eq, like, or, sql } from "drizzle-orm";
import { getDb, schema } from "../db/index.js";
import { generateId } from "../utils/id.js";
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

function buildDisplayName(data: {
  name?: string;
  firstName?: string;
  lastName?: string;
  company?: string;
}): string {
  if (data.company?.trim()) return data.company.trim();
  if (data.firstName || data.lastName) {
    return [data.firstName, data.lastName].filter(Boolean).join(" ");
  }
  return data.name ?? "";
}

export async function createCustomer(data: CreateCustomerRequest) {
  const db = getDb();
  const id = generateId();
  await db.insert(schema.customers).values({
    id,
    name: buildDisplayName(data),
    firstName: data.firstName ?? null,
    lastName: data.lastName ?? null,
    company: data.company ?? null,
    email: data.email ?? null,
    phone: data.phone ?? null,
    address: data.address ?? null,
    notes: data.notes ?? null,
  });
  return getCustomerById(id);
}

export async function updateCustomer(id: string, data: UpdateCustomerRequest) {
  const db = getDb();
  const existing = await getCustomerById(id);
  if (!existing) return null;

  const updates: Record<string, unknown> = {};
  if (
    data.name !== undefined ||
    data.firstName !== undefined ||
    data.lastName !== undefined ||
    data.company !== undefined
  ) {
    updates.firstName = data.firstName ?? existing.firstName;
    updates.lastName = data.lastName ?? existing.lastName;
    updates.company = data.company ?? existing.company;
    updates.name = buildDisplayName({
      name: data.name ?? existing.name,
      firstName: (updates.firstName as string | null) ?? undefined,
      lastName: (updates.lastName as string | null) ?? undefined,
      company: (updates.company as string | null) ?? undefined,
    });
  }
  if (data.email !== undefined) updates.email = data.email;
  if (data.phone !== undefined) updates.phone = data.phone;
  if (data.address !== undefined) updates.address = data.address;
  if (data.notes !== undefined) updates.notes = data.notes;

  if (Object.keys(updates).length > 0) {
    await db.update(schema.customers).set(updates).where(eq(schema.customers.id, id));
  }

  return getCustomerById(id);
}

export async function deleteCustomer(id: string) {
  const db = getDb();
  const existing = await getCustomerById(id);
  if (!existing) return false;

  await db.delete(schema.customers).where(eq(schema.customers.id, id));
  return true;
}
