import { useEffect, useState } from "react";
import type { Row } from "../domain/types";
import type { Field, T } from "./ui";
import { client } from "../lib/supabase";
import { formatDate } from "../lib/format";
export function PostingSelect({ field, t }: { field: Field; t: T }) {
  const [query, setQuery] = useState(""),
    [cursors, setCursors] = useState<(string | null)[]>([null]),
    [items, setItems] = useState<Row[]>([]),
    [more, setMore] = useState(false),
    [error, setError] = useState(""),
    [loading, setLoading] = useState(false);
  useEffect(() => {
    let cancelled = false;
    setItems([]);
    setLoading(true);
    void client()
      .rpc("reconciliation_options", {
        statement_id: field.statementId,
        search_term: query,
        cursor_id: cursors.at(-1),
      })
      .then(({ data, error }) => {
        if (cancelled) return;
        if (error) setError(error.message);
        else {
          setItems(data.items);
          setMore(data.has_more);
          setError("");
        }
        setLoading(false);
      });
    return () => {
      cancelled = true;
    };
  }, [query, cursors, field.statementId]);
  return (
    <div className="patient-select">
      <input
        type="search"
        placeholder={t("Search postings")}
        value={query}
        onChange={(e) => {
          setQuery(e.target.value);
          setCursors([null]);
        }}
      />
      <select
        id={`field-${field.name}`}
        name={field.name}
        required
        disabled={loading}
      >
        <option value="">{t("Choose matching posting")}</option>
        {items.map((item) => (
          <option key={item.id} value={item.id}>
            {formatDate(item.created_at)} · {String(item.description)} ·{" "}
            {String(item.currency)} {String(item.amount)}
          </option>
        ))}
      </select>
      <div className="inline-actions">
        <button
          type="button"
          disabled={cursors.length === 1 || loading}
          onClick={() => setCursors(cursors.slice(0, -1))}
        >
          {t("Previous")}
        </button>
        <button
          type="button"
          disabled={!more || loading}
          onClick={() => setCursors([...cursors, items.at(-1)!.id])}
        >
          {t("Next")}
        </button>
      </div>
      {error && <span role="alert">{error}</span>}
    </div>
  );
}
