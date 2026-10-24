import { useRef, useState, type FormEvent } from "react";
import { FileImage, Upload } from "lucide-react";
import { invoke } from "../lib/functions";
import type { Row, Snapshot } from "../domain/types";
import {
  Dialog,
  Empty,
  ErrorMessage,
  InputField,
  options,
  type T,
} from "../components/ui";
import { patient, text } from "./actions";
export function MediaPanel({
  data,
  t,
  patientId,
  onSaved,
}: {
  data: Snapshot;
  t: T;
  patientId?: string;
  onSaved: () => Promise<void>;
}) {
  const [open, setOpen] = useState(false),
    [busy, setBusy] = useState(false),
    [error, setError] = useState(""),
    [images, setImages] = useState<
      { id: string; url: string; title: string; mime: string }[]
    >([]);
  const rows = data.media.filter(
    (m) => (!patientId || m.patient_id === patientId) && m.status === "ready",
  );
  const uploadAttempt = useRef<{ fingerprint: string; id: string } | null>(
    null,
  );
  async function upload(e: FormEvent<HTMLFormElement>) {
    e.preventDefault();
    setBusy(true);
    setError("");
    try {
      const form = new FormData(e.currentTarget);
      const file = form.get("file");
      if (!(file instanceof File) || file.size > 10485760)
        throw new Error("Choose a file up to 10 MB");
      const digest = Array.from(
        new Uint8Array(
          await crypto.subtle.digest("SHA-256", await file.arrayBuffer()),
        ),
      )
        .map((x) => x.toString(16).padStart(2, "0"))
        .join("");
      const fingerprint =
        JSON.stringify([...form.entries()].filter(([k]) => k !== "file")) +
        digest;
      if (uploadAttempt.current?.fingerprint !== fingerprint)
        uploadAttempt.current = { fingerprint, id: crypto.randomUUID() };
      form.set("upload_id", uploadAttempt.current.id);
      await invoke<{ id: string }>("clinical-media", form);
      await onSaved();
      setOpen(false);
      uploadAttempt.current = null;
    } catch (e) {
      setError(e instanceof Error ? e.message : "Upload failed");
    } finally {
      setBusy(false);
    }
  }
  async function view(m: Row) {
    setError("");
    try {
      const result = await invoke<{ url: string }>("clinical-media", {
        action: "read",
        media_id: m.id,
      });
      setImages((prev) => [
        ...prev.filter((x) => x.id !== m.id).slice(-1),
        {
          id: m.id,
          url: result.url,
          title: String(m.title),
          mime: String(m.mime_type),
        },
      ]);
    } catch (e) {
      setError(e instanceof Error ? e.message : "Access denied");
    }
  }
  return (
    <section className="panel">
      <div className="panel-head">
        <h2>{t("Clinical media")}</h2>
        <button
          className="button secondary"
          onClick={() => {
            setError("");
            setOpen(true);
          }}
        >
          <Upload size={16} />
          {t("Upload document / photo")}
        </button>
      </div>
      {error && !open && <ErrorMessage error={error} />}
      <div className="media-grid">
        {rows.map((m) => (
          <button
            key={m.id}
            className="media-card"
            onClick={() => void view(m)}
          >
            <div>
              <FileImage size={30} strokeWidth={1.1} />
            </div>
            <strong>{String(m.title)}</strong>
            <span>
              {String(m.body_site)} ·{" "}
              {new Date(String(m.created_at)).toLocaleDateString()}
            </span>
          </button>
        ))}
      </div>
      {!rows.length && <Empty t={t} />}{" "}
      {images.length > 0 && (
        <div className="photo-comparison">
          {images.map((i) => (
            <figure key={i.id}>
              {i.mime === "application/pdf" ? (
                <a
                  className="button secondary"
                  href={i.url}
                  target="_blank"
                  rel="noopener noreferrer"
                >
                  {t("View")} · PDF
                </a>
              ) : (
                <img src={i.url} alt={i.title} />
              )}
              <figcaption>{i.title}</figcaption>
            </figure>
          ))}
        </div>
      )}
      {open && (
        <Dialog
          title={t("Upload document / photo")}
          onClose={() => !busy && setOpen(false)}
        >
          <form onSubmit={upload}>
            <div className="dialog-body form-grid">
              <InputField t={t} field={patient(data, patientId)} />
              <InputField t={t} field={text("title", "Title")} />
              <InputField t={t} field={text("body_site", "Body site")} />
              <InputField
                t={t}
                field={{
                  name: "consent_id",
                  label: "Consent",
                  required: true,
                  options: options(
                    data.consents
                      .filter(
                        (c) =>
                          c.granted &&
                          c.purpose === "care_photography" &&
                          (!patientId || c.patient_id === patientId),
                      )
                      .map((c) => ({
                        ...c,
                        label: `${data.patients.find((p) => p.id === c.patient_id)?.full_name} · ${String(c.evidence).slice(0, 50)}`,
                      })),
                    "label",
                  ),
                }}
              />
              <label className="field wide">
                <span>{t("File")}</span>
                <input
                  type="file"
                  name="file"
                  accept="image/jpeg,image/png,image/webp,application/pdf"
                  required
                />
              </label>
              {error && <ErrorMessage error={error} />}
            </div>
            <footer className="dialog-footer">
              <button className="button primary" disabled={busy}>
                {t(busy ? "Saving…" : "Save")}
              </button>
            </footer>
          </form>
        </Dialog>
      )}
    </section>
  );
}
