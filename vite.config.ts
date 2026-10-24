import { defineConfig } from "vitest/config";
import react from "@vitejs/plugin-react";
import { loadEnv } from "vite";
export default defineConfig(({ mode }) => {
  const env = loadEnv(mode, process.cwd(), "VITE_");
  const url = env.VITE_SUPABASE_URL ? new URL(env.VITE_SUPABASE_URL) : null;
  if (
    url &&
    (url.username ||
      url.password ||
      !(
        ["https:"].includes(url.protocol) ||
        (url.protocol === "http:" &&
          ["127.0.0.1", "localhost"].includes(url.hostname))
      ))
  )
    throw new Error("Supabase must use HTTPS or local development loopback.");
  const key = env.VITE_SUPABASE_PUBLISHABLE_KEY ?? "";
  if (key && !key.startsWith("sb_publishable_"))
    throw new Error(
      "Use a Supabase publishable key in the frontend. Privileged and legacy keys are not accepted.",
    );
  const origin = url?.origin ?? "http://127.0.0.1:54321";
  const policy = `default-src 'self'; script-src 'self'${mode === "development" ? " 'unsafe-inline'" : ""}; style-src 'self' 'unsafe-inline'; font-src 'self'; connect-src 'self' ${origin} ${mode === "development" ? "ws://127.0.0.1:5173" : ""}; img-src 'self' data: blob: ${origin}; object-src 'none'; base-uri 'self'; form-action 'self'`;
  return {
    base: "./",
    plugins: [
      react(),
      {
        name: "clinic-security-policy",
        transformIndexHtml() {
          return [
            {
              tag: "meta",
              attrs: {
                "http-equiv": "Content-Security-Policy",
                content: policy,
              },
              injectTo: "head-prepend",
            },
          ];
        },
        generateBundle() {
          this.emitFile({
            type: "asset",
            fileName: "runtime.json",
            source: JSON.stringify({ apiOrigin: origin }),
          });
          this.emitFile({
            type: "asset",
            fileName: "_headers",
            source: `/*\n  Content-Security-Policy: ${policy}; frame-ancestors 'none'\n  X-Content-Type-Options: nosniff\n  Referrer-Policy: no-referrer\n  Cache-Control: no-store\n  X-Frame-Options: DENY\n`,
          });
        },
      },
    ],
    server: {
      host: "127.0.0.1",
      port: 5173,
      strictPort: true,
      headers: {
        "Referrer-Policy": "no-referrer",
        "X-Content-Type-Options": "nosniff",
      },
    },
    build: {
      sourcemap: false,
      rolldownOptions: {
        output: {
          strictExecutionOrder: true,
          codeSplitting: {
            groups: [
              {
                name: "react",
                test: /node_modules\/(react|react-dom|scheduler)\//,
                priority: 20,
              },
              {
                name: "supabase",
                test: /node_modules\/@supabase\//,
                priority: 15,
              },
              { name: "validation", test: /node_modules\/zod\//, priority: 10 },
            ],
          },
        },
      },
    },
    test: {
      include: ["tests/**/*.test.{ts,tsx}"],
      testTimeout: 30000,
      hookTimeout: 30000,
      fileParallelism: false,
    },
  };
});
