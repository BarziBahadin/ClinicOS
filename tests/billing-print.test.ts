// @vitest-environment happy-dom
import { afterEach, expect, it, vi } from "vitest";
import { printInvoice, printReceipt } from "../src/features/billing";
import { printPrescription } from "../src/features/workflows";
import { printDocument } from "../src/lib/print";
import type { Patient, Snapshot } from "../src/domain/types";
vi.mock("../src/lib/print", () => ({ printDocument: vi.fn() }));
afterEach(() => vi.resetAllMocks());
const data = {
  organization: {
    id: "clinic",
    name: "Synthetic clinic",
    document_phone: "+964 750 000 0000",
  },
  members: [{ user_id: "issuer", display_name: "Test issuer" }],
  patients: [{ full_name: "Changed current name" }],
} as unknown as Snapshot;
it("prints invoice snapshots, each price, discounts and the server balance", () => {
  printInvoice(
    {
      id: "invoice",
      invoice_number: "INV-001",
      currency: "USD",
      total: "90",
      balance: "40",
      created_by: "issuer",
      created_at: "2026-10-28T09:00:00Z",
      patient_snapshot: {
        full_name: "Historical patient",
        patient_number: "P-001",
      },
      lines: [
        {
          description: "Consultation",
          quantity: 1,
          unit_price: "100",
          amount: "100",
        },
        {
          description: "Discount",
          quantity: 1,
          unit_price: "-10",
          amount: "-10",
        },
      ],
    },
    (s) => s,
    "en",
    data,
  );
  const details = vi.mocked(printDocument).mock.calls[0][3]!;
  expect(details.metadata).toContainEqual(["Patient", "Historical patient"]);
  expect(details.metadata).toContainEqual(["Patient number", "P-001"]);
  expect(details.metadata).toContainEqual(["Issued by", "Test issuer"]);
  expect(details.table?.rows).toHaveLength(2);
  expect(details.table?.rows[1][3]).toBe("-$10");
  expect(details.totals).toEqual([
    ["Total", "$90"],
    ["Balance", "$40"],
  ]);
});
it("keeps refund tender, historical FX, invoice allocation and the original reference distinct", () => {
  printReceipt(
    {
      id: "refund",
      kind: "refund",
      created_at: "2026-10-28T09:00:00Z",
      patient_snapshot: {
        full_name: "Historical patient",
        patient_number: "P-001",
      },
      created_by: "issuer",
      amount: "15000",
      currency: "IQD",
      method: "cash",
      invoice_number: "INV-001",
      invoice_currency: "USD",
      invoice_amount: "10",
      exchange_rate: "1500",
      original_payment_id: "original",
      reason: "Test refund",
    },
    (s) => s,
    "en",
    data,
  );
  const [title, , , details] = vi.mocked(printDocument).mock.calls[0];
  expect(title).toBe("Refund receipt");
  expect(details?.metadata).toContainEqual(["IQD per USD", "1500"]);
  expect(details?.metadata).toContainEqual(["Original payment", "original"]);
  expect(details?.totals?.[0]).toEqual(["Applied to invoice", "$10"]);
  expect(details?.totals?.[1][0]).toBe("Amount refunded");
  expect(details?.note).toBe("Reason: Test refund");
});

it("prints the signed clinician and patient identities with complete medicine instructions", () => {
  printPrescription(
    {
      id: "encounter",
      signed_at: "2026-10-28T09:00:00Z",
      doctor_id: "issuer",
      identity_snapshot: {
        full_name: "Signed patient name",
        patient_number: "OLD-001",
        clinician_name: "Signed clinician",
      },
      prescription_items: [
        {
          medicine: "Test medicine",
          strength: "10 mg",
          dose: "1",
          route: "Oral",
          frequency: "Once daily",
          duration: "7 days",
          quantity: 7,
          instructions: "Line one\nهێڵی دووەم",
        },
      ],
      prescriptions: "Signed additional instructions",
    },
    { full_name: "Changed patient", patient_number: "NEW-001" } as Patient,
    data,
    (s) => s,
    "ckb",
  );
  const details = vi.mocked(printDocument).mock.calls[0][3]!;
  expect(details.metadata).toContainEqual(["Patient", "Signed patient name"]);
  expect(details.metadata).toContainEqual(["Patient number", "OLD-001"]);
  expect(details.metadata).toContainEqual(["Clinician", "Signed clinician"]);
  expect(details.signature).toContain("Signed clinician");
  expect(details.sections?.[0].lines).toContain("Line one\nهێڵی دووەم");
  expect(details.sections?.[0].fields).toContainEqual(["Duration", "7 days"]);
  expect(details.sections?.[0].fields).toContainEqual(["Quantity", "7"]);
  expect(details.sections?.[1].lines).toEqual([
    "Signed additional instructions",
  ]);
});
