import type { Locale } from "../domain/types";
export function printDocument(title: string, rows: string[], locale: Locale) {
  document.getElementById("clinicos-print")?.remove();
  const section = document.createElement("section");
  section.id = "clinicos-print";
  section.dir = locale === "ckb" ? "rtl" : "ltr";
  section.lang = locale;
  const heading = document.createElement("h1");
  heading.textContent = title;
  section.append(heading);
  for (const row of rows.flatMap((text) => text.split(/\r?\n/))) {
    const p = document.createElement("p");
    p.dir = "auto";
    p.style.whiteSpace = "pre-wrap";
    p.textContent = row;
    section.append(p);
  }
  document.body.append(section);
  const cleanup = () => {
    section.remove();
    window.removeEventListener("afterprint", cleanup);
  };
  window.addEventListener("afterprint", cleanup);
  window.print();
}
