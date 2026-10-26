import { execFileSync, spawn } from "node:child_process";
import {
  createCipheriv,
  createDecipheriv,
  createHash,
  randomBytes,
} from "node:crypto";
import {
  createReadStream,
  createWriteStream,
  mkdirSync,
  writeFileSync,
  appendFileSync,
  statSync,
  renameSync,
  unlinkSync,
  rmSync,
  openSync,
  closeSync,
  readSync,
} from "node:fs";
import { createGzip, createGunzip } from "node:zlib";
import { pipeline } from "node:stream/promises";
import { Readable } from "node:stream";
import { createInterface } from "node:readline";
import { createClient } from "@supabase/supabase-js";
import pg from "pg";
// This executable deliberately targets local development only. Hosted backup configuration
// requires the selected project's backup/export policy and an independent destination.
const mode = process.argv[2] ?? "create",
  input = process.argv[3];
const encoded = process.env.CLINICOS_BACKUP_KEY;
if (!encoded || Buffer.from(encoded, "base64").length !== 32)
  throw new Error(
    "Set CLINICOS_BACKUP_KEY to a separately stored, base64-encoded 32-byte encryption key.",
  );
const key = Buffer.from(encoded, "base64");
mkdirSync(".local/backups", { recursive: true, mode: 0o700 });
if (mode === "create") {
  const status = JSON.parse(
    execFileSync("npx", ["supabase", "status", "--output", "json"], {
      encoding: "utf8",
      stdio: ["ignore", "pipe", "pipe"],
    }),
  );
  if (!/^http:\/\/127\.0\.0\.1:/.test(status.API_URL))
    throw new Error("Local backup script cannot operate on hosted projects.");
  const folder = `.local/backups/${new Date().toISOString().replaceAll(":", "-")}`;
  mkdirSync(folder, { mode: 0o700 });
  const dump = `${folder}/database.dump`;
  const dumpProcess = spawn(
    "docker",
    [
      "exec",
      "supabase_db_clinicOS",
      "pg_dump",
      "-U",
      "postgres",
      "-d",
      "postgres",
      "-Fc",
    ],
    { stdio: ["ignore", "pipe", "inherit"] },
  );
  await Promise.all([
    pipeline(dumpProcess.stdout, createWriteStream(dump, { mode: 0o600 })),
    new Promise<void>((resolve, reject) => {
      dumpProcess.on("error", reject);
      dumpProcess.on("exit", (code) =>
        code === 0 ? resolve() : reject(new Error("Database export failed")),
      );
    }),
  ]);
  const dumpDigest = createHash("sha256");
  for await (const chunk of createReadStream(dump)) dumpDigest.update(chunk);
  const dumpHash = dumpDigest.digest("hex");
  const admin = createClient(status.API_URL, status.SECRET_KEY, {
      auth: { persistSession: false },
    }),
    db = new pg.Client({ connectionString: status.DB_URL });
  await db.connect();
  const { rows } = await db.query(
    "select object_key,mime_type from clinic.media where status='ready' union all select preview_key as object_key,'image/png' as mime_type from clinic.media where status='ready' and preview_key is not null order by object_key",
  );
  await db.end();
  const file = `${folder}/clinicos.backup`,
    temporary = `${file}.partial`,
    iv = randomBytes(12),
    cipher = createCipheriv("aes-256-gcm", key, iv);
  writeFileSync(temporary, iv, { mode: 0o600 });
  let count = 0;
  async function* records() {
    yield Buffer.from(
      JSON.stringify({
        type: "manifest",
        version: 1,
        created_at: new Date().toISOString(),
      }) + "\n",
    );
    for await (const chunk of createReadStream(dump))
      yield Buffer.from(
        JSON.stringify({
          type: "database",
          bytes: (chunk as Buffer).toString("base64"),
        }) + "\n",
      );
    for (const row of rows) {
      const { data, error } = await admin.storage
        .from("clinical")
        .download(row.object_key);
      if (error) throw error;
      const bytes = Buffer.from(await data.arrayBuffer());
      yield Buffer.from(
        JSON.stringify({
          type: "object",
          key: row.object_key,
          mime: row.mime_type,
          sha256: createHash("sha256").update(bytes).digest("hex"),
          bytes: bytes.toString("base64"),
        }) + "\n",
      );
      count++;
    }
    yield Buffer.from(
      JSON.stringify({
        type: "complete",
        objects: count,
        database_sha256: dumpHash,
      }) + "\n",
    );
  }
  try {
    await pipeline(
      Readable.from(records()),
      createGzip(),
      cipher,
      createWriteStream(temporary, { flags: "a" }),
    );
    appendFileSync(temporary, cipher.getAuthTag());
    renameSync(temporary, file);
    console.log(`Encrypted local database + media backup: ${file}`);
  } finally {
    unlinkSync(dump);
  }
} else if (mode === "verify") {
  if (!input)
    throw new Error("Usage: backup-local.ts verify <encrypted-backup>");
  const size = statSync(input).size;
  if (size < 29) throw new Error("Backup is incomplete");
  const fd = openSync(input, "r"),
    iv = Buffer.alloc(12),
    tag = Buffer.alloc(16);
  readSync(fd, iv, 0, 12, 0);
  readSync(fd, tag, 0, 16, size - 16);
  closeSync(fd);
  const decipher = createDecipheriv("aes-256-gcm", key, iv);
  decipher.setAuthTag(tag);
  const stream = createGunzip();
  const decrypt = pipeline(
    createReadStream(input, { start: 12, end: size - 17 }),
    decipher,
    stream,
  );
  const lines = createInterface({ input: stream, crlfDelay: Infinity });
  const verifiedDestination = `.local/backups/verified-${Date.now()}`;
  const destination = `${verifiedDestination}.partial`;
  mkdirSync(destination, { mode: 0o700 });
  const dump = `${destination}/database.dump`;
  writeFileSync(dump, "", { mode: 0o600 });
  const digest = createHash("sha256");
  let count = 0,
    complete = false;
  const objects: {
    key: string;
    mime_type: string;
    sha256: string;
    file: string;
  }[] = [];
  const verify = async () => {
    for await (const line of lines) {
      const r = JSON.parse(line);
      if (complete) throw new Error("Unexpected data after backup completion");
      if (r.type === "manifest") {
        if (r.version !== 1) throw new Error("Unsupported backup version");
      } else if (r.type === "database") {
        const b = Buffer.from(r.bytes, "base64");
        appendFileSync(dump, b);
        digest.update(b);
      } else if (r.type === "object") {
        const b = Buffer.from(r.bytes, "base64");
        if (createHash("sha256").update(b).digest("hex") !== r.sha256)
          throw new Error("Object checksum mismatch");
        const safe = createHash("sha256").update(r.key).digest("hex");
        writeFileSync(`${destination}/${safe}`, b, { mode: 0o600 });
        objects.push({
          key: r.key,
          mime_type: r.mime,
          sha256: r.sha256,
          file: safe,
        });
        count++;
      } else if (r.type === "complete") {
        if (r.objects !== count || r.database_sha256 !== digest.digest("hex"))
          throw new Error("Backup manifest mismatch");
        complete = true;
      } else throw new Error("Unknown backup record");
    }
    if (!complete) throw new Error("Backup is incomplete");
  };
  try {
    await Promise.all([verify(), decrypt]);
    writeFileSync(
      `${destination}/objects.json`,
      JSON.stringify(objects, null, 2),
      { mode: 0o600 },
    );
    renameSync(destination, verifiedDestination);
  } catch (error) {
    stream.destroy();
    lines.close();
    await decrypt.catch(() => {});
    rmSync(destination, { recursive: true, force: true });
    throw error;
  }
  console.log(
    `Verified encrypted backup: ${count} media objects. Local restore input: ${verifiedDestination}/database.dump`,
  );
} else throw new Error("Supported modes: create, verify");
