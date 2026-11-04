import { createHash } from "node:crypto";
import { realpathSync } from "node:fs";
import { createServer } from "vite";

export async function ensureDevServer(root: string, port = 5173) {
  const workspace = createHash("sha256")
    .update(realpathSync(root))
    .digest("hex");
  const url = `http://127.0.0.1:${port}/`;
  async function alreadyRunning() {
    try {
      const response = await fetch(new URL("@vite/client", url), {
        method: "HEAD",
        redirect: "error",
        signal: AbortSignal.timeout(1000),
      });
      return (
        response.ok &&
        response.headers.get("x-clinicos-workspace") === workspace
      );
    } catch {
      return false;
    }
  }
  if (await alreadyRunning()) return { server: null, url };
  const server = await createServer({
    root,
    server: {
      host: "127.0.0.1",
      port,
      strictPort: true,
      headers: { "X-ClinicOS-Workspace": workspace },
    },
  });
  try {
    await server.listen();
    return { server, url: server.resolvedUrls!.local[0] };
  } catch (error) {
    await server.close();
    // Another launch can win the port between our check and listen().
    if (await alreadyRunning()) return { server: null, url };
    if (error instanceof Error && error.message.includes("already in use"))
      throw new Error(
        `Port ${port} is occupied by another application or checkout. Stop that server, then run npm run dev again.`,
      );
    throw error;
  }
}
