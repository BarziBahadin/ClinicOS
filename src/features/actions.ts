import { hasRole } from "../domain/staff";
import type { Action, Field } from "../components/ui";
import { options } from "../components/ui";
import type { Patient, Row, Snapshot } from "../domain/types";
export const choice = (
  name: string,
  label: string,
  values: string[],
  value?: unknown,
): Field => ({
  name,
  label,
  required: true,
  options: values.map((v) => ({
    value: v,
    label:
      (
        {
          day: "Exact date",
          month: "Month and year",
          year: "Year only",
          ckb: "کوردی",
          en: "English",
          care_photography: "Care photography",
          not_disclosed: "Not disclosed",
          owner_contribution: "Owner contribution",
          owner_withdrawal: "Owner withdrawal",
          owner_loan: "Owner loan",
          opening_balance: "Opening balance",
        } as Record<string, string>
      )[v] ?? v.charAt(0).toUpperCase() + v.slice(1).replaceAll("_", " "),
  })),
  value,
});
export const text = (
  name: string,
  label: string,
  required = true,
  value?: unknown,
): Field => ({ name, label, required, value });
export const number = (
  name: string,
  label: string,
  value?: unknown,
): Field => ({
  name,
  label,
  required: true,
  type: "number",
  min: "0.001",
  step: "0.001",
  value,
});
export const currency = (): Field =>
  choice("currency", "Currency", ["IQD", "USD"], "IQD");
export const method = (): Field =>
  choice("method", "Payment method", ["cash", "bank", "card"], "cash");
export const patient = (d: Snapshot, value?: string): Field => ({
  name: "patient_id",
  label: "Patient",
  required: true,
  options: d.patients
    .filter((p) => !p.merged_into)
    .map((p) => ({
      value: p.id,
      label: `${p.full_name} · ${p.patient_number}`,
    })),
  value,
});
export const encounter = (
  d: Snapshot,
  p?: string,
  encounterStatus?: "draft" | "signed",
  ownOnly = false,
): Field => ({
  patientId: p,
  encounterStatus,
  ownOnly,
  name: "encounter_id",
  label: "Clinical records",
  required: true,
  options: d.encounters
    .filter((e) => !p || e.patient_id === p)
    .map((e) => ({
      value: e.id,
      label: `${String(e.chief_complaint)} · ${String(e.status)}`,
    })),
});
export function patientAction(p?: Patient): Action {
  const precision = p?.birth_precision ?? "unknown";
  const birth = p?.birth_date?.slice(
    0,
    precision === "year" ? 4 : precision === "month" ? 7 : 10,
  );
  return {
    title: p ? "Edit profile" : "New patient",
    kind: p ? "patient.update" : "patient.create",
    fixed: p ? { patient_id: p.id, version: p.version } : undefined,
    fields: [
      text("full_name", "Full name", true, p?.full_name),
      { ...text("phone", "Phone number", false, p?.phone), type: "tel" },
      text("contact_owner", "Contact owner", false, p?.contact_owner),
      choice(
        "birth_precision",
        "Birth precision",
        ["unknown", "day", "month", "year"],
        precision,
      ),
      {
        ...text("birth_date", "Birth information", false, birth),
        placeholder: "YYYY / YYYY-MM / YYYY-MM-DD",
      },
      choice(
        "gender",
        "Gender",
        ["unknown", "female", "male", "other", "not_disclosed"],
        p?.gender ?? "unknown",
      ),
      choice(
        "language",
        "Preferred language",
        ["ckb", "en"],
        p?.language ?? "ckb",
      ),
      text("guardian_name", "Guardian name", false, p?.guardian_name),
      text(
        "guardian_relationship",
        "Guardian relationship",
        false,
        p?.guardian_relationship,
      ),
      {
        name: "communication_consent",
        label: "Communication consent",
        type: "checkbox",
        value: p?.communication_consent,
      },
      ...(!p
        ? [
            {
              ...number("reported_age", "Reported age"),
              required: false,
              min: "0",
              max: "130",
              step: "1",
            },
          ]
        : []),
    ],
  };
}
export function appointmentAction(d: Snapshot, p?: string): Action {
  return {
    title: "New appointment",
    kind: "appointment.create",
    fields: [
      patient(d, p),
      {
        name: "doctor_id",
        label: "Clinician",
        required: true,
        options: options(
          d.members.filter((m) => m.active && hasRole(m, "doctor")),
          "display_name",
          "user_id",
        ),
      },
      text("service_name", "Service"),
      { name: "resource_id", label: "Room / device", required: false },
      {
        name: "starts_at",
        label: "Start",
        type: "datetime-local",
        required: true,
      },
      { name: "ends_at", label: "End", type: "datetime-local", required: true },
      { name: "walk_in", label: "Walk-in", type: "checkbox" },
    ],
  };
}
export function encounterAction(d: Snapshot, p?: string, row?: Row): Action {
  return {
    title: row ? "Clinical note" : "New encounter",
    kind: "encounter.save",
    fixed: row
      ? { id: row.id, version: row.version, patient_id: row.patient_id }
      : undefined,
    fields: [
      ...(!row ? [patient(d, p)] : []),
      text("chief_complaint", "Chief complaint", true, row?.chief_complaint),
      ...(
        [
          "history",
          "allergies",
          "findings",
          "diagnosis",
          "plan",
          "prescriptions",
          "clinical_sex_notes",
        ] as const
      ).map((name, i) => ({
        name,
        label: [
          "History",
          "Allergies",
          "Findings",
          "Diagnosis",
          "Treatment plan",
          "Prescriptions",
          "Clinical sex information",
        ][i],
        type: "textarea",
        value: row?.[name],
        required: name === "allergies",
      })),
    ],
  };
}
export function consentAction(d: Snapshot, p?: string): Action {
  return {
    title: "Record consent",
    kind: "consent.record",
    fields: [
      patient(d, p),
      choice(
        "purpose",
        "Purpose",
        [
          "care_photography",
          "procedure",
          "teaching",
          "publication",
          "marketing",
          "communication",
        ],
        "care_photography",
      ),
      { name: "granted", label: "Granted", type: "checkbox", value: true },
      text("template_version", "Template version", true, "1"),
      { ...text("evidence", "Evidence / discussion"), type: "textarea" },
    ],
  };
}
export function procedureAction(d: Snapshot, p?: string): Action {
  return {
    title: "Record procedure",
    kind: "procedure.create",
    fields: [
      patient(d, p),
      encounter(d, p),
      text("name", "Procedure"),
      text("body_site", "Body site"),
      text("product", "Product", false),
      text("lot_number", "Lot number", false),
      text("settings", "Device / settings", false),
      { ...number("quantity", "Quantity"), required: false },
      { ...text("aftercare", "Aftercare"), type: "textarea" },
      { ...text("adverse_event", "Adverse event", false), type: "textarea" },
    ],
  };
}
export function invoiceAction(d: Snapshot, p?: string): Action {
  return {
    title: "New invoice",
    kind: "invoice.issue",
    fields: [
      patient(d, p),
      { ...number("discount", "Discount"), required: false, min: "0" },
      text("discount_reason", "Discount reason", false),
    ],
  };
}
export function paymentAction(d: Snapshot, invoice?: Row): Action {
  const cross = Boolean(invoice && d.organization.allow_cross_currency);
  return {
    title: "Record payment",
    kind: "payment.record",
    fixed: invoice
      ? {
          invoice_id: invoice.id,
          ...(!cross ? { currency: invoice.currency } : {}),
        }
      : undefined,
    fields: [
      patient(d, invoice?.patient_id as string),
      ...(!invoice || cross
        ? [
            {
              ...currency(),
              value: invoice?.currency ?? "IQD",
              label: "Currency received",
            },
          ]
        : []),
      number("amount", "Amount received"),
      ...(cross
        ? [
            {
              ...number("exchange_rate", "IQD per USD"),
              required: false,
              step: "0.000001",
              help: "Required when the payment and invoice currencies differ. Enter IQD for one USD.",
            },
          ]
        : []),
      method(),
    ],
  };
}
export function expenseAction(): Action {
  return {
    title: "Record expense",
    kind: "expense.record",
    fields: [
      choice(
        "category",
        "Category",
        ["operating", "supplies", "salary", "rent", "utilities"],
        "operating",
      ),
      text("supplier", "Supplier / payee"),
      text("description", "Description"),
      currency(),
      number("amount", "Amount"),
      method(),
      { name: "paid", label: "Paid now", type: "checkbox", value: true },
    ],
  };
}
export function stockAction(): Action {
  return {
    title: "Receive stock",
    kind: "stock.receive",
    fields: [
      text("product", "Product"),
      text("lot_number", "Lot number"),
      {
        name: "expires_on",
        label: "Expiry date",
        type: "date",
        required: true,
      },
      text("unit", "Unit"),
      number("amount", "Quantity"),
    ],
  };
}
