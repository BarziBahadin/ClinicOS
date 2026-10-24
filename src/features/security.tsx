import { useState } from "react";
import { ShieldCheck } from "lucide-react";
import { client } from "../lib/supabase";
import { ErrorMessage, type T } from "../components/ui";
export function MfaPanel({
  t,
  onVerified,
}: {
  t: T;
  onVerified: () => Promise<void>;
}) {
  const [qr, setQr] = useState(""),
    [factor, setFactor] = useState(""),
    [code, setCode] = useState(""),
    [busy, setBusy] = useState(false),
    [error, setError] = useState("");
  async function begin() {
    setBusy(true);
    setError("");
    try {
      const { data, error } = await client().auth.mfa.listFactors();
      if (error) throw error;
      const existing = data.totp.find((f) => f.status === "verified");
      if (existing) {
        setFactor(existing.id);
        return;
      }
      const { data: enrolled, error: enrollError } =
        await client().auth.mfa.enroll({
          factorType: "totp",
          friendlyName: `ClinicOS ${new Date().toISOString().slice(0, 16)}`,
        });
      if (enrollError) throw enrollError;
      setFactor(enrolled.id);
      setQr(enrolled.totp.qr_code);
    } catch (e) {
      setError(e instanceof Error ? e.message : "MFA enrollment failed");
    } finally {
      setBusy(false);
    }
  }
  return (
    <div className="mfa-panel">
      <div className="mfa-icon">
        <ShieldCheck size={25} />
      </div>
      <h3>{t("Security")}</h3>
      <p className="muted">{t("Multi-factor verification required")}</p>
      {qr && (
        <img
          className="mfa-qr"
          src={qr}
          alt="Authenticator enrollment QR code"
        />
      )}
      {!factor ? (
        <button
          className="button secondary"
          disabled={busy}
          onClick={() => void begin()}
        >
          {t("Enroll authenticator")}
        </button>
      ) : (
        <form
          onSubmit={async (e) => {
            e.preventDefault();
            setBusy(true);
            setError("");
            try {
              const { error } = await client().auth.mfa.challengeAndVerify({
                factorId: factor,
                code,
              });
              if (error) throw error;
              await onVerified();
              setCode("");
              setQr("");
            } catch (e) {
              setError(e instanceof Error ? e.message : "Verification failed");
            } finally {
              setBusy(false);
            }
          }}
        >
          <label className="field">
            <span>{t("Verification code")}</span>
            <input
              value={code}
              onChange={(e) => setCode(e.target.value)}
              inputMode="numeric"
              autoComplete="one-time-code"
              pattern="[0-9]{6}"
              required
              maxLength={6}
            />
          </label>
          <button className="button primary" disabled={busy}>
            {t("Verify")}
          </button>
        </form>
      )}
      {error && <ErrorMessage error={error} />}
    </div>
  );
}
