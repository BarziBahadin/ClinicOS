// @vitest-environment happy-dom
import { afterEach, expect, it, vi } from "vitest";
import { printDocument } from "../src/lib/print";
const originalPrint = Object.getOwnPropertyDescriptor(window, "print");
afterEach(() => {
  if (originalPrint) Object.defineProperty(window, "print", originalPrint);
  else Reflect.deleteProperty(window, "print");
  document.getElementById("clinicos-print")?.remove();
  vi.restoreAllMocks();
});
it("prints mixed-direction lines independently, preserves literal text and removes the temporary document after printing", () => {
  const print = vi.fn();
  Object.defineProperty(window, "print", {
    value: print,
    configurable: true,
    writable: true,
  });
  printDocument(
    "بەڵگە / Document",
    [
      "نەخۆش: تاقیکردنەوە\nEnglish instructions.",
      "<img src=x onerror=alert(1)>",
    ],
    "ckb",
  );
  const section = document.getElementById("clinicos-print")!;
  expect(print).toHaveBeenCalledOnce();
  expect(section.dir).toBe("rtl");
  expect(section.lang).toBe("ckb");
  const paragraphs = section.querySelectorAll("p");
  expect([...paragraphs].map((p) => p.textContent)).toEqual([
    "نەخۆش: تاقیکردنەوە",
    "English instructions.",
    "<img src=x onerror=alert(1)>",
  ]);
  expect([...paragraphs].every((p) => p.dir === "auto")).toBe(true);
  expect(section.querySelector("img")).toBeNull();
  window.dispatchEvent(new Event("afterprint"));
  expect(document.getElementById("clinicos-print")).toBeNull();
});

it("renders clinic details, isolated identifiers, table headers and totals without interpreting HTML", () => {
  Object.defineProperty(window, "print", {
    value: vi.fn(),
    configurable: true,
  });
  document.title = "ClinicOS";
  printDocument("Invoice", [], "ckb", {
    clinic: {
      id: "clinic",
      name: "Test clinic",
      document_address: "Test address",
      document_phone: "+964 750 000 0000",
    },
    metadata: [
      ["Patient", "تاقیکردنەوە"],
      ["Invoice number", "INV-001"],
    ],
    table: {
      columns: [{ label: "Description" }, { label: "Amount", numeric: true }],
      rows: [["<img src=x>", "USD 10.00"]],
    },
    totals: [["Balance", "USD 10.00"]],
  });
  const section = document.getElementById("clinicos-print")!;
  expect(section.querySelector(".print-clinic")?.textContent).toBe(
    "Test clinic",
  );
  expect(section.textContent).toContain("+964 750 000 0000");
  expect(section.querySelector("th")?.scope).toBe("col");
  expect(section.querySelector("tbody td")?.textContent).toBe("<img src=x>");
  expect(section.querySelector("img")).toBeNull();
  expect(section.querySelector("dd bdi")?.getAttribute("dir")).toBe("auto");
  expect(document.title).toBe("Invoice");
  window.dispatchEvent(new Event("afterprint"));
  expect(document.title).toBe("ClinicOS");
});

it("removes sensitive print content if the print dialog fails", () => {
  Object.defineProperty(window, "print", {
    value: () => {
      throw new Error("Printer unavailable");
    },
    configurable: true,
  });
  expect(() => printDocument("Document", ["Private content"], "en")).toThrow(
    "Printer unavailable",
  );
  expect(document.getElementById("clinicos-print")).toBeNull();
});
