import { useEffect, useState } from "react";
import { ArrowLeft, ArrowRight, Search } from "lucide-react";
import { client } from "../lib/supabase";
import type { Patient } from "../domain/types";
import { ageAt } from "../domain/patient";
import { DataTable, Empty, ErrorMessage, type T } from "../components/ui";
export function PatientDirectory({
  t,
  onSelect,
  refreshKey,
}: {
  t: T;
  onSelect: (p: Patient) => void;
  refreshKey: unknown;
}) {
  const [query, setQuery] = useState(""),
    [cursors, setCursors] = useState<(string | null)[]>([null]),
    [items, setItems] = useState<Patient[]>([]),
    [more, setMore] = useState(false),
    [loading, setLoading] = useState(false),
    [error, setError] = useState("");
  const cursor = cursors.at(-1);
  useEffect(() => {
    let cancelled = false;
    const timer = setTimeout(async () => {
      setLoading(true);
      try {
        const { data, error } = await client().rpc("patient_search", {
          search_term: query,
          cursor_id: cursor,
          page_size: 50,
        });
        if (error) throw error;
        if (!cancelled) {
          setItems(data.items);
          setMore(data.has_more);
          setError("");
        }
      } catch (e) {
        if (!cancelled)
          setError(e instanceof Error ? e.message : "Search failed");
      } finally {
        if (!cancelled) setLoading(false);
      }
    }, 200);
    return () => {
      cancelled = true;
      clearTimeout(timer);
    };
  }, [query, cursor, refreshKey]);
  return (
    <section className="panel">
      <div className="panel-head">
        <label className="search-input">
          <Search size={17} />
          <input
            value={query}
            onChange={(e) => {
              setQuery(e.target.value);
              setCursors([null]);
            }}
            placeholder={t("Search patients…")}
            aria-label={t("Search patients…")}
          />
        </label>
        <span className="muted">
          {loading ? "…" : `${items.length} ${t("Patients")}`}
        </span>
      </div>
      <p className="panel-hint">
        {t(
          "Shared numbers are allowed. Confirm the patient using two identifiers.",
        )}
      </p>
      {error && <ErrorMessage error={error} />}{" "}
      {items.length ? (
        <DataTable
          heads={[
            "Patient",
            "Patient number",
            "Phone number",
            "Age",
            "Action",
          ].map(t)}
        >
          {items.map((p) => (
            <tr key={p.id}>
              <td>
                <button className="patient-link" onClick={() => onSelect(p)}>
                  <span className="avatar">{p.full_name.slice(0, 1)}</span>
                  <span className="strong" dir="auto">
                    {p.full_name}
                  </span>
                </button>
              </td>
              <td className="mono">{p.patient_number}</td>
              <td dir="ltr">{p.phone ?? "—"}</td>
              <td>{ageAt(p.birth_date, p.birth_precision)}</td>
              <td>
                <button className="text-button" onClick={() => onSelect(p)}>
                  {t("View")}
                </button>
              </td>
            </tr>
          ))}
        </DataTable>
      ) : (
        !loading && (
          <Empty
            t={t}
            text={query ? "No matching patients" : "Nothing here yet"}
          />
        )
      )}
      <div className="panel-head">
        <button
          className="button secondary small"
          disabled={cursors.length === 1 || loading}
          onClick={() => setCursors(cursors.slice(0, -1))}
        >
          <ArrowLeft size={14} />
          {t("Previous")}
        </button>
        <span className="muted">{cursors.length}</span>
        <button
          className="button secondary small"
          disabled={!more || loading}
          onClick={() => setCursors([...cursors, items.at(-1)!.id])}
        >
          {t("Next")}
          <ArrowRight size={14} />
        </button>
      </div>
    </section>
  );
}
