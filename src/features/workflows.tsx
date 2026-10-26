import { hasRole } from "../domain/staff";
import { useEffect, useState } from "react";
import type { Currency, Locale, Patient, Row, Snapshot } from "../domain/types";
import { RecordPager, useRecordPage } from "../components/RecordPager";
import {
  DataTable,
  ErrorMessage,
  options,
  type Action,
  type T,
} from "../components/ui";
import {
  choice,
  currency,
  encounter,
  number,
  text,
  patient as patientField,
  encounterAction,
  procedureAction,
} from "./actions";
import { client } from "../lib/supabase";
import { formatDate, str } from "../lib/format";
import { money } from "../domain/money";
import { printDocument } from "../lib/print";
import { CareTeam, PatientExport } from "./access";

type Props = {
  data: Snapshot;
  t: T;
  locale: Locale;
  setAction: (action: Action) => void;
};
const area = (
  name: string,
  label: string,
  required = true,
  value?: unknown,
) => ({ ...text(name, label, required, value), type: "textarea" });
const date = (name: string, label: string) => ({
  name,
  label,
  type: "date",
  required: true,
});
const dateTime = (name: string, label: string) => ({
  name,
  label,
  type: "datetime-local",
  required: true,
});
export function Treatments({ data, t, locale, setAction }: Props) {
  const services = useRecordPage("services", data),
    templates = useRecordPage("document_templates", data);
  const [tab, setTab] = useState("services");
  const clinical = data.permissions.includes("clinical");
  function useTemplate(row: Row) {
    if (row.kind === "consent") {
      setAction({
        title: "Record consent",
        kind: "consent.record",
        instructions: String(row.content),
        fixed: { template_id: row.id, template_version: String(row.version) },
        fields: [
          patientField(data),
          choice(
            "purpose",
            "Purpose",
            clinical
              ? [
                  "care_photography",
                  "procedure",
                  "teaching",
                  "publication",
                  "marketing",
                  "communication",
                ]
              : ["communication"],
          ),
          { name: "granted", label: "Granted", type: "checkbox", value: true },
          area("evidence", "Evidence / discussion"),
        ],
      });
    } else if (row.kind === "clinical") {
      const action = encounterAction(data);
      setAction({
        ...action,
        instructions: String(row.content),
        fixed: { template_id: row.id },
        fields: action.fields.map((f) =>
          f.name === "history" ? { ...f, value: row.content } : f,
        ),
      });
    } else if (row.kind === "procedure") {
      const action = procedureAction(data);
      setAction({
        ...action,
        instructions: String(row.content),
        fixed: { template_id: row.id },
        fields: action.fields.map((f) =>
          f.name === "name" ? { ...f, value: row.name } : f,
        ),
      });
    } else {
      setAction({
        title: "Sign patient document",
        kind: "document.create",
        instructions:
          "Review the patient-specific details before signing this document.",
        fixed: { template_id: row.id, kind: row.kind },
        fields: [
          patientField(data),
          text("title", "Title", true, row.name),
          area("body", "Document content", true, row.content),
        ],
      });
    }
  }
  return (
    <>
      <div className="segmented">
        <button
          onClick={() => setTab("services")}
          className={tab === "services" ? "selected" : ""}
        >
          {t("Treatments")}
        </button>
        <button
          onClick={() => setTab("templates")}
          className={tab === "templates" ? "selected" : ""}
        >
          {t("Document templates")}
        </button>
      </div>
      {tab === "services" ? (
        <section className="panel">
          <div className="panel-head">
            <h2>{t("Treatments")}</h2>
            <button
              className="button primary"
              onClick={() =>
                setAction({
                  title: "Add treatment",
                  kind: "service.propose",
                  fields: [
                    text("name", "Service"),
                    text("name_ckb", "Name in Sorani", false),
                    choice("category", "Category", ["medical", "cosmetic"]),
                    {
                      ...number("duration", "Duration (minutes)", 30),
                      min: "5",
                      max: "480",
                      step: "1",
                    },
                    currency(),
                  ],
                })
              }
            >
              {t("Add treatment")}
            </button>
          </div>
          <p className="panel-hint">
            {t(
              "The front desk can add treatments. Prices require approval before billing.",
            )}
          </p>
          <RecordPager page={services} t={t} />
          <DataTable
            heads={["Service", "Category", "Price", "Status", "Action"].map(t)}
          >
            {services.items.map((s) => (
              <tr key={s.id}>
                <td>
                  <span dir="auto">{str(s, "name")}</span>
                  <br />
                  <span dir="auto">{str(s, "name_ckb")}</span>
                </td>
                <td>{t(str(s, "category"))}</td>
                <td>
                  {s.active
                    ? money(s.price, s.currency as Currency, locale)
                    : "—"}
                </td>
                <td>{t(s.active ? "Approved" : "Draft")}</td>
                <td>
                  {!s.active && data.permissions.includes("settings") && (
                    <button
                      className="text-button"
                      onClick={() =>
                        setAction({
                          title: "Approve price",
                          kind: "service.approve",
                          fixed: { id: s.id },
                          fields: [
                            currency(),
                            { ...number("price", "Price"), min: "0" },
                          ],
                        })
                      }
                    >
                      {t("Approve price")}
                    </button>
                  )}
                </td>
              </tr>
            ))}
          </DataTable>
        </section>
      ) : (
        <section className="panel">
          <div className="panel-head">
            <h2>{t("Document templates")}</h2>
            {clinical && (
              <button
                className="button primary"
                onClick={() =>
                  setAction({
                    title: "New template version",
                    kind: "template.create",
                    fields: [
                      choice("kind", "Document type", [
                        "clinical",
                        "procedure",
                        "consent",
                        "aftercare",
                        "referral",
                      ]),
                      text("name", "Title"),
                      choice("language", "Preferred language", ["en", "ckb"]),
                      {
                        ...number("version", "Version", 1),
                        min: "1",
                        step: "1",
                      },
                      area("content", "Content"),
                    ],
                  })
                }
              >
                {t("New template version")}
              </button>
            )}
          </div>
          <RecordPager page={templates} t={t} />
          {templates.items.map((row) => (
            <article className="encounter" key={row.id}>
              <h3>
                {str(row, "name")} · {t(str(row, "kind"))} ·{" "}
                {str(row, "language")} · {t("Version")} {str(row, "version")}
              </h3>
              <p className="muted">{t(String(row.status))}</p>
              <p dir="auto" style={{ whiteSpace: "pre-wrap" }}>
                {str(row, "content")}
              </p>
              <div className="action-bar">
                {row.status === "approved" &&
                  (clinical || row.kind === "consent") && (
                    <button
                      className="button primary"
                      onClick={() => useTemplate(row)}
                    >
                      {t("Use template")}
                    </button>
                  )}
                {row.status === "draft" && clinical && (
                  <button
                    className="button secondary"
                    onClick={() =>
                      setAction({
                        title: "Approve template",
                        kind: "template.approve",
                        fixed: { id: row.id },
                        fields: [],
                      })
                    }
                  >
                    {t("Approve template")}
                  </button>
                )}
                {row.status === "approved" && (
                  <button
                    className="button secondary"
                    onClick={() =>
                      printDocument(
                        `${data.organization.name} · ${row.name}`,
                        [
                          String(row.content),
                          `${t("Version")}: ${row.version}`,
                        ],
                        row.language as Locale,
                      )
                    }
                  >
                    {t("Print")}
                  </button>
                )}
              </div>
            </article>
          ))}
        </section>
      )}
    </>
  );
}
export function ScheduleTools({ data, t, setAction }: Omit<Props, "locale">) {
  const windows = useRecordPage("clinician_availability", data),
    resources = useRecordPage("clinic_resources", data);
  return (
    <>
      <div className="action-bar">
        <button
          className="button secondary"
          onClick={() =>
            setAction({
              title: "Clinician availability",
              kind: "availability.add",
              fields: [
                {
                  name: "doctor_id",
                  label: "Clinician",
                  required: true,
                  options: options(
                    data.members.filter(
                      (m) => m.active && hasRole(m, "doctor"),
                    ),
                    "display_name",
                    "user_id",
                  ),
                },
                choice("kind", "Status", ["available", "leave"]),
                dateTime("starts_at", "Start"),
                dateTime("ends_at", "End"),
                text("description", "Description"),
              ],
            })
          }
        >
          {t("Clinician availability")}
        </button>
        {data.permissions.includes("settings") && (
          <button
            className="button secondary"
            onClick={() =>
              setAction({
                title: "Add room or device",
                kind: "resource.add",
                fields: [
                  text("name", "Title"),
                  choice("kind", "Category", ["room", "device"]),
                ],
              })
            }
          >
            {t("Add room or device")}
          </button>
        )}
      </div>
      <details className="panel">
        <summary>{t("Clinician availability")}</summary>
        <RecordPager page={windows} t={t} />
        <DataTable
          heads={["Clinician", "Start", "End", "Status", "Action"].map(t)}
        >
          {windows.items.map((r) => (
            <tr key={r.id}>
              <td>
                {
                  data.members.find((m) => m.user_id === r.doctor_id)
                    ?.display_name
                }
              </td>
              <td>{formatDate(r.starts_at, true)}</td>
              <td>{formatDate(r.ends_at, true)}</td>
              <td>{t(r.ended ? "Ended" : str(r, "kind"))}</td>
              <td>
                {!r.ended && (
                  <button
                    className="text-button"
                    onClick={() =>
                      setAction({
                        title: "End availability window",
                        kind: "availability.end",
                        fixed: { id: r.id },
                        fields: [text("reason", "Reason")],
                      })
                    }
                  >
                    {t("End availability window")}
                  </button>
                )}
              </td>
            </tr>
          ))}
        </DataTable>
      </details>
      <details className="panel">
        <summary>{t("Rooms and devices")}</summary>
        <RecordPager page={resources} t={t} />
        <DataTable heads={["Title", "Category"].map(t)}>
          {resources.items.map((r) => (
            <tr key={r.id}>
              <td>{str(r, "name")}</td>
              <td>{t(str(r, "kind"))}</td>
            </tr>
          ))}
        </DataTable>
      </details>
    </>
  );
}
export function PerformedCharges({ data, t, locale, setAction }: Props) {
  const page = useRecordPage("performed_services", data);
  return (
    <section className="panel">
      <div className="panel-head">
        <h2>{t("Performed treatments")}</h2>
      </div>
      <RecordPager page={page} t={t} />
      <DataTable
        heads={["Patient", "Service", "Quantity", "Status", "Action"].map(t)}
      >
        {page.items.map((r) => (
          <tr key={r.id}>
            <td>{str(r, "patient_name")}</td>
            <td>
              {(data.services.find((s) => s.id === r.service_id)
                ?.name as string) ?? "—"}
            </td>
            <td>{str(r, "quantity")}</td>
            <td>{t(r.invoice_id ? "Invoiced" : "Unbilled")}</td>
            <td>
              {!r.invoice_id && (
                <button
                  className="button secondary"
                  onClick={() =>
                    setAction({
                      title: "Invoice performed treatment",
                      kind: "performed.invoice",
                      fixed: { id: r.id },
                      fields: [],
                    })
                  }
                >
                  {t("New invoice")}
                </button>
              )}
            </td>
          </tr>
        ))}
      </DataTable>
      <span className="panel-hint">
        {t("Separate balances for IQD and USD.")} ·{" "}
        {locale === "ckb" ? "کوردی" : "English"}
      </span>
    </section>
  );
}
export function PatientTools({
  data,
  t,
  locale,
  setAction,
  patient,
  record,
  section,
}: Props & {
  patient: Patient;
  record: { encounters: Row[]; procedures: Row[]; facts?: Row[] } | null;
  section: string;
}) {
  const clinical = data.permissions.includes("clinical"),
    logs = useRecordPage("contact_log", data, patient.id),
    consents = useRecordPage("consents", clinical ? data : null, patient.id);
  const [contacts, setContacts] = useState<Row[]>([]),
    [error, setError] = useState("");
  useEffect(() => {
    let cancelled = false;
    setContacts([]);
    setError("");
    void client()
      .rpc("patient_contacts", { patient_id: patient.id })
      .then(({ data, error }) => {
        if (cancelled) return;
        if (error) setError(error.message);
        else setContacts(data);
      });
    return () => {
      cancelled = true;
    };
  }, [patient.id, data]);
  const recordData = { ...data, encounters: record?.encounters ?? [] };
  const printHeader = (row: Row) => documentIdentity(row, patient, t);
  return (
    <>
      {section === "access" && (
        <>
          <div className="action-bar">
            <PatientExport patient={patient} data={data} t={t} />
            {data.membership.role === "owner" && (
              <button
                className="button secondary"
                onClick={() =>
                  setAction({
                    title: "Place legal hold",
                    kind: "retention.hold",
                    fixed: { patient_id: patient.id },
                    fields: [text("reason", "Hold authorization")],
                  })
                }
              >
                {t("Place legal hold")}
              </button>
            )}
          </div>
          <CareTeam
            patientId={patient.id}
            data={data}
            t={t}
            setAction={setAction}
          />
        </>
      )}
      {clinical && section === "documents" && (
        <PatientDocuments
          data={data}
          patient={patient}
          t={t}
          locale={locale}
          setAction={setAction}
        />
      )}
      {section === "contacts" && (
        <>
          <section className="panel">
            <div className="panel-head">
              <h2>{t("Contacts")}</h2>
              <button
                className="button secondary"
                onClick={() =>
                  setAction({
                    title: "Add contact",
                    kind: "contact.add",
                    fixed: { patient_id: patient.id },
                    fields: [
                      { ...text("phone", "Phone number"), type: "tel" },
                      text("owner_name", "Contact owner"),
                      text("relationship", "Relationship", false),
                      {
                        name: "preferred",
                        label: "Preferred",
                        type: "checkbox",
                      },
                      { name: "verified", label: "Verified", type: "checkbox" },
                    ],
                  })
                }
              >
                {t("Add contact")}
              </button>
            </div>
            {error && <ErrorMessage error={error} />}
            <DataTable
              heads={[
                "Phone number",
                "Contact owner",
                "Relationship",
                "Status",
                "Action",
              ].map(t)}
            >
              {contacts.map((c) => (
                <tr key={c.id}>
                  <td dir="ltr">{str(c, "phone")}</td>
                  <td>{str(c, "owner_name")}</td>
                  <td>{str(c, "relationship")}</td>
                  <td>
                    {t(c.valid_to ? "Historical" : "Active")}
                    {c.preferred ? " · " + t("Preferred") : ""}
                  </td>
                  <td>
                    {!c.valid_to && (
                      <button
                        className="text-button"
                        onClick={() =>
                          setAction({
                            title: "End contact",
                            kind: "contact.end",
                            fixed: { id: c.id, patient_id: patient.id },
                            fields: [],
                          })
                        }
                      >
                        {t("End contact")}
                      </button>
                    )}
                  </td>
                </tr>
              ))}
            </DataTable>
          </section>
          <section className="panel">
            <div className="panel-head">
              <h2>{t("Contact log")}</h2>
              <button
                className="button secondary"
                onClick={() =>
                  setAction({
                    title: "Record contact",
                    kind: "contact.log",
                    fixed: { patient_id: patient.id },
                    fields: [
                      choice("channel", "Channel", [
                        "phone",
                        "in_person",
                        "sms",
                        "whatsapp",
                        "other",
                      ]),
                      text("purpose", "Purpose"),
                      choice("outcome", "Outcome", [
                        "reached",
                        "no_answer",
                        "declined",
                        "scheduled",
                        "other",
                      ]),
                      area("notes", "Notes"),
                    ],
                  })
                }
              >
                {t("Record contact")}
              </button>
            </div>
            <RecordPager page={logs} t={t} />
            <DataTable
              heads={["Date", "Channel", "Purpose", "Outcome", "Notes"].map(t)}
            >
              {logs.items.map((c) => (
                <tr key={c.id}>
                  <td>{formatDate(c.created_at, true, locale)}</td>
                  <td>{t(str(c, "channel"))}</td>
                  <td>
                    {c.purpose === "appointment_reminder"
                      ? t("Appointment reminder")
                      : str(c, "purpose")}
                  </td>
                  <td>{t(str(c, "outcome"))}</td>
                  <td dir="auto">{str(c, "notes")}</td>
                </tr>
              ))}
            </DataTable>
          </section>
        </>
      )}
      {clinical && section === "history" && (
        <>
          <section className="panel">
            <div className="panel-head">
              <h2>{t("Longitudinal clinical history")}</h2>
              <button
                className="button secondary"
                onClick={() =>
                  setAction({
                    title: "Record clinical fact",
                    kind: "fact.record",
                    fixed: { patient_id: patient.id },
                    fields: [
                      choice("kind", "Category", [
                        "allergy",
                        "problem",
                        "medication",
                        "history",
                      ]),
                      area("content", "Content"),
                      choice(
                        "status",
                        "Status",
                        ["active", "resolved", "entered_in_error"],
                        "active",
                      ),
                    ],
                  })
                }
              >
                {t("Record clinical fact")}
              </button>
            </div>
            {record?.facts?.map((f) => (
              <article className="encounter" key={f.id}>
                <strong>
                  {t(str(f, "kind"))} · {t(str(f, "status"))}
                </strong>
                <p dir="auto">{str(f, "content")}</p>
                <button
                  className="text-button"
                  onClick={() =>
                    setAction({
                      title: "Amend clinical fact",
                      kind: "fact.record",
                      fixed: {
                        patient_id: patient.id,
                        kind: f.kind,
                        supersedes_id: f.id,
                      },
                      fields: [
                        area("content", "Content", true, f.content),
                        choice(
                          "status",
                          "Status",
                          ["active", "resolved", "entered_in_error"],
                          String(f.status),
                        ),
                      ],
                    })
                  }
                >
                  {t("Amend clinical fact")}
                </button>
              </article>
            ))}
          </section>
          <section className="panel">
            <div className="panel-head">
              <h2>{t("Prescriptions and performed treatments")}</h2>
            </div>
            <div className="action-bar">
              <button
                className="button secondary"
                onClick={() =>
                  setAction({
                    title: "Add prescription item",
                    kind: "prescription.add",
                    fixed: { patient_id: patient.id },
                    fields: [
                      encounter(
                        {
                          ...recordData,
                          encounters: recordData.encounters.filter(
                            (e) =>
                              e.status === "draft" &&
                              e.doctor_id === data.membership.user_id,
                          ),
                        },
                        patient.id,
                        "draft",
                        true,
                      ),
                      text("medicine", "Medicine"),
                      text("strength", "Strength", false),
                      text("dose", "Dose"),
                      text("route", "Route"),
                      text("frequency", "Frequency"),
                      text("duration", "Duration"),
                      text("quantity", "Quantity", false),
                      area("instructions", "Instructions", false),
                    ],
                  })
                }
              >
                {t("Add prescription item")}
              </button>
              <button
                className="button secondary"
                onClick={() =>
                  setAction({
                    title: "Record performed treatment",
                    kind: "performed.record",
                    fixed: { patient_id: patient.id },
                    fields: [
                      encounter(
                        {
                          ...recordData,
                          encounters: recordData.encounters.filter(
                            (e) => e.status === "signed",
                          ),
                        },
                        patient.id,
                        "signed",
                      ),
                      {
                        name: "service_id",
                        label: "Service",
                        required: true,
                        options: options(data.services, "name"),
                      },
                      {
                        ...number("quantity", "Quantity", 1),
                        step: "1",
                        min: "1",
                      },
                    ],
                  })
                }
              >
                {t("Record performed treatment")}
              </button>
            </div>
            {recordData.encounters.map((e) => {
              const meds = (e.prescription_items ?? []) as Row[];
              return (
                <article className="encounter" key={e.id}>
                  <h3>
                    {str(e, "chief_complaint")} · {t(str(e, "status"))}
                  </h3>
                  {meds.map((m) => (
                    <p key={m.id} dir="auto">
                      {m.medicine as string} {m.strength as string} ·{" "}
                      {m.dose as string} · {m.route as string} ·{" "}
                      {m.frequency as string} · {m.duration as string} ·{" "}
                      {m.instructions as string}
                    </p>
                  ))}
                  {e.status === "signed" &&
                    (meds.length > 0 || Boolean(e.prescriptions)) && (
                      <button
                        className="button secondary"
                        onClick={() =>
                          printDocument(
                            `${data.organization.name} · ${t("Prescription")}`,
                            [
                              ...printHeader(e),
                              `${t("Date")}: ${formatDate(e.signed_at, true, locale)}`,
                              `${t("Clinician")}: ${(e.identity_snapshot as Row | undefined)?.clinician_name ?? data.members.find((m) => m.user_id === e.doctor_id)?.display_name ?? "—"}`,
                              ...meds.map(
                                (m) =>
                                  `${m.medicine} ${m.strength}\n${t("Dose")}: ${m.dose}\n${t("Route")}: ${m.route} · ${t("Frequency")}: ${m.frequency} · ${t("Duration")}: ${m.duration}\n${t("Quantity")}: ${m.quantity}\n${m.instructions}`,
                              ),
                              String(e.prescriptions ?? ""),
                            ],
                            locale,
                          )
                        }
                      >
                        {t("Print prescription")}
                      </button>
                    )}
                </article>
              );
            })}
          </section>
        </>
      )}
      {clinical && section === "documents" && (
        <>
          <section className="panel">
            <div className="panel-head">
              <h2>{t("Procedure and aftercare documents")}</h2>
            </div>
            {record?.procedures.map((p) => (
              <article className="encounter" key={p.id}>
                <h3>
                  {str(p, "name")} · {str(p, "body_site")}
                </h3>
                <p dir="auto">{str(p, "aftercare")}</p>
                <button
                  className="button secondary"
                  onClick={() =>
                    printDocument(
                      `${data.organization.name} · ${t("Aftercare")}`,
                      [
                        ...printHeader(p),
                        `${t("Procedure")}: ${p.name}`,
                        `${t("Date")}: ${formatDate(p.created_at, true, locale)}`,
                        String(p.aftercare),
                      ],
                      locale,
                    )
                  }
                >
                  {t("Print aftercare")}
                </button>
              </article>
            ))}
          </section>
          <section className="panel">
            <div className="panel-head">
              <h2>{t("Consent history")}</h2>
            </div>
            <RecordPager page={consents} t={t} />
            {consents.items.map((c) => (
              <article className="encounter" key={c.id}>
                <h3>
                  {t(str(c, "purpose"))} ·{" "}
                  {t(c.granted ? "Granted" : "Withdrawn")}
                </h3>
                <p dir="auto">{str(c, "evidence")}</p>
                <button
                  className="text-button"
                  onClick={() =>
                    printDocument(
                      `${data.organization.name} · ${t("Consent")}`,
                      [
                        ...printHeader(c),
                        `${t("Purpose")}: ${t(str(c, "purpose"))}`,
                        `${t("Status")}: ${t(c.granted ? "Granted" : "Withdrawn")}`,
                        `${t("Date")}: ${formatDate(c.created_at, true, locale)}`,
                        `${t("Version")}: ${c.template_version}`,
                        String(
                          (c.template_snapshot as Row | undefined)?.content ??
                            "",
                        ),
                        String(c.evidence),
                      ],
                      locale,
                    )
                  }
                >
                  {t("Print")}
                </button>
              </article>
            ))}
          </section>
        </>
      )}
    </>
  );
}
export function StockActions({
  row,
  t,
  setAction,
}: {
  row: Row;
  t: T;
  setAction: (action: Action) => void;
}) {
  return (
    <button
      className="text-button"
      onClick={() =>
        setAction({
          title: "Record stock count or waste",
          kind: "stock.adjust",
          fixed: { id: row.id, version: row.version },
          fields: [
            { ...number("counted", "Counted quantity"), min: "0" },
            area("reason", "Reason"),
          ],
        })
      }
    >
      {t("Count / adjust stock")}
    </button>
  );
}
export function PackageActions({
  row,
  t,
  setAction,
}: {
  row: Row;
  t: T;
  setAction: (action: Action) => void;
}) {
  return row.cancelled_at ? (
    <span>{t("Cancelled")}</span>
  ) : (
    <div className="inline-actions">
      <button
        className="text-button"
        onClick={() =>
          setAction({
            title: "Set package expiry",
            kind: "package.expiry",
            fixed: { id: row.id },
            fields: [
              date("expires_on", "Expiry date"),
              area("reason", "Reason"),
            ],
          })
        }
      >
        {t("Set package expiry")}
      </button>
      <button
        className="text-button danger"
        onClick={() =>
          setAction({
            title: "Cancel and refund unused sessions",
            kind: "package.cancel",
            fixed: { id: row.id },
            fields: [area("reason", "Reason")],
          })
        }
      >
        {t("Cancel and refund unused sessions")}
      </button>
    </div>
  );
}

function PatientDocuments({
  data,
  patient,
  t,
  locale,
  setAction,
}: Props & { patient: Patient }) {
  const page = useRecordPage("patient_documents", data, patient.id);
  return (
    <section className="panel">
      <div className="panel-head">
        <h2>{t("Signed patient documents")}</h2>
        <button
          className="button secondary"
          onClick={() =>
            setAction({
              title: "Sign patient document",
              kind: "document.create",
              fixed: { patient_id: patient.id, kind: "care_letter" },
              instructions:
                "Review the patient-specific details before signing this document.",
              fields: [
                text("title", "Title"),
                area("body", "Document content"),
              ],
            })
          }
        >
          {t("New patient letter")}
        </button>
      </div>
      <RecordPager page={page} t={t} />
      {page.items.map((row) => (
        <article className="encounter" key={row.id}>
          <h3>
            {str(row, "title")} · {formatDate(row.signed_at, true, locale)}
          </h3>
          <p dir="auto" style={{ whiteSpace: "pre-wrap" }}>
            {str(row, "body")}
          </p>
          {Boolean(row.supersedes_id) && (
            <p>
              {t("Corrected document")} · <bdi>{str(row, "supersedes_id")}</bdi>
            </p>
          )}
          <div className="action-bar">
            <button
              className="button secondary"
              onClick={() =>
                printDocument(
                  `${data.organization.name} · ${row.title}`,
                  [
                    ...documentIdentity(row, patient, t),
                    `${t("Clinician")}: ${(row.identity_snapshot as Row | undefined)?.clinician_name ?? data.members.find((m) => m.user_id === row.signed_by)?.display_name ?? "—"}`,
                    `${t("Signed")}: ${formatDate(row.signed_at, true, locale)}`,
                    String(row.body),
                    ...(row.correction_reason
                      ? [`${t("Correction reason")}: ${row.correction_reason}`]
                      : []),
                  ],
                  locale,
                )
              }
            >
              {t("Print")}
            </button>
            <button
              className="text-button"
              onClick={() =>
                setAction({
                  title: "Sign corrected patient document",
                  kind: "document.create",
                  fixed: {
                    patient_id: patient.id,
                    kind: row.kind,
                    supersedes_id: row.id,
                  },
                  fields: [
                    text("title", "Title", true, row.title),
                    area("body", "Document content", true, row.body),
                    text("correction_reason", "Correction reason"),
                  ],
                })
              }
            >
              {t("Add corrected document")}
            </button>
          </div>
        </article>
      ))}
    </section>
  );
}

function documentIdentity(row: Row, patient: Patient, t: T) {
  const identity = row.identity_snapshot as Row | undefined;
  return [
    `${t(identity?.full_name ? "Patient" : "Current patient identity")}: ${identity?.full_name ?? patient.full_name}`,
    `${t("Patient number")}: ${identity?.patient_number ?? patient.patient_number}`,
  ];
}
