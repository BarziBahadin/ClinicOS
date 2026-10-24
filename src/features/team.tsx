import { useState } from "react";
import type { Snapshot } from "../domain/types";
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
  const [open, setOpen] = useState(false),
    [error, setError] = useState(""),
    [busy, setBusy] = useState(false);
  return (
    <>
      <div className="action-bar">
        <button className="button primary" onClick={() => setOpen(true)}>
          <Plus size={17} />
          {t("Invite staff")}
        </button>
      </div>
      <section className="panel">
        <DataTable heads={["Full name", "Role", "Status", "Action"].map(t)}>
          {data.members.map((m) => (
            <tr key={m.id}>
              <td>{m.display_name}</td>
              <td>{t(m.role.charAt(0).toUpperCase() + m.role.slice(1))}</td>
              <td>{m.active ? t("Active") : "Inactive"}</td>
              <td>
                {m.user_id !== data.membership.user_id && (
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
                              "owner",
                              "administrator",
                              "doctor",
                              "receptionist",
                              "accountant",
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
                )}
              </td>
            </tr>
          ))}
        </DataTable>
      </section>
      {open && (
        <Dialog
          title={t("Invite staff")}
          onClose={() => !busy && setOpen(false)}
        >
          <form
            onSubmit={async (e) => {
              e.preventDefault();
              setBusy(true);
              setError("");
              const f = new FormData(e.currentTarget);
              try {
                await invoke("staff-admin", {
                  action: "invite",
                  email: f.get("email"),
                  display_name: f.get("display_name"),
                  role: f.get("role"),
                });
                await onSaved();
                setOpen(false);
              } catch (e) {
                setError(e instanceof Error ? e.message : "Invitation failed");
              } finally {
                setBusy(false);
              }
            }}
          >
            <div className="dialog-body form-grid">
              <InputField
                t={t}
                field={{
                  name: "email",
                  label: "Email",
                  type: "email",
                  required: true,
                }}
              />
              <InputField t={t} field={text("display_name", "Full name")} />
              <InputField
                t={t}
                field={choice("role", "Role", [
                  "doctor",
                  "receptionist",
                  "administrator",
                  "accountant",
                ])}
              />
              {error && <ErrorMessage error={error} />}
            </div>
            <footer className="dialog-footer">
              <button className="button primary" disabled={busy}>
                {t("Invite staff")}
              </button>
            </footer>
          </form>
        </Dialog>
      )}
    </>
  );
}
