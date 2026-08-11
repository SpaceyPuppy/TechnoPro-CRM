import { describe, expect, it } from "vitest";
import {
  assertSupplierOrderQuantity,
  calculatePurchaseOrderTotal,
} from "../services/purchase-orders.service.js";

describe("purchase-order safety guards", () => {
  it("calculates multi-line PO totals in integer minor units", () => {
    expect(calculatePurchaseOrderTotal([
      { quantity: 3, unitCost: "0.10" },
      { quantity: 2, unitCost: "19.95" },
    ])).toBe("40.20");
  });

  it("rejects invalid supplier pack and MOQ quantities", () => {
    expect(() => assertSupplierOrderQuantity(5, 6, 2)).toThrow("minimum order quantity");
    expect(() => assertSupplierOrderQuantity(7, 1, 2)).toThrow("multiple of 2");
    expect(() => assertSupplierOrderQuantity(6, 6, 2)).not.toThrow();
  });
});
