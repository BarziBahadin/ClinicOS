import {
  useEffect,
  useLayoutEffect,
  useRef,
  useState,
  type FormEvent,
} from "react";
import { client } from "../lib/supabase";
import { FileImage, Upload } from "lucide-react";
import { invoke } from "../lib/functions";
import type { Row, Snapshot } from "../domain/types";
import {
  Dialog,
  Empty,
  ErrorMessage,
  InputField,
  type T,
} from "../components/ui";
import { patient, text } from "./actions";
import { RecordPager, useRecordPage } from "../components/RecordPager";
export function MediaWorkspace(props: Parameters<typeof MediaPanel>[0]) {
  const page = useRecordPage("media", props.data, props.patientId);
  return (
    <>
      <RecordPager page={page} t={props.t} />
      <MediaPanel {...props} data={{ ...props.data, media: page.items }} />
    </>
  );
}
export function MediaPanel({
  data,
  t,
  patientId,
  onSaved,
  sessionKey,
}: {
  data: Snapshot;
  t: T;
  patientId?: string;
  onSaved: () => Promise<void>;
  sessionKey: string;
}) {
  const [open, setOpen] = useState(false),
    [retryRow, setRetryRow] = useState<Row | null>(null),
    [busy, setBusy] = useState(false),
    [error, setError] = useState(""),
    [images, setImages] = useState<
      {
        id: string;
        patientId: unknown;
        url: string;
        title: string;
        mime: string;
        original: boolean;
      }[]
    >([]);
  const rows = data.media.filter(
    (m) => !patientId || m.patient_id === patientId,
  );
  const uploadAttempt = useRef<{ fingerprint: string; id: string } | null>(
    null,
  );
  const generation = useRef(0);
  const readRequests = useRef(new Map<string, number>());
  const preview = useRef<HTMLDivElement>(null);
  const [uploadPatient, setUploadPatient] = useState(patientId ?? "");
  useLayoutEffect(() => {
    generation.current++;
    setImages([]);
    setError("");
    setOpen(false);
    setBusy(false);
    uploadAttempt.current = null;
    readRequests.current.clear();
    setRetryRow(null);
    setUploadPatient(patientId ?? "");
    return () => {
      generation.current++;
    };
  }, [patientId, sessionKey]);
  async function upload(e: FormEvent<HTMLFormElement>) {
    e.preventDefault();
    const requestGeneration = generation.current;
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
      if (requestGeneration !== generation.current) return;
      if (uploadAttempt.current?.fingerprint !== fingerprint)
        uploadAttempt.current = {
          fingerprint,
          id: retryRow?.id ?? crypto.randomUUID(),
        };
      form.set("upload_id", uploadAttempt.current.id);
      await invoke<{ id: string }>("clinical-media", form);
      if (requestGeneration !== generation.current) return;
      await onSaved();
      if (requestGeneration !== generation.current) return;
      setOpen(false);
      uploadAttempt.current = null;
    } catch (e) {
      if (requestGeneration !== generation.current) return;
      setError(e instanceof Error ? e.message : "Upload failed");
    } finally {
      if (requestGeneration === generation.current) setBusy(false);
    }
  }
  async function view(m: Row, original = false) {
    const requestGeneration = generation.current;
    const sequence = (readRequests.current.get(m.id) ?? 0) + 1;
    readRequests.current.set(m.id, sequence);
    setError("");
    try {
      const result = await invoke<{ url: string; mime_type?: string }>(
        "clinical-media",
        {
          action:
            original || m.mime_type === "application/pdf" ? "read" : "preview",
          media_id: m.id,
        },
      );
      if (
        requestGeneration !== generation.current ||
        readRequests.current.get(m.id) !== sequence
      )
        return;
      setImages((prev) => [
        ...prev
          .filter((x) => x.id !== m.id && x.patientId === m.patient_id)
          .slice(-1),
        {
          id: m.id,
          patientId: m.patient_id,
          url: result.url,
          title: String(m.title),
          mime: result.mime_type ?? String(m.mime_type),
          original,
        },
      ]);
    } catch (e) {
      if (requestGeneration !== generation.current) return;
      setError(e instanceof Error ? e.message : "Access denied");
    }
  }
  async function regenerate(m: Row) {
    const requestGeneration = generation.current;
    setError("");
    try {
      await invoke("clinical-media", {
        action: "regenerate_preview",
        media_id: m.id,
      });
      if (requestGeneration === generation.current) await onSaved();
    } catch (e) {
      if (requestGeneration === generation.current)
        setError(e instanceof Error ? e.message : "Preview generation failed");
    }
  }
  async function cancelUpload(m: Row) {
    const reason = window.prompt(
      t("Why is this pending upload being cancelled?"),
    );
    if (!reason) return;
    const requestGeneration = generation.current;
    const result = await client().rpc("media_cancel_upload", {
      media_id: m.id,
      reason,
    });
    if (requestGeneration !== generation.current) return;
    if (result.error) setError(result.error.message);
    else await onSaved();
  }
  return (
    <section className="panel">
      <div className="panel-head">
        <h2>{t("Clinical media")}</h2>
        <button
          className="button secondary"
          onClick={() => {
            setError("");
            setRetryRow(null);
            setUploadPatient(patientId ?? "");
            uploadAttempt.current = null;
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
          <div key={m.id}>
            <button
              className="media-card"
              disabled={m.status !== "ready"}
              onClick={() => void view(m)}
            >
              <div>
                <FileImage size={30} strokeWidth={1.1} />
              </div>
              <strong>{String(m.title)}</strong>
              <span>
                {t(
                  String(m.status).charAt(0).toUpperCase() +
                    String(m.status).slice(1),
                )}
              </span>
              <span>
                {String(m.body_site)} ·{" "}
                {new Date(String(m.created_at)).toLocaleDateString()}
              </span>
            </button>
            <div className="inline-actions">
              {m.status === "ready" && m.mime_type !== "application/pdf" && (
                <>
                  <button
                    className="text-button"
                    onClick={() => void view(m, true)}
                  >
                    {t("View original")}
                  </button>
                  {!m.preview_key && (
                    <button
                      className="text-button"
                      onClick={() => void regenerate(m)}
                    >
                      {t("Generate preview")}
                    </button>
                  )}
                </>
              )}
              {m.status === "pending" && (
                <>
                  <button
                    className="text-button"
                    onClick={() => {
                      setRetryRow(m);
                      setUploadPatient(String(m.patient_id));
                      setError("");
                      setOpen(true);
                    }}
                  >
                    {t("Retry upload")}
                  </button>
                  <button
                    className="text-button"
                    onClick={() => void cancelUpload(m)}
                  >
                    {t("Cancel upload")}
                  </button>
                </>
              )}
            </div>
          </div>
        ))}
      </div>
      {!rows.length && <Empty t={t} />}{" "}
      {images.length > 0 && (
        <div className="photo-comparison" ref={preview}>
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
                <img
                  src={i.url}
                  alt={i.title}
                  onLoad={() =>
                    preview.current?.scrollIntoView({ block: "start" })
                  }
                />
              )}
              <figcaption>
                {i.title} · {t(i.original ? "Original" : "Preview")}
                {!i.original && i.mime !== "application/pdf" && (
                  <p>
                    {t(
                      "Preview is resized and metadata is removed. The original file is preserved.",
                    )}
                  </p>
                )}
              </figcaption>
            </figure>
          ))}
        </div>
      )}
      {open && (
        <Dialog
          title={t("Upload document / photo")}
          onClose={() => !busy && setOpen(false)}
        >
          <form
            onSubmit={upload}
            onChange={(e) => {
              const p = new FormData(e.currentTarget).get("patient_id");
              if (p) setUploadPatient(String(p));
            }}
          >
            <div className="dialog-body form-grid">
              <InputField
                t={t}
                field={patient(
                  data,
                  retryRow ? String(retryRow.patient_id) : patientId,
                )}
              />
              <InputField
                t={t}
                field={text("title", "Title", true, retryRow?.title)}
              />
              <InputField
                t={t}
                field={text(
                  "body_site",
                  "Body site",
                  true,
                  retryRow?.body_site,
                )}
              />
              <CurrentConsent patientId={uploadPatient} t={t} />
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

function CurrentConsent({ patientId, t }: { patientId: string; t: T }) {
  const [rows, setRows] = useState<Row[]>([]),
    [error, setError] = useState("");
  useLayoutEffect(() => {
    setRows([]);
    setError("");
  }, [patientId]);
  useEffect(() => {
    if (!patientId) return;
    let cancelled = false;
    void client()
      .rpc("current_photography_consent", { patient_id: patientId })
      .then(({ data, error }) => {
        if (cancelled) return;
        if (error) setError(error.message);
        else setRows(data);
      });
    return () => {
      cancelled = true;
    };
  }, [patientId]);
  return (
    <label className="field">
      <span>{t("Current photography consent")}</span>
      <select name="consent_id" required disabled={!patientId}>
        <option value="">{t("Choose current consent")}</option>
        {rows.map((row) => (
          <option key={row.id} value={row.id}>
            {t("Granted")} · {String(row.template_version)} ·{" "}
            {new Date(String(row.created_at)).toLocaleDateString()}
          </option>
        ))}
      </select>
      {error && <span role="alert">{error}</span>}
    </label>
  );
}
