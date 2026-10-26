import { useLayoutEffect, useEffect, useState } from "react";
import { client } from "../lib/supabase";
import { formatDate } from "../lib/format";
import type { Row } from "../domain/types";
import type { Field, T } from "./ui";
export function EncounterSelect({
  field,
  t,
  patientId,
}: {
  field: Field;
  t: T;
  patientId?: string;
}) {
  const [query, setQuery] = useState(""),
    [cursor, setCursor] = useState<(string | null)[]>([null]),
    [items, setItems] = useState<Row[]>([]),
    [value, setValue] = useState(""),
    [more, setMore] = useState(false),
    [error, setError] = useState(""),
    [loading, setLoading] = useState(false);
  const selectedPatient = field.patientId ?? patientId;
  useLayoutEffect(() => {
    setValue("");
    setItems([]);
    setCursor([null]);
    setQuery("");
  }, [selectedPatient]);
  useEffect(() => {
    if (!selectedPatient) return;
    let cancelled = false;
    setLoading(true);
    setItems([]);
    setError("");
    const timer = setTimeout(() => {
      void client()
        .rpc("encounter_search", {
          patient_id: selectedPatient,
          search_term: query,
          cursor_id: cursor.at(-1),
          status_filter: field.encounterStatus ?? null,
          only_author: field.ownOnly ?? false,
        })
        .then(({ data, error }) => {
          if (cancelled) return;
          if (error) setError(error.message);
          else {
            setItems(data.items);
            setMore(data.has_more);
          }
          setLoading(false);
        });
    }, 150);
    return () => {
      cancelled = true;
      clearTimeout(timer);
    };
  }, [selectedPatient, query, cursor, field.encounterStatus, field.ownOnly]);
  return (
    <div className="patient-select">
      <input
        type="search"
        value={query}
        onChange={(e) => {
          setQuery(e.target.value);
          setCursor([null]);
        }}
        placeholder={t("Search encounters by date or complaint")}
        disabled={!selectedPatient}
      />
      <select
        id={`field-${field.name}`}
        name={field.name}
        value={value}
        onChange={(e) => setValue(e.target.value)}
        required={field.required}
        disabled={!selectedPatient || loading}
      >
        <option value="">
          {t(selectedPatient ? "Choose encounter" : "Choose a patient first")}
        </option>
        {items.map((e) => (
          <option key={e.id} value={e.id}>
            {formatDate(e.created_at, true)} · {String(e.label)} ·{" "}
            {t(String(e.status))}
          </option>
        ))}
      </select>
      <div className="inline-actions">
        <button
          type="button"
          disabled={cursor.length === 1 || loading}
          onClick={() => setCursor(cursor.slice(0, -1))}
        >
          {t("Previous")}
        </button>
        <button
          type="button"
          disabled={!more || loading}
          onClick={() => setCursor([...cursor, items.at(-1)!.id])}
        >
          {t("Next")}
        </button>
      </div>
      {error && <span role="alert">{error}</span>}
    </div>
  );
}
