import { useRequestScope } from "../lib/request-scope";
import { useState } from "react";
import { RecordPager, useRecordPage } from "../components/RecordPager";
import type { Snapshot, Currency, Locale } from "../domain/types";
import {
  DataTable,
  Empty,
  SectionNav,
  type T,
  type Action,
} from "../components/ui";
import { money } from "../domain/money";
import { formatDate, str } from "../lib/format";
import { number, method, currency, choice, text } from "./actions";
import { exportAccounting } from "../lib/api";
export function Finance({
  data,
  t,
  locale,
  setAction,
  can,
}: {
  data: Snapshot;
  t: T;
  locale: Locale;
  setAction: (a: Action) => void;
  can: (p: string) => boolean;
}) {
  const requestScope = useRequestScope(
    `${data.organization.id}:${data.membership.user_id}`,
  );
  const expenses = useRecordPage("expenses", data);
  const [section, setSection] = useState("expenses");
  const movements = useRecordPage("cash_movements", data);
  const tills = useRecordPage("tills", data);
  return (
    <>
      <SectionNav
        label="Finance sections"
        t={t}
        active={section}
        onChange={setSection}
        items={[
          { id: "expenses", label: "Expenses" },
          { id: "movements", label: "Cash movements" },
          { id: "tills", label: "Till sessions" },
        ]}
      />
      <div className="action-bar">
        {can("approve") && (
          <>
            <button
              className="button secondary"
              onClick={() =>
                setAction({
                  title: "Accounting adjustment",
                  kind: "journal.post",
                  fields: [
                    currency(),
                    number("amount", "Amount"),
                    choice("debit_account", "Debit", [
                      "cash",
                      "bank",
                      "card",
                      "receivable",
                      "deposits",
                      "revenue",
                      "expense",
                      "inventory",
                      "payable",
                      "equity",
                      "owner_loan",
                      "fx_clearing",
                    ]),
                    choice("credit_account", "Credit", [
                      "cash",
                      "bank",
                      "card",
                      "receivable",
                      "deposits",
                      "revenue",
                      "expense",
                      "inventory",
                      "payable",
                      "equity",
                      "owner_loan",
                      "fx_clearing",
                    ]),
                    text("description", "Description"),
                  ],
                })
              }
            >
              {t("Accounting adjustment")}
            </button>
            <button
              className="button secondary"
              onClick={() =>
                setAction({
                  title: "Cash movement",
                  kind: "cash.record",
                  fields: [
                    choice(
                      "kind",
                      "Movement type",
                      [
                        "owner_contribution",
                        "owner_withdrawal",
                        "owner_loan",
                        "transfer",
                        "opening_balance",
                      ],
                      "owner_contribution",
                    ),
                    currency(),
                    number("amount", "Amount"),
                    method(),
                    {
                      ...choice("destination", "Destination account", [
                        "cash",
                        "bank",
                        "card",
                      ]),
                      required: false,
                    },
                    text("description", "Description"),
                  ],
                })
              }
            >
              {t("Cash movement")}
            </button>
            <button
              className="button secondary"
              onClick={() =>
                setAction({
                  title: "Exchange currency",
                  kind: "fx.exchange",
                  fields: [
                    currency(),
                    number("amount", "Amount"),
                    choice(
                      "destination_currency",
                      "Destination currency",
                      ["USD", "IQD"],
                      "USD",
                    ),
                    { ...number("rate", "Exchange rate"), step: "0.000001" },
                    method(),
                    text("description", "Description"),
                  ],
                })
              }
            >
              {t("Exchange currency")}
            </button>
          </>
        )}
        {can("billing") && (
          <button
            className="button secondary"
            onClick={() =>
              setAction({
                title: "Open till",
                kind: "till.open",
                fields: [
                  currency(),
                  { ...number("opening", "Opening float", 0), min: "0" },
                ],
              })
            }
          >
            {t("Open till")}
          </button>
        )}
        {can("export") && (
          <button
            className="button secondary"
            onClick={() => void downloadAccounting(requestScope())}
          >
            {t("Export accounting")}
          </button>
        )}
      </div>
      {section === "expenses" && (
        <section className="panel">
          <div className="panel-head">
            <h2>{t("Expenses")}</h2>
          </div>
          <RecordPager page={expenses} t={t} />
          {expenses.items.length ? (
            <DataTable
              heads={[
                "Date",
                "Supplier / payee",
                "Category",
                "Description",
                "Amount",
                "Status",
              ].map(t)}
            >
              {expenses.items.map((e) => (
                <tr key={e.id}>
                  <td>{formatDate(e.created_at, false, locale)}</td>
                  <td>{str(e, "supplier")}</td>
                  <td>
                    {t(
                      str(e, "category").charAt(0).toUpperCase() +
                        str(e, "category").slice(1),
                    )}
                  </td>
                  <td>{str(e, "description")}</td>
                  <td>{money(e.amount, e.currency as Currency, locale)}</td>
                  <td>
                    {e.is_paid || e.paid ? (
                      t("Paid")
                    ) : (
                      <button
                        className="text-button"
                        onClick={() =>
                          setAction({
                            title: "Settle payable",
                            kind: "expense.pay",
                            fixed: { expense_id: e.id },
                            fields: [method()],
                          })
                        }
                      >
                        {t("Settle payable")}
                      </button>
                    )}
                  </td>
                </tr>
              ))}
            </DataTable>
          ) : (
            <Empty t={t} loading={expenses.loading} />
          )}
        </section>
      )}
      {section === "movements" && (
        <section className="panel">
          <div className="panel-head">
            <h2>{t("Cash movement")}</h2>
          </div>
          <RecordPager page={movements} t={t} />
          {movements.items.length ? (
            <DataTable
              heads={["Date", "Movement type", "Amount", "Description"].map(t)}
            >
              {movements.items.map((e) => (
                <tr key={e.id}>
                  <td>{formatDate(e.created_at, true, locale)}</td>
                  <td>{str(e, "kind")}</td>
                  <td>{money(e.amount, e.currency as Currency, locale)}</td>
                  <td>{str(e, "description")}</td>
                </tr>
              ))}
            </DataTable>
          ) : (
            <Empty t={t} loading={movements.loading} />
          )}
        </section>
      )}
      {section === "tills" && (
        <section className="panel">
          <div className="panel-head">
            <h2>{t("Till sessions")}</h2>
          </div>
          <RecordPager page={tills} t={t} />
          {tills.items.length ? (
            <DataTable
              heads={[
                "Date",
                "Currency",
                "Opening float",
                "Expected",
                "Counted cash",
                "Action",
              ].map(t)}
            >
              {tills.items.map((e) => (
                <tr key={e.id}>
                  <td>{formatDate(e.opened_at, true, locale)}</td>
                  <td>{str(e, "currency")}</td>
                  <td>{str(e, "opening")}</td>
                  <td>{str(e, "expected")}</td>
                  <td>{str(e, "counted")}</td>
                  <td>
                    {!e.closed_at && can("billing") && (
                      <button
                        className="button small secondary"
                        onClick={() =>
                          setAction({
                            title: "Close till",
                            kind: "till.close",
                            fixed: { id: e.id },
                            fields: [
                              {
                                ...number("counted", "Counted cash"),
                                min: "0",
                              },
                              text("reason", "Reason", false),
                            ],
                          })
                        }
                      >
                        {t("Close till")}
                      </button>
                    )}
                  </td>
                </tr>
              ))}
            </DataTable>
          ) : (
            <Empty t={t} loading={tills.loading} />
          )}
        </section>
      )}
    </>
  );
}
async function downloadAccounting(isCurrent: () => boolean) {
  try {
    const rows = await exportAccounting();
    if (!isCurrent()) return;
    const header = [
      "id",
      "currency",
      "description",
      "source_type",
      "source_id",
      "created_at",
      "account",
      "debit",
      "credit",
    ];
    const quote = (x: unknown) =>
      `"${String(x ?? "")
        .replace(/^[=+@-]/, "'$&")
        .replaceAll('"', '""')}"`;
    const csv = [
      header.map(quote).join(","),
      ...rows.map((r) => header.map((k) => quote(r[k])).join(",")),
    ].join("\r\n");
    const url = URL.createObjectURL(
      new Blob(["\uFEFF", csv], { type: "text/csv;charset=utf-8" }),
    );
    const a = document.createElement("a");
    a.href = url;
    a.download = `clinicos-accounting-${new Date().toISOString().slice(0, 10)}.csv`;
    a.click();
    setTimeout(() => URL.revokeObjectURL(url), 1000);
  } catch (e) {
    if (isCurrent())
      window.alert(e instanceof Error ? e.message : "Export failed");
  }
}
