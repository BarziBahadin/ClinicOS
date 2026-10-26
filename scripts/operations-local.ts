import { execFileSync } from "node:child_process";
import {
  createCipheriv,
  createDecipheriv,
  createHash,
  randomBytes,
} from "node:crypto";
import {
  createReadStream,
  createWriteStream,
  openSync,
  readSync,
  closeSync,
  mkdirSync,
  renameSync,
  readdirSync,
  statSync,
  writeFileSync,
  appendFileSync,
} from "node:fs";
import { resolve } from "node:path";
import { Readable } from "node:stream";
import { pipeline } from "node:stream/promises";
import { createGzip, createGunzip } from "node:zlib";
import { createInterface } from "node:readline";
import { createClient } from "@supabase/supabase-js";
import pg from "pg";

// Local tools never accept a hosted database URL. Production scheduling/destinations
// must use a separately reviewed operator deployment, outside the application renderer.
const mode = process.argv[2] ?? "health";
if (
  ![
    "health",
    "audit-export",
    "audit-verify",
    "media-inspect",
    "media-cleanup",
  ].includes(mode)
)
  throw new Error("Unknown operations command");
const key = () => {
  const value = process.env.CLINICOS_AUDIT_KEY;
  const bytes = Buffer.from(value ?? "", "base64");
  if (bytes.length !== 32)
    throw new Error(
      "Set CLINICOS_AUDIT_KEY to a separately stored base64 32-byte key",
    );
  return bytes;
};
if (mode === "audit-verify") {
  const file = process.argv[3];
  if (!file) throw new Error("Supply an encrypted audit copy");
  const size = statSync(file).size;
  if (size < 29) throw new Error("Invalid audit copy");
  const descriptor = openSync(file, "r"),
    iv = Buffer.alloc(12),
    tag = Buffer.alloc(16);
  try {
    readSync(descriptor, iv, 0, 12, 0);
    readSync(descriptor, tag, 0, 16, size - 16);
  } finally {
    closeSync(descriptor);
  }
  const decipher = createDecipheriv("aes-256-gcm", key(), iv);
  decipher.setAuthTag(tag);
  const plain = createGunzip();
  const completed = pipeline(
    createReadStream(file, { start: 12, end: size - 17 }),
    decipher,
    plain,
  );
  void completed.catch(() => {});
  let count = 0,
    manifest = false,
    complete = false;
  const digest = createHash("sha256");
  for await (const line of createInterface({
    input: plain,
    crlfDelay: Infinity,
  })) {
    const item = JSON.parse(line);
    if (item.type === "manifest") {
      if (manifest) throw new Error("Duplicate manifest");
      manifest = item.version === 1;
    } else if (item.type === "event") {
      if (!manifest || complete) throw new Error("Invalid record order");
      digest.update(line + "\n");
      count++;
    } else if (item.type === "complete") {
      if (
        complete ||
        item.count !== count ||
        item.sha256 !== digest.digest("hex")
      )
        throw new Error("Audit copy integrity mismatch");
      complete = true;
    } else throw new Error("Unknown audit copy record");
  }
  await completed;
  if (!manifest || !complete) throw new Error("Incomplete audit copy");
  console.log(JSON.stringify({ verified: true, events: count }));
} else {
  const status = JSON.parse(
    execFileSync("npx", ["supabase", "status", "--output", "json"], {
      encoding: "utf8",
      stdio: ["ignore", "pipe", "pipe"],
    }),
  );
  const dbUrl = new URL(status.DB_URL);
  if (
    new URL(status.API_URL).hostname !== "127.0.0.1" ||
    !["127.0.0.1", "localhost"].includes(dbUrl.hostname)
  )
    throw new Error("Local operations refuse hosted targets");
  const db = new pg.Client({ connectionString: status.DB_URL });
  await db.connect();
  try {
    if (mode === "health") {
      const counts = (
        await db.query(
          "select (select count(*) from clinic.media where status='pending' and created_at<now()-interval '1 hour') pending_uploads_over_hour,(select count(*) from clinic.media where status='rejected') rejected_uploads,(select count(*) from clinic.tasks where completed_at is null and due_at<now()) overdue_tasks,(select count(*) from clinic.results where status not in ('closed','notified') and created_at<now()-interval '7 days') overdue_results,(select count(*) from clinic.audit_events where entity_type='memberships' and created_at>now()-interval '24 hours') access_changes_24h",
        )
      ).rows[0];
      const services: Record<string, string> = {};
      for (const name of ["clinicos-scanner", "clinicos-media-processor"]) {
        try {
          services[name] = execFileSync(
            "docker",
            ["inspect", "--format", "{{.State.Health.Status}}", name],
            { encoding: "utf8", stdio: ["ignore", "pipe", "ignore"] },
          ).trim();
        } catch {
          services[name] = "unavailable";
        }
      }
      let scannerDefinitionsFresh = false;
      try {
        const version = execFileSync(
          "docker",
          ["exec", "clinicos-scanner", "clamdscan", "--version"],
          { encoding: "utf8", stdio: ["ignore", "pipe", "ignore"] },
        ).trim();
        const date = Date.parse(version.split("/").slice(2).join("/"));
        scannerDefinitionsFresh =
          Number.isFinite(date) && Date.now() - date < 48 * 3600000;
      } catch {}
      let backupFresh = false;
      try {
        backupFresh = readdirSync(".local/backups", { withFileTypes: true })
          .filter((f) => f.isDirectory())
          .some((f) => {
            try {
              return (
                Date.now() -
                  statSync(`.local/backups/${f.name}/clinicos.backup`).mtimeMs <
                86400000
              );
            } catch {
              return false;
            }
          });
      } catch {}
      const healthy =
        Object.values(services).every((s) => s === "healthy") &&
        scannerDefinitionsFresh &&
        backupFresh;
      console.log(
        JSON.stringify({
          healthy,
          services,
          scannerDefinitionsFresh,
          backupFresh,
          counts,
        }),
      );
      if (!healthy) process.exitCode = 1;
    } else if (mode === "audit-export") {
      const folder = resolve(
        process.env.CLINICOS_AUDIT_DIR ?? ".local/audit-copies",
      );
      mkdirSync(folder, { recursive: true, mode: 0o700 });
      const file = resolve(
          folder,
          `audit-${new Date().toISOString().replaceAll(":", "-")}-${randomBytes(4).toString("hex")}.aes`,
        ),
        temporary = file + ".partial";
      const iv = randomBytes(12),
        cipher = createCipheriv("aes-256-gcm", key(), iv);
      writeFileSync(temporary, iv, { mode: 0o600 });
      await db.query("begin isolation level repeatable read read only");
      let count = 0;
      const digest = createHash("sha256");
      async function* records() {
        yield JSON.stringify({
          type: "manifest",
          version: 1,
          created_at: new Date().toISOString(),
        }) + "\n";
        let cursor: { created_at: string; id: string } | null = null;
        while (true) {
          const result: pg.QueryResult = await db.query(
            "select id,organization_id,actor_id,action,entity_id,entity_type,created_at::text from clinic.audit_events where ($1::timestamptz is null or (created_at,id)>($1::timestamptz,$2::uuid)) order by created_at,id limit 1000",
            [cursor?.created_at ?? null, cursor?.id ?? null],
          );
          if (!result.rows.length) break;
          for (const row of result.rows) {
            const line = JSON.stringify({ type: "event", ...row }) + "\n";
            digest.update(line);
            count++;
            yield line;
          }
          cursor = result.rows.at(-1);
        }
        yield JSON.stringify({
          type: "complete",
          count,
          sha256: digest.digest("hex"),
        }) + "\n";
      }
      await pipeline(
        Readable.from(records()),
        createGzip(),
        cipher,
        createWriteStream(temporary, { flags: "a", mode: 0o600 }),
      );
      appendFileSync(temporary, cipher.getAuthTag());
      await db.query("commit");
      renameSync(temporary, file);
      const hash = createHash("sha256");
      for await (const bytes of createReadStream(file)) hash.update(bytes);
      console.log(
        JSON.stringify({ file, events: count, sha256: hash.digest("hex") }),
      );
    } else {
      const admin = createClient(status.API_URL, status.SECRET_KEY, {
        auth: { persistSession: false, autoRefreshToken: false },
      });
      const result = await admin.rpc("media_maintenance", {
        expire_abandoned: mode === "media-cleanup",
      });
      if (result.error) throw new Error(result.error.message);
      let removed = 0;
      if (mode === "media-cleanup")
        for (const item of result.data.objects) {
          const deletion = await admin.storage
            .from("clinical")
            .remove([item.object_key]);
          if (deletion.error)
            throw new Error("Private temporary object cleanup failed");
          const recorded = await admin.rpc("media_cleanup_record", {
            media_id: item.media_id,
            object_key: item.object_key,
          });
          if (recorded.error)
            throw new Error("Cleanup evidence could not be recorded");
          removed++;
        }
      console.log(
        JSON.stringify({
          expired: result.data.expired,
          candidates: result.data.objects.length,
          removed,
        }),
      );
    }
  } finally {
    await db.end();
  }
}
