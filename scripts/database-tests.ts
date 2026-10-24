import assert from "node:assert/strict";
import { execFileSync } from "node:child_process";
import { randomUUID } from "node:crypto";
import { createClient, type SupabaseClient } from "@supabase/supabase-js";
import pg from "pg";
import { recoveryCheck } from "./recovery-check";
import { antivirusPdf } from "./test-fixtures";
import { TOTP } from "otpauth";
const status = JSON.parse(
  execFileSync("npx", ["supabase", "status", "--output", "json"], {
    encoding: "utf8",
    stdio: ["ignore", "pipe", "pipe"],
  }),
);
if (!/^http:\/\/127\.0\.0\.1:/.test(status.API_URL))
  throw new Error("Database tests are restricted to the local stack.");
const admin = createClient(status.API_URL, status.SECRET_KEY, {
  auth: { persistSession: false },
});
const db = new pg.Client({ connectionString: status.DB_URL });
await db.connect();
const org = randomUUID(),
  other = randomUUID(),
  branch = randomUUID();
const ids: string[] = [];
const clients: Record<string, SupabaseClient> = {};
let passed = 0;
async function test(name: string, fn: () => Promise<void>) {
  await fn();
  passed++;
  console.log(`PASS ${name}`);
}
async function command(
  role: string,
  kind: string,
  payload: Record<string, unknown>,
  id = randomUUID(),
) {
  return clients[role].rpc("command", { kind, payload, request_id: id });
}
function success<T extends { error: unknown }>(r: T): T {
  assert.equal(r.error, null, JSON.stringify(r.error));
  return r;
}
try {
  await db.query(
    "insert into clinic.organizations(id,name,require_mfa) values($1,$2,false),($3,$4,false)",
    [org, "Integration test clinic", other, "Isolation test clinic"],
  );
  await db.query(
    "insert into clinic.branches(id,organization_id,name) values($1,$2,'Test branch')",
    [branch, org],
  );
  for (const role of ["owner", "doctor", "receptionist", "accountant"]) {
    const email = `test-${role}-${org}@clinicos.test`,
      password = `Test-${randomUUID()}!`;
    const { data, error } = await admin.auth.admin.createUser({
      email,
      password,
      email_confirm: true,
    });
    if (error) throw error;
    ids.push(data.user.id);
    await db.query(
      "insert into clinic.memberships(organization_id,user_id,display_name,role) values($1,$2,$3,$3)",
      [org, data.user.id, role],
    );
    const c = createClient(status.API_URL, status.PUBLISHABLE_KEY, {
      auth: { persistSession: false },
    });
    success(await c.auth.signInWithPassword({ email, password }));
    clients[role] = c;
  }
  await test("Public signup is blocked while invited individual staff can sign in", async () => {
    const c = createClient(status.API_URL, status.PUBLISHABLE_KEY, {
      auth: { persistSession: false },
    });
    const result = await c.auth.signUp({
      email: `blocked-${org}@clinicos.test`,
      password: `Test-${randomUUID()}!`,
    });
    assert.ok(result.error);
    assert.equal(result.error.code, "signup_disabled");
  });
  await test("One-time recovery proof works in a fresh session and cannot be replayed", async () => {
    const {
      data: { user },
    } = await clients.accountant.auth.getUser();
    const link = success(
      await admin.auth.admin.generateLink({
        type: "recovery",
        email: user!.email!,
      }),
    );
    const c = createClient(status.API_URL, status.PUBLISHABLE_KEY, {
      auth: { persistSession: false },
    });
    success(
      await c.auth.verifyOtp({
        token_hash: link.data.properties!.hashed_token,
        type: "recovery",
      }),
    );
    success(await c.auth.updateUser({ password: `New-${randomUUID()}!` }));
    const second = createClient(status.API_URL, status.PUBLISHABLE_KEY, {
      auth: { persistSession: false },
    });
    assert.ok(
      (
        await second.auth.verifyOtp({
          token_hash: link.data.properties!.hashed_token,
          type: "recovery",
        })
      ).error,
    );
    await c.auth.signOut({ scope: "local" });
  });
  let patientId = "",
    invoiceId = "",
    encounterId = "";
  await test("Receptionist registration supports shared family phones and missing birth dates", async () => {
    const p = {
      full_name: "Test patient",
      phone: "+9647501234567",
      birth_precision: "unknown",
      gender: "unknown",
      language: "ckb",
    };
    const first = success(await command("receptionist", "patient.create", p));
    patientId = first.data.id;
    success(
      await command("receptionist", "patient.create", {
        ...p,
        full_name: "Test minor",
        guardian_name: "Guardian",
      }),
    );
    const r = await db.query(
      "select count(*) from clinic.patients where organization_id=$1 and phone=$2",
      [org, p.phone],
    );
    assert.equal(r.rows[0].count, "2");
  });
  await test("Idempotent retries return one patient and reject changed payload", async () => {
    const id = randomUUID(),
      payload = { full_name: "Idempotency test", birth_precision: "unknown" };
    const rs = await Promise.all([
      command("receptionist", "patient.create", payload, id),
      command("receptionist", "patient.create", payload, id),
    ]);
    rs.forEach(success);
    assert.equal(rs[0].data.id, rs[1].data.id);
    assert.ok(
      (
        await command(
          "receptionist",
          "patient.create",
          { ...payload, full_name: "Changed" },
          id,
        )
      ).error,
    );
  });
  await test("Future and impossible birth dates fail on the database", async () => {
    assert.ok(
      (
        await command("receptionist", "patient.create", {
          full_name: "Future date",
          birth_precision: "day",
          birth_date: "2999-01-01",
        })
      ).error,
    );
    assert.ok(
      (
        await command("receptionist", "patient.create", {
          full_name: "Invalid date",
          birth_precision: "day",
          birth_date: "2000-02-31",
        })
      ).error,
    );
  });
  await test("Clinical information is denied to reception and owner", async () => {
    assert.ok(
      (
        await clients.receptionist.rpc("clinical_record", {
          patient_id: patientId,
        })
      ).error,
    );
    assert.ok(
      (await clients.owner.rpc("clinical_record", { patient_id: patientId }))
        .error,
    );
    const w = success(await clients.receptionist.rpc("workspace"));
    assert.deepEqual(w.data.encounters, []);
  });
  await test("Anonymous API calls cannot load the workspace or mutate", async () => {
    const c = createClient(status.API_URL, status.PUBLISHABLE_KEY, {
      auth: { persistSession: false },
    });
    assert.ok((await c.rpc("workspace")).error);
    assert.ok(
      (
        await c.rpc("command", {
          kind: "patient.create",
          payload: { full_name: "Unauthenticated" },
          request_id: randomUUID(),
        })
      ).error,
    );
  });
  await test("Doctor signs once and signed clinical content cannot be overwritten", async () => {
    const r = success(
      await command("doctor", "encounter.save", {
        patient_id: patientId,
        chief_complaint: "Review",
        allergies: "No known allergies",
        diagnosis: "Test diagnosis",
        plan: "Review plan",
      }),
    );
    encounterId = r.data.id;
    success(
      await command("doctor", "encounter.sign", {
        id: encounterId,
        version: 1,
      }),
    );
    assert.ok(
      (
        await command("doctor", "encounter.save", {
          id: encounterId,
          patient_id: patientId,
          version: 2,
          chief_complaint: "Overwrite",
        })
      ).error,
    );
    success(
      await command("doctor", "encounter.addendum", {
        encounter_id: encounterId,
        content: "Correction is a signed-record addendum.",
      }),
    );
    const record = success(
      await clients.doctor.rpc("clinical_record", { patient_id: patientId }),
    );
    assert.equal(record.data.encounters[0].addenda.length, 1);
  });
  await test("Stale demographic updates fail rather than overwriting another edit", async () => {
    const payload = {
      patient_id: patientId,
      version: 1,
      full_name: "Updated test patient",
      birth_precision: "unknown",
    };
    success(await command("receptionist", "patient.update", payload));
    assert.equal(
      (
        await command("receptionist", "patient.update", {
          ...payload,
          full_name: "Stale write",
        })
      ).error?.code,
      "40001",
    );
  });
  await test("Double booking is prevented in concurrent appointment creation", async () => {
    const {
      data: { user },
    } = await clients.doctor.auth.getUser();
    const starts_at = new Date(Date.now() + 86400000).toISOString(),
      ends_at = new Date(Date.now() + 88200000).toISOString();
    const rs = await Promise.all(
      [1, 2].map(() =>
        command("receptionist", "appointment.create", {
          patient_id: patientId,
          doctor_id: user!.id,
          starts_at,
          ends_at,
          service_name: "Review",
        }),
      ),
    );
    assert.equal(rs.filter((r) => !r.error).length, 1);
  });
  let serviceId = "";
  await test("Owner configures services; receptionist cannot change prices", async () => {
    const s = success(
      await command("owner", "service.save", {
        name: "USD test service",
        category: "medical",
        currency: "USD",
        price: "100",
        duration: 30,
      }),
    );
    serviceId = s.data.id;
    assert.ok(
      (
        await command("receptionist", "service.save", {
          name: "Unauthorized service",
          category: "medical",
          currency: "USD",
          price: "1",
          duration: 30,
        })
      ).error,
    );
  });
  await test("Invoice posting creates balanced immutable journals", async () => {
    const r = success(
      await command("receptionist", "invoice.issue", {
        patient_id: patientId,
        currency: "USD",
        lines: [{ service_id: serviceId, quantity: 1 }],
      }),
    );
    invoiceId = r.data.id;
    const x = await db.query(
      "select sum(l.debit) debit,sum(l.credit) credit from clinic.journal_lines l join clinic.journals j on j.id=l.journal_id where j.source_id=$1",
      [invoiceId],
    );
    assert.equal(x.rows[0].debit, "100.000");
    assert.equal(x.rows[0].debit, x.rows[0].credit);
    await assert.rejects(
      db.query("update clinic.invoices set total=1 where id=$1", [invoiceId]),
      /immutable/i,
    );
  });
  await test("Concurrent payments cannot overpay an invoice", async () => {
    const rs = await Promise.all(
      [1, 2].map(() =>
        command("receptionist", "payment.record", {
          patient_id: patientId,
          invoice_id: invoiceId,
          currency: "USD",
          amount: "70",
          method: "cash",
        }),
      ),
    );
    assert.equal(
      rs.filter((r) => !r.error).length,
      1,
      JSON.stringify(rs.map((x) => x.error)),
    );
  });
  await test("USD sub-cent amounts and cross-currency payments without rates are rejected", async () => {
    assert.ok(
      (
        await command("receptionist", "payment.record", {
          patient_id: patientId,
          invoice_id: invoiceId,
          currency: "USD",
          amount: "0.001",
          method: "cash",
        })
      ).error,
    );
    assert.ok(
      (
        await command("receptionist", "payment.record", {
          patient_id: patientId,
          invoice_id: invoiceId,
          currency: "IQD",
          amount: "1",
          method: "cash",
        })
      ).error,
    );
  });
  await test("Cross-currency receipts settle either invoice currency and refunds retain the original rate", async () => {
    const usd = success(
      await command("receptionist", "invoice.issue", {
        patient_id: patientId,
        currency: "USD",
        lines: [{ service_id: serviceId, quantity: 1 }],
      }),
    ).data.id;
    const received = success(
      await command("receptionist", "payment.record", {
        patient_id: patientId,
        invoice_id: usd,
        currency: "IQD",
        amount: "131000",
        exchange_rate: "1310",
        method: "cash",
      }),
    ).data.id;
    let payment = (
      await db.query("select * from clinic.payments where id=$1", [received])
    ).rows[0];
    assert.equal(payment.amount, "131000.000");
    assert.equal(payment.invoice_amount, "100.000");
    assert.equal(payment.exchange_rate, "1310.000000");
    assert.equal(
      success(await clients.receptionist.rpc("workspace")).data.invoices.find(
        (x: { id: string }) => x.id === usd,
      ).balance,
      0,
    );
    success(
      await command("accountant", "refund.record", {
        payment_id: received,
        currency: "IQD",
        amount: "43666.667",
        reason: "Synthetic partial FX refund",
      }),
    );
    success(
      await command("accountant", "refund.record", {
        payment_id: received,
        currency: "IQD",
        amount: "87333.333",
        reason: "Synthetic remaining FX refund",
      }),
    );
    const refunds = (
      await db.query(
        "select sum(amount) tender,sum(invoice_amount) applied,bool_and(exchange_rate=1310) rate from clinic.payments where original_payment_id=$1",
        [received],
      )
    ).rows[0];
    assert.equal(refunds.tender, "131000.000");
    assert.equal(refunds.applied, "100.000");
    assert.equal(refunds.rate, true);
    const service = success(
      await command("owner", "service.save", {
        name: "IQD FX test",
        category: "medical",
        currency: "IQD",
        price: "131000",
        duration: 30,
      }),
    ).data.id;
    const iqd = success(
      await command("receptionist", "invoice.issue", {
        patient_id: patientId,
        currency: "IQD",
        lines: [{ service_id: service, quantity: 1 }],
      }),
    ).data.id;
    success(
      await command("receptionist", "payment.record", {
        patient_id: patientId,
        invoice_id: iqd,
        currency: "USD",
        amount: "100",
        exchange_rate: "1310",
        method: "cash",
      }),
    );
    assert.ok(
      (
        await command("accountant", "invoice.credit", {
          invoice_id: iqd,
          currency: "IQD",
          amount: "1",
          reason: "Cannot credit fully settled invoice",
        })
      ).error,
    );
    const snapshot = success(await clients.receptionist.rpc("workspace")).data;
    assert.equal(
      snapshot.invoices.find((x: { id: string }) => x.id === iqd).balance,
      0,
    );
    assert.equal(
      snapshot.invoices.find((x: { id: string }) => x.id === usd).balance,
      0,
    );
    const bad = (
      await db.query(
        "select j.id from clinic.journals j left join clinic.journal_lines l on l.journal_id=j.id where j.organization_id=$1 group by j.id having count(l.id)<2 or sum(l.debit)<>sum(l.credit)",
        [org],
      )
    ).rows;
    assert.equal(bad.length, 0);
  });
  await test("FX rates and refund splits cannot strand rounding residuals", async () => {
    const service = success(
      await command("owner", "service.save", {
        name: "Rounding test",
        category: "medical",
        currency: "USD",
        price: "0.01",
        duration: 10,
      }),
    ).data.id;
    const invoice = success(
      await command("receptionist", "invoice.issue", {
        patient_id: patientId,
        currency: "USD",
        lines: [{ service_id: service, quantity: 1 }],
      }),
    ).data.id;
    for (const rate of ["0", "-1", "1310.0000001"]) {
      assert.ok(
        (
          await command("receptionist", "payment.record", {
            patient_id: patientId,
            invoice_id: invoice,
            currency: "IQD",
            amount: "13.1",
            exchange_rate: rate,
            method: "cash",
          })
        ).error,
      );
    }
    const receipt = success(
      await command("receptionist", "payment.record", {
        patient_id: patientId,
        invoice_id: invoice,
        currency: "IQD",
        amount: "13.1",
        exchange_rate: "1310",
        method: "cash",
      }),
    ).data.id;
    assert.ok(
      (
        await command("accountant", "refund.record", {
          payment_id: receipt,
          currency: "IQD",
          amount: "10",
          reason: "Unrepresentable split",
        })
      ).error,
    );
    success(
      await command("accountant", "refund.record", {
        payment_id: receipt,
        currency: "IQD",
        amount: "13.1",
        reason: "Return full original receipt",
      }),
    );
  });
  await test("Refunds require approval, cannot exceed original receipts, and preserve ledger balance", async () => {
    const {
      rows: [payment],
    } = await db.query(
      "select id from clinic.payments where invoice_id=$1 and kind='payment'",
      [invoiceId],
    );
    assert.ok(
      (
        await command("receptionist", "refund.record", {
          payment_id: payment.id,
          currency: "USD",
          amount: "10",
          reason: "Service adjustment",
        })
      ).error,
    );
    success(
      await command("owner", "refund.record", {
        payment_id: payment.id,
        currency: "USD",
        amount: "10",
        reason: "Service adjustment",
      }),
    );
    assert.ok(
      (
        await command("owner", "refund.record", {
          payment_id: payment.id,
          currency: "USD",
          amount: "100",
          reason: "Excess refund",
        })
      ).error,
    );
    const x = await db.query(
      "select sum(debit)-sum(credit) balance from clinic.journal_lines where organization_id=$1",
      [org],
    );
    assert.equal(Number(x.rows[0].balance), 0);
  });
  await test("Foreign-organization identifiers cannot be accessed", async () => {
    const id = randomUUID();
    await db.query(
      "insert into clinic.patients(id,organization_id,patient_number,full_name) values($1,$2,'OTHER-1','Other clinic patient')",
      [id, other],
    );
    assert.ok(
      (
        await command("receptionist", "patient.update", {
          patient_id: id,
          version: 1,
          full_name: "Attempt",
          birth_precision: "unknown",
        })
      ).error,
    );
    const w = success(await clients.receptionist.rpc("workspace"));
    assert.ok(!w.data.patients.some((p: { id: string }) => p.id === id));
  });
  await test("Stock cannot be consumed below zero or after expiry", async () => {
    const r = success(
      await command("owner", "stock.receive", {
        product: "Test stock",
        lot_number: "LOT-1",
        expires_on: "2099-01-01",
        unit: "unit",
        amount: "2",
      }),
    );
    success(
      await command("doctor", "stock.use", {
        lot_id: r.data.id,
        encounter_id: encounterId,
        amount: "1",
        reason: "Procedure usage",
      }),
    );
    assert.ok(
      (
        await command("doctor", "stock.use", {
          lot_id: r.data.id,
          encounter_id: encounterId,
          amount: "2",
          reason: "Overspend",
        })
      ).error,
    );
  });
  await test("Deposits cannot be spent twice and do not create revenue on receipt", async () => {
    success(
      await command("receptionist", "payment.record", {
        patient_id: patientId,
        currency: "USD",
        amount: "25",
        method: "cash",
      }),
    );
    success(
      await command("receptionist", "deposit.apply", {
        patient_id: patientId,
        invoice_id: invoiceId,
        currency: "USD",
        amount: "20",
      }),
    );
    assert.ok(
      (
        await command("receptionist", "deposit.apply", {
          patient_id: patientId,
          invoice_id: invoiceId,
          currency: "USD",
          amount: "20",
        })
      ).error,
    );
  });
  await test("Treatment package redemption requires a signed patient encounter and is not duplicated", async () => {
    const pkg = success(
      await command("receptionist", "package.sell", {
        patient_id: patientId,
        name: "Three session test",
        sessions: 3,
        currency: "USD",
        amount: "100",
        method: "cash",
      }),
    );
    success(
      await command("receptionist", "package.redeem", {
        patient_id: patientId,
        package_id: pkg.data.id,
        encounter_id: encounterId,
      }),
    );
    assert.ok(
      (
        await command("receptionist", "package.redeem", {
          patient_id: patientId,
          package_id: pkg.data.id,
          encounter_id: encounterId,
        })
      ).error,
    );
    const {
      rows: [p],
    } = await db.query(
      "select remaining,redeemed_value from clinic.packages where id=$1",
      [pkg.data.id],
    );
    assert.equal(p.remaining, 2);
    assert.equal(p.redeemed_value, "33.330");
  });
  await test("FX records two separately balanced currencies using the supplied immutable rate", async () => {
    success(
      await command("owner", "fx.exchange", {
        currency: "USD",
        destination_currency: "IQD",
        amount: "10",
        rate: "1310",
        method: "cash",
        description: "Test exchange",
      }),
    );
    const { rows } = await db.query(
      "select currency,sum(debit)-sum(credit) balance from clinic.journals j join clinic.journal_lines l on l.journal_id=j.id where j.organization_id=$1 group by currency",
      [org],
    );
    assert.equal(rows.length, 2);
    assert.ok(rows.every((r) => Number(r.balance) === 0));
  });
  await test("Unpaid supplier bills can be settled exactly once", async () => {
    const exp = success(
      await command("owner", "expense.record", {
        category: "operating",
        supplier: "Test supplier",
        description: "Test unpaid bill",
        currency: "USD",
        amount: "20",
        paid: false,
        method: "bank",
      }),
    );
    success(
      await command("owner", "expense.pay", {
        expense_id: exp.data.id,
        method: "bank",
      }),
    );
    assert.ok(
      (
        await command("owner", "expense.pay", {
          expense_id: exp.data.id,
          method: "bank",
        })
      ).error,
    );
  });
  await test("Accountants receive financial records without patient demographics or clinical content", async () => {
    const w = success(await clients.accountant.rpc("workspace"));
    assert.equal(w.data.patients.length, 0);
    assert.equal(w.data.encounters.length, 0);
    assert.ok(w.data.journals.length > 0);
  });
  await test("Patient search is server-side, normalized, and cursor-paginated", async () => {
    const r = success(
      await clients.receptionist.rpc("patient_search", {
        search_term: "test",
        page_size: 1,
      }),
    );
    assert.equal(r.data.items.length, 1);
    assert.equal(r.data.has_more, true);
    const next = success(
      await clients.receptionist.rpc("patient_search", {
        search_term: "test",
        page_size: 1,
        cursor_id: r.data.items[0].id,
      }),
    );
    assert.notEqual(next.data.items[0].id, r.data.items[0].id);
  });
  if (process.argv.includes("--media")) {
    await test("Private media requires consent, scans clean uploads and authorizes temporary access", async () => {
      const consent = success(
        await command("doctor", "consent.record", {
          patient_id: patientId,
          purpose: "care_photography",
          granted: true,
          template_version: "test",
          evidence: "Synthetic test consent",
        }),
      );
      const file = new File(
        [
          Buffer.from(
            "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+a9VsAAAAASUVORK5CYII=",
            "base64",
          ),
        ],
        "test.png",
        { type: "image/png" },
      );
      const form = new FormData();
      for (const [k, v] of Object.entries({
        upload_id: randomUUID(),
        patient_id: patientId,
        consent_id: consent.data.id,
        title: "Synthetic image",
        body_site: "Test site",
      }))
        form.set(k, v);
      form.set("file", file);
      const upload = await clients.doctor.functions.invoke("clinical-media", {
        body: form,
      });
      if (upload.error)
        throw new Error(JSON.stringify(await upload.error.context.json()));
      assert.ok(upload.data.id, JSON.stringify(upload.data));
      const read = await clients.doctor.functions.invoke("clinical-media", {
        body: { action: "read", media_id: upload.data.id },
      });
      assert.equal(read.error, null, JSON.stringify(read));
      assert.match(read.data.url, /^http:\/\/127\.0\.0\.1:54321\/storage/);
      const response = await fetch(read.data.url);
      assert.equal(response.status, 200);
      assert.equal((await response.arrayBuffer()).byteLength, file.size);
      assert.ok(
        (
          await clients.receptionist.functions.invoke("clinical-media", {
            body: { action: "read", media_id: upload.data.id },
          })
        ).error,
      );
      if(process.argv.includes("--recovery"))await test("Encrypted database and private media restore independently; altered keys fail closed",()=>recoveryCheck(db,admin,org));
      const rejectedId = randomUUID();
      const infected = new FormData();
      for (const [k, v] of Object.entries({
        upload_id: rejectedId,
        patient_id: patientId,
        consent_id: consent.data.id,
        title: "Antivirus regression",
        body_site: "Test site",
      }))
        infected.set(k, v);
      infected.set(
        "file",
        new File(
          [antivirusPdf() as Uint8Array<ArrayBuffer>],
          "antivirus-test.pdf",
          { type: "application/pdf" },
        ),
      );
      assert.ok(
        (
          await clients.doctor.functions.invoke("clinical-media", {
            body: infected,
          })
        ).error,
      );
      const rejected = (
        await db.query(
          "select status,object_key from clinic.media where id=$1",
          [rejectedId],
        )
      ).rows[0];
      assert.equal(rejected?.status, "rejected");
      assert.ok(
        (await admin.storage.from("clinical").download(rejected.object_key))
          .error,
      );
      success(
        await command("doctor", "consent.record", {
          patient_id: patientId,
          purpose: "care_photography",
          granted: false,
          template_version: "test",
          evidence: "Consent withdrawal test",
        }),
      );
      assert.ok(
        (
          await clients.doctor.functions.invoke("clinical-media", {
            body: { action: "read", media_id: upload.data.id },
          })
        ).error,
      );
    });
  }
  await test("MFA policy denies a password-only token and accepts actual TOTP verification", async () => {
    await db.query(
      "update clinic.organizations set require_mfa=true where id=$1",
      [org],
    );
    assert.ok(
      (
        await command("owner", "service.save", {
          name: "Should fail",
          category: "medical",
          currency: "USD",
          price: "1",
          duration: 10,
        })
      ).error,
    );
    const enrolled = success(
      await clients.owner.auth.mfa.enroll({
        factorType: "totp",
        friendlyName: "Integration test",
      }),
    );
    assert.ok(enrolled.data);
    const totp = new TOTP({
      secret: enrolled.data.totp.secret,
      algorithm: "SHA1",
      digits: 6,
      period: 30,
    });
    success(
      await clients.owner.auth.mfa.challengeAndVerify({
        factorId: enrolled.data.id,
        code: totp.generate(),
      }),
    );
    success(
      await command("owner", "service.save", {
        name: "Verified MFA",
        category: "medical",
        currency: "USD",
        price: "1",
        duration: 10,
      }),
    );
    await db.query(
      "update clinic.organizations set require_mfa=false where id=$1",
      [org],
    );
  });
  await test("Revoking membership takes effect on the next operation with an existing token", async () => {
    const {
      data: { user },
    } = await clients.receptionist.auth.getUser();
    await db.query(
      "update clinic.memberships set active=false where organization_id=$1 and user_id=$2",
      [org, user!.id],
    );
    assert.ok((await clients.receptionist.rpc("workspace")).error);
  });
  console.log(`\n${passed} database/API integration checks passed.`);
} finally {
  const { rows: objects } = await db.query(
    "select object_key from clinic.media where organization_id=$1",
    [org],
  );
  if (objects.length)
    await admin.storage
      .from("clinical")
      .remove(objects.map((r) => r.object_key));
  await db.query("begin");
  try {
    await db.query("set local session_replication_role='replica'");
    const { rows } = await db.query(
      "select tablename from pg_tables where schemaname='clinic' and tablename not in ('organizations')",
    );
    for (const { tablename } of rows)
      await db.query(
        `delete from clinic."${tablename}" where organization_id=any($1::uuid[])`,
        [[org, other]],
      );
    await db.query(
      "delete from clinic.organizations where id=any($1::uuid[])",
      [[org, other]],
    );
    await db.query("commit");
  } catch (e) {
    await db.query("rollback");
    throw e;
  } finally {
    for (const id of ids) await admin.auth.admin.deleteUser(id);
    await db.end();
  }
}
