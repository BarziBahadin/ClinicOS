import { useState } from "react";
import { useRecordPage } from "./RecordPager";
import type { Field, T } from "./ui";
export function ResourceSelect({
  field,
  t,
  recordType = "clinic_resources",
}: {
  field: Field;
  t: T;
  recordType?: "clinic_resources" | "suppliers";
}) {
  const page = useRecordPage(recordType, true);
  const [value, setValue] = useState(String(field.value ?? ""));
  return (
    <div className="patient-select">
      <input
        type="search"
        value={page.query}
        onChange={(e) => page.setQuery(e.target.value)}
        placeholder={t(
          recordType === "suppliers"
            ? "Search suppliers"
            : "Search rooms and devices",
        )}
      />
      <select
        id={`field-${field.name}`}
        name={field.name}
        value={value}
        onChange={(e) => setValue(e.target.value)}
      >
        <option value="">
          {t(
            recordType === "suppliers"
              ? "No preferred supplier"
              : "No room or device",
          )}
        </option>
        {value && !page.items.some((r) => r.id === value) && (
          <option value={value}>
            {t(
              recordType === "suppliers"
                ? "Current supplier"
                : "Current room / device",
            )}
          </option>
        )}
        {page.items
          .filter((row) => row.active)
          .map((row) => (
            <option key={row.id} value={row.id}>
              {String(row.name)}
            </option>
          ))}
      </select>
      <div className="inline-actions">
        <button
          type="button"
          disabled={!page.hasPrevious || page.loading}
          onClick={page.previous}
        >
          {t("Previous")}
        </button>
        <button
          type="button"
          disabled={!page.more || page.loading}
          onClick={page.next}
        >
          {t("Next")}
        </button>
      </div>
      {page.error && <span role="alert">{page.error}</span>}
    </div>
  );
}
