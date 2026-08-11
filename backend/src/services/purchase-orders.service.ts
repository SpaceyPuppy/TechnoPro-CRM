import { and, eq, like, desc, count, inArray, sql } from "drizzle-orm";
import { getDb, schema } from "../db/index.js";
import { generateId } from "../utils/id.js";
import type { CreatePurchaseOrderRequest, UpdatePurchaseOrderRequest } from "@technopro/shared";
import { applyStockMovementInTransaction } from "./stock.service.js";
import { decimalToHundredths, hundredthsToDecimal } from "../utils/money.js";

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
  const id = generateId();
  
  await db.transaction(async (tx) => {
    
    // Generate PO Number
    const countResult = await tx.select({ value: count() }).from(schema.purchaseOrders);
    const num = (countResult[0]?.value || 0) + 1;
    const poNumber = `PO-${String(num).padStart(5, '0')}`;
    
    // Calculate total
    let totalCost = 0n;
    for (const item of data.items) {
      if (!Number.isSafeInteger(item.quantity) || item.quantity < 1) throw new Error("Purchase order quantities must be positive integers");
      const unitCost = decimalToHundredths(item.unitCost);
      if (unitCost < 0n) throw new Error("Purchase order unit cost cannot be negative");
      totalCost += BigInt(item.quantity) * unitCost;
    }
    
    await tx.insert(schema.purchaseOrders).values({
      id,
      poNumber,
      supplierId: data.supplierId,
      status: "draft",
      expectedDeliveryDate: data.expectedDeliveryDate ? new Date(data.expectedDeliveryDate) : null,
      notes: data.notes || null,
      totalCost: hundredthsToDecimal(totalCost),
    });
    
    for (const item of data.items) {
      const [supplierItem] = item.supplierItemId
        ? await tx.select().from(schema.supplierItems).where(eq(schema.supplierItems.id, item.supplierItemId)).limit(1)
        : [];
      if (supplierItem && supplierItem.supplierId !== data.supplierId) throw new Error("Supplier item does not belong to this purchase order supplier");
      if (supplierItem && supplierItem.active !== 1) throw new Error("Supplier item is inactive");
      if (supplierItem && item.quantity < supplierItem.minimumOrderQty) throw new Error(`Supplier item minimum order quantity is ${supplierItem.minimumOrderQty}`);
      if (supplierItem && item.quantity % supplierItem.packSize !== 0) throw new Error(`Supplier item quantity must be a multiple of ${supplierItem.packSize}`);
      await tx.insert(schema.poItems).values({
        id: generateId(),
        poId: id,
        inventoryItemId: item.inventoryItemId || null,
        supplierItemId: item.supplierItemId || null,
        supplierSku: supplierItem?.supplierSku ?? null,
        description: item.description || null,
        quantity: item.quantity,
        unitCost: hundredthsToDecimal(decimalToHundredths(item.unitCost)),
      });
    }

  });

  const created = await getPurchaseOrderById(id);
  if (!created) throw new Error("Failed to create purchase order");
  return created;
}

export async function updatePurchaseOrder(id: string, data: UpdatePurchaseOrderRequest) {
  const db = getDb();
  
  const existing = await getPurchaseOrderById(id);
  if (!existing) return null;
  if (data.status !== undefined && data.status !== "draft" && data.status !== "ordered") {
    throw new Error("Use receiving to change a purchase order to received or cancelled");
  }
  
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

export async function receivePurchaseOrder(id: string, actorUserId: string, input: { receiptReference: string; lines: Array<{ poItemId: string; receivedQty: number; cancelledQty?: number; unitCost?: string; reasonCode?: string; reasonNote?: string }> }) {
  const db = getDb();
  await db.transaction(async (tx) => {
    const result = await tx.select().from(schema.purchaseOrders).where(eq(schema.purchaseOrders.id, id)).limit(1);
    const po = result[0];
    
    if (!po) throw new Error("PO not found");
    if (po.status === "received" || po.status === "cancelled") {
      throw new Error(`PO is already ${po.status}`);
    }
    if (!input.receiptReference?.trim() || input.lines.length === 0) throw new Error("A receipt reference and at least one line are required");
    for (const line of input.lines) {
      if (!Number.isSafeInteger(line.receivedQty) || line.receivedQty < 0 || !Number.isSafeInteger(line.cancelledQty ?? 0) || (line.receivedQty + (line.cancelledQty ?? 0)) === 0) throw new Error("Receipt quantities must be positive integers");
      const [item] = await tx.select().from(schema.poItems).where(and(eq(schema.poItems.id, line.poItemId), eq(schema.poItems.poId, id))).limit(1).for("update");
      if (!item) throw new Error("Purchase order line not found");
      const remaining = item.quantity - item.receivedQty - item.cancelledQty;
      if (line.receivedQty + (line.cancelledQty ?? 0) > remaining) throw new Error("Receipt exceeds the remaining quantity");
      const sourceReference = `po-receipt:${id}:${input.receiptReference}:${item.id}`;
      const [priorReceipt] = await tx.select({ id: schema.purchaseOrderReceiptLines.id }).from(schema.purchaseOrderReceiptLines).where(and(eq(schema.purchaseOrderReceiptLines.poItemId, item.id), eq(schema.purchaseOrderReceiptLines.receiptReference, input.receiptReference))).limit(1).for("update");
      if (priorReceipt) throw new Error("This receipt line has already been processed");
      if (line.receivedQty > 0 && item.inventoryItemId) {
        const [inventory] = await tx.select().from(schema.inventoryItems).where(eq(schema.inventoryItems.id, item.inventoryItemId)).limit(1).for("update");
        if (!inventory) throw new Error("Inventory item not found");
        if (inventory.stockQty !== null) await applyStockMovementInTransaction(tx, { inventoryItemId: inventory.id, quantityDelta: line.receivedQty, unitCost: line.unitCost ?? item.unitCost.toString(), sourceType: "po_receipt", sourceReference, reasonCode: line.reasonCode ?? "supplier_receipt", reasonNote: line.reasonNote, actorUserId });
      }
      await tx.insert(schema.purchaseOrderReceiptLines).values({
        id: generateId(),
        poItemId: item.id,
        receiptReference: input.receiptReference.trim(),
        receivedQty: line.receivedQty,
        cancelledQty: line.cancelledQty ?? 0,
      });
      await tx.update(schema.poItems).set({ receivedQty: sql`${schema.poItems.receivedQty} + ${line.receivedQty}`, cancelledQty: sql`${schema.poItems.cancelledQty} + ${line.cancelledQty ?? 0}` }).where(eq(schema.poItems.id, item.id));
    }
    const allItems = await tx.select().from(schema.poItems).where(eq(schema.poItems.poId, id));
    const resolved = allItems.every((item) => item.quantity <= item.receivedQty + item.cancelledQty);
    const anyReceived = allItems.some((item) => item.receivedQty > 0);
    await tx.update(schema.purchaseOrders).set({ status: resolved ? (anyReceived ? "received" : "cancelled") : "partially_received" }).where(eq(schema.purchaseOrders.id, id));
  });

  const received = await getPurchaseOrderById(id);
  if (!received) throw new Error("Failed to reload received purchase order");
  return received;
}
