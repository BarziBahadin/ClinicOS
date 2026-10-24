import { useState } from "react";
import { client } from "../lib/supabase";
import { ErrorMessage, type T } from "../components/ui";
import { MfaPanel } from "./security";
export function AccountPanel({
  t,
  onVerified,
}: {
  t: T;
  onVerified: () => Promise<void>;
}) {
  const [error, setError] = useState(""),
    [message, setMessage] = useState(""),
    [busy, setBusy] = useState(false);
  return (
    <section className="panel">
      <div className="panel-head">
        <h2>{t("Account & security")}</h2>
      </div>
      <form
        className="account-form"
        onSubmit={async (e) => {
          e.preventDefault();
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
            const { error } = await client().auth.updateUser({ password });
            if (error) throw error;
            form.reset();
            setMessage(t("Password updated"));
          } catch (e) {
            setError(
              e instanceof Error ? e.message : "Unable to update password",
            );
          } finally {
            setBusy(false);
          }
        }}
      >
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
