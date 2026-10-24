import type { Locale } from "../domain/types";
export const formatDate = (v: unknown, time = false, locale: Locale = "en") =>
  v
    ? new Intl.DateTimeFormat(locale === "ckb" ? "ckb-IQ" : "en-GB", {
        timeZone: "Asia/Baghdad",
        day: "numeric",
        month: "short",
        year: "numeric",
        ...(time ? ({ hour: "2-digit", minute: "2-digit" } as const) : {}),
      }).format(new Date(String(v)))
    : "—";
export const day = (v: unknown) =>
  new Intl.DateTimeFormat("en-CA", {
    timeZone: "Asia/Baghdad",
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  }).format(new Date(String(v)));
export const str = (r: Record<string, unknown>, k: string) =>
  String(r[k] ?? "—");
