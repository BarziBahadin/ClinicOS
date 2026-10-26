import { useEffect, useLayoutEffect, useState } from "react";
import type { Locale, Row, Snapshot } from "../domain/types";
import {
  DataTable,
  Empty,
  ErrorMessage,
  type Action,
  type T,
} from "../components/ui";
import { choice, text } from "./actions";
import { rpc } from "../lib/api";
import { day, formatDate, str } from "../lib/format";
export function PhoneReminders({
  data,
  t,
  locale,
  setAction,
}: {
  data: Snapshot;
  t: T;
  locale: Locale;
  setAction: (action: Action) => void;
}) {
  const today = day(new Date().toISOString());
  const [filters, setFilters] = useState({
    from: today,
    to: day(new Date(Date.now() + 7 * 86400000).toISOString()),
    includeContacted: false,
  });
  const [page, setPage] = useState(0),
    [rows, setRows] = useState<Row[]>([]),
    [records, setRecords] = useState(0),
    [more, setMore] = useState(false),
    [error, setError] = useState(""),
    [loading, setLoading] = useState(false);
  useLayoutEffect(() => {
    setRows([]);
    setRecords(0);
    setError("");
    setMore(false);
  }, [filters, page, data]);
  useEffect(() => {
    let cancelled = false;
    setLoading(true);
    void rpc<{ items: Row[]; records: number; has_more: boolean }>(
      "phone_reminders",
      {
        from_day: filters.from,
        to_day: filters.to,
        include_contacted: filters.includeContacted,
        page_number: page,
      },
    )
      .then((result) => {
        if (cancelled) return;
        setRows(result.items);
        setRecords(result.records);
        setMore(result.has_more);
      })
      .catch((e) => {
        if (!cancelled)
          setError(
            e instanceof Error ? e.message : "Unable to load call reminders",
          );
      })
      .finally(() => {
        if (!cancelled) setLoading(false);
      });
    return () => {
      cancelled = true;
    };
  }, [filters, page, data]);
  if (!data.permissions.includes("patients")) return null;
  return (
    <details className="panel">
      <summary>{t("Staff phone-call reminders")}</summary>
      <p className="panel-hint">
        {t(
          "Call patients yourself and record the actual outcome. This list sends no messages. Review communication consent and the contact owner before calling.",
        )}
      </p>
      <form
        className="dialog-body form-grid"
        onSubmit={(event) => {
          event.preventDefault();
          const form = new FormData(event.currentTarget);
          setPage(0);
          setFilters({
            from: String(form.get("from")),
            to: String(form.get("to")),
            includeContacted: form.get("contacted") === "on",
          });
        }}
      >
        <label className="field">
          <span>{t("From")}</span>
          <input type="date" name="from" defaultValue={filters.from} required />
        </label>
        <label className="field">
          <span>{t("To")}</span>
          <input type="date" name="to" defaultValue={filters.to} required />
        </label>
        <label className="field">
          <span>{t("Include contacted appointments")}</span>
          <input
            type="checkbox"
            name="contacted"
            defaultChecked={filters.includeContacted}
          />
        </label>
        <button className="button secondary" disabled={loading}>
          {t("Load call list")}
        </button>
      </form>
      {error && <ErrorMessage error={error} />}
      <p className="panel-hint">
        {records} {t("Appointments")} · {t("Asia/Baghdad")}
      </p>
      {rows.length ? (
        <DataTable
          heads={[
            "Time",
            "Patient",
            "Service",
            "Clinician",
            "Phone number",
            "Contact owner",
            "Last call",
            "Outcome",
            "Action",
          ].map(t)}
        >
          {rows.map((row) => (
            <tr key={row.id}>
              <td>{formatDate(row.starts_at, true, locale)}</td>
              <td>
                <a href={`#patients/${row.patient_id}`}>
                  {str(row, "patient_name")}
                </a>
                <p>
                  <bdi dir="ltr">{str(row, "patient_number")}</bdi>
                </p>
              </td>
              <td>{str(row, "service_name")}</td>
              <td>{str(row, "clinician_name")}</td>
              <td>
                <bdi dir="ltr">{str(row, "phone")}</bdi>
              </td>
              <td dir="auto">{str(row, "contact_owner")}</td>
              <td>{formatDate(row.last_call_at, true, locale)}</td>
              <td>{t(str(row, "last_outcome")).replaceAll("_", " ")}</td>
              <td>
                {!row.communication_allowed ? (
                  <button
                    className="text-button"
                    onClick={() =>
                      setAction({
                        title: "Review communication consent",
                        kind: "consent.record",
                        fixed: {
                          patient_id: row.patient_id,
                          purpose: "communication",
                        },
                        fields: [
                          {
                            name: "granted",
                            label: "Granted",
                            type: "checkbox",
                            value: true,
                          },
                          text("template_version", "Policy reference"),
                          {
                            ...text("evidence", "Evidence / discussion"),
                            type: "textarea",
                          },
                        ],
                      })
                    }
                  >
                    {t("Review communication consent")}
                  </button>
                ) : !row.phone ? (
                  <button
                    className="text-button"
                    onClick={() =>
                      setAction({
                        title: "Add contact",
                        kind: "contact.add",
                        fixed: { patient_id: row.patient_id },
                        fields: [
                          text("phone", "Phone number"),
                          text("owner_name", "Contact owner"),
                          text("relationship", "Relationship", false),
                          {
                            name: "preferred",
                            label: "Preferred",
                            type: "checkbox",
                            value: true,
                          },
                        ],
                      })
                    }
                  >
                    {t("Add contact")}
                  </button>
                ) : (
                  <button
                    className="button secondary"
                    onClick={() =>
                      setAction({
                        title: "Record reminder call",
                        kind: "contact.log",
                        fixed: {
                          patient_id: row.patient_id,
                          appointment_id: row.id,
                          appointment_version: row.version,
                          contact_id: row.contact_id,
                          channel: "phone",
                          purpose: "appointment_reminder",
                        },
                        instructions: `${t("Patient")}: ${row.patient_name}\n${t("Phone number")}: ${row.phone}\n${t("Contact owner")}: ${row.contact_owner ?? "—"}`,
                        fields: [
                          choice("outcome", "Outcome", [
                            "reached",
                            "no_answer",
                            "declined",
                            "other",
                          ]),
                          { ...text("notes", "Notes"), type: "textarea" },
                        ],
                      })
                    }
                  >
                    {t("Record reminder call")}
                  </button>
                )}
              </td>
            </tr>
          ))}
        </DataTable>
      ) : (
        <Empty t={t} text={loading ? "Loading…" : "Nothing here yet"} />
      )}
      <div className="panel-head">
        <button
          className="button secondary"
          disabled={page === 0 || loading}
          onClick={() => setPage(page - 1)}
        >
          {t("Previous")}
        </button>
        <span>{page + 1}</span>
        <button
          className="button secondary"
          disabled={!more || loading}
          onClick={() => setPage(page + 1)}
        >
          {t("Next")}
        </button>
      </div>
    </details>
  );
}
