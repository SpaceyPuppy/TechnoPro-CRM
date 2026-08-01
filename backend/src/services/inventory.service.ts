import { eq, like, or, sql, desc } from "drizzle-orm";
import { getDb, schema } from "../db/index.js";
import { generateId } from "../utils/id.js";
import type { CreateInventoryItemRequest, UpdateInventoryItemRequest } from "@technopro/shared";

export async function listInventory(options: {
  page: number;
  pageSize: number;
  search?: string;
}) {
  const db = getDb();
  const { page, pageSize, search } = options;
  const offset = (page - 1) * pageSize;

  const condition = search
    ? or(
        like(schema.inventoryItems.name, `%${search}%`),
        like(schema.inventoryItems.sku, `%${search}%`),
      )
    : undefined;

  const [rows, countResult] = await Promise.all([
    db
      .select()
      .from(schema.inventoryItems)
      .where(condition)
      .orderBy(desc(schema.inventoryItems.createdAt))
      .limit(pageSize)
      .offset(offset),
    db
      .select({ count: sql<number>`count(*)` })
      .from(schema.inventoryItems)
      .where(condition),
  ]);

  return { rows, totalCount: countResult[0]?.count ?? 0 };
}

export async function getInventoryItemById(id: string) {
  const db = getDb();
  const results = await db
    .select()
    .from(schema.inventoryItems)
    .where(eq(schema.inventoryItems.id, id))
    .limit(1);
  return results[0] ?? null;
}

export async function createInventoryItem(data: CreateInventoryItemRequest) {
  const db = getDb();
  const id = generateId();

  await db.insert(schema.inventoryItems).values({
    id,
    sku: data.sku,
    name: data.name,
    description: data.description ?? null,
    stockQty: data.stockQty ?? null,
    cost: data.cost ?? "0.00",
    price: data.price,
    barcode: data.barcode ?? null,
  });

  return getInventoryItemById(id);
}

export async function updateInventoryItem(id: string, data: UpdateInventoryItemRequest) {
  const db = getDb();
  const existing = await getInventoryItemById(id);
  if (!existing) return null;

  const updates: Record<string, unknown> = {};
  if (data.sku !== undefined) updates.sku = data.sku;
  if (data.name !== undefined) updates.name = data.name;
  if (data.description !== undefined) updates.description = data.description;
  if (data.stockQty !== undefined) updates.stockQty = data.stockQty;
  if (data.cost !== undefined) updates.cost = data.cost;
  if (data.price !== undefined) updates.price = data.price;
  if (data.barcode !== undefined) updates.barcode = data.barcode;

  if (Object.keys(updates).length > 0) {
    await db
      .update(schema.inventoryItems)
      .set(updates)
      .where(eq(schema.inventoryItems.id, id));
  }

  return getInventoryItemById(id);
}

export async function deleteInventoryItem(id: string): Promise<boolean> {
  const db = getDb();
  const existing = await getInventoryItemById(id);
  if (!existing) return false;
  await db.delete(schema.inventoryItems).where(eq(schema.inventoryItems.id, id));
  return true;
}
