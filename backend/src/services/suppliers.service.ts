import { eq, like, or, count } from "drizzle-orm";
import { getDb, schema } from "../db/index.js";
import { generateId } from "../utils/id.js";
import type { CreateSupplierRequest, UpdateSupplierRequest } from "@technopro/shared";

export async function listSuppliers(params: { page: number; pageSize: number; search?: string }) {
  const db = getDb();
  let where = undefined;
  
  if (params.search) {
    const term = `%${params.search}%`;
    where = or(
      like(schema.suppliers.name, term),
      like(schema.suppliers.email, term),
      like(schema.suppliers.contactName, term)
    );
  }

  const offset = (params.page - 1) * params.pageSize;
  
  const [totalResult, rows] = await Promise.all([
    db.select({ count: count() }).from(schema.suppliers).where(where),
    db.select()
      .from(schema.suppliers)
      .where(where)
      .limit(params.pageSize)
      .offset(offset)
      .orderBy(schema.suppliers.name)
  ]);

  return {
    rows,
    totalCount: totalResult[0]?.count ?? 0,
  };
}

export async function getSupplierById(id: string) {
  const db = getDb();
  const result = await db.select().from(schema.suppliers).where(eq(schema.suppliers.id, id)).limit(1);
  return result[0] || null;
}

export async function createSupplier(data: CreateSupplierRequest) {
  const db = getDb();
  const id = generateId();
  
  await db.insert(schema.suppliers).values({
    id,
    name: data.name,
    contactName: data.contactName || null,
    email: data.email || null,
    phone: data.phone || null,
    accountNumber: data.accountNumber || null,
    leadTimeDays: data.leadTimeDays || null,
    notes: data.notes || null,
  });

  return getSupplierById(id);
}

export async function updateSupplier(id: string, data: UpdateSupplierRequest) {
  const db = getDb();
  
  const existing = await getSupplierById(id);
  if (!existing) return null;

  await db.update(schema.suppliers).set({
    name: data.name !== undefined ? data.name : existing.name,
    contactName: data.contactName !== undefined ? data.contactName : existing.contactName,
    email: data.email !== undefined ? data.email : existing.email,
    phone: data.phone !== undefined ? data.phone : existing.phone,
    accountNumber: data.accountNumber !== undefined ? data.accountNumber : existing.accountNumber,
    leadTimeDays: data.leadTimeDays !== undefined ? data.leadTimeDays : existing.leadTimeDays,
    notes: data.notes !== undefined ? data.notes : existing.notes,
  }).where(eq(schema.suppliers.id, id));

  return getSupplierById(id);
}

export async function deleteSupplier(id: string) {
  const db = getDb();
  const result = await db.delete(schema.suppliers).where(eq(schema.suppliers.id, id));
  return result[0].affectedRows > 0;
}
