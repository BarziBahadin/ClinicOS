import { PatientSelect } from "./PatientSelect";
import {
  useEffect,
  useRef,
  useState,
  type ReactNode,
  type FormEvent,
} from "react";
import {
  X,
  AlertCircle,
  LoaderCircle,
  Inbox,
  Plus,
  Trash2,
} from "lucide-react";
import type { CommandName, Row, Snapshot } from "../domain/types";
import { execute } from "../lib/api";
export type T = (s: string) => string;
export type Field = {
  name: string;
  label: string;
  type?: string;
  required?: boolean;
  options?: { value: string; label: string }[];
  value?: unknown;
  placeholder?: string;
  help?: string;
  min?: string;
  max?: string;
  step?: string;
};
export function Empty({
  t,
  text = "Nothing here yet",
}: {
  t: T;
  text?: string;
}) {
  return (
    <div className="empty">
      <Inbox size={30} strokeWidth={1.3} />
      <strong>{t(text)}</strong>
      <p>{t("Start with a new record using the action above.")}</p>
    </div>
  );
}
export function Badge({ status, t }: { status: unknown; t: T }) {
  const s = String(status ?? "");
  return (
    <span className={`badge badge-${s}`}>
      {t(
        (
          {
            checked_in: "Checked in",
            in_care: "In care",
            no_show: "No-show",
          } as Record<string, string>
        )[s] ?? s.charAt(0).toUpperCase() + s.slice(1),
      )}
    </span>
  );
}
export function DataTable({
  heads,
  children,
}: {
  heads: string[];
  children: ReactNode;
}) {
  return (
    <div className="table-scroll">
      <table>
        <thead>
          <tr>
            {heads.map((h) => (
              <th key={h} scope="col">
                {h}
              </th>
            ))}
          </tr>
        </thead>
        <tbody>{children}</tbody>
      </table>
    </div>
  );
}
export function ErrorMessage({ error }: { error: string }) {
  return (
    <div className="error" role="alert">
      <AlertCircle size={17} />
      <span>{error}</span>
    </div>
  );
}
export function Dialog({
  title,
  children,
  onClose,
}: {
  title: string;
  children: ReactNode;
  onClose: () => void;
}) {
  const ref = useRef<HTMLDialogElement>(null);
  useEffect(() => {
    ref.current?.showModal();
    return () => ref.current?.close();
  }, []);
  return (
    <dialog
      ref={ref}
      aria-labelledby="dialog-title"
      onCancel={(e) => {
        e.preventDefault();
        onClose();
      }}
    >
      <div className="dialog-head">
        <h2 id="dialog-title">{title}</h2>
        <button className="icon-button" aria-label="Close" onClick={onClose}>
          <X size={20} />
        </button>
      </div>
      {children}
    </dialog>
  );
}
export function InputField({ field, t }: { field: Field; t: T }) {
  const id = `field-${field.name}`;
  return (
    <label
      className={`field ${field.type === "textarea" ? "wide" : ""}`}
      htmlFor={id}
    >
      <span>
        {t(field.label)}
        {field.required && <span aria-hidden="true"> *</span>}
      </span>
      {field.name === "patient_id" || field.type === "patient" ? (
        <PatientSelect field={field} t={t} />
      ) : field.options ? (
        <select
          id={id}
          name={field.name}
          required={field.required}
          defaultValue={String(field.value ?? "")}
        >
          <option value="">—</option>
          {field.options.map((o) => (
            <option key={o.value} value={o.value}>
              {t(o.label)}
            </option>
          ))}
        </select>
      ) : field.type === "textarea" ? (
        <textarea
          id={id}
          name={field.name}
          required={field.required}
          defaultValue={String(field.value ?? "")}
          rows={4}
          maxLength={20000}
          dir="auto"
        />
      ) : field.type === "checkbox" ? (
        <input
          id={id}
          name={field.name}
          type="checkbox"
          defaultChecked={Boolean(field.value)}
        />
      ) : (
        <input
          id={id}
          name={field.name}
          type={field.type ?? "text"}
          required={field.required}
          defaultValue={String(field.value ?? "")}
          placeholder={field.placeholder}
          min={field.min}
          max={field.max}
          step={field.step}
          maxLength={field.type === "text" || !field.type ? 500 : undefined}
          dir={
            ["email", "tel", "number", "date", "datetime-local"].includes(
              field.type ?? "",
            )
              ? "ltr"
              : "auto"
          }
        />
      )}
      {field.help && <small className="muted">{t(field.help)}</small>}
    </label>
  );
}
export interface Action {
  title: string;
  kind: CommandName;
  fields: Field[];
  fixed?: Record<string, unknown>;
}
export function CommandDialog({
  action,
  t,
  data,
  onClose,
  onSaved,
}: {
  action: Action;
  t: T;
  data: Snapshot;
  onClose: () => void;
  onSaved: () => Promise<void>;
}) {
  const [busy, setBusy] = useState(false),
    [error, setError] = useState(""),
    [dirty, setDirty] = useState(false);
  const attempt = useRef<{ body: string; id: string } | null>(null);
  const [currency, setCurrency] = useState("IQD");
  const [lineIds, setLineIds] = useState([crypto.randomUUID()]);
  useEffect(() => {
    const handler = (e: BeforeUnloadEvent) => {
      if (dirty) {
        e.preventDefault();
        e.returnValue = "";
      }
    };
    window.addEventListener("beforeunload", handler);
    return () => window.removeEventListener("beforeunload", handler);
  }, [dirty]);
  const close = () => {
    if (!busy && (!dirty || window.confirm(t("Discard unsaved changes?"))))
      onClose();
  };
  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setError("");
    const form = new FormData(event.currentTarget);
    const payload: Record<string, unknown> = { ...action.fixed };
    for (const field of action.fields) {
      const value = form.get(field.name);
      payload[field.name] =
        field.type === "checkbox"
          ? value === "on"
          : typeof value === "string"
            ? value.trim()
            : value;
    }
    try {
      if (
        action.kind.startsWith("patient.") &&
        action.kind !== "patient.merge"
      ) {
        const { normalizePhone } = await import("../domain/phone");
        payload.phone = normalizePhone(String(payload.phone ?? ""));
        const precision = payload.birth_precision;
        const b = String(payload.birth_date ?? "");
        if (precision === "unknown") {
          payload.birth_date = null;
        } else {
          if (!b) throw new Error("Enter known birth information.");
          if (
            (precision === "year" && !/^\d{4}$/.test(b)) ||
            (precision === "month" && !/^\d{4}-\d{2}$/.test(b)) ||
            (precision === "day" && !/^\d{4}-\d{2}-\d{2}$/.test(b))
          )
            throw new Error(
              "Use YYYY, YYYY-MM or YYYY-MM-DD for the chosen precision.",
            );
          payload.birth_date =
            precision === "year"
              ? `${b}-01-01`
              : precision === "month"
                ? `${b}-01`
                : b;
        }
      }
      const { clinicDateTime } = await import("../domain/time");
      for (const key of ["starts_at", "ends_at", "due_at"])
        if (payload[key])
          payload[key] = clinicDateTime(
            String(payload[key]),
            data.organization?.timezone ?? "Asia/Baghdad",
          );
      if (action.kind === "invoice.issue") {
        payload.currency = currency;
        payload.lines = lineIds.map((id) => ({
          service_id: String(form.get(`service-${id}`)),
          quantity: Number(form.get(`quantity-${id}`)),
        }));
      }
      const body = JSON.stringify(payload);
      if (attempt.current?.body !== body)
        attempt.current = { body, id: crypto.randomUUID() };
      setBusy(true);
      await execute(action.kind, payload, attempt.current!.id);
      setDirty(false);
      await onSaved();
      onClose();
    } catch (err) {
      setError(
        err instanceof Error
          ? err.message
          : "Unable to save. Retry with the same form to safely check the result.",
      );
    } finally {
      setBusy(false);
    }
  }
  return (
    <Dialog title={t(action.title)} onClose={close}>
      <form onSubmit={submit} onChange={() => setDirty(true)}>
        <div className="dialog-body">
          <div className="form-grid">
            {action.fields.map((field) => (
              <InputField key={field.name} field={field} t={t} />
            ))}
          </div>
          {action.kind === "invoice.issue" && (
            <div className="invoice-editor">
              <label className="field">
                <span>{t("Currency")}</span>
                <select
                  value={currency}
                  onChange={(e) => setCurrency(e.target.value)}
                >
                  <option>IQD</option>
                  <option>USD</option>
                </select>
              </label>
              {lineIds.map((id) => (
                <div className="invoice-line" key={id}>
                  <label className="field">
                    <span>{t("Service")}</span>
                    <select name={`service-${id}`} required>
                      <option value="">—</option>
                      {data.services
                        .filter((s) => s.currency === currency)
                        .map((s) => (
                          <option key={s.id} value={s.id}>
                            {String(s.name)} · {String(s.price)} {currency}
                          </option>
                        ))}
                    </select>
                  </label>
                  <label className="field">
                    <span>{t("Quantity")}</span>
                    <input
                      type="number"
                      name={`quantity-${id}`}
                      min="1"
                      max="1000"
                      defaultValue="1"
                      required
                    />
                  </label>
                  <button
                    type="button"
                    className="icon-button"
                    aria-label={t("Remove")}
                    disabled={lineIds.length === 1}
                    onClick={() => setLineIds(lineIds.filter((x) => x !== id))}
                  >
                    <Trash2 size={17} />
                  </button>
                </div>
              ))}
              <button
                type="button"
                className="button secondary"
                onClick={() => setLineIds([...lineIds, crypto.randomUUID()])}
              >
                <Plus size={15} />
                {t("Add line")}
              </button>
            </div>
          )}
          {error && <ErrorMessage error={error} />}
        </div>
        <footer className="dialog-footer">
          <button
            type="button"
            className="button secondary"
            onClick={close}
            disabled={busy}
          >
            {t("Cancel")}
          </button>
          <button className="button primary" disabled={busy}>
            {busy ? <LoaderCircle size={16} className="spin" /> : null}
            {t(busy ? "Saving…" : "Save")}
          </button>
        </footer>
      </form>
    </Dialog>
  );
}
export const options = (rows: Row[], label = "name", value = "id") =>
  rows.map((r) => ({
    value: String(r[value]),
    label: String(r[label] ?? r.id),
  }));
