import assert from "node:assert/strict";
import { execFileSync } from "node:child_process";
import { createHash, randomBytes, randomUUID } from "node:crypto";
import { readFileSync, rmSync, mkdtempSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { dirname } from "node:path";
import pg from "pg";
import type { SupabaseClient } from "@supabase/supabase-js";
export async function recoveryCheck(
  db: pg.Client,
  admin: SupabaseClient,
  org: string,
) {
  const auditFolder = mkdtempSync(join(tmpdir(), "clinicos-audit-"));
  const auditEnv = {
    ...process.env,
    CLINICOS_AUDIT_DIR: auditFolder,
    CLINICOS_AUDIT_KEY: randomBytes(32).toString("base64"),
  };
  const auditRun = (args: string[], extra = auditEnv) =>
    execFileSync("npx", ["tsx", "scripts/operations-local.ts", ...args], {
      env: extra,
      encoding: "utf8",
      stdio: ["ignore", "pipe", "pipe"],
    });
  try {
    const audit = JSON.parse(auditRun(["audit-export"]));
    const verified = JSON.parse(auditRun(["audit-verify", audit.file]));
    assert.ok(verified.events > 0);
    assert.equal(verified.events, audit.events);
    assert.throws(() =>
      auditRun(["audit-verify", audit.file], {
        ...auditEnv,
        CLINICOS_AUDIT_KEY: randomBytes(32).toString("base64"),
      }),
    );
    const corrupt = readFileSync(audit.file);
    corrupt[Math.floor(corrupt.length / 2)] ^= 1;
    writeFileSync(join(auditFolder, "corrupt.aes"), corrupt);
    assert.throws(() =>
      auditRun(["audit-verify", join(auditFolder, "corrupt.aes")]),
    );
  } finally {
    rmSync(auditFolder, { recursive: true, force: true });
  }
  const env = {
    ...process.env,
    CLINICOS_BACKUP_KEY: randomBytes(32).toString("base64"),
  };
  const run = (args: string[], extra = env) =>
    execFileSync("npx", ["tsx", "scripts/backup-local.ts", ...args], {
      env: extra,
      encoding: "utf8",
      stdio: ["ignore", "pipe", "pipe"],
    });
  const created = run(["create"]);
  const archive = created.trim().split(": ").at(-1)!;
  let verified = "";
  const database = `clinicos_drill_${randomUUID().replaceAll("-", "")}`;
  const bucket = `recovery-${randomUUID()}`;
  let restored: pg.Client | undefined;
  try {
    const output = run(["verify", archive]);
    verified = dirname(output.trim().split(": ").at(-1)!);
    const objects = JSON.parse(
      readFileSync(`${verified}/objects.json`, "utf8"),
    ) as { key: string; mime_type: string; sha256: string; file: string }[];
    assert.ok(
      objects.length > 0,
      "The recovery drill must include real private object bytes",
    );
    assert.throws(() =>
      run(["verify", archive], {
        ...env,
        CLINICOS_BACKUP_KEY: randomBytes(32).toString("base64"),
      }),
    );
    execFileSync(
      "docker",
      [
        "exec",
        "supabase_db_clinicOS",
        "psql",
        "-U",
        "supabase_admin",
        "-d",
        "postgres",
        "-v",
        "ON_ERROR_STOP=1",
        "-c",
        `create database "${database}" owner supabase_admin`,
      ],
      { stdio: "pipe" },
    );
    execFileSync(
      "docker",
      [
        "exec",
        "-i",
        "supabase_db_clinicOS",
        "pg_restore",
        "-U",
        "supabase_admin",
        "-d",
        database,
        "--exit-on-error",
      ],
      {
        input: readFileSync(`${verified}/database.dump`),
        stdio: ["pipe", "ignore", "pipe"],
      },
    );
    const status = JSON.parse(
      execFileSync("npx", ["supabase", "status", "--output", "json"], {
        encoding: "utf8",
        stdio: ["ignore", "pipe", "pipe"],
      }),
    );
    const url = new URL(status.DB_URL);
    url.pathname = `/${database}`;
    restored = new pg.Client({ connectionString: url.href });
    await restored.connect();
    const original = (
      await db.query(
        "select count(*) from clinic.patients where organization_id=$1",
        [org],
      )
    ).rows[0].count;
    assert.equal(
      (
        await restored.query(
          "select count(*) from clinic.patients where organization_id=$1",
          [org],
        )
      ).rows[0].count,
      original,
    );
    assert.ok(
      (
        await restored.query(
          "select id from clinic.encounters where organization_id=$1 and status='signed'",
          [org],
        )
      ).rows.length > 0,
    );
    await assert.rejects(
      restored.query(
        "update clinic.encounters set diagnosis='Overwrite restored record' where organization_id=$1 and status='signed'",
        [org],
      ),
      /immutable/i,
    );
    assert.equal(
      (
        await restored.query(
          "select j.id from clinic.journals j left join clinic.journal_lines l on l.journal_id=j.id where j.organization_id=$1 group by j.id having count(l.id)<2 or sum(l.debit)<>sum(l.credit)",
          [org],
        )
      ).rows.length,
      0,
    );
    const { error } = await admin.storage.createBucket(bucket, {
      public: false,
    });
    if (error) throw error;
    for (const object of objects) {
      const bytes = readFileSync(`${verified}/${object.file}`);
      const uploaded = await admin.storage
        .from(bucket)
        .upload(object.key, bytes, { contentType: object.mime_type });
      if (uploaded.error) throw uploaded.error;
      const download = await admin.storage.from(bucket).download(object.key);
      if (download.error) throw download.error;
      assert.equal(
        createHash("sha256")
          .update(Buffer.from(await download.data.arrayBuffer()))
          .digest("hex"),
        object.sha256,
      );
      assert.ok(
        (
          await restored.query(
            "select id from clinic.media where object_key=$1 or preview_key=$1",
            [object.key],
          )
        ).rows.length > 0,
      );
    }
  } finally {
    if (restored) await restored.end();
    execFileSync(
      "docker",
      [
        "exec",
        "supabase_db_clinicOS",
        "psql",
        "-U",
        "supabase_admin",
        "-d",
        "postgres",
        "-v",
        "ON_ERROR_STOP=1",
        "-c",
        `drop database if exists "${database}"`,
      ],
      { stdio: "pipe" },
    );
    await admin.storage.emptyBucket(bucket);
    await admin.storage.deleteBucket(bucket);
    if (verified) rmSync(verified, { recursive: true, force: true });
    rmSync(dirname(archive), { recursive: true, force: true });
  }
}
