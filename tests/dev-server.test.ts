import { afterEach, expect, it } from "vitest";
import { mkdtemp, rm, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { createServer } from "node:http";
import { ensureDevServer } from "../scripts/dev-server";

const cleanup: (() => Promise<unknown>)[] = [];
afterEach(async () => {
  for (const close of cleanup.reverse()) await close();
  cleanup.length = 0;
});
async function workspace() {
  const root = await mkdtemp(join(tmpdir(), "clinicos-dev-test-"));
  cleanup.push(() => rm(root, { recursive: true, force: true }));
  await writeFile(join(root, "index.html"), "<h1>Synthetic dev fixture</h1>");
  return root;
}
it("starts once and reuses the same checkout without stopping its server", async () => {
  const root = await workspace();
  const first = await ensureDevServer(root, 0);
  cleanup.push(() => first.server!.close());
  const port = Number(new URL(first.url).port);
  const second = await ensureDevServer(root, port);
  expect(second.server).toBeNull();
  expect(second.url).toBe(first.url);
  expect(await (await fetch(first.url)).text()).toContain(
    "Synthetic dev fixture",
  );
});
it("refuses to reuse or stop another checkout on the same port", async () => {
  const firstRoot = await workspace(),
    secondRoot = await workspace();
  const first = await ensureDevServer(firstRoot, 0);
  cleanup.push(() => first.server!.close());
  await expect(
    ensureDevServer(secondRoot, Number(new URL(first.url).port)),
  ).rejects.toThrow("occupied by another application or checkout");
  expect((await fetch(first.url)).ok).toBe(true);
});
it("leaves an unrelated application running and reports the conflict clearly", async () => {
  const root = await workspace();
  const other = createServer((_request, response) =>
    response.end("Other application"),
  );
  await new Promise<void>((resolve) => other.listen(0, "127.0.0.1", resolve));
  cleanup.push(
    () =>
      new Promise<void>((resolve, reject) =>
        other.close((error) => (error ? reject(error) : resolve())),
      ),
  );
  const port = (other.address() as { port: number }).port;
  await expect(ensureDevServer(root, port)).rejects.toThrow(
    `Port ${port} is occupied`,
  );
  expect(await (await fetch(`http://127.0.0.1:${port}/`)).text()).toBe(
    "Other application",
  );
});
it("shares one server when two terminals start the same checkout together", async () => {
  const root = await workspace();
  const reservation = createServer();
  await new Promise<void>((resolve) =>
    reservation.listen(0, "127.0.0.1", resolve),
  );
  const port = (reservation.address() as { port: number }).port;
  await new Promise<void>((resolve) => reservation.close(() => resolve()));
  const launches = await Promise.all([
    ensureDevServer(root, port),
    ensureDevServer(root, port),
  ]);
  for (const launch of launches)
    if (launch.server) cleanup.push(() => launch.server!.close());
  expect(launches.filter((launch) => launch.server)).toHaveLength(1);
  expect(launches[0].url).toBe(launches[1].url);
  expect((await fetch(launches[0].url)).ok).toBe(true);
});
