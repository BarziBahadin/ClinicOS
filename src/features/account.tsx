import { useRequestScope } from "../lib/request-scope";
import { useState } from "react";
import { invoke } from "../lib/functions";
import { client } from "../lib/supabase";
import { ErrorMessage, type T } from "../components/ui";
import { MfaPanel } from "./security";
export function AccountPanel({
  t,
  onVerified,
  required = false,
  onPasswordChanged,
}: {
  t: T;
  onVerified: () => Promise<void>;
  required?: boolean;
  onPasswordChanged?: () => void;
}) {
  const requestScope = useRequestScope();
  const [error, setError] = useState(""),
    [message, setMessage] = useState(""),
    [busy, setBusy] = useState(false);
  return (
    <section className="panel">
      <div className="panel-head">
        <h2>{t("Account & security")}</h2>
      </div>
      {required && (
        <p role="status">
          {t("Change your temporary password before opening clinic records.")}
        </p>
      )}
      <form
        className="account-form"
        onSubmit={async (e) => {
          e.preventDefault();
          const isCurrent = requestScope();
          const form = e.currentTarget;
          const f = new FormData(form);
          const password = String(f.get("password"));
          if (password !== f.get("confirmation")) {
            setError(t("Passwords do not match"));
            return;
          }
          setBusy(true);
          setError("");
          try {
            await invoke("staff-admin", {
              action: "change_password",
              current_password: f.get("current_password"),
              password,
            });
            if (!isCurrent()) return;
            form.reset();
            setMessage(t("Password updated. Sign in with your new password."));
            onPasswordChanged?.();
            await client().auth.signOut({ scope: "local" });
          } catch (e) {
            if (!isCurrent()) return;
            setError(
              e instanceof Error ? e.message : "Unable to update password",
            );
          } finally {
            if (isCurrent()) setBusy(false);
          }
        }}
      >
        <label className="field">
          <span>{t("Current password")}</span>
          <input
            type="password"
            name="current_password"
            required
            autoComplete="current-password"
            maxLength={128}
          />
        </label>
        <label className="field">
          <span>{t("New password")}</span>
          <input
            type="password"
            name="password"
            required
            minLength={16}
            maxLength={128}
            autoComplete="new-password"
          />
        </label>
        <label className="field">
          <span>{t("Confirm password")}</span>
          <input
            type="password"
            name="confirmation"
            required
            minLength={16}
            maxLength={128}
            autoComplete="new-password"
          />
        </label>
        {error && <ErrorMessage error={error} />}
        <p role="status">{message}</p>
        <button className="button primary" disabled={busy}>
          {t("Update password")}
        </button>
      </form>
      <MfaPanel t={t} onVerified={onVerified} />
    </section>
  );
}
