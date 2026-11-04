import { useEffect, useLayoutEffect, useRef, useState } from "react";
import { client } from "../lib/supabase";
import {
  ArrowLeft,
  ArrowRight,
  FileImage,
  FileText,
  Upload,
} from "lucide-react";
import { formatDate } from "../lib/format";
import { invoke } from "../lib/functions";
import type { Row, Snapshot } from "../domain/types";
import {
  Dialog,
  Empty,
  ErrorMessage,
  InputField,
  type T,
} from "../components/ui";
import { patient } from "./actions";
import { RecordPager, useRecordPage } from "../components/RecordPager";
export function MediaWorkspace(props: Parameters<typeof MediaPanel>[0]) {
  const page = useRecordPage(
    props.documentsOnly ? "media_documents" : "media",
    props.data,
    props.patientId,
    16,
  );
  return (
    <>
      <RecordPager page={page} t={props.t} />
      <MediaPanel
        {...props}
        loading={page.loading}
        data={{ ...props.data, media: page.items }}
      />
    </>
  );
}
export function MediaPanel({
  data,
  t,
  patientId,
  onSaved,
  sessionKey,
  documentsOnly = false,
  loading = false,
}: {
  data: Snapshot;
  t: T;
  patientId?: string;
  onSaved: () => Promise<void>;
  sessionKey: string;
  documentsOnly?: boolean;
  loading?: boolean;
}) {
  const [busy, setBusy] = useState(false),
    [error, setError] = useState(""),
    [reportTitle, setReportTitle] = useState(""),
    [viewer, setViewer] = useState<{
      row: Row;
      original: boolean;
      scope: string;
    } | null>(null);
  const rows = data.media.filter(
    (m) =>
      (!patientId || m.patient_id === patientId) &&
      (!documentsOnly || m.mime_type === "application/pdf"),
  );
  const galleryRows = rows.filter(
    (m) => m.status === "ready" && m.patient_id === viewer?.row.patient_id,
  );
  const viewerIndex = galleryRows.findIndex((m) => m.id === viewer?.row.id);
  const uploadAttempt = useRef<{ fingerprint: string; id: string } | null>(
    null,
  );
  const generation = useRef(0);
  const fileInput = useRef<HTMLInputElement>(null);
  const pickerGeneration = useRef<number | null>(null);
  const retryRow = useRef<Row | null>(null);
  const uploading = useRef(false);
  const [uploadPatient, setUploadPatient] = useState(patientId ?? "");
  useLayoutEffect(() => {
    generation.current++;
    setViewer(null);
    setReportTitle("");
    setError("");
    setBusy(false);
    uploadAttempt.current = null;
    retryRow.current = null;
    uploading.current = false;
    pickerGeneration.current = null;
    if (fileInput.current) fileInput.current.value = "";
    setUploadPatient(patientId ?? "");
    return () => {
      generation.current++;
    };
  }, [patientId, sessionKey, documentsOnly]);
  async function upload(file: File) {
    if (uploading.current) return;
    uploading.current = true;
    const requestGeneration = generation.current;
    setBusy(true);
    setError("");
    try {
      if (documentsOnly && file.type !== "application/pdf")
        throw new Error(t("Choose a PDF report"));
      if (!file.size || file.size > 10485760)
        throw new Error(t("Choose a file up to 10 MB"));
      const selectedPatient = String(
        retryRow.current?.patient_id ?? patientId ?? uploadPatient,
      );
      const { data: consents, error: consentError } = await client().rpc(
        "current_photography_consent",
        { patient_id: selectedPatient },
      );
      if (requestGeneration !== generation.current) return;
      if (consentError) throw new Error(consentError.message);
      if (!consents?.length)
        throw new Error(t("Record photography consent before uploading."));
      const form = new FormData();
      form.set("file", file);
      form.set("patient_id", selectedPatient);
      form.set(
        "consent_id",
        String(retryRow.current?.consent_id ?? consents[0].id),
      );
      form.set(
        "title",
        String(
          retryRow.current?.title ??
            ((documentsOnly ? reportTitle.trim() : "") || file.name),
        ),
      );
      form.set(
        "body_site",
        String(retryRow.current?.body_site ?? "Not recorded"),
      );
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
          id: retryRow.current?.id ?? crypto.randomUUID(),
        };
      form.set("upload_id", uploadAttempt.current.id);
      await invoke<{ id: string }>("clinical-media", form);
      if (requestGeneration !== generation.current) return;
      await onSaved();
      if (requestGeneration !== generation.current) return;
      uploadAttempt.current = null;
      retryRow.current = null;
    } catch (e) {
      if (requestGeneration !== generation.current) return;
      setError(e instanceof Error ? e.message : "Upload failed");
    } finally {
      if (requestGeneration === generation.current) {
        setBusy(false);
        uploading.current = false;
      }
    }
  }
  function view(m: Row, original = false) {
    setViewer({
      row: m,
      original,
      scope: `${patientId}-${sessionKey}-${documentsOnly}`,
    });
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
        <h2>
          {t(documentsOnly ? "Lab reports & documents" : "Clinical media")}
        </h2>
        <button
          className="button secondary"
          disabled={
            busy ||
            !(patientId || uploadPatient) ||
            (documentsOnly && !reportTitle.trim())
          }
          onClick={() => {
            retryRow.current = null;
            pickerGeneration.current = generation.current;
            fileInput.current?.click();
          }}
        >
          <Upload size={16} />
          {t(
            busy
              ? "Saving…"
              : documentsOnly
                ? "Upload PDF report"
                : "Upload document / photo",
          )}
        </button>
      </div>
      <p className="panel-hint">
        {t(
          documentsOnly
            ? "Keep lab tests and scanned reports in the patient profile. Choose a PDF saved on this computer (up to 10 MB)."
            : "Browse photos and documents. Select a tile to open the gallery viewer.",
        )}
      </p>
      {documentsOnly && (
        <label className="field report-title">
          <span>{t("Report title")}</span>
          <input
            value={reportTitle}
            dir="auto"
            maxLength={500}
            disabled={busy}
            onChange={(e) => setReportTitle(e.target.value)}
            placeholder={t("For example: Blood test — November 2026")}
          />
        </label>
      )}
      {!patientId && (
        <div
          onChange={(e) => {
            if (e.target instanceof HTMLSelectElement) {
              generation.current++;
              setUploadPatient(e.target.value);
              uploadAttempt.current = null;
              retryRow.current = null;
              uploading.current = false;
              setBusy(false);
              setError("");
            }
          }}
        >
          <InputField t={t} field={patient(data)} />
        </div>
      )}
      <input
        ref={fileInput}
        type="file"
        hidden
        aria-label={t("File")}
        accept={
          documentsOnly
            ? "application/pdf"
            : "image/jpeg,image/png,image/webp,application/pdf"
        }
        disabled={busy}
        onChange={(e) => {
          const file = e.currentTarget.files?.[0];
          e.currentTarget.value = "";
          const currentPicker = pickerGeneration.current === generation.current;
          pickerGeneration.current = null;
          if (file && currentPicker) void upload(file);
        }}
      />
      {busy && <p role="status">{t("Saving…")}</p>}
      {error && <ErrorMessage error={error} />}
      <div className="media-grid">
        {rows.map((m) => (
          <article
            className="media-item"
            key={m.id}
            aria-label={String(m.title)}
          >
            <button
              className="media-card"
              disabled={m.status !== "ready"}
              onClick={() => void view(m)}
            >
              <MediaThumbnail
                key={`${sessionKey}-${m.patient_id}-${m.id}`}
                row={m}
                sessionKey={sessionKey}
                t={t}
              />
              <span className="media-card-body">
                <strong dir="auto">{String(m.title)}</strong>
                <span className="media-card-status">
                  {t(
                    String(m.status).charAt(0).toUpperCase() +
                      String(m.status).slice(1),
                  )}
                </span>
                <span className="media-card-details">
                  {!patientId && <bdi>{String(m.patient_name ?? "")}</bdi>}
                  {!documentsOnly && (
                    <bdi>
                      {m.body_site === "Not recorded"
                        ? t("Not recorded")
                        : String(m.body_site)}
                    </bdi>
                  )}
                  <time dateTime={String(m.created_at)}>
                    <bdi>
                      {formatDate(
                        m.created_at,
                        false,
                        document.documentElement.lang === "ckb" ? "ckb" : "en",
                      )}
                    </bdi>
                  </time>
                </span>
              </span>
            </button>
            <div className="inline-actions media-actions">
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
                    disabled={busy}
                    onClick={() => {
                      retryRow.current = m;
                      pickerGeneration.current = generation.current;
                      setError("");
                      fileInput.current?.click();
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
          </article>
        ))}
      </div>
      {!rows.length && (
        <Empty
          t={t}
          loading={loading}
          text={documentsOnly ? "No reports uploaded yet" : "Nothing here yet"}
          hint={
            documentsOnly
              ? "Give the report a clear title, then upload a PDF from this computer."
              : "Records will appear here when available."
          }
        />
      )}
      {viewer &&
        viewer.scope === `${patientId}-${sessionKey}-${documentsOnly}` && (
          <MediaViewer
            key={`${sessionKey}-${viewer.row.patient_id}-${viewer.row.id}-${viewer.original}`}
            row={viewer.row}
            original={viewer.original}
            t={t}
            onClose={() => setViewer(null)}
            onMove={(direction) => {
              const next = galleryRows[viewerIndex + direction];
              if (next) setViewer({ ...viewer, row: next, original: false });
            }}
            previous={viewerIndex > 0}
            next={viewerIndex >= 0 && viewerIndex < galleryRows.length - 1}
          />
        )}
    </section>
  );
}

function MediaThumbnail({
  row,
  sessionKey,
  t,
}: {
  row: Row;
  sessionKey: string;
  t: T;
}) {
  const [url, setUrl] = useState("");
  useEffect(() => {
    let current = true;
    setUrl("");
    if (
      row.status === "ready" &&
      row.preview_key &&
      row.mime_type !== "application/pdf"
    ) {
      void invoke<{ url: string }>("clinical-media", {
        action: "preview",
        media_id: row.id,
      })
        .then((result) => {
          if (current) setUrl(result.url);
        })
        .catch(() => {
          /* Keep the file icon when a preview is unavailable. */
        });
    }
    return () => {
      current = false;
    };
  }, [
    row.id,
    row.patient_id,
    row.preview_key,
    row.status,
    row.mime_type,
    sessionKey,
  ]);
  return (
    <span className="media-card-preview" aria-hidden="true">
      {url ? (
        <img src={url} alt="" loading="lazy" onError={() => setUrl("")} />
      ) : row.mime_type === "application/pdf" ? (
        <>
          <FileText size={32} strokeWidth={1.3} />
          <span>PDF</span>
        </>
      ) : (
        <>
          <FileImage size={32} strokeWidth={1.3} />
          <span>{t("Photo")}</span>
        </>
      )}
    </span>
  );
}

function MediaViewer({
  row,
  original,
  t,
  onClose,
  onMove,
  previous,
  next,
}: {
  row: Row;
  original: boolean;
  t: T;
  onClose: () => void;
  onMove: (direction: number) => void;
  previous: boolean;
  next: boolean;
}) {
  const [file, setFile] = useState<{ url: string; mime: string } | null>(null);
  const [error, setError] = useState("");
  const [attempt, setAttempt] = useState(0);
  useEffect(() => {
    let current = true;
    setFile(null);
    setError("");
    void invoke<{ url: string; mime_type?: string }>("clinical-media", {
      action:
        original || row.mime_type === "application/pdf" ? "read" : "preview",
      media_id: row.id,
    })
      .then((result) => {
        if (current)
          setFile({
            url: result.url,
            mime: result.mime_type ?? String(row.mime_type),
          });
      })
      .catch((e) => {
        if (current)
          setError(e instanceof Error ? e.message : t("Access denied"));
      });
    return () => {
      current = false;
    };
  }, [row.id, row.mime_type, original, attempt, t]);
  useEffect(() => {
    const keydown = (e: KeyboardEvent) => {
      if (e.key !== "ArrowLeft" && e.key !== "ArrowRight") return;
      e.preventDefault();
      const direction = e.key === "ArrowRight" ? 1 : -1;
      onMove(document.documentElement.dir === "rtl" ? -direction : direction);
    };
    window.addEventListener("keydown", keydown);
    return () => window.removeEventListener("keydown", keydown);
  }, [onMove]);
  return (
    <Dialog
      title={String(row.title)}
      onClose={onClose}
      className="media-viewer"
    >
      <div className="media-viewer-body">
        <div className="media-viewer-stage" aria-busy={!file && !error}>
          {error ? (
            <div>
              <ErrorMessage error={error} />
              <button
                className="button secondary"
                onClick={() => setAttempt(attempt + 1)}
              >
                {t("Retry")}
              </button>
            </div>
          ) : !file ? (
            <p role="status">{t("Loading…")}</p>
          ) : file.mime === "application/pdf" ? (
            <div className="media-pdf">
              <FileText size={64} strokeWidth={1} />
              <p>{t("PDF report")}</p>
              <a
                className="button primary"
                href={file.url}
                target="_blank"
                rel="noopener noreferrer"
              >
                {t("Open PDF")}
              </a>
            </div>
          ) : (
            <img
              src={file.url}
              alt={String(row.title)}
              onError={() =>
                setError(t("Unable to load image. Retry to refresh access."))
              }
            />
          )}
        </div>
        <div className="media-viewer-toolbar">
          <button
            className="button secondary"
            disabled={!previous}
            onClick={() => onMove(-1)}
          >
            <ArrowLeft size={16} />
            {t("Previous")}
          </button>
          <span className="muted">
            {t(
              original
                ? "Original"
                : row.mime_type === "application/pdf"
                  ? "PDF report"
                  : "Preview",
            )}
          </span>
          <button
            className="button secondary"
            disabled={!next}
            onClick={() => onMove(1)}
          >
            {t("Next")}
            <ArrowRight size={16} />
          </button>
        </div>
        {!original && row.mime_type !== "application/pdf" && (
          <p className="panel-hint">
            {t(
              "Preview is resized and metadata is removed. The original file is preserved.",
            )}
          </p>
        )}
      </div>
    </Dialog>
  );
}
