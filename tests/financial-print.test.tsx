// @vitest-environment happy-dom
import { afterEach, expect, it, vi } from "vitest";
import { act, cleanup, render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { FinancialReports } from "../src/features/financial-reports";
import { printDocument } from "../src/lib/print";
import { rpc } from "../src/lib/api";
import type { Snapshot } from "../src/domain/types";
const query = vi.hoisted(() => vi.fn());
vi.mock("../src/lib/supabase", () => ({ client: () => ({ rpc: query }) }));
vi.mock("../src/lib/api", () => ({ rpc: vi.fn() }));
vi.mock("../src/lib/print", () => ({ printDocument: vi.fn() }));
const data = {
  organization: { id: "clinic", name: "Synthetic clinic" },
  membership: { display_name: "Test accountant" },
  permissions: ["finance"],
} as Snapshot;
const report = {
  as_at: "2026-10-28T09:00:00Z",
  records: 2,
  opening_balances: [],
  closing_balances: [],
  prepayment_totals: [],
  totals: [{ currency: "USD", amount: "20.00" }],
  has_more: true,
  items: [
    {
      id: "one",
      invoice_number: "INV-001",
      patient_name: "Historical name",
      patient_number: "P-001",
      currency: "USD",
      amount: "10.00",
      age_days: 1,
      aging_band: "0–30",
    },
  ],
};
afterEach(() => {
  cleanup();
  vi.resetAllMocks();
});
it("prints all report pages at one cutoff with database totals and separate table columns", async () => {
  query.mockResolvedValue({ data: report, error: null });
  vi.mocked(rpc).mockResolvedValue({
    ...report,
    has_more: false,
    items: [{ ...report.items[0], id: "two", invoice_number: "INV-002" }],
  });
  render(<FinancialReports data={data} locale="ckb" t={(s) => s} />);
  await userEvent.click(
    await screen.findByRole("button", { name: "Print report" }),
  );
  expect(rpc).toHaveBeenCalledWith(
    "financial_report",
    expect.objectContaining({ page_number: 1, as_at: report.as_at }),
  );
  expect(printDocument).toHaveBeenCalledOnce();
  const [title, , locale, details] = vi.mocked(printDocument).mock.calls[0];
  expect(title).toBe("Receivables and aging");
  expect(locale).toBe("ckb");
  expect(details?.table?.rows.map((r) => r[0])).toEqual(["INV-001", "INV-002"]);
  expect(details?.table?.columns).toHaveLength(7);
  expect(details?.metadata).toContainEqual([
    "Report cutoff",
    expect.any(String),
  ]);
  expect(details?.totals).toEqual([["Total", "٢٠ US$"]]);
});
it("does not print an incomplete report when another page fails", async () => {
  query.mockResolvedValue({ data: report, error: null });
  vi.mocked(rpc).mockRejectedValue(new Error("Connection interrupted"));
  render(<FinancialReports data={data} locale="en" t={(s) => s} />);
  await userEvent.click(
    await screen.findByRole("button", { name: "Print report" }),
  );
  expect(await screen.findByText("Connection interrupted")).toBeTruthy();
  expect(printDocument).not.toHaveBeenCalled();
});
it("discards an unfinished report print when the workspace changes", async () => {
  query.mockResolvedValue({ data: report, error: null });
  let resolve!: (value: unknown) => void;
  vi.mocked(rpc).mockImplementation(
    () =>
      new Promise((r) => {
        resolve = r;
      }),
  );
  const view = render(
    <FinancialReports data={data} locale="en" t={(s) => s} />,
  );
  await userEvent.click(
    await screen.findByRole("button", { name: "Print report" }),
  );
  view.rerender(
    <FinancialReports data={{ ...data }} locale="en" t={(s) => s} />,
  );
  await act(async () => {
    resolve({ ...report, has_more: false, items: [] });
  });
  expect(printDocument).not.toHaveBeenCalled();
});
