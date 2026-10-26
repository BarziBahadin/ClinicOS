import { describe, expect, it } from "vitest";
import { parseCsv, statementCsv, csvText } from "../src/domain/csv";
describe("Statement import integrity", () => {
  it("preserves quoted commas, multiline descriptions and signed decimal amounts", () => {
    const rows = statementCsv(
      'Date,Account,Currency,Amount,Reference,Statement ID\r\n2026-10-25,bank,USD,-12.34,"Fee, reference\nsecond line",BANK-001\r\n',
    );
    expect(rows[0].amount).toBe("-12.34");
    expect(rows[0].reference).toBe("Fee, reference\nsecond line");
    expect(parseCsv('"A""B",C\n')).toEqual([['A"B', "C"]]);
  });
  it("rejects corrupt quoting, wrong headings and amounts with excessive currency precision", () => {
    expect(() => parseCsv('"incomplete')).toThrow();
    expect(() => parseCsv('"closed"junk')).toThrow();
    expect(() => statementCsv("Wrong,headings\n")).toThrow();
    expect(() =>
      statementCsv(
        "Date,Account,Currency,Amount,Reference,Statement ID\n2026-10-25,bank,USD,1.001,Fee,ID",
      ),
    ).toThrow(/precision/);
    expect(() =>
      statementCsv(
        "Date,Account,Currency,Amount,Reference,Statement ID\n2026-10-25,bank,USD,NaN,Fee,ID",
      ),
    ).toThrow();
  });
  it("escapes spreadsheet formulas in exports", () =>
    expect(csvText([["=SUM(1,2)", "plain"]])).toContain('"\'=SUM(1,2)"'));
});
