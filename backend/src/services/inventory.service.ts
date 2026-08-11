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
    // Quantity is established by an opening-balance stock movement in the
    // route. A general item create must not manufacture stock history.
    stockQty: data.stockQty === null || data.stockQty === undefined ? null : 0,
    cost: data.stockQty === null || data.stockQty === undefined ? (data.cost ?? "0.00") : "0.00",
    price: data.price,
    barcode: data.barcode ?? null,
    ...(data as any).upc !== undefined ? { upc: (data as any).upc || null } : {},
    ...(data as any).manufacturerPartNumber !== undefined ? { manufacturerPartNumber: (data as any).manufacturerPartNumber || null } : {},
    ...(data as any).itemType !== undefined ? { itemType: (data as any).itemType } : {},
    ...(data as any).category !== undefined ? { category: (data as any).category || null } : {},
    ...(data as any).subcategory !== undefined ? { subcategory: (data as any).subcategory || null } : {},
    ...(data as any).brand !== undefined ? { brand: (data as any).brand || null } : {},
    ...(data as any).compatibleModel !== undefined ? { compatibleModel: (data as any).compatibleModel || null } : {},
    ...(data as any).condition !== undefined ? { condition: (data as any).condition || null } : {},
    ...(data as any).reorderPoint !== undefined ? { reorderPoint: (data as any).reorderPoint } : {},
    ...(data as any).targetStockLevel !== undefined ? { targetStockLevel: (data as any).targetStockLevel } : {},
    ...(data as any).warrantyMonths !== undefined ? { warrantyMonths: (data as any).warrantyMonths } : {},
    ...(data as any).internalNotes !== undefined ? { internalNotes: (data as any).internalNotes || null } : {},
    ...(data as any).active !== undefined ? { active: (data as any).active } : {},
    ...(data as any).posSellable !== undefined ? { posSellable: (data as any).posSellable } : {},
    ...(data as any).serialized !== undefined ? { serialized: (data as any).serialized } : {},
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
  // Stock quantity and weighted cost are controlled exclusively by the stock
  // movement service. Product edits may never overwrite either value.
  if (data.price !== undefined) updates.price = data.price;
  if (data.barcode !== undefined) updates.barcode = data.barcode;
  for (const field of ["upc", "manufacturerPartNumber", "itemType", "category", "subcategory", "brand", "compatibleModel", "condition", "reorderPoint", "targetStockLevel", "warrantyMonths", "internalNotes", "active", "posSellable", "serialized"]) {
    if ((data as any)[field] !== undefined) updates[field] = (data as any)[field];
  }

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
