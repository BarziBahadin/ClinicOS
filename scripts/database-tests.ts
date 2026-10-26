import { phoneReminderChecks } from "./phone-reminder-tests";
import assert from "node:assert/strict";
import { execFileSync } from "node:child_process";
import { createHash, randomUUID } from "node:crypto";
import { createClient, type SupabaseClient } from "@supabase/supabase-js";
import pg from "pg";
import { recoveryCheck } from "./recovery-check";
import { antivirusPdf } from "./test-fixtures";
import { TOTP } from "otpauth";
import { usernameIdentity } from "../supabase/functions/_shared/username";
import {
  workflowChecks,
  accountingChecks,
  accessChecks,
} from "./workflow-tests";
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
  id: string = randomUUID(),
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
  for (const role of [
    "owner",
    "doctor",
    "receptionist",
    "accountant",
    "administrator",
  ]) {
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
  if (process.argv.includes("--media")) {
    await test("Administrators create username accounts; temporary passwords, resets and privilege boundaries are enforced", async () => {
      const username = `staff-${org.slice(0, 8)}`;
      const initial = `Temporary-${randomUUID()}!`,
        personal = `Personal-${randomUUID()}!`,
        reset = `Reset-${randomUUID()}!`;
      const payload = {
        action: "create",
        username,
        display_name: "Synthetic front desk",
        role: "receptionist",
        password: initial,
        request_id: randomUUID(),
      };
      const created = success(
        await clients.administrator.functions.invoke("staff-admin", {
          body: payload,
        }),
      );
      ids.push(created.data.id);
      const retry = success(
        await clients.administrator.functions.invoke("staff-admin", {
          body: payload,
        }),
      );
      assert.equal(retry.data.id, created.data.id);
      const staff = createClient(status.API_URL, status.PUBLISHABLE_KEY, {
        auth: { persistSession: false, autoRefreshToken: false },
      });
      success(
        await staff.auth.signInWithPassword({
          email: usernameIdentity(username),
          password: initial,
        }),
      );
      assert.equal(
        success(await staff.rpc("account_status")).data
          .password_change_required,
        true,
      );
      assert.ok(
        (
          await staff.rpc("command", {
            kind: "patient.create",
            payload: { full_name: "Denied temporary password" },
            request_id: randomUUID(),
          })
        ).error,
      );
      success(
        await staff.functions.invoke("staff-admin", {
          body: {
            action: "change_password",
            current_password: initial,
            password: personal,
          },
        }),
      );
      assert.equal(
        success(await staff.rpc("authorize", { permission: "patients" })).data,
        false,
      );
      success(
        await staff.auth.signInWithPassword({
          email: usernameIdentity(username),
          password: personal,
        }),
      );
      assert.equal(
        success(await staff.rpc("account_status")).data
          .password_change_required,
        false,
      );
      assert.equal(
        success(await staff.rpc("authorize", { permission: "patients" })).data,
        true,
      );
      assert.ok(
        (
          await clients.receptionist.functions.invoke("staff-admin", {
            body: { ...payload, username: `denied-${org.slice(0, 8)}` },
          })
        ).error,
      );
      assert.ok(
        (
          await command("administrator", "member.update", {
            user_id: created.data.id,
            role: "owner",
            active: true,
          })
        ).error,
      );
      const ownerId = success(await clients.owner.auth.getUser()).data.user!.id;
      assert.ok(
        (
          await clients.administrator.functions.invoke("staff-admin", {
            body: {
              action: "reset_password",
              user_id: ownerId,
              password: reset,
            },
          })
        ).error,
      );
      success(
        await clients.administrator.functions.invoke("staff-admin", {
          body: {
            action: "reset_password",
            user_id: created.data.id,
            password: reset,
          },
        }),
      );
      assert.equal(
        success(await staff.rpc("authorize", { permission: "patients" })).data,
        false,
      );
      assert.ok((await staff.rpc("account_status")).error);
      success(
        await staff.auth.signInWithPassword({
          email: usernameIdentity(username),
          password: reset,
        }),
      );
      assert.equal(
        success(await staff.rpc("account_status")).data
          .password_change_required,
        true,
      );
      success(
        await staff.functions.invoke("staff-admin", {
          body: {
            action: "change_password",
            current_password: reset,
            password: personal,
          },
        }),
      );
      await staff.auth.signOut({ scope: "local" });
    });
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
    const replacementPassword = `New-${randomUUID()}!`;
    success(await c.auth.updateUser({ password: replacementPassword }));
    assert.equal(
      success(
        await clients.accountant.rpc("authorize", { permission: "finance" }),
      ).data,
      false,
    );
    success(
      await clients.accountant.auth.signInWithPassword({
        email: user!.email!,
        password: replacementPassword,
      }),
    );
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
  await test("Patient merges reject stale identity reviews before changing either profile", async () => {
    const source = success(
      await command("receptionist", "patient.create", {
        full_name: "Merge review source",
        birth_precision: "unknown",
      }),
    ).data.id;
    const payload = {
      patient_id: source,
      target_id: patientId,
      version: 0,
      reason: "Synthetic identity review with two identifiers",
    };
    assert.equal(
      (await command("owner", "patient.merge", payload)).error?.code,
      "40001",
    );
    const unchanged = (
      await db.query(
        "select merged_into,version from clinic.patients where id=$1",
        [source],
      )
    ).rows[0];
    assert.equal(unchanged.merged_into, null);
    assert.equal(unchanged.version, 1);
    success(
      await command("owner", "patient.merge", { ...payload, version: 1 }),
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
  await test("Encounters cannot attach another patient's appointment or an unknown appointment", async () => {
    const appointment = (
      await db.query(
        "select id from clinic.appointments where organization_id=$1 limit 1",
        [org],
      )
    ).rows[0].id;
    const differentPatient = success(
      await command("receptionist", "patient.create", {
        full_name: "Appointment identity test",
        birth_precision: "unknown",
      }),
    ).data.id;
    for (const appointment_id of [appointment, randomUUID()]) {
      const result = await command("doctor", "encounter.save", {
        patient_id: differentPatient,
        appointment_id,
        chief_complaint: "Appointment review",
      });
      assert.match(result.error?.message ?? "", /Appointment does not belong/);
    }
    assert.equal(
      (
        await db.query(
          "select count(*) from clinic.encounters where patient_id=$1",
          [differentPatient],
        )
      ).rows[0].count,
      "0",
    );
    success(
      await command("doctor", "encounter.save", {
        patient_id: patientId,
        appointment_id: appointment,
        chief_complaint: "Matching appointment",
      }),
    );
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
  await test("Financial record pages enforce permissions, paginate, and retain invoice currency", async () => {
    const pageInvoice = success(
      await command("receptionist", "invoice.issue", {
        patient_id: patientId,
        currency: "USD",
        lines: [{ service_id: serviceId, quantity: 1 }],
      }),
    ).data.id;
    success(
      await command("receptionist", "payment.record", {
        patient_id: patientId,
        invoice_id: pageInvoice,
        currency: "USD",
        amount: "25",
        method: "cash",
      }),
    );
    const anonymous = createClient(status.API_URL, status.PUBLISHABLE_KEY, {
      auth: { persistSession: false },
    });
    assert.ok(
      (await anonymous.rpc("record_page", { record_type: "invoices" })).error,
    );
    assert.ok(
      (
        await clients.receptionist.rpc("record_page", {
          record_type: "expenses",
        })
      ).error,
    );
    assert.ok(
      (await clients.doctor.rpc("record_page", { record_type: "invoices" }))
        .error,
    );
    const first = success(
      await clients.receptionist.rpc("record_page", {
        record_type: "invoices",
        page_size: 1,
      }),
    );
    assert.equal(first.data.items.length, 1);
    assert.equal(first.data.has_more, true);
    const next = success(
      await clients.receptionist.rpc("record_page", {
        record_type: "invoices",
        page_size: 1,
        cursor_id: first.data.items[0].id,
      }),
    );
    assert.equal(next.data.items.length, 1);
    assert.notEqual(next.data.items[0].id, first.data.items[0].id);
    const invoice = success(
      await clients.receptionist.rpc("record_page", {
        record_type: "invoices",
        search_term: pageInvoice,
      }),
    );
    assert.equal(invoice.data.items.length, 1);
    assert.equal(Number(invoice.data.items[0].balance), 75);
    const payment = (
      await db.query(
        "select p.id,i.currency,i.invoice_number from clinic.payments p join clinic.invoices i on i.id=p.invoice_id where p.organization_id=$1 and p.currency<>i.currency limit 1",
        [org],
      )
    ).rows[0];
    assert.ok(payment);
    const page = success(
      await clients.receptionist.rpc("record_page", {
        record_type: "payments",
        search_term: payment.id,
      }),
    );
    assert.equal(page.data.items.length, 1);
    assert.equal(page.data.items[0].invoice_currency, payment.currency);
    assert.equal(page.data.items[0].invoice_number, payment.invoice_number);
    assert.ok(
      page.data.items.every(
        (item: { organization_id: string }) => item.organization_id === org,
      ),
    );
  });
  await workflowChecks({
    db,
    org,
    other,
    clients,
    ids,
    admin,
    patientId,
    encounterId,
    serviceId,
    test,
    command,
  });
  await phoneReminderChecks({
    db,
    org,
    other,
    clients,
    ids,
    admin,
    patientId,
    encounterId,
    serviceId,
    test,
    command,
  });
  await accountingChecks({
    db,
    org,
    other,
    clients,
    ids,
    admin,
    patientId,
    encounterId,
    serviceId,
    test,
    command,
  });
  await test("Anonymous API execution and authenticated server-only operations are explicitly revoked", async () => {
    const anonymous = await db.query(
      "select p.oid::regprocedure signature from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname in ('clinic','public') and p.prokind='f' and has_function_privilege('anon',p.oid,'execute') and not exists(select 1 from pg_depend d where d.classid='pg_proc'::regclass and d.objid=p.oid and d.deptype='e')",
    );
    assert.deepEqual(anonymous.rows, []);
    for (const signature of [
      "public.media_finalize(uuid,boolean)",
      "public.provision_member(uuid,uuid,text,text)",
      "public.media_complete(uuid,text,text,text)",
      "public.media_cleanup_record(uuid,text)",
    ])
      assert.equal(
        (
          await db.query(
            "select has_function_privilege('authenticated',$1::regprocedure,'execute') allowed",
            [signature],
          )
        ).rows[0].allowed,
        false,
      );
  });
  await accessChecks({
    db,
    org,
    other,
    clients,
    ids,
    admin,
    patientId,
    encounterId,
    serviceId,
    test,
    command,
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
            "iVBORw0KGgoAAAANSUhEUgAAAAIAAAACCAIAAAD91JpzAAAACXBIWXMAAAPoAAAD6AG1e1JrAAAAEUlEQVQImWPoKE/rKE9jgFAAJ6IFla15zswAAAAASUVORK5CYII=",
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
      const originalBytes = Buffer.from(await response.arrayBuffer());
      assert.deepEqual(originalBytes, Buffer.from(await file.arrayBuffer()));
      const preview = success(
        await clients.doctor.functions.invoke("clinical-media", {
          body: { action: "preview", media_id: upload.data.id },
        }),
      );
      const previewResponse = await fetch(preview.data.url);
      assert.equal(previewResponse.status, 200);
      const previewBytes = Buffer.from(await previewResponse.arrayBuffer());
      assert.equal(previewBytes.subarray(1, 4).toString(), "PNG");
      const metadata = (
        await db.query(
          "select preview_key,preview_sha256,processing_note from clinic.media where id=$1",
          [upload.data.id],
        )
      ).rows[0];
      assert.ok(metadata.preview_key);
      assert.equal(
        metadata.preview_sha256,
        createHash("sha256").update(previewBytes).digest("hex"),
      );
      assert.match(metadata.processing_note, /Original bytes preserved/);
      assert.ok(
        (
          await clients.receptionist.functions.invoke("clinical-media", {
            body: { action: "preview", media_id: upload.data.id },
          })
        ).error,
      );
      const malformed = new FormData();
      const malformedId = randomUUID();
      for (const [key, value] of Object.entries({
        upload_id: malformedId,
        patient_id: patientId,
        consent_id: consent.data.id,
        title: "Malformed synthetic PNG",
        body_site: "Test site",
      }))
        malformed.set(key, value);
      malformed.set(
        "file",
        new File(
          [
            Buffer.from(
              "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+a9VsAAAAASUVORK5CYII=",
              "base64",
            ),
          ],
          "malformed.png",
          { type: "image/png" },
        ),
      );
      assert.ok(
        (
          await clients.doctor.functions.invoke("clinical-media", {
            body: malformed,
          })
        ).error,
      );
      assert.equal(
        (
          await db.query("select status from clinic.media where id=$1", [
            malformedId,
          ])
        ).rows[0].status,
        "rejected",
      );
      assert.ok(
        (
          await clients.receptionist.functions.invoke("clinical-media", {
            body: { action: "read", media_id: upload.data.id },
          })
        ).error,
      );
      if (process.argv.includes("--recovery"))
        await test("Encrypted database and private media restore independently; altered keys fail closed", () =>
          recoveryCheck(db, admin, org));
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

      await test("Maintenance expires abandoned uploads without erasing ready media or upload evidence", async () => {
        assert.ok(
          (
            await clients.owner.rpc("media_maintenance", {
              expire_abandoned: true,
            })
          ).error,
        );
        assert.ok(
          (
            await clients.doctor.rpc("media_cleanup_record", {
              media_id: upload.data.id,
              object_key: "forbidden",
            })
          ).error,
        );
        const staleId = randomUUID();
        const staleHash = createHash("sha256")
          .update("abandoned synthetic")
          .digest("hex");
        success(
          await clients.doctor.rpc("media_prepare", {
            media_id: staleId,
            patient_id: patientId,
            consent_id: consent.data.id,
            title: "Abandoned synthetic upload",
            body_site: "Test site",
            mime_type: "image/png",
            content_hash: staleHash,
          }),
        );
        await db.query(
          "update clinic.media set created_at=now()-interval '8 days' where id=$1",
          [staleId],
        );
        const maintenance = success(
          await admin.rpc("media_maintenance", { expire_abandoned: true }),
        ).data;
        assert.ok(maintenance.expired >= 1);
        assert.equal(
          (
            await db.query("select status from clinic.media where id=$1", [
              staleId,
            ])
          ).rows[0].status,
          "rejected",
        );
        assert.equal(
          (
            await db.query("select status from clinic.media where id=$1", [
              upload.data.id,
            ])
          ).rows[0].status,
          "ready",
        );
        assert.ok(
          (
            await admin.rpc("media_cleanup_record", {
              media_id: upload.data.id,
              object_key: (
                await db.query(
                  "select object_key from clinic.media where id=$1",
                  [upload.data.id],
                )
              ).rows[0].object_key,
            })
          ).error,
        );
        const key = (
          await db.query("select object_key from clinic.media where id=$1", [
            staleId,
          ])
        ).rows[0].object_key;
        success(
          await admin.storage
            .from("clinical")
            .upload(key, Buffer.from("failed synthetic bytes"), {
              contentType: "image/png",
            }),
        );
        await db.query(
          "update clinic.media set rejected_at=now()-interval '31 days' where id=$1",
          [staleId],
        );
        const candidates = success(await admin.rpc("media_maintenance")).data
          .objects;
        assert.ok(
          candidates.some(
            (r: any) => r.media_id === staleId && r.object_key === key,
          ),
        );
        assert.ok(!candidates.some((r: any) => r.media_id === upload.data.id));
        success(await admin.storage.from("clinical").remove([key]));
        success(
          await admin.rpc("media_cleanup_record", {
            media_id: staleId,
            object_key: key,
          }),
        );
        assert.equal(
          (
            await db.query(
              "select count(*) from clinic.media_cleanup_events where media_id=$1",
              [staleId],
            )
          ).rows[0].count,
          "1",
        );
        assert.equal(
          (
            await db.query("select count(*) from clinic.media where id=$1", [
              staleId,
            ])
          ).rows[0].count,
          "1",
        );
      });
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
    "select object_key,preview_key from clinic.media where organization_id=$1",
    [org],
  );
  if (objects.length)
    await admin.storage
      .from("clinical")
      .remove(
        objects
          .flatMap((r) => [r.object_key, r.preview_key])
          .filter((key): key is string => typeof key === "string"),
      );
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
