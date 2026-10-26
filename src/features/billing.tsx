import { RecordPager, useRecordPage } from "../components/RecordPager";
import { useState } from "react";
import type { Snapshot, Row, Currency, Locale } from "../domain/types";
import {
  DataTable,
  Empty,
  SectionNav,
  options,
  type T,
  type Action,
} from "../components/ui";
import { money } from "../domain/money";
import { formatDate, str } from "../lib/format";
import { PerformedCharges, PackageActions } from "./workflows";
import { FinancialReports } from "./financial-reports";
import {
  patient,
  number,
  method,
  currency,
  text,
  paymentAction,
} from "./actions";
export function Billing({
  data,
  t,
  locale,
  setAction,
  patientName,
  openInvoice,
  can,
}: {
  data: Snapshot;
  t: T;
  locale: Locale;
  setAction: (a: Action) => void;
  patientName: (id: unknown) => string;
  openInvoice: (r: Row) => number;
  can: (p: string) => boolean;
}) {
  const accountName = (row: Row) =>
    String(
      (row.patient_snapshot as Row | undefined)?.full_name ??
        row.patient_name ??
        patientName(row.patient_id),
    );
  const invoices = useRecordPage("invoices", data);
  const [section, setSection] = useState("invoices");
  const payments = useRecordPage("payments", data);
  const packages = useRecordPage("packages", data);
  return (
    <>
      <SectionNav
        label="Billing sections"
        t={t}
        active={section}
        onChange={setSection}
        items={[
          { id: "invoices", label: "Invoice" },
          { id: "payments", label: "Payments" },
          { id: "packages", label: "Treatment packages" },
          { id: "performed", label: "Performed treatments" },
          { id: "statements", label: "Patient statements and collections" },
        ]}
      />
      {section === "statements" && (
        <FinancialReports data={data} t={t} locale={locale} />
      )}
      {section === "performed" && (
        <PerformedCharges
          data={data}
          t={t}
          locale={locale}
          setAction={setAction}
        />
      )}
      <div className="action-bar">
        <button
          className="button secondary"
          onClick={() => setAction(paymentAction(data))}
        >
          {t("Patient deposit")}
        </button>
        <button
          className="button secondary"
          onClick={() =>
            setAction({
              title: "Sell package",
              kind: "package.sell",
              fields: [
                patient(data),
                text("name", "Treatment packages"),
                { ...number("sessions", "Sessions"), step: "1", min: "1" },
                currency(),
                number("amount", "Amount"),
                method(),
              ],
            })
          }
        >
          {t("Sell package")}
        </button>
      </div>
      {section === "invoices" && (
        <section className="panel">
          <div className="panel-head">
            <h2>{t("Invoice")}</h2>
            <span className="muted">
              {t("Separate balances for IQD and USD.")}
            </span>
          </div>
          <RecordPager page={invoices} t={t} />
          {invoices.items.length ? (
            <DataTable
              heads={[
                "Invoice number",
                "Patient",
                "Date",
                "Total",
                "Balance",
                "Action",
              ].map(t)}
            >
              {invoices.items.map((inv) => (
                <tr key={inv.id}>
                  <td className="mono strong">{str(inv, "invoice_number")}</td>
                  <td>{accountName(inv)}</td>
                  <td>{formatDate(inv.created_at, false, locale)}</td>
                  <td>{money(inv.total, inv.currency as Currency, locale)}</td>
                  <td>
                    <span
                      className={`badge ${openInvoice(inv) <= 0 ? "badge-completed" : "badge-pending"}`}
                    >
                      {money(
                        openInvoice(inv),
                        inv.currency as Currency,
                        locale,
                      )}
                    </span>
                  </td>
                  <td>
                    <div className="inline-actions">
                      {openInvoice(inv) > 0 && (
                        <>
                          <button
                            className="button small primary"
                            onClick={() => setAction(paymentAction(data, inv))}
                          >
                            {t("Record payment")}
                          </button>
                          <button
                            className="text-button"
                            onClick={() =>
                              setAction({
                                title: "Apply deposit",
                                kind: "deposit.apply",
                                fixed: {
                                  patient_id: inv.patient_id,
                                  invoice_id: inv.id,
                                  currency: inv.currency,
                                },
                                fields: [number("amount", "Amount")],
                              })
                            }
                          >
                            {t("Apply deposit")}
                          </button>
                          {can("approve") && (
                            <button
                              className="text-button danger"
                              onClick={() =>
                                setAction({
                                  title: "Invoice correction",
                                  kind: "invoice.credit",
                                  fixed: {
                                    invoice_id: inv.id,
                                    currency: inv.currency,
                                  },
                                  fields: [
                                    number("amount", "Amount"),
                                    text("reason", "Reason"),
                                  ],
                                })
                              }
                            >
                              {t("Credit note")}
                            </button>
                          )}
                        </>
                      )}
                      <button
                        className="text-button"
                        onClick={() =>
                          printInvoice(
                            inv,
                            t,
                            locale,
                            String(data.organization.name),
                          )
                        }
                      >
                        {t("Print")}
                      </button>
                    </div>
                  </td>
                </tr>
              ))}
            </DataTable>
          ) : (
            <Empty t={t} loading={invoices.loading} />
          )}
        </section>
      )}
      {section === "payments" && (
        <section className="panel">
          <div className="panel-head">
            <h2>{t("Payments")}</h2>
          </div>
          <RecordPager page={payments} t={t} />
          {payments.items.length ? (
            <DataTable
              heads={[
                "Patient",
                "Date",
                "Amount",
                "Payment method",
                "Category",
                "Action",
              ].map(t)}
            >
              {payments.items.map((p) => (
                <tr key={p.id}>
                  <td>{accountName(p)}</td>
                  <td>{formatDate(p.created_at, true, locale)}</td>
                  <td>
                    {money(p.amount, p.currency as Currency, locale)}
                    {Boolean(p.exchange_rate) && (
                      <small className="muted">
                        {t("Applied to invoice")}:{" "}
                        {money(
                          p.invoice_amount,
                          p.invoice_currency as Currency,
                          locale,
                        )}{" "}
                        · {t("IQD per USD")}: {String(p.exchange_rate)}
                      </small>
                    )}
                  </td>
                  <td>
                    {t(
                      str(p, "method").charAt(0).toUpperCase() +
                        str(p, "method").slice(1),
                    )}
                  </td>
                  <td>{str(p, "kind")}</td>
                  <td>
                    <button
                      className="text-button"
                      onClick={() =>
                        printReceipt(
                          p,
                          t,
                          locale,
                          String(data.organization.name),
                        )
                      }
                    >
                      {t("Receipt")}
                    </button>
                    {can("approve") &&
                      ["payment", "deposit"].includes(String(p.kind)) && (
                        <button
                          className="text-button danger"
                          onClick={() =>
                            setAction({
                              title: "Record refund",
                              kind: "refund.record",
                              fixed: { payment_id: p.id, currency: p.currency },
                              fields: [
                                number("amount", "Amount"),
                                text("reason", "Reason"),
                              ],
                            })
                          }
                        >
                          {t("Refund")}
                        </button>
                      )}
                  </td>
                </tr>
              ))}
            </DataTable>
          ) : (
            <Empty t={t} loading={payments.loading} />
          )}
        </section>
      )}
      {section === "packages" && (
        <section className="panel">
          <div className="panel-head">
            <h2>{t("Treatment packages")}</h2>
          </div>
          <RecordPager page={packages} t={t} />
          {packages.items.length ? (
            <DataTable
              heads={[
                "Patient",
                "Treatment packages",
                "Remaining",
                "Total",
                "Action",
              ].map(t)}
            >
              {packages.items.map((p) => (
                <tr key={p.id}>
                  <td>{accountName(p)}</td>
                  <td>{str(p, "name")}</td>
                  <td>
                    {str(p, "remaining")} / {str(p, "sessions")}
                  </td>
                  <td>{money(p.total, p.currency as Currency, locale)}</td>
                  <td>
                    <button
                      className="button small secondary"
                      disabled={
                        Number(p.remaining) === 0 ||
                        Boolean(p.cancelled_at) ||
                        Boolean(
                          p.expires_on &&
                          String(p.expires_on) <
                            new Date().toISOString().slice(0, 10),
                        )
                      }
                      onClick={() =>
                        setAction({
                          title: "Redeem session",
                          kind: "package.redeem",
                          fixed: { package_id: p.id, patient_id: p.patient_id },
                          fields: [
                            {
                              name: "encounter_id",
                              label: "Clinical records",
                              required: true,
                              options: options(
                                data.billable_encounters
                                  .filter((e) => e.patient_id === p.patient_id)
                                  .map((e) => ({
                                    ...e,
                                    label: formatDate(
                                      e.created_at,
                                      true,
                                      locale,
                                    ),
                                  })),
                                "label",
                              ),
                            },
                          ],
                        })
                      }
                    >
                      {t("Redeem session")}
                    </button>
                    {can("approve") && (
                      <PackageActions row={p} t={t} setAction={setAction} />
                    )}
                  </td>
                </tr>
              ))}
            </DataTable>
          ) : (
            <Empty t={t} loading={packages.loading} />
          )}
        </section>
      )}
    </>
  );
}
function printRows(heading: string, rows: string[], locale: Locale) {
  document.getElementById("clinicos-print")?.remove();
  const section = document.createElement("section");
  section.id = "clinicos-print";
  section.dir = locale === "ckb" ? "rtl" : "ltr";
  section.lang = locale;
  const title = document.createElement("h1");
  title.textContent = heading;
  section.append(title);
  for (const text of rows) {
    const p = document.createElement("p");
    p.textContent = text;
    section.append(p);
  }
  document.body.append(section);
  const cleanup = () => {
    section.remove();
    window.removeEventListener("afterprint", cleanup);
  };
  window.addEventListener("afterprint", cleanup);
  window.print();
}
function printInvoice(inv: Row, t: T, locale: Locale, clinic: string) {
  printRows(
    `${clinic} · ${inv.invoice_number}`,
    [
      String(
        (inv.patient_snapshot as Record<string, unknown>)?.full_name ?? "",
      ),
      formatDate(inv.created_at, true, locale),
      ...(inv.lines as Row[]).map(
        (line) =>
          `${line.description} × ${line.quantity} — ${money(line.amount, inv.currency as Currency, locale)}`,
      ),
      `${t("Total")}: ${money(inv.total, inv.currency as Currency, locale)}`,
    ],
    locale,
  );
}
function printReceipt(p: Row, t: T, locale: Locale, clinic: string) {
  const snapshot = p.patient_snapshot as Record<string, unknown>;
  printRows(
    `${clinic} · ${t("Receipt")}`,
    [
      String(p.id),
      String(snapshot?.full_name ?? ""),
      String(snapshot?.patient_number ?? ""),
      formatDate(p.created_at, true, locale),
      `${t("Category")}: ${p.kind}`,
      `${t("Payment method")}: ${t(String(p.method).charAt(0).toUpperCase() + String(p.method).slice(1))}`,
      `${t("Amount received")}: ${money(p.amount, p.currency as Currency, locale)}`,
      ...(p.invoice_number
        ? [
            `${t("Invoice number")}: ${p.invoice_number}`,
            `${t("Applied to invoice")}: ${money(p.invoice_amount ?? p.amount, p.invoice_currency as Currency, locale)}`,
          ]
        : []),
      ...(p.exchange_rate ? [`${t("IQD per USD")}: ${p.exchange_rate}`] : []),
      ...(p.original_payment_id
        ? [String(p.original_payment_id), String(p.reason ?? "")]
        : []),
    ],
    locale,
  );
}
