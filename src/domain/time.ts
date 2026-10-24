import { Temporal } from "@js-temporal/polyfill";
export function clinicDateTime(input: string, zone = "Asia/Baghdad"): string {
  return Temporal.PlainDateTime.from(input)
    .toZonedDateTime(zone, { disambiguation: "reject" })
    .toInstant()
    .toString();
}
