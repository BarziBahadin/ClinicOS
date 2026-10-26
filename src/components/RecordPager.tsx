import { useEffect, useLayoutEffect, useRef, useState } from "react";
import { client } from "../lib/supabase";
import type { Row } from "../domain/types";
import { ErrorMessage, type T } from "./ui";
export type RecordType =
  | "accounting:statements"
  | "accounting:matches"
  | "accounting:mappings"
  | "accounting:batches"
  | "accounting:periods"
  | "invoices"
  | "payments"
  | "expenses"
  | "audit"
  | "encounters"
  | "procedures"
  | "patient_documents"
  | "tasks"
  | "results"
  | "media"
  | "consents"
  | "cash_movements"
  | "tills"
  | "stock_lots"
  | "suppliers"
  | "inventory_products"
  | "stock_movements"
  | "packages"
  | "services"
  | "document_templates"
  | "clinical_facts"
  | "contact_log"
  | "performed_services"
  | "clinician_availability"
  | "clinic_resources";
export function useRecordPage(
  type: RecordType,
  refreshKey: unknown,
  patientId?: string,
) {
  const [query, setQuery] = useState(""),
    [cursors, setCursors] = useState<(string | null)[]>([null]),
    [items, setItems] = useState<Row[]>([]),
    [more, setMore] = useState(false),
    [error, setError] = useState(""),
    [loading, setLoading] = useState(false);
  const cursor = cursors.at(-1);
  const generation = useRef(0);
  useLayoutEffect(() => {
    generation.current++;
  }, [type, patientId, refreshKey]);
  useLayoutEffect(() => {
    setQuery("");
    setCursors([null]);
    setItems([]);
  }, [type, patientId]);
  useEffect(() => {
    if (!refreshKey) {
      setItems([]);
      setMore(false);
      setError("");
      setLoading(false);
      return;
    }
    let cancelled = false;
    const requestGeneration = generation.current;
    setLoading(true);
    setItems([]);
    setMore(false);
    setError("");
    const timer = setTimeout(async () => {
      try {
        const financial = [
          "invoices",
          "payments",
          "expenses",
          "audit",
        ].includes(type);
        const accounting = type.startsWith("accounting:");
        const { data, error } = await client().rpc(
          accounting
            ? "accounting_page"
            : financial
              ? "record_page"
              : "history_page",
          {
            record_type: accounting ? type.split(":")[1] : type,
            search_term: query,
            cursor_id: cursor,
            ...(!accounting ? { page_size: 50 } : {}),
            ...(!financial && !accounting
              ? { patient_id: patientId ?? null }
              : {}),
          },
        );
        if (cancelled || requestGeneration !== generation.current) return;
        if (error) throw error;
        setItems(data.items);
        setMore(data.has_more);
      } catch (error) {
        if (!cancelled && requestGeneration === generation.current)
          setError(
            error instanceof Error ? error.message : "Unable to load records",
          );
      } finally {
        if (!cancelled && requestGeneration === generation.current)
          setLoading(false);
      }
    }, 150);
    return () => {
      cancelled = true;
      clearTimeout(timer);
    };
  }, [type, query, cursor, refreshKey, patientId]);
  return {
    items,
    more,
    error,
    loading,
    query,
    setQuery: (value: string) => {
      setQuery(value);
      setCursors([null]);
    },
    previous: () => setCursors((c) => c.slice(0, -1)),
    next: () => {
      const last = items.at(-1);
      if (last) setCursors((c) => [...c, last.id]);
    },
    hasPrevious: cursors.length > 1,
  };
}
export function RecordPager({
  page,
  t,
}: {
  page: ReturnType<typeof useRecordPage>;
  t: T;
}) {
  return (
    <div className="record-pager">
      <label className="search-input">
        <span>{t("Search")}</span>
        <input
          type="search"
          value={page.query}
          onChange={(e) => page.setQuery(e.target.value)}
          aria-label={t("Search")}
        />
      </label>
      <div className="inline-actions">
        <button
          className="button small secondary"
          disabled={!page.hasPrevious || page.loading}
          onClick={page.previous}
        >
          {t("Previous")}
        </button>
        <button
          className="button small secondary"
          disabled={!page.more || page.loading}
          onClick={page.next}
        >
          {t("Next")}
        </button>
        <span role="status" className="muted">
          {page.loading ? t("Loading…") : `${page.items.length} ${t("shown")}`}
        </span>
      </div>
      {page.error && <ErrorMessage error={page.error} />}
    </div>
  );
}
