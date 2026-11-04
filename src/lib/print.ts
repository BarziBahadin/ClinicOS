import type { Locale, Row } from "../domain/types";

export type PrintDetails = {
  clinic?: Row & { name: string };
  metadata?: [string, string][];
  table?: {
    columns: { label: string; numeric?: boolean }[];
    rows: string[][];
  };
  sections?: { title: string; lines: string[]; fields?: [string, string][] }[];
  totals?: [string, string][];
  signature?: string;
  note?: string;
};

// Use textContent throughout: clinical text must never become HTML or fetch assets.
export function buildPrintDocument(
  title: string,
  rows: string[],
  locale: Locale,
  details: PrintDetails = {},
) {
  const section = document.createElement("section");
  section.id = "clinicos-print";
  section.dir = locale === "ckb" ? "rtl" : "ltr";
  section.lang = locale;
  function element(tag: string, value = "", className = "") {
    const node = document.createElement(tag);
    node.textContent = value;
    node.className = className;
    return node;
  }
  function lines(parent: HTMLElement, values: string[]) {
    for (const value of values.flatMap((line) => line.split(/\r?\n/))) {
      if (!value.trim()) continue;
      const p = element("p", value);
      p.dir = "auto";
      parent.append(p);
    }
  }
  const header = element("header", "", "print-header");
  if (details.clinic) {
    header.append(element("div", details.clinic.name, "print-clinic"));
    for (const value of [
      details.clinic.document_address,
      details.clinic.document_phone,
    ]) {
      if (!value) continue;
      const p = element("p");
      const isolated = element("bdi", String(value));
      isolated.dir = "auto";
      p.append(isolated);
      header.append(p);
    }
    title = title.replace(`${details.clinic.name} · `, "");
  }
  header.append(element("h1", title));
  section.append(header);
  if (details.metadata?.length) {
    const metadata = element("dl", "", "print-metadata");
    for (const [label, value] of details.metadata) {
      const item = element("div");
      const content = element("dd");
      const isolated = element("bdi", value);
      isolated.dir = "auto";
      content.append(isolated);
      item.append(element("dt", label), content);
      metadata.append(item);
    }
    section.append(metadata);
  }
  lines(section, rows);
  for (const group of details.sections ?? []) {
    const block = element("section", "", "print-block");
    const heading = element("h2");
    const title = element("bdi", group.title);
    title.dir = "auto";
    heading.append(title);
    block.append(heading);
    if (group.fields) {
      const fields = element("dl", "", "print-instructions");
      for (const [label, value] of group.fields) {
        const item = element("div");
        const content = element("dd");
        const isolated = element("bdi", value);
        isolated.dir = "auto";
        content.append(isolated);
        item.append(element("dt", label), content);
        fields.append(item);
      }
      block.append(fields);
    }
    lines(block, group.lines);
    section.append(block);
  }
  if (details.table) {
    const table = document.createElement("table");
    const head = table.createTHead().insertRow();
    for (const column of details.table.columns) {
      const th = document.createElement("th");
      th.scope = "col";
      th.textContent = column.label;
      if (column.numeric) th.className = "print-number";
      head.append(th);
    }
    const body = table.createTBody();
    for (const values of details.table.rows) {
      const row = body.insertRow();
      values.forEach((value, index) => {
        const cell = row.insertCell();
        const isolated = element("bdi", value);
        isolated.dir = "auto";
        cell.append(isolated);
        if (details.table!.columns[index]?.numeric)
          cell.className = "print-number";
      });
    }
    section.append(table);
  }
  if (details.totals?.length) {
    const totals = element("dl", "", "print-totals");
    for (const [label, value] of details.totals) {
      const row = element("div");
      const content = element("dd");
      const isolated = element("bdi", value);
      isolated.dir = "auto";
      content.append(isolated);
      row.append(element("dt", label), content);
      totals.append(row);
    }
    section.append(totals);
  }
  const footer = element("footer", "", "print-footer");
  if (details.signature)
    footer.append(element("p", details.signature, "print-signature"));
  if (details.note) lines(footer, [details.note]);
  footer.append(element("div", details.clinic?.name ?? "ClinicOS"));
  section.append(footer);
  return section;
}

export function printDocument(
  title: string,
  rows: string[],
  locale: Locale,
  details: PrintDetails = {},
) {
  document.getElementById("clinicos-print")?.remove();
  const section = buildPrintDocument(title, rows, locale, details);
  document.body.append(section);
  const previousTitle = document.title;
  document.title = title;
  const cleanup = () => {
    section.remove();
    document.title = previousTitle;
    window.removeEventListener("afterprint", cleanup);
  };
  window.addEventListener("afterprint", cleanup);
  try {
    window.print();
  } catch (error) {
    cleanup();
    throw error;
  }
}
