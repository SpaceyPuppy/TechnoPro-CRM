import { describe, expect, it } from "vitest";
import {
  addDecimals,
  calculateLineTotal,
  calculateTax,
  removeTax,
  calculateTimedAmount,
  decimalToHundredths,
  hundredthsToDecimal,
  subtractDecimals,
  sumDecimals,
} from "../utils/money.js";

describe("money helpers", () => {
  it("round-trips decimal strings through integer hundredths", () => {
    expect(decimalToHundredths("123.45")).toBe(12345n);
    expect(hundredthsToDecimal(-105n)).toBe("-1.05");
  });

  it("calculates line totals with quantity and discount", () => {
    expect(calculateLineTotal("19.99", 3, "10.00")).toBe("53.97");
  });

  it("rounds GST to the nearest cent", () => {
    expect(calculateTax("19.95", "10.00")).toBe("2.00");
  });

  it("extracts GST from inclusive prices without floating point", () => {
    expect(removeTax("110.00", "10.00")).toBe("100.00");
    expect(removeTax("19.95", "10.00")).toBe("18.14");
  });

  it("calculates timed labour without floating point", () => {
    expect(calculateTimedAmount("75.00", 5400)).toBe("112.50");
    expect(calculateTimedAmount("75.00", 1)).toBe("0.02");
  });

  it("adds, subtracts and sums without floating point", () => {
    expect(sumDecimals(["0.10", "0.20", "10.00"])).toBe("10.30");
    expect(addDecimals("10.00", "0.30")).toBe("10.30");
    expect(subtractDecimals("10.00", "0.30")).toBe("9.70");
  });
});
