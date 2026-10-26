import { useEffect, useState } from "react";
import { client } from "../lib/supabase";
import type { Field, T } from "./ui";
export function PatientSelect({ field, t }: { field: Field; t: T }) {
  const initial = field.options ?? [],
    [query, setQuery] = useState(""),
    [items, setItems] = useState(initial),
    [value, setValue] = useState(String(field.value ?? "")),
    [error, setError] = useState("");
  const selected =
    initial.find((o) => o.value === value) ??
    items.find((o) => o.value === value);
  useEffect(() => {
    if (!query.trim()) {
      setItems(initial);
      return;
    }
    let cancelled = false;
    const timer = setTimeout(() => {
      void client()
        .rpc(
          field.type === "billing-patient"
            ? "billing_patient_search"
            : "patient_search",
          { search_term: query, page_size: 50 },
        )
        .then(({ data, error }) => {
          if (cancelled) return;
          if (error) {
            setError(error.message);
            return;
          }
          setError("");
          setItems(
            data.items.map(
              (p: {
                id: string;
                full_name: string;
                patient_number: string;
              }) => ({
                value: p.id,
                label: `${p.full_name} · ${p.patient_number}`,
              }),
            ),
          );
        });
    }, 200);
    return () => {
      cancelled = true;
      clearTimeout(timer);
    };
  }, [query, field.type]);
  return (
    <div className="patient-select">
      <input
        type="search"
        value={query}
        onChange={(e) => setQuery(e.target.value)}
        placeholder={t("Search patients…")}
        aria-label={t("Search patients…")}
      />
      <select
        id={`field-${field.name}`}
        name={field.name}
        required={field.required}
        value={value}
        onChange={(e) => setValue(e.target.value)}
      >
        <option value="">—</option>
        {selected && !items.some((o) => o.value === value) && (
          <option value={selected.value}>{selected.label}</option>
        )}
        {items.map((o) => (
          <option key={o.value} value={o.value}>
            {o.label}
          </option>
        ))}
      </select>
      {error && <span role="alert">{error}</span>}
    </div>
  );
}
