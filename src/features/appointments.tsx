import { useEffect, useState, type ReactNode } from "react";
import { client } from "../lib/supabase";
import type { Row } from "../domain/types";
import {
  DataTable,
  Empty,
  ErrorMessage,
  Loading,
  type T,
} from "../components/ui";
import { day } from "../lib/format";
export function AppointmentsPage({
  t,
  renderRows,
  refreshKey,
}: {
  t: T;
  renderRows: (rows: Row[]) => ReactNode;
  refreshKey: unknown;
}) {
  const [date, setDate] = useState(() => day(new Date().toISOString())),
    [rows, setRows] = useState<Row[]>([]),
    [loading, setLoading] = useState(true),
    [error, setError] = useState("");
  useEffect(() => {
    let cancelled = false;
    setLoading(true);
    void client()
      .rpc("appointments_for_day", { service_day: date })
      .then(({ data, error }) => {
        if (cancelled) return;
        setLoading(false);
        if (error) {
          setError(error.message);
          return;
        }
        setRows(data);
        setError("");
      });
    return () => {
      cancelled = true;
    };
  }, [date, refreshKey]);
  return (
    <section className="panel">
      <div className="panel-head">
        <h2>{t("Appointments")}</h2>
        <label className="field">
          <span>{t("Date")} · Asia/Baghdad</span>
          <input
            type="date"
            required
            value={date}
            onChange={(e) => {
              if (e.target.value) {
                setLoading(true);
                setRows([]);
                setDate(e.target.value);
              }
            }}
          />
        </label>
      </div>
      {error && <ErrorMessage error={error} />}{" "}
      {loading ? (
        <Loading t={t} />
      ) : rows.length ? (
        <DataTable
          heads={[
            "Time",
            "Patient",
            "Service",
            "Clinician",
            "Status",
            "Action",
          ].map(t)}
        >
          {renderRows(rows)}
        </DataTable>
      ) : (
        <Empty t={t} />
      )}
    </section>
  );
}
