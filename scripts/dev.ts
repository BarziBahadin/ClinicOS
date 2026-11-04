import { spawn } from "node:child_process";
import { createRequire } from "node:module";
import { fileURLToPath } from "node:url";
import type { ViteDevServer } from "vite";
import { ensureDevServer } from "./dev-server";

const root = fileURLToPath(new URL("../", import.meta.url));
let ownedServer: ViteDevServer | null = null;
try {
  const { server, url } = await ensureDevServer(root);
  ownedServer = server;
  console.log(
    server
      ? `ClinicOS is running at ${url}`
      : `ClinicOS is already running at ${url} — reusing the existing server.`,
  );
  if (process.argv.includes("--desktop")) {
    const electron = createRequire(import.meta.url)("electron") as string;
    const env = { ...process.env };
    delete env.ELECTRON_RUN_AS_NODE;
    const child = spawn(electron, [root], { cwd: root, stdio: "inherit", env });
    try {
      process.exitCode = await new Promise<number>((resolve, reject) => {
        child.once("error", reject);
        child.once("exit", (code) => resolve(code ?? 1));
      });
    } finally {
      await server?.close();
    }
  } else {
    server?.bindCLIShortcuts({ print: true });
  }
} catch (error) {
  await ownedServer?.close();
  console.error(error instanceof Error ? error.message : String(error));
  process.exitCode = 1;
}
