import { describe, expect, it } from "vitest";
import { createRequire } from "node:module";
const { bundlePath } = createRequire(import.meta.url)(
  "../electron/bundle-path.cjs",
);
describe("Desktop private bundle protocol", () => {
  it("serves only the application bundle under the fixed desktop origin", () => {
    expect(bundlePath("/bundle", "clinicos://app/index.html")).toBe(
      "/bundle/index.html",
    );
    expect(bundlePath("/bundle", "clinicos://app/assets/main.js")).toBe(
      "/bundle/assets/main.js",
    );
    for (const url of [
      "clinicos://other/index.html",
      "clinicos://app/../secret",
      "clinicos://app/assets/%2e%2e/%2e%2e/secret",
      "clinicos://app/assets/%2f..%2f..%2fsecret",
      "clinicos://app/assets/a%00.js",
      "file:///bundle/index.html",
      "clinicos://user@app/index.html",
    ])
      expect(bundlePath("/bundle", url)).toBeNull();
    expect(
      bundlePath("/bundle", "clinicos://app/index.html", "POST"),
    ).toBeNull();
  });
});
