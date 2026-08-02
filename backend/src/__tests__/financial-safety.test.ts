import { describe, expect, it } from "vitest";
import {
  addDecimals,
  calculateTax,
  decimalToHundredths,
  hundredthsToDecimal,
  subtractDecimals,
} from "../utils/money.js";
import { normalisePaymentRequest } from "../services/invoice.service.js";

describe("financial regression guards", () => {
  it("keeps GST, payment and refund arithmetic in integer hundredths", () => {
    const total = addDecimals("19.95", calculateTax("19.95", "10.00"));
    const paidAfterRefund = subtractDecimals(total, "10.00");

    expect(total).toBe("21.95");
    expect(paidAfterRefund).toBe("11.95");
    expect(hundredthsToDecimal(decimalToHundredths("0.10") + decimalToHundredths("0.20"))).toBe("0.30");
  });

  it("normalises equivalent payment retries while retaining the payment reference", () => {
    expect(normalisePaymentRequest({ amount: "10.0", method: "cash", reference: " REF-1 " })).toMatchObject({
      amount: "10.00",
      reference: "REF-1",
    });
    expect(normalisePaymentRequest({ amount: "10.00", method: "cash", reference: "REF-2" }).reference).not.toBe(
      "REF-1",
    );
  });
});
