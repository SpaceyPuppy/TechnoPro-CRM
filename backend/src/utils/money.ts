const DECIMAL_PATTERN = /^-?\d+(?:\.\d{1,2})?$/;

/** Parse a decimal currency/rate string without using floating point. */
export function decimalToHundredths(value: string): bigint {
  if (!DECIMAL_PATTERN.test(value)) {
    throw new Error(`Invalid decimal value: ${value}`);
  }

  const negative = value.startsWith("-");
  const unsigned = negative ? value.slice(1) : value;
  const [whole, fraction = ""] = unsigned.split(".");
  const result = BigInt(whole!) * 100n + BigInt(fraction.padEnd(2, "0"));
  return negative ? -result : result;
}

export function hundredthsToDecimal(value: bigint): string {
  const negative = value < 0n;
  const absolute = negative ? -value : value;
  const whole = absolute / 100n;
  const fraction = (absolute % 100n).toString().padStart(2, "0");
  return `${negative ? "-" : ""}${whole}.${fraction}`;
}

function divideRounded(numerator: bigint, denominator: bigint): bigint {
  if (numerator < 0n || denominator <= 0n) {
    throw new Error("Rounded division requires non-negative values");
  }
  return (numerator + denominator / 2n) / denominator;
}

/** Calculate a quantity/discount line total using integer minor units. */
export function calculateLineTotal(
  unitPrice: string,
  quantity: number,
  discountPercent = "0.00",
): string {
  if (!Number.isSafeInteger(quantity) || quantity < 1) {
    throw new Error("Quantity must be a positive integer");
  }

  const unitPriceHundredths = decimalToHundredths(unitPrice);
  const discountHundredths = decimalToHundredths(discountPercent);
  if (unitPriceHundredths < 0n) throw new Error("Unit price cannot be negative");
  if (discountHundredths < 0n || discountHundredths > 10000n) {
    throw new Error("Discount must be between 0.00 and 100.00");
  }

  const gross = unitPriceHundredths * BigInt(quantity);
  const discounted = divideRounded(gross * (10000n - discountHundredths), 10000n);
  return hundredthsToDecimal(discounted);
}

/** Calculate tax from a subtotal and a percentage such as 10.00. */
export function calculateTax(subtotal: string, taxRatePercent: string): string {
  const subtotalHundredths = decimalToHundredths(subtotal);
  const rateHundredths = decimalToHundredths(taxRatePercent);
  if (subtotalHundredths < 0n || rateHundredths < 0n) {
    throw new Error("Subtotal and tax rate cannot be negative");
  }
  return hundredthsToDecimal(
    divideRounded(subtotalHundredths * rateHundredths, 10000n),
  );
}

/** Convert a GST-inclusive amount to its GST-exclusive amount without floating point. */
export function removeTax(inclusiveAmount: string, taxRatePercent: string): string {
  const inclusiveHundredths = decimalToHundredths(inclusiveAmount);
  const rateHundredths = decimalToHundredths(taxRatePercent);
  if (inclusiveHundredths < 0n || rateHundredths < 0n) {
    throw new Error("Inclusive amount and tax rate cannot be negative");
  }
  return hundredthsToDecimal(
    divideRounded(inclusiveHundredths * 10000n, 10000n + rateHundredths),
  );
}

/** Bill elapsed seconds at an hourly rate, rounded to the nearest cent. */
export function calculateTimedAmount(hourlyRate: string, durationSeconds: number): string {
  if (!Number.isSafeInteger(durationSeconds) || durationSeconds < 0) {
    throw new Error("Duration must be a non-negative integer number of seconds");
  }
  const rateHundredths = decimalToHundredths(hourlyRate);
  if (rateHundredths < 0n) throw new Error("Hourly rate cannot be negative");
  return hundredthsToDecimal(
    divideRounded(rateHundredths * BigInt(durationSeconds), 3600n),
  );
}

export function sumDecimals(values: string[]): string {
  return hundredthsToDecimal(
    values.reduce((sum, value) => sum + decimalToHundredths(value), 0n),
  );
}

export function addDecimals(left: string, right: string): string {
  return hundredthsToDecimal(decimalToHundredths(left) + decimalToHundredths(right));
}

export function subtractDecimals(left: string, right: string): string {
  return hundredthsToDecimal(decimalToHundredths(left) - decimalToHundredths(right));
}
