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
