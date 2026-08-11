import "dotenv/config";
import { getDb, closeDb, schema } from "../db/index.js";
import { generateId } from "../utils/id.js";
import { eq } from "drizzle-orm";
import { applyStockMovement } from "../services/stock.service.js";

async function seedProcurement() {
  console.log("Seeding Procurement data...");
  const db = getDb();
  const suffix = Math.floor(Math.random() * 1000);

  // 0. Clear existing PO data
  await db.delete(schema.purchaseOrderReceiptLines);
  await db.delete(schema.poItems);
  await db.delete(schema.purchaseOrders);
  console.log("  Cleared existing PO data.");

  // 1. Create a Supplier
  let supplierId = generateId();
  const existingSuppliers = await db.select().from(schema.suppliers).where(eq(schema.suppliers.name, "Global Tech Parts Ltd")).limit(1);
  if (existingSuppliers.length > 0) {
    supplierId = existingSuppliers[0].id;
    console.log("  Using existing Supplier: Global Tech Parts Ltd");
  } else {
    await db.insert(schema.suppliers).values({
      id: supplierId,
      name: "Global Tech Parts Ltd",
      contactName: "John Smith",
      email: "sales@globaltechparts.com",
      phone: "02 9999 8888",
      accountNumber: "SUP-10101",
      leadTimeDays: 3,
    });
    console.log("  Created Supplier: Global Tech Parts Ltd");
  }

  // 2. Create some Inventory Items if none exist, or use existing ones
  let items = await db.select().from(schema.inventoryItems).limit(2);
  if (items.length < 2) {
    const item1Id = generateId();
    const item2Id = generateId();
    await db.insert(schema.inventoryItems).values([
      {
        id: item1Id,
        sku: "SCRN-IP13-ORG",
        name: "iPhone 13 Screen (Original)",
        stockQty: 0,
        cost: "0.00",
        price: "249.00",
      },
      {
        id: item2Id,
        sku: "BATT-IP12-PREM",
        name: "iPhone 12 Battery (Premium)",
        stockQty: 0,
        cost: "0.00",
        price: "89.00",
      }
    ]);
    await Promise.all([
      applyStockMovement({ inventoryItemId: item1Id, quantityDelta: 5, unitCost: "85.00", sourceType: "opening_balance", sourceReference: `seed-opening:${item1Id}`, reasonCode: "development_seed" }),
      applyStockMovement({ inventoryItemId: item2Id, quantityDelta: 10, unitCost: "15.50", sourceType: "opening_balance", sourceReference: `seed-opening:${item2Id}`, reasonCode: "development_seed" }),
    ]);
    items = await db.select().from(schema.inventoryItems).limit(2);
    console.log("  Created 2 Test Inventory Items");
  }

  // Supplier mappings make the native PO form exercise supplier SKUs, quotes
  // and ordering constraints instead of falling back to anonymous lines.
  await db.insert(schema.supplierItems).values([
    { id: generateId(), supplierId, inventoryItemId: items[0].id, supplierSku: "GTP-SCRN-IP13-ORG", packSize: 1, minimumOrderQty: 1, quotedUnitCost: items[0].cost },
    { id: generateId(), supplierId, inventoryItemId: items[1].id, supplierSku: "GTP-BATT-IP12-PREM", packSize: 1, minimumOrderQty: 1, quotedUnitCost: items[1].cost },
  ]).onDuplicateKeyUpdate({ set: { active: 1 } });

  // 3. Create a DRAFT Purchase Order
  const poDraftId = generateId();
  await db.insert(schema.purchaseOrders).values({
    id: poDraftId,
    poNumber: `PO-2026-DRAFT-${suffix}`,
    supplierId: supplierId,
    status: "draft",
    totalCost: "100.50",
    notes: "Initial stock order test",
  });

  await db.insert(schema.poItems).values([
    {
      id: generateId(),
      poId: poDraftId,
      inventoryItemId: items[0].id,
      quantity: 1,
      unitCost: items[0].cost,
    }
  ]);
  console.log(`  Created Draft PO: PO-2026-DRAFT-${suffix}`);

  // 4. Create an ORDERED Purchase Order (Ready for Receiving in Flutter)
  const poOrderedId = generateId();
  await db.insert(schema.purchaseOrders).values({
    id: poOrderedId,
    poNumber: `PO-2026-ORDERED-${suffix}`,
    supplierId: supplierId,
    status: "ordered",
    totalCost: "250.00",
    notes: "Express parts restock",
  });

  await db.insert(schema.poItems).values([
    {
      id: generateId(),
      poId: poOrderedId,
      inventoryItemId: items[0].id,
      quantity: 2,
      unitCost: items[0].cost,
    },
    {
      id: generateId(),
      poId: poOrderedId,
      inventoryItemId: items[1].id,
      quantity: 5,
      unitCost: items[1].cost,
    }
  ]);
  console.log(`  Created Ordered PO: PO-2026-ORDERED-${suffix} (Test this in Flutter!)`);

  console.log("Procurement Seed complete.");
  await closeDb();
}

seedProcurement().catch((err) => {
  console.error("Procurement Seed failed:", err);
  process.exit(1);
});
