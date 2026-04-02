import { eq, like, desc, count, inArray, sql } from "drizzle-orm";
import { getDb, schema } from "../db/index.js";
import { generateId } from "../utils/id.js";
import type { CreatePurchaseOrderRequest, UpdatePurchaseOrderRequest } from "@technopro/shared";

export async function listPurchaseOrders(params: { page: number; pageSize: number; search?: string }) {
  const db = getDb();
  let where = undefined;
  
  if (params.search) {
    const term = `%${params.search}%`;
    where = like(schema.purchaseOrders.poNumber, term);
  }

  const offset = (params.page - 1) * params.pageSize;
  
  const [totalResult, rows] = await Promise.all([
    db.select({ count: count() }).from(schema.purchaseOrders).where(where),
    db.select({
        po: schema.purchaseOrders,
        supplierName: schema.suppliers.name,
      })
      .from(schema.purchaseOrders)
      .leftJoin(schema.suppliers, eq(schema.purchaseOrders.supplierId, schema.suppliers.id))
      .where(where)
      .limit(params.pageSize)
      .offset(offset)
      .orderBy(desc(schema.purchaseOrders.createdAt))
  ]);

  return {
    rows: rows.map(r => ({ ...r.po, supplierName: r.supplierName })),
    totalCount: totalResult[0]?.count ?? 0,
  };
}

export async function getPurchaseOrderById(id: string) {
  const db = getDb();
  
  const result = await db
    .select({
      po: schema.purchaseOrders,
      supplier: schema.suppliers,
    })
    .from(schema.purchaseOrders)
    .innerJoin(schema.suppliers, eq(schema.purchaseOrders.supplierId, schema.suppliers.id))
    .where(eq(schema.purchaseOrders.id, id))
    .limit(1);

  const data = result[0];
  if (!data) return null;
  
  const items = await db
    .select({
      item: schema.poItems,
      inventory: schema.inventoryItems,
    })
    .from(schema.poItems)
    .leftJoin(schema.inventoryItems, eq(schema.poItems.inventoryItemId, schema.inventoryItems.id))
    .where(eq(schema.poItems.poId, id));
  
  return { 
    ...data.po, 
    supplier: data.supplier,
    items: items.map(i => ({
      ...i.item,
      inventoryItem: i.inventory
    }))
  };
}

export async function createPurchaseOrder(data: CreatePurchaseOrderRequest) {
  const db = getDb();
  
  return await db.transaction(async (tx) => {
    const id = generateId();
    
    // Generate PO Number
    const countResult = await tx.select({ value: count() }).from(schema.purchaseOrders);
    const num = (countResult[0]?.value || 0) + 1;
    const poNumber = `PO-${String(num).padStart(5, '0')}`;
    
    // Calculate total
    let totalCost = 0;
    for (const item of data.items) {
      totalCost += item.quantity * parseFloat(item.unitCost);
    }
    
    await tx.insert(schema.purchaseOrders).values({
      id,
      poNumber,
      supplierId: data.supplierId,
      status: "draft",
      expectedDeliveryDate: data.expectedDeliveryDate ? new Date(data.expectedDeliveryDate) : null,
      notes: data.notes || null,
      totalCost: totalCost.toFixed(2),
    });
    
    for (const item of data.items) {
      await tx.insert(schema.poItems).values({
        id: generateId(),
        poId: id,
        inventoryItemId: item.inventoryItemId || null,
        description: item.description || null,
        quantity: item.quantity,
        unitCost: parseFloat(item.unitCost).toFixed(2),
      });
    }

    // Retrieve full object
    const createdPoResult = await tx.select().from(schema.purchaseOrders).where(eq(schema.purchaseOrders.id, id)).limit(1);
    const createdItems = await tx.select().from(schema.poItems).where(eq(schema.poItems.poId, id));
    
    return { ...createdPoResult[0], items: createdItems };
  });
}

export async function updatePurchaseOrder(id: string, data: UpdatePurchaseOrderRequest) {
  const db = getDb();
  
  const existing = await getPurchaseOrderById(id);
  if (!existing) return null;
  
  if (existing.status === "received" || existing.status === "cancelled") {
    throw new Error(`Cannot update a PO that is ${existing.status}`);
  }

  await db.update(schema.purchaseOrders).set({
    status: data.status !== undefined ? data.status : existing.status,
    expectedDeliveryDate: data.expectedDeliveryDate !== undefined ? (data.expectedDeliveryDate ? new Date(data.expectedDeliveryDate) : null) : existing.expectedDeliveryDate,
    notes: data.notes !== undefined ? data.notes : existing.notes,
  }).where(eq(schema.purchaseOrders.id, id));

  return getPurchaseOrderById(id);
}

export async function receivePurchaseOrder(id: string) {
  const db = getDb();
  
  return await db.transaction(async (tx) => {
    const result = await tx.select().from(schema.purchaseOrders).where(eq(schema.purchaseOrders.id, id)).limit(1);
    const po = result[0];
    
    if (!po) throw new Error("PO not found");
    if (po.status === "received" || po.status === "cancelled") {
      throw new Error(`PO is already ${po.status}`);
    }

    const items = await tx.select().from(schema.poItems).where(eq(schema.poItems.poId, id));
    
    // Update inventory logic
    for (const item of items) {
      if (!item.inventoryItemId) continue; // Skip one-off items

      // 1. Get current item cost to calculate moving average (if we wanted to, but for simplicity we'll overwrite cost)
      const invItems = await tx.select().from(schema.inventoryItems).where(eq(schema.inventoryItems.id, item.inventoryItemId)).limit(1);
      const invItem = invItems[0];
      
      if (invItem && invItem.stockQty !== null) {
        // Overwrite the cost with standard cost from PO and increment quantity
        await tx.update(schema.inventoryItems)
          .set({ 
            stockQty: sql`${schema.inventoryItems.stockQty} + ${item.quantity}`,
            cost: item.unitCost
          })
          .where(eq(schema.inventoryItems.id, item.inventoryItemId));
      } else if (invItem) {
        // Stock not tracked -> just update cost
        await tx.update(schema.inventoryItems)
          .set({ cost: item.unitCost })
          .where(eq(schema.inventoryItems.id, item.inventoryItemId));
      }
    }
    
    // Update PO status
    await tx.update(schema.purchaseOrders)
      .set({ status: "received" })
      .where(eq(schema.purchaseOrders.id, id));
      
    // Reload PO
    const finalPoResult = await tx.select().from(schema.purchaseOrders).where(eq(schema.purchaseOrders.id, id)).limit(1);
    const finalItems = await tx.select().from(schema.poItems).where(eq(schema.poItems.poId, id));
    return { ...finalPoResult[0], items: finalItems };
  });
}
