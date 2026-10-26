import { RecordPager, useRecordPage } from "../components/RecordPager";
import { useState } from "react";
import type { Snapshot, Currency, Locale } from "../domain/types";
import { DataTable, Empty, type T } from "../components/ui";
import { money, sum, difference } from "../domain/money";
import { formatDate, str } from "../lib/format";
import { FinancialReports } from "./financial-reports";
export function Reports({
  data,
  t,
  locale,
}: {
  data: Snapshot;
  t: T;
  locale: Locale;
}) {
  const audit = useRecordPage("audit", data);
  const [tab, setTab] = useState<"balances" | "audit" | "operations">(
    "operations",
  );
  return (
    <>
      <div className="segmented">
        <button
          className={tab === "operations" ? "selected" : ""}
          onClick={() => setTab("operations")}
        >
          {t("Operational reports")}
        </button>
        <button
          className={tab === "balances" ? "selected" : ""}
          onClick={() => setTab("balances")}
        >
          {t("Trial balance")}
        </button>
        <button
          className={tab === "audit" ? "selected" : ""}
          onClick={() => setTab("audit")}
        >
          {t("Audit trail")}
        </button>
      </div>
      {tab === "operations" ? (
        <FinancialReports data={data} t={t} locale={locale} />
      ) : tab === "audit" ? (
        <section className="panel">
          <RecordPager page={audit} t={t} />
          <DataTable heads={["Date", "Actor", "Action", "Record"].map(t)}>
            {audit.items.map((a) => (
              <tr key={a.id}>
                <td>{formatDate(a.created_at, true, locale)}</td>
                <td>
                  {data.members.find((m) => m.user_id === a.actor_id)
                    ?.display_name ?? "System"}
                </td>
                <td>{str(a, "action")}</td>
                <td>{str(a, "entity_type")}</td>
              </tr>
            ))}
          </DataTable>
        </section>
      ) : (
        <>
          {(["IQD", "USD"] as Currency[]).map((c) => {
            const lines = data.trial_balance.filter((l) => l.currency === c);
            const accounts = [...new Set(lines.map((l) => String(l.account)))];
            return (
              <section className="panel" key={c}>
                <div className="panel-head">
                  <h2>
                    {t("Trial balance")} · {c}
                  </h2>
                </div>
                {accounts.length ? (
                  <DataTable
                    heads={["Account", "Debit", "Credit", "Balance"].map(t)}
                  >
                    {accounts.map((a) => {
                      const l = lines.filter((x) => x.account === a);
                      const d = sum(l.map((x) => x.debit)),
                        cr = sum(l.map((x) => x.credit));
                      return (
                        <tr key={a}>
                          <td className="strong">{a}</td>
                          <td>{money(d, c, locale)}</td>
                          <td>{money(cr, c, locale)}</td>
                          <td>{money(difference(d, cr), c, locale)}</td>
                        </tr>
                      );
                    })}
                    <tr className="total-row">
                      <td>{t("Total")}</td>
                      <td>
                        {money(sum(lines.map((l) => l.debit)), c, locale)}
                      </td>
                      <td>
                        {money(sum(lines.map((l) => l.credit)), c, locale)}
                      </td>
                      <td>—</td>
                    </tr>
                  </DataTable>
                ) : (
                  <Empty t={t} />
                )}
              </section>
            );
          })}
        </>
      )}
    </>
  );
}
