import { useRequestScope } from "../lib/request-scope";
import { rpc } from "../lib/api";
import { useRef, useState } from "react";
import type { Currency, Locale, Row, Snapshot } from "../domain/types";
import { RecordPager, useRecordPage } from "../components/RecordPager";
import {
  DataTable,
  Dialog,
  ErrorMessage,
  type Action,
  type T,
} from "../components/ui";
import { text, number, currency, choice } from "./actions";
import { formatDate, str } from "../lib/format";
import { money } from "../domain/money";
import { csvText, statementCsv } from "../domain/csv";
import { downloadFile } from "../lib/download";
const accounts = [
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
];
const date = (name: string, label: string) => ({
  name,
  label,
  type: "date",
  required: true,
});
export function Accounting({
  data,
  t,
  locale,
  setAction,
  onSaved,
}: {
  data: Snapshot;
  t: T;
  locale: Locale;
  setAction: (a: Action) => void;
  onSaved: () => Promise<void>;
}) {
  const requestScope = useRequestScope(
    `${data.organization.id}:${data.membership.user_id}:${data.permissions.join(",")}`,
  );
  const [tab, setTab] = useState("statements"),
    [importing, setImporting] = useState(false),
    [error, setError] = useState(""),
    [busy, setBusy] = useState(false);
  const statements = useRecordPage("accounting:statements", data),
    matches = useRecordPage("accounting:matches", data),
    mappings = useRecordPage("accounting:mappings", data),
    batches = useRecordPage("accounting:batches", data),
    periods = useRecordPage("accounting:periods", data);
  const attempt = useRef<{ fingerprint: string; id: string } | null>(null);
  const can = (permission: string) => data.permissions.includes(permission);
  async function batchDownload(batch: Row) {
    setError("");
    const isCurrent = requestScope();
    try {
      const rows = await rpc<Row[]>("accounting_batch_download", {
        batch_id: batch.id,
      });
      if (!isCurrent()) return;
      const heads = [
        "batch_id",
        "journal_id",
        "line_id",
        "date",
        "currency",
        "account_code",
        "account",
        "debit",
        "credit",
        "source_type",
        "source_id",
        "description",
      ];
      downloadFile(
        `clinicos-batch-${batch.id}.csv`,
        csvText([
          heads,
          ...rows.map((row: Row) => heads.map((key) => row[key])),
        ]),
        "text/csv;charset=utf-8",
      );
    } catch (e) {
      if (isCurrent())
        setError(e instanceof Error ? e.message : "Unable to download batch");
    }
  }
  return (
    <>
      <div className="segmented">
        {[
          ["statements", "Bank/card reconciliation"],
          ["matches", "Reconciliation history"],
          ["mappings", "Account mappings"],
          ["batches", "Accounting batches"],
          ["periods", "Accounting periods"],
        ].map(([key, label]) => (
          <button
            key={key}
            className={tab === key ? "selected" : ""}
            aria-current={tab === key ? "page" : undefined}
            onClick={() => {
              setTab(key);
              setError("");
            }}
          >
            {t(label)}
          </button>
        ))}
      </div>
      {error && <ErrorMessage error={error} />}
      {tab === "statements" && (
        <section className="panel">
          <div className="panel-head">
            <h2>{t("Bank/card reconciliation")}</h2>
            <button
              className="button primary"
              onClick={() => {
                setError("");
                setImporting(true);
              }}
            >
              {t("Import statement CSV")}
            </button>
          </div>
          <p className="panel-hint">
            {t(
              "Match statement lines to existing postings. Record fees and corrections separately; matching does not create money movements.",
            )}
          </p>
          <RecordPager page={statements} t={t} />
          <DataTable
            heads={[
              "Date",
              "Account",
              "Reference",
              "Amount",
              "Status",
              "Action",
            ].map(t)}
          >
            {statements.items.map((row) => (
              <tr key={row.id}>
                <td>{formatDate(row.posted_on, false, locale)}</td>
                <td>{t(str(row, "account"))}</td>
                <td dir="auto">{str(row, "reference")}</td>
                <td>{money(row.amount, row.currency as Currency, locale)}</td>
                <td>{t(row.matched ? "Reconciled" : "Unmatched")}</td>
                <td>
                  {!row.matched && (
                    <button
                      className="button secondary"
                      onClick={() =>
                        setAction({
                          title: "Match statement line",
                          kind: "finance.bank.match",
                          fixed: { id: row.id },
                          fields: [
                            {
                              name: "journal_line_id",
                              label: "Matching posting",
                              required: true,
                              statementId: row.id,
                            },
                            text("reason", "Matching evidence"),
                          ],
                        })
                      }
                    >
                      {t("Match")}
                    </button>
                  )}
                </td>
              </tr>
            ))}
          </DataTable>
        </section>
      )}
      {tab === "matches" && (
        <section className="panel">
          <RecordPager page={matches} t={t} />
          <DataTable
            heads={["Date", "Reference", "Reason", "Status", "Action"].map(t)}
          >
            {matches.items.map((row) => (
              <tr key={row.id}>
                <td>{formatDate(row.created_at, true, locale)}</td>
                <td>
                  <bdi>{row.id}</bdi>
                </td>
                <td dir="auto">{str(row, "reason")}</td>
                <td>{t(row.reversed ? "Reversed" : "Reconciled")}</td>
                <td>
                  {!row.reversed && can("approve") && (
                    <button
                      className="text-button"
                      onClick={() =>
                        setAction({
                          title: "Reverse reconciliation match",
                          kind: "finance.bank.reverse_match",
                          fixed: { id: row.id },
                          fields: [text("reason", "Reason")],
                        })
                      }
                    >
                      {t("Reverse match")}
                    </button>
                  )}
                </td>
              </tr>
            ))}
          </DataTable>
        </section>
      )}
      {tab === "mappings" && (
        <section className="panel">
          <div className="panel-head">
            <h2>{t("Account mappings")}</h2>
            {can("approve") && (
              <button
                className="button primary"
                onClick={() =>
                  setAction({
                    title: "New mapping version",
                    kind: "finance.mapping.create",
                    fields: [
                      text("name", "Version name"),
                      ...accounts.map((account) =>
                        text("code_" + account, t(account)),
                      ),
                    ],
                  })
                }
              >
                {t("New mapping version")}
              </button>
            )}
          </div>
          <p className="panel-hint">
            {t(
              "Enter the external account codes supplied by your accountant. Approved mapping versions cannot be edited.",
            )}
          </p>
          <RecordPager page={mappings} t={t} />
          {mappings.items.map((row) => (
            <article className="encounter" key={row.id}>
              <h3>
                {str(row, "name")} · {t(row.approved_at ? "Approved" : "Draft")}
              </h3>
              <DataTable heads={["Account", "External code"].map(t)}>
                {Object.entries(row.codes as Record<string, string>).map(
                  ([key, value]) => (
                    <tr key={key}>
                      <td>{t(key)}</td>
                      <td dir="ltr">{value}</td>
                    </tr>
                  ),
                )}
              </DataTable>
              <div className="action-bar">
                {!row.approved_at && can("approve") && (
                  <button
                    className="button secondary"
                    onClick={() =>
                      setAction({
                        title: "Approve mapping",
                        kind: "finance.mapping.approve",
                        fixed: { id: row.id },
                        fields: [],
                      })
                    }
                  >
                    {t("Approve mapping")}
                  </button>
                )}
                {Boolean(row.approved_at) && can("export") && (
                  <button
                    className="button secondary"
                    onClick={() =>
                      setAction({
                        title: "Create accounting batch",
                        kind: "finance.batch.create",
                        fixed: { mapping_id: row.id },
                        fields: [
                          date("from_day", "From"),
                          date("to_day", "To"),
                        ],
                      })
                    }
                  >
                    {t("Create accounting batch")}
                  </button>
                )}
              </div>
            </article>
          ))}
        </section>
      )}
      {tab === "batches" && (
        <section className="panel">
          <p className="panel-hint">
            {t(
              "Download and import each batch once. Record the accounting system reference after confirming counts and totals.",
            )}
          </p>
          <RecordPager page={batches} t={t} />
          <DataTable
            heads={["Reference", "From", "To", "Status", "Action"].map(t)}
          >
            {batches.items.map((row) => (
              <tr key={row.id}>
                <td>
                  <bdi>{row.id}</bdi>
                </td>
                <td>{str(row, "from_day")}</td>
                <td>{str(row, "to_day")}</td>
                <td>
                  {t(
                    row.acknowledged
                      ? "Acknowledged"
                      : "Awaiting acknowledgement",
                  )}
                </td>
                <td>
                  {can("export") && (
                    <div className="inline-actions">
                      <button
                        className="text-button"
                        onClick={() => void batchDownload(row)}
                      >
                        {t("Download CSV")}
                      </button>
                      {!row.acknowledged && (
                        <button
                          className="text-button"
                          onClick={() =>
                            setAction({
                              title: "Acknowledge accounting batch",
                              kind: "finance.batch.acknowledge",
                              fixed: { id: row.id },
                              fields: [
                                text(
                                  "external_reference",
                                  "Accounting system reference",
                                ),
                                {
                                  ...text("notes", "Reconciliation notes"),
                                  type: "textarea",
                                },
                              ],
                            })
                          }
                        >
                          {t("Acknowledge")}
                        </button>
                      )}
                    </div>
                  )}
                </td>
              </tr>
            ))}
          </DataTable>
        </section>
      )}
      {tab === "periods" && (
        <section className="panel">
          <div className="panel-head">
            <h2>{t("Accounting periods")}</h2>
            {can("approve") && (
              <div className="inline-actions">
                <button
                  className="button secondary"
                  onClick={() =>
                    setAction({
                      title: "Close accounting period",
                      kind: "finance.period.close",
                      fields: [
                        date("from_day", "From"),
                        date("to_day", "To"),
                        text("reason", "Close evidence"),
                      ],
                    })
                  }
                >
                  {t("Close accounting period")}
                </button>
                <button
                  className="button secondary"
                  onClick={() =>
                    setAction({
                      title: "Dated accounting adjustment",
                      kind: "finance.journal.adjust",
                      fields: [
                        date("posting_day", "Posting date"),
                        currency(),
                        number("amount", "Amount"),
                        choice("debit_account", "Debit", accounts),
                        choice("credit_account", "Credit", accounts),
                        text("description", "Reason"),
                      ],
                    })
                  }
                >
                  {t("Dated accounting adjustment")}
                </button>
              </div>
            )}
          </div>
          <p className="panel-hint">
            {t(
              "Closing a period prevents new postings on those dates. Correct through an authorized adjustment in an open period.",
            )}
          </p>
          <RecordPager page={periods} t={t} />
          <DataTable heads={["From", "To", "Reason"].map(t)}>
            {periods.items.map((row) => (
              <tr key={row.id}>
                <td>{str(row, "from_day")}</td>
                <td>{str(row, "to_day")}</td>
                <td dir="auto">{str(row, "reason")}</td>
              </tr>
            ))}
          </DataTable>
        </section>
      )}
      {importing && (
        <Dialog
          title={t("Import statement CSV")}
          onClose={() => !busy && setImporting(false)}
        >
          <form
            onSubmit={async (e) => {
              e.preventDefault();
              const isCurrent = requestScope();
              const form = e.currentTarget;
              setBusy(true);
              setError("");
              try {
                const file = new FormData(form).get("statement");
                if (!(file instanceof File) || file.size > 180000)
                  throw new Error("Choose a CSV smaller than 180 KB.");
                const lines = statementCsv(await file.text());
                if (!isCurrent()) return;
                const fingerprint = JSON.stringify(lines);
                if (attempt.current?.fingerprint !== fingerprint)
                  attempt.current = { fingerprint, id: crypto.randomUUID() };
                await rpc("finance_workflow", {
                  kind: "finance.bank.import",
                  payload: { lines },
                  request_id: attempt.current.id,
                });
                if (!isCurrent()) return;
                attempt.current = null;
                await onSaved();
                if (isCurrent()) setImporting(false);
              } catch (e) {
                if (isCurrent())
                  setError(
                    e instanceof Error ? e.message : "Statement import failed",
                  );
              } finally {
                if (isCurrent()) setBusy(false);
              }
            }}
          >
            <div className="dialog-body">
              <p>
                {t(
                  "Use bank or card, IQD or USD, signed amounts and a stable statement identifier for each transaction.",
                )}
              </p>
              <button
                type="button"
                className="button secondary"
                onClick={() =>
                  downloadFile(
                    "clinicos-statement-template.csv",
                    "Date,Account,Currency,Amount,Reference,Statement ID\n",
                    "text/csv;charset=utf-8",
                  )
                }
              >
                {t("Download CSV template")}
              </button>
              <label className="field">
                <span>{t("Statement CSV")}</span>
                <input
                  name="statement"
                  type="file"
                  accept=".csv,text/csv"
                  required
                />
              </label>
              {error && <ErrorMessage error={error} />}
            </div>
            <footer className="dialog-footer">
              <button className="button primary" disabled={busy}>
                {t(busy ? "Saving…" : "Import statement CSV")}
              </button>
            </footer>
          </form>
        </Dialog>
      )}
    </>
  );
}
