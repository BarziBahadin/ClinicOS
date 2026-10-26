import { useRequestScope } from "../lib/request-scope";
import { useRef, useState } from "react";
import type { Membership, Snapshot } from "../domain/types";
import {
  DataTable,
  Dialog,
  ErrorMessage,
  InputField,
  type T,
  type Action,
} from "../components/ui";
import { choice, text } from "./actions";
import { Plus } from "lucide-react";
import { invoke } from "../lib/functions";
import { MemberAccessActions } from "./access";
export function Team({
  data,
  t,
  onSaved,
  setAction,
}: {
  data: Snapshot;
  t: T;
  onSaved: () => Promise<void>;
  setAction: (a: Action) => void;
}) {
  const requestScope = useRequestScope();
  const [open, setOpen] = useState(false),
    [target, setTarget] = useState<Membership | null>(null),
    [error, setError] = useState(""),
    [busy, setBusy] = useState(false);
  const attempt = useRef<{ fingerprint: string; id: string } | null>(null);
  const isOwner = data.membership.role === "owner";
  const canManage = (m: Membership) =>
    m.user_id !== data.membership.user_id &&
    m.role !== "owner" &&
    (isOwner || !["administrator", "accountant"].includes(m.role));
  return (
    <>
      <div className="action-bar">
        <button
          className="button primary"
          onClick={() => {
            setTarget(null);
            setError("");
            setOpen(true);
            attempt.current = null;
          }}
        >
          <Plus size={17} />
          {t("Create staff account")}
        </button>
      </div>
      <section className="panel">
        <DataTable
          heads={["Full name", "Username", "Role", "Status", "Action"].map(t)}
        >
          {data.members.map((m) => (
            <tr key={m.id}>
              <td>{m.display_name}</td>
              <td dir="ltr">{m.username ?? "—"}</td>
              <td>
                {t(m.role.charAt(0).toUpperCase() + m.role.slice(1))}
                {m.additional_roles?.map((role) => (
                  <p key={role}>{t(role)}</p>
                ))}
              </td>
              <td>{t(m.active ? "Active" : "Inactive")}</td>
              <td>
                {(isOwner || canManage(m)) &&
                  m.user_id !== data.membership.user_id &&
                  m.role !== "owner" && (
                    <details className="row-actions">
                      <summary>{t("Manage account")}</summary>
                      <div className="row-actions-body">
                        <MemberAccessActions
                          member={m}
                          data={data}
                          t={t}
                          setAction={setAction}
                        />
                        {canManage(m) && (
                          <div className="inline-actions">
                            <button
                              className="text-button"
                              onClick={() =>
                                setAction({
                                  title: "Team & access",
                                  kind: "member.update",
                                  fixed: { user_id: m.user_id },
                                  fields: [
                                    choice(
                                      "role",
                                      "Role",
                                      [
                                        "doctor",
                                        "receptionist",
                                        ...(isOwner
                                          ? ["administrator", "accountant"]
                                          : []),
                                      ],
                                      m.role,
                                    ),
                                    {
                                      name: "active",
                                      label: "Active",
                                      type: "checkbox",
                                      value: m.active,
                                    },
                                  ],
                                })
                              }
                            >
                              {t("Edit profile")}
                            </button>
                            {m.username && (
                              <button
                                className="text-button"
                                onClick={() => {
                                  setTarget(m);
                                  setError("");
                                  setOpen(true);
                                }}
                              >
                                {t("Reset password")}
                              </button>
                            )}
                          </div>
                        )}
                      </div>
                    </details>
                  )}
              </td>
            </tr>
          ))}
        </DataTable>
      </section>
      {open && (
        <Dialog
          busy={busy}
          title={t(target ? "Reset password" : "Create staff account")}
          onClose={() => !busy && setOpen(false)}
        >
          <form
            onSubmit={async (e) => {
              e.preventDefault();
              const isCurrent = requestScope();
              const form = e.currentTarget;
              const f = new FormData(form);
              setBusy(true);
              setError("");
              const payload = target
                ? {
                    action: "reset_password",
                    user_id: target.user_id,
                    password: String(f.get("password")),
                  }
                : {
                    action: "create",
                    username: String(f.get("username")),
                    display_name: String(f.get("display_name")),
                    role: String(f.get("role")),
                    password: String(f.get("password")),
                  };
              const fingerprint = JSON.stringify(payload);
              if (attempt.current?.fingerprint !== fingerprint)
                attempt.current = { fingerprint, id: crypto.randomUUID() };
              try {
                await invoke("staff-admin", {
                  ...payload,
                  request_id: attempt.current.id,
                });
                if (!isCurrent()) return;
                form.reset();
                attempt.current = null;
                await onSaved();
                if (isCurrent()) setOpen(false);
              } catch (e) {
                if (!isCurrent()) return;
                setError(
                  e instanceof Error ? e.message : "Account operation failed",
                );
              } finally {
                if (isCurrent()) setBusy(false);
              }
            }}
          >
            <div className="dialog-body form-grid">
              {target ? (
                <p>
                  {target.display_name} · <bdi dir="ltr">{target.username}</bdi>
                </p>
              ) : (
                <>
                  <InputField
                    t={t}
                    field={{
                      ...text("username", "Username"),
                      help: "Use 3–32 letters, numbers, dots, hyphens or underscores, starting with a letter.",
                    }}
                  />
                  <InputField t={t} field={text("display_name", "Full name")} />
                  <InputField
                    t={t}
                    field={choice("role", "Role", [
                      "doctor",
                      "receptionist",
                      ...(isOwner ? ["administrator", "accountant"] : []),
                    ])}
                  />
                </>
              )}
              <label className="field">
                <span>{t("Temporary password")}</span>
                <input
                  name="password"
                  type="password"
                  required
                  minLength={16}
                  maxLength={128}
                  autoComplete="new-password"
                />
              </label>
              <p>
                {t(
                  "Give the username and temporary password to this staff member in person. They must change the password at first sign-in.",
                )}
              </p>
              {error && <ErrorMessage error={error} />}
            </div>
            <footer className="dialog-footer">
              <button className="button primary" disabled={busy}>
                {t(
                  busy
                    ? "Saving…"
                    : target
                      ? "Reset password"
                      : "Create staff account",
                )}
              </button>
            </footer>
          </form>
        </Dialog>
      )}
    </>
  );
}
