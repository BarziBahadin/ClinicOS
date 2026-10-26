import { useEffect, useLayoutEffect, useRef, useState } from "react";
import type {
  Membership,
  Patient,
  Snapshot,
  Locale,
  Row,
} from "../domain/types";
import {
  DataTable,
  Dialog,
  ErrorMessage,
  options,
  type Action,
  type T,
} from "../components/ui";
import { choice, currency, number, text } from "./actions";
import { client } from "../lib/supabase";
import { hasRole } from "../domain/staff";
import { downloadFile } from "../lib/download";
import { formatDate, str } from "../lib/format";
export function MemberAccessActions({
  member,
  data,
  t,
  setAction,
}: {
  member: Membership;
  data: Snapshot;
  t: T;
  setAction: (a: Action) => void;
}) {
  if (
    data.membership.role !== "owner" ||
    member.user_id === data.membership.user_id ||
    member.role === "owner"
  )
    return null;
  return (
    <>
      <button
        className="text-button"
        onClick={() =>
          setAction({
            title: "Grant an additional role",
            kind: "access.role.grant",
            fixed: { user_id: member.user_id },
            fields: [
              choice(
                "role",
                "Additional role",
                ["doctor", "receptionist", "accountant"].filter(
                  (role) =>
                    role !== member.role &&
                    !member.additional_roles?.includes(role as never),
                ),
              ),
              text("reason", "Authorization evidence"),
            ],
          })
        }
      >
        {t("Grant an additional role")}
      </button>
      {member.additional_roles?.map((role) => (
        <button
          key={role}
          className="text-button"
          onClick={() =>
            setAction({
              title: "Revoke additional role",
              kind: "access.role.revoke",
              fixed: { user_id: member.user_id, role },
              fields: [text("reason", "Reason")],
            })
          }
        >
          {t("Revoke")} · {t(role)}
        </button>
      ))}
      <button
        className="text-button"
        onClick={() =>
          setAction({
            title: "Set approval limit",
            kind: "access.limit.set",
            fixed: { user_id: member.user_id },
            fields: [
              currency(),
              { ...number("max_amount", "Maximum approval amount"), min: "0" },
              text("reason", "Authorization evidence"),
            ],
          })
        }
      >
        {t("Set approval limit")}
      </button>
    </>
  );
}
export function CareTeam({
  patientId,
  data,
  t,
  setAction,
}: {
  patientId: string;
  data: Snapshot;
  t: T;
  setAction: (a: Action) => void;
}) {
  const [rows, setRows] = useState<Row[]>([]),
    [error, setError] = useState("");
  const enabled = data.permissions.includes("staff");
  useLayoutEffect(() => {
    setRows([]);
    setError("");
  }, [patientId, enabled]);
  useEffect(() => {
    if (!enabled) return;
    let cancelled = false;
    void client()
      .rpc("care_team", { patient_id: patientId })
      .then(({ data, error }) => {
        if (cancelled) return;
        if (error) setError(error.message);
        else setRows(data);
      });
    return () => {
      cancelled = true;
    };
  }, [patientId, data, enabled]);
  if (!enabled) return null;
  return (
    <section className="panel">
      <div className="panel-head">
        <h2>{t("Assigned care team")}</h2>
        <button
          className="button secondary"
          onClick={() =>
            setAction({
              title: "Assign clinician",
              kind: "care.assign",
              fixed: { patient_id: patientId },
              fields: [
                {
                  name: "user_id",
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
                text("reason", "Assignment reason"),
              ],
            })
          }
        >
          {t("Assign clinician")}
        </button>
      </div>
      {error && <ErrorMessage error={error} />}
      <DataTable heads={["Clinician", "Reason", "Action"].map(t)}>
        {rows.map((row) => (
          <tr key={row.id}>
            <td>{str(row, "display_name")}</td>
            <td dir="auto">{str(row, "reason")}</td>
            <td>
              <button
                className="text-button"
                onClick={() =>
                  setAction({
                    title: "End care assignment",
                    kind: "care.revoke",
                    fixed: { id: row.id },
                    fields: [text("reason", "Reason")],
                  })
                }
              >
                {t("End care assignment")}
              </button>
            </td>
          </tr>
        ))}
      </DataTable>
    </section>
  );
}
export function ClinicalSharing({
  data,
  t,
  setAction,
}: {
  data: Snapshot;
  t: T;
  setAction: (a: Action) => void;
}) {
  return (
    <section className="panel">
      <div className="panel-head">
        <h2>{t("Clinical access scope")}</h2>
        <span>
          {t(
            data.organization.clinical_access_scope === "assigned"
              ? "Assigned care team"
              : "All clinic clinicians",
          )}
        </span>
        {data.membership.role === "owner" && (
          <button
            className="button secondary"
            onClick={() =>
              setAction({
                title: "Change clinical access scope",
                kind: "care.scope.set",
                fields: [
                  {
                    name: "scope",
                    label: "Clinical access scope",
                    required: true,
                    options: [
                      { value: "organization", label: "All clinic clinicians" },
                      { value: "assigned", label: "Assigned care team" },
                    ],
                    value: data.organization.clinical_access_scope,
                  },
                  text("reason", "Authorization evidence"),
                ],
              })
            }
          >
            {t("Change clinical access scope")}
          </button>
        )}
      </div>
      <p className="panel-hint">
        {t(
          "Assign clinicians to patients before enabling assigned-care access. Business roles do not receive clinical access automatically.",
        )}
      </p>
    </section>
  );
}
export function Retention({
  data,
  t,
  locale,
  setAction,
}: {
  data: Snapshot;
  t: T;
  locale: Locale;
  setAction: (a: Action) => void;
}) {
  const [rules, setRules] = useState<Row[]>([]),
    [holds, setHolds] = useState<Row[]>([]),
    [error, setError] = useState("");
  useEffect(() => {
    let cancelled = false;
    void client()
      .rpc("retention_state")
      .then(({ data, error }) => {
        if (cancelled) return;
        if (error) setError(error.message);
        else {
          setRules(data.rules);
          setHolds(data.holds);
        }
      });
    return () => {
      cancelled = true;
    };
  }, [data]);
  const owner = data.membership.role === "owner";
  return (
    <>
      <section className="panel">
        <div className="panel-head">
          <h2>{t("Retention policies")}</h2>
          {owner && (
            <button
              className="button secondary"
              onClick={() =>
                setAction({
                  title: "Record retention policy",
                  kind: "retention.rule.create",
                  fields: [
                    choice("record_type", "Record type", [
                      "clinical",
                      "media",
                      "finance",
                      "audit",
                      "contact",
                    ]),
                    {
                      ...number("retain_days", "Retention days"),
                      min: "1",
                      step: "1",
                    },
                    text("policy_reference", "Approved policy reference"),
                    text("reason", "Reason"),
                  ],
                })
              }
            >
              {t("Record retention policy")}
            </button>
          )}
        </div>
        <p className="panel-hint">
          {t(
            "Policies and legal holds are recorded here. Automatic deletion is disabled until an approved deletion and backup-expiry procedure is configured.",
          )}
        </p>
        {error && <ErrorMessage error={error} />}
        <DataTable
          heads={[
            "Record type",
            "Retention days",
            "Policy reference",
            "Status",
            "Action",
          ].map(t)}
        >
          {rules.map((row) => (
            <tr key={row.id}>
              <td>{t(str(row, "record_type"))}</td>
              <td>{str(row, "retain_days")}</td>
              <td>{str(row, "policy_reference")}</td>
              <td>{t(row.approved_at ? "Approved" : "Draft")}</td>
              <td>
                {owner && !row.approved_at && (
                  <button
                    className="text-button"
                    onClick={() =>
                      setAction({
                        title: "Approve retention policy",
                        kind: "retention.rule.approve",
                        fixed: { id: row.id },
                        fields: [text("reason", "Approval evidence")],
                      })
                    }
                  >
                    {t("Approve")}
                  </button>
                )}
              </td>
            </tr>
          ))}
        </DataTable>
      </section>
      <section className="panel">
        <div className="panel-head">
          <h2>{t("Legal holds")}</h2>
        </div>
        <DataTable
          heads={["Patient account", "Date", "Reason", "Status", "Action"].map(
            t,
          )}
        >
          {holds.map((row) => (
            <tr key={row.id}>
              <td>
                <bdi>{str(row, "patient_id")}</bdi>
              </td>
              <td>{formatDate(row.created_at, false, locale)}</td>
              <td dir="auto">{str(row, "reason")}</td>
              <td>{t(row.released ? "Released" : "Active")}</td>
              <td>
                {owner && !row.released && (
                  <button
                    className="text-button"
                    onClick={() =>
                      setAction({
                        title: "Release legal hold",
                        kind: "retention.release",
                        fixed: { id: row.id },
                        fields: [text("reason", "Release authorization")],
                      })
                    }
                  >
                    {t("Release hold")}
                  </button>
                )}
              </td>
            </tr>
          ))}
        </DataTable>
      </section>
    </>
  );
}
export function PatientExport({
  patient,
  data,
  t,
}: {
  patient: Patient;
  data: Snapshot;
  t: T;
}) {
  const [open, setOpen] = useState(false),
    [error, setError] = useState(""),
    [busy, setBusy] = useState(false);
  const generation = useRef(0);
  useLayoutEffect(() => {
    generation.current++;
    return () => {
      generation.current++;
    };
  }, [patient.id, data.membership.user_id]);
  if (!data.permissions.includes("clinical.export")) return null;
  return (
    <>
      <button className="button secondary" onClick={() => setOpen(true)}>
        {t("Export clinical record")}
      </button>
      {open && (
        <Dialog
          title={t("Export clinical record")}
          onClose={() => !busy && setOpen(false)}
        >
          <form
            onSubmit={async (e) => {
              e.preventDefault();
              setBusy(true);
              setError("");
              const sequence = generation.current;
              try {
                const purpose = String(
                  new FormData(e.currentTarget).get("reason"),
                );
                const result = await client().rpc("patient_export", {
                  patient_id: patient.id,
                  reason: purpose,
                });
                if (sequence !== generation.current) return;
                if (result.error) throw result.error;
                downloadFile(
                  `clinicos-${patient.patient_number}-clinical-record.json`,
                  JSON.stringify(result.data, null, 2),
                  "application/json",
                );
                setOpen(false);
              } catch (e) {
                if (sequence === generation.current)
                  setError(e instanceof Error ? e.message : "Export failed");
              } finally {
                if (sequence === generation.current) setBusy(false);
              }
            }}
          >
            <div className="dialog-body">
              <p>
                {t(
                  "This export contains clinical text, prescriptions, results and document metadata. Original photographs are accessed separately through the clinical media viewer.",
                )}
              </p>
              <label className="field">
                <span>{t("Export purpose")}</span>
                <textarea
                  name="reason"
                  required
                  minLength={10}
                  maxLength={2000}
                />
              </label>
              {error && <ErrorMessage error={error} />}
            </div>
            <footer className="dialog-footer">
              <button className="button primary" disabled={busy}>
                {t("Export clinical record")}
              </button>
            </footer>
          </form>
        </Dialog>
      )}
    </>
  );
}
