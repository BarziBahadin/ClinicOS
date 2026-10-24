export function ageAt(
  birth: string | null,
  precision: string,
  at = new Date(),
): string {
  if (!birth || precision === "unknown") return "—";
  const b = new Date(`${birth}T12:00:00Z`);
  if (!Number.isFinite(b.getTime())) return "—";
  const parts = new Intl.DateTimeFormat("en-CA", {
    timeZone: "Asia/Baghdad",
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  }).formatToParts(at);
  const value = (type: string) =>
    Number(parts.find((p) => p.type === type)!.value);
  const year = value("year"),
    month = value("month") - 1,
    date = value("day");
  let age = year - b.getUTCFullYear();
  if (
    month < b.getUTCMonth() ||
    (month === b.getUTCMonth() && date < b.getUTCDate())
  )
    age--;
  return `${precision === "day" ? "" : "≈ "}${age}`;
}
export function searchText(value: string) {
  return value
    .normalize("NFKC")
    .replace(/[يى]/g, "ی")
    .replace(/ك/g, "ک")
    .replace(/[٠-٩]/g, (d) => String(d.charCodeAt(0) - 1632))
    .replace(/[۰-۹]/g, (d) => String(d.charCodeAt(0) - 1776))
    .toLocaleLowerCase()
    .trim();
}
