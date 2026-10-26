import Decimal from "decimal.js";
/** RFC 4180 fields, including quoted commas, newlines and escaped quotes. */
export function parseCsv(text: string): string[][] {
  const rows: string[][] = [];
  let row: string[] = [],
    value = "",
    quoted = false,
    closed = false;
  const source = text.replace(/^\uFEFF/, "");
  for (let i = 0; i < source.length; i++) {
    const c = source[i];
    if (quoted) {
      if (c === '"') {
        if (source[i + 1] === '"') {
          value += '"';
          i++;
        } else {
          quoted = false;
          closed = true;
        }
      } else value += c;
      continue;
    }
    if (c === '"') {
      if (value || closed) throw new Error("Invalid CSV quoting");
      quoted = true;
      continue;
    }
    if (c === "," || c === "\n" || c === "\r") {
      row.push(value);
      value = "";
      closed = false;
      if (c !== ",") {
        if (c === "\r" && source[i + 1] === "\n") i++;
        if (row.some((x) => x.length)) rows.push(row);
        row = [];
      }
      continue;
    }
    if (closed)
      throw new Error("Unexpected characters after a quoted CSV field");
    value += c;
  }
  if (quoted) throw new Error("Unclosed CSV quote");
  if (value || row.length || closed) {
    row.push(value);
    if (row.some((x) => x.length)) rows.push(row);
  }
  return rows;
}
export function statementCsv(text: string) {
  if (new TextEncoder().encode(text).length > 180000)
    throw new Error("Import a CSV smaller than 180 KB.");
  const [header, ...rows] = parseCsv(text);
  const expected = [
    "date",
    "account",
    "currency",
    "amount",
    "reference",
    "statement id",
  ];
  if (
    !header ||
    header.length !== 6 ||
    header.some(
      (value, index) => value.trim().toLowerCase() !== expected[index],
    )
  )
    throw new Error("Use the statement CSV template headings.");
  if (rows.length < 1 || rows.length > 1000)
    throw new Error("Import 1–1000 statement lines.");
  return rows.map((row, index) => {
    if (row.length !== 6)
      throw new Error(`Line ${index + 2} must have six fields.`);
    const [posted_on, account, currency, amount, reference, external_id] =
      row.map((x) => x.trim());
    if (
      !/^\d{4}-\d{2}-\d{2}$/.test(posted_on) ||
      !["bank", "card"].includes(account) ||
      !["IQD", "USD"].includes(currency) ||
      !/^[-+]?\d+(\.\d+)?$/.test(amount) ||
      !external_id ||
      !reference
    )
      throw new Error(`Line ${index + 2} has invalid or missing fields.`);
    const decimal = new Decimal(amount);
    if (
      decimal.isZero() ||
      decimal.decimalPlaces() > (currency === "USD" ? 2 : 3)
    )
      throw new Error(`Line ${index + 2} has invalid currency precision.`);
    return {
      posted_on,
      account,
      currency,
      amount: decimal.toFixed(),
      reference,
      external_id,
    };
  });
}
export function csvText(rows: unknown[][]): string {
  return (
    "\uFEFF" +
    rows
      .map((row) =>
        row
          .map(
            (value) =>
              '"' +
              String(value ?? "")
                .replace(/^[\t\r\n ]*[=+@-]/, "'$&")
                .replaceAll('"', '""') +
              '"',
          )
          .join(","),
      )
      .join("\r\n")
  );
}
