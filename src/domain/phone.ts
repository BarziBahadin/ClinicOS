import { parsePhoneNumberFromString } from "libphonenumber-js";
export function normalizePhone(input: string): string | null {
  if (!input.trim()) return null;
  const phone = parsePhoneNumberFromString(input, "IQ");
  if (!phone?.isValid())
    throw new Error("Enter a valid Iraqi or international phone number.");
  return phone.number;
}
