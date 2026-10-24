import { describe, expect, it } from "vitest";
import { amount, sum } from "../src/domain/money";
import { ageAt, searchText } from "../src/domain/patient";
import { clinicDateTime } from "../src/domain/time";
import { normalizePhone } from "../src/domain/phone";
describe("Patient identity", () => {
  it("normalizes Iraqi numbers without treating reachability as identity", () => {
    expect(normalizePhone("0750 123 4567")).toBe("+9647501234567");
    expect(normalizePhone("")).toBeNull();
    expect(() => normalizePhone("123")).toThrow();
  });
  it("calculates age at an historical visit and labels uncertainty", () => {
    expect(ageAt("2000-10-24", "day", new Date("2020-10-23"))).toBe("19");
    expect(ageAt("2000-10-24", "day", new Date("2020-10-24"))).toBe("20");
    expect(ageAt(null, "unknown")).toBe("—");
    expect(ageAt("2000-01-01", "year", new Date("2020-06-01"))).toBe("≈ 20");
  });
  it("normalizes a search representation without changing stored names", () =>
    expect(searchText("كي ١٢٣")).toBe("کی 123"));
});
describe("Currency arithmetic", () => {
  it("keeps exact decimal sums", () => expect(sum(["0.1", "0.2"])).toBe("0.3"));
  it("enforces currency-specific precision", () => {
    expect(amount("12.345", "IQD")).toBe("12.345");
    expect(() => amount("12.345", "USD")).toThrow();
    expect(() => amount("-1", "USD")).toThrow();
    expect(() => amount("1e6", "IQD")).toThrow();
  });
});

describe("Clinic calendar", () => {
  it("interprets entered appointment time in Baghdad rather than the device timezone", () => {
    expect(clinicDateTime("2026-10-24T09:30")).toBe("2026-10-24T06:30:00Z");
    expect(clinicDateTime("2026-10-25T00:15")).toBe("2026-10-24T21:15:00Z");
  });
  it("rejects impossible dates and ambiguous DST times", () => {
    expect(() => clinicDateTime("2026-02-30T09:00")).toThrow();
    expect(() =>
      clinicDateTime("2026-11-01T01:30", "America/New_York"),
    ).toThrow();
  });
});
