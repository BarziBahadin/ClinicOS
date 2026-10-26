import { useEffect, useLayoutEffect, useRef, useState } from "react";
import { client } from "../lib/supabase";
import { PatientSelect } from "../components/PatientSelect";
import { DataTable, Empty, ErrorMessage, type T } from "../components/ui";
import type { Currency, Locale, Row, Snapshot } from "../domain/types";
import { day, formatDate } from "../lib/format";
import { money } from "../domain/money";
import { printDocument } from "../lib/print";
const kinds: Record<string, string> = {
  receivables: "Receivables and aging",
  patient_statement: "Patient statement",
  collections: "Collections and refunds",
  liabilities: "Deposits and package liabilities",
  payables: "Supplier payables",
  cash_register: "Cash and bank register",
  till_variances: "Till variances",
};
const columns: Record<string, [string, string][]> = {
  receivables: [
    ["invoice_number", "Invoice number"],
    ["patient_name", "Patient"],
    ["patient_number", "Patient number"],
    ["currency", "Currency"],
    ["amount", "Balance"],
    ["age_days", "Age in days"],
    ["aging_band", "Aging band"],
  ],
  patient_statement: [
    ["date", "Date"],
    ["reference", "Reference"],
    ["category", "Category"],
    ["currency", "Currency"],
    ["amount", "Amount"],
  ],
  collections: [
    ["date", "Date"],
    ["currency", "Currency"],
    ["method", "Payment method"],
    ["category", "Category"],
    ["transactions", "Transactions"],
    ["amount", "Amount"],
  ],
  liabilities: [
    ["patient_id", "Patient account"],
    ["currency", "Currency"],
    ["category", "Category"],
    ["amount", "Balance"],
  ],
  payables: [
    ["date", "Date"],
    ["supplier", "Supplier / payee"],
    ["category", "Category"],
    ["description", "Description"],
    ["currency", "Currency"],
    ["amount", "Amount"],
  ],
  cash_register: [
    ["date", "Date"],
    ["account", "Account"],
    ["currency", "Currency"],
    ["category", "Category"],
    ["reference", "Reference"],
    ["description", "Description"],
    ["amount", "Amount"],
  ],
  till_variances: [
    ["date", "Date"],
    ["currency", "Currency"],
    ["opening", "Opening float"],
    ["expected", "Expected"],
    ["counted", "Counted cash"],
    ["amount", "Variance"],
    ["reason", "Reason"],
  ],
};
type Report = {
  as_at: string;
  opening_balances: { currency: Currency; amount: string | number }[];
  closing_balances: { currency: Currency; amount: string | number }[];
  prepayment_totals: { currency: Currency; amount: string | number }[];
  items: Row[];
  totals: { currency: Currency; amount: string | number }[];
  has_more: boolean;
  records: number;
};
export function FinancialReports({
  data,
  t,
  locale,
}: {
  data: Snapshot;
  t: T;
  locale: Locale;
}) {
  const today = day(new Date().toISOString());
  const snapshotTime = useRef<string | null>(null);
  const [chosenReport, setChosenReport] = useState("receivables");
  const [filters, setFilters] = useState({
      type: "receivables",
      from: today.slice(0, 7) + "-01",
      to: today,
      patientId: "",
    }),
    [page, setPage] = useState(0),
    [report, setReport] = useState<Report | null>(null),
    [error, setError] = useState(""),
    [loading, setLoading] = useState(false);
  useLayoutEffect(() => {
    snapshotTime.current = null;
    setPage(0);
    setReport(null);
  }, [filters, data]);
  useEffect(() => {
    let cancelled = false;
    setLoading(true);
    setReport(null);
    setError("");
    void client()
      .rpc("financial_report", {
        report_type: filters.type,
        from_day: filters.from,
        to_day: filters.to,
        patient_id: filters.patientId || null,
        page_number: page,
        as_at: snapshotTime.current,
      })
      .then(({ data, error }) => {
        if (cancelled) return;
        if (error) setError(error.message);
        else {
          snapshotTime.current = data.as_at;
          setReport(data);
        }
        setLoading(false);
      });
    return () => {
      cancelled = true;
    };
  }, [filters, page, data]);
  const heads = columns[filters.type];
  const cell = (row: Row, key: string) =>
    ["amount", "opening", "expected", "counted"].includes(key)
      ? money(row[key], row.currency as Currency, locale)
      : key === "date"
        ? formatDate(row[key], false, locale)
        : String(row[key] ?? "—");
  return (
    <section className="panel">
      <div className="panel-head">
        <h2>{t("Operational financial reports")}</h2>
      </div>
      <form
        className="dialog-body form-grid"
        onSubmit={(e) => {
          e.preventDefault();
          const f = new FormData(e.currentTarget);
          setPage(0);
          setFilters({
            type: String(f.get("type")),
            from: String(f.get("from")),
            to: String(f.get("to")),
            patientId: String(f.get("patient_id") ?? ""),
          });
        }}
      >
        <label className="field">
          <span>{t("Report")}</span>
          <select
            name="type"
            value={chosenReport}
            onChange={(e) => setChosenReport(e.target.value)}
          >
            {Object.entries(kinds)
              .filter(
                ([k]) =>
                  data.permissions.includes("finance") ||
                  [
                    "receivables",
                    "patient_statement",
                    "collections",
                    "liabilities",
                  ].includes(k),
              )
              .map(([k, label]) => (
                <option key={k} value={k}>
                  {t(label)}
                </option>
              ))}
          </select>
        </label>
        <label className="field">
          <span>{t("From")}</span>
          <input type="date" name="from" required defaultValue={filters.from} />
        </label>
        <label className="field">
          <span>{t("To")}</span>
          <input
            type="date"
            name="to"
            required
            max={today}
            defaultValue={filters.to}
          />
        </label>
        {[
          "receivables",
          "patient_statement",
          "collections",
          "liabilities",
        ].includes(chosenReport) && (
          <label className="field">
            <span>
              {t("Patient account")} · {t("Optional")}
            </span>
            <PatientSelect
              field={{
                name: "patient_id",
                label: "Patient account",
                type: "billing-patient",
              }}
              t={t}
            />
          </label>
        )}
        <button className="button primary" disabled={loading}>
          {t("Run report")}
        </button>
      </form>
      {error && <ErrorMessage error={error} />}
      <p className="panel-hint">
        {t(
          "Totals cover all matching records. Detail rows are paginated. IQD and USD remain separate.",
        )}
      </p>
      {report && (
        <>
          <div className="action-bar">
            {report.opening_balances?.map((total) => (
              <span key={`opening-${total.currency}`}>
                {t("Opening invoiced balance")}:{" "}
                {money(total.amount, total.currency, locale)}
              </span>
            ))}
            {report.totals.map((total) => (
              <strong key={total.currency}>
                {t(
                  filters.type === "patient_statement"
                    ? "Period movement"
                    : "Total",
                )}{" "}
                · {money(total.amount, total.currency, locale)}
              </strong>
            ))}
            <span>
              {report.records} {t("Records")}
            </span>
            {report.closing_balances?.map((total) => (
              <strong key={`closing-${total.currency}`}>
                {t("Closing invoiced balance")}:{" "}
                {money(total.amount, total.currency, locale)}
              </strong>
            ))}
            {report.prepayment_totals?.map((total) => (
              <span key={`prepayments-${total.currency}`}>
                {t("Prepayments — shown separately")}:{" "}
                {money(total.amount, total.currency, locale)}
              </span>
            ))}
          </div>
          {report.items.length ? (
            <DataTable heads={heads.map(([, label]) => t(label))}>
              {report.items.map((row, index) => (
                <tr key={`${row.id ?? "group"}-${index}`}>
                  {heads.map(([key]) => (
                    <td key={key} dir="auto">
                      {cell(row, key)}
                    </td>
                  ))}
                </tr>
              ))}
            </DataTable>
          ) : (
            <Empty t={t} />
          )}
          <div className="panel-head">
            <button
              className="button secondary"
              disabled={page === 0 || loading}
              onClick={() => setPage(page - 1)}
            >
              {t("Previous")}
            </button>
            <span>{page + 1}</span>
            <button
              className="button secondary"
              disabled={!report.has_more || loading}
              onClick={() => setPage(page + 1)}
            >
              {t("Next")}
            </button>
            <button
              className="button secondary"
              onClick={() =>
                printDocument(
                  `${data.organization.name} · ${t(kinds[filters.type])}`,
                  [
                    `${filters.from} — ${filters.to}`,
                    `${t("Page")}: ${page + 1}`,
                    `${t("Report cutoff")}: ${formatDate(report.as_at, true, locale)}`,
                    ...report.opening_balances.map(
                      (total) =>
                        `${t("Opening invoiced balance")}: ${money(total.amount, total.currency, locale)}`,
                    ),
                    ...report.closing_balances.map(
                      (total) =>
                        `${t("Closing invoiced balance")}: ${money(total.amount, total.currency, locale)}`,
                    ),
                    ...report.prepayment_totals.map(
                      (total) =>
                        `${t("Prepayments — shown separately")}: ${money(total.amount, total.currency, locale)}`,
                    ),
                    ...report.totals.map(
                      (total) =>
                        `${t("Total")}: ${money(total.amount, total.currency, locale)}`,
                    ),
                    ...report.items.map((row) =>
                      heads
                        .map(([key, label]) => `${t(label)}: ${cell(row, key)}`)
                        .join(" · "),
                    ),
                  ],
                  locale,
                )
              }
            >
              {t("Print this page")}
            </button>
          </div>
        </>
      )}
    </section>
  );
}
