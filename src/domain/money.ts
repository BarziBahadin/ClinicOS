import Decimal from "decimal.js";
import type { Currency } from "./types";
export const currencyScale: Record<Currency, number> = { USD: 2, IQD: 3 };
export function money(
  value: unknown,
  currency: Currency = "IQD",
  locale = "en",
) {
  const amount = new Decimal(String(value ?? 0));
  return new Intl.NumberFormat(locale === "ckb" ? "ckb-IQ" : "en-US", {
    style: "currency",
    currency,
    minimumFractionDigits: 0,
    maximumFractionDigits: currencyScale[currency],
  }).format(amount.toNumber());
}
export function amount(value: string, currency: Currency): string {
  if (!/^\d+(\.\d+)?$/.test(value)) throw new Error("Enter a positive amount.");
  const d = new Decimal(value);
  if (!d.isPositive() || d.decimalPlaces() > currencyScale[currency])
    throw new Error(`Invalid ${currency} amount.`);
  return d.toFixed(currencyScale[currency]);
}
export function sum(values: unknown[]) {
  return values
    .reduce<Decimal>((acc, x) => acc.plus(String(x ?? 0)), new Decimal(0))
    .toString();
}

export function difference(left:unknown,right:unknown){return new Decimal(String(left??0)).minus(String(right??0)).toString();}
