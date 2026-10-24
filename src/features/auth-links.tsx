import { useState } from "react";
import { client } from "../lib/supabase";
import { emailLink, consumeEmailLink } from "../lib/email-link";
import { Dialog, ErrorMessage, type T } from "../components/ui";
export function EmailConfirmation({ t }: { t: T }) {
  const [busy, setBusy] = useState(false),
    [error, setError] = useState("");
  return (
    <div className="splash">
      <h1>ClinicOS</h1>
      <p>{t("Confirm your clinic email link to continue.")}</p>
      {error && <ErrorMessage error={error} />}
      <button
        className="button primary"
        disabled={busy}
        onClick={async () => {
          if (!emailLink) return;
          setBusy(true);
          setError("");
          try {
            const { error } = await client().auth.verifyOtp(emailLink);
            if (error) throw error;
            consumeEmailLink();
          } catch (e) {
            setError(e instanceof Error ? e.message : "Verification failed");
          } finally {
            setBusy(false);
          }
        }}
      >
        {t("Continue")}
      </button>
      <a href={location.pathname}>{t("Back to sign in")}</a>
    </div>
  );
}
export function PasswordRecovery({
  t,
  onClose,
}: {
  t: T;
  onClose: () => void;
}) {
  const [busy, setBusy] = useState(false),
    [error, setError] = useState(""),
    [sent, setSent] = useState(false);
  return (
    <Dialog title={t("Reset password")} onClose={() => !busy && onClose()}>
      <form
        onSubmit={async (e) => {
          e.preventDefault();
          const email = String(new FormData(e.currentTarget).get("email"));
          setBusy(true);
          setError("");
          try {
            const { error } = await client().auth.resetPasswordForEmail(email);
            if (error) throw error;
            setSent(true);
          } catch (e) {
            setError(
              e instanceof Error ? e.message : "Unable to send recovery email",
            );
          } finally {
            setBusy(false);
          }
        }}
      >
        <div className="dialog-body">
          {sent ? (
            <p role="status">
              {t(
                "If an account exists, a recovery link has been sent. Open it to set a new password.",
              )}
            </p>
          ) : (
            <label className="field">
              <span>{t("Email")}</span>
              <input
                name="email"
                type="email"
                autoComplete="username"
                required
                dir="ltr"
              />
            </label>
          )}
          {error && <ErrorMessage error={error} />}
        </div>
        <div className="dialog-footer">
          <button
            type="button"
            className="button secondary"
            disabled={busy}
            onClick={onClose}
          >
            {t("Close")}
          </button>
          {!sent && (
            <button className="button primary" disabled={busy}>
              {t("Send recovery link")}
            </button>
          )}
        </div>
      </form>
    </Dialog>
  );
}
