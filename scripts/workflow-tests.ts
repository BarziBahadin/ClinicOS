import assert from "node:assert/strict";
import { randomUUID } from "node:crypto";
import Decimal from "decimal.js";
import type pg from "pg";
import type { SupabaseClient } from "@supabase/supabase-js";
type Result = { data: any; error: any };
export type Context = {
  db: pg.Client;
  org: string;
  other: string;
  clients: Record<string, SupabaseClient>;
  ids: string[];
  admin: SupabaseClient;
  patientId: string;
  encounterId: string;
  serviceId: string;
  test: (name: string, fn: () => Promise<void>) => Promise<void>;
  command: (
    role: string,
    kind: string,
    payload: Record<string, unknown>,
    id?: string,
  ) => PromiseLike<Result>;
};
function success(result: Result): Result {
  assert.equal(result.error, null, JSON.stringify(result.error));
  return result;
}
export async function workflowChecks(ctx: Context) {
  const {
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
  } = ctx;
  const workflow = (
    role: string,
    kind: string,
    payload: Record<string, unknown>,
    request_id = randomUUID(),
  ) => clients[role].rpc("workflow", { kind, payload, request_id });
  let templateId = "",
    draftId = "";
  await test("Front desk proposes treatments while only price approvers can activate them", async () => {
    const proposed = success(
      await workflow("receptionist", "service.propose", {
        name: "Reception proposal",
        category: "medical",
        currency: "USD",
        duration: 20,
      }),
    ).data.id;
    assert.equal(
      (
        await db.query("select active from clinic.services where id=$1", [
          proposed,
        ])
      ).rows[0].active,
      false,
    );
    assert.ok(
      (
        await workflow("receptionist", "service.approve", {
          id: proposed,
          currency: "USD",
          price: "15",
        })
      ).error,
    );
    success(
      await workflow("owner", "service.approve", {
        id: proposed,
        currency: "USD",
        price: "15",
      }),
    );
    assert.equal(
      (
        await db.query("select active from clinic.services where id=$1", [
          proposed,
        ])
      ).rows[0].active,
      true,
    );
  });
  await test("Approved consent templates are immutable and captured in consent evidence", async () => {
    const payload = {
      kind: "consent",
      name: "Synthetic consent",
      language: "en",
      version: 1,
      content: "Synthetic wording for integration verification only.",
    };
    assert.ok((await workflow("owner", "template.create", payload)).error);
    templateId = success(await workflow("doctor", "template.create", payload))
      .data.id;
    assert.ok(
      (await workflow("receptionist", "template.approve", { id: templateId }))
        .error,
    );
    success(await workflow("doctor", "template.approve", { id: templateId }));
    await assert.rejects(
      db.query(
        "update clinic.document_templates set content='Changed after approval' where id=$1",
        [templateId],
      ),
      /immutable/i,
    );
    const consent = success(
      await command("doctor", "consent.record", {
        patient_id: patientId,
        purpose: "procedure",
        granted: true,
        template_id: templateId,
        template_version: "1",
        evidence: "Synthetic discussion verified",
      }),
    ).data.id;
    assert.equal(
      (
        await db.query(
          "select template_snapshot from clinic.consents where id=$1",
          [consent],
        )
      ).rows[0].template_snapshot.content,
      payload.content,
    );
  });
  await test("Clinical facts preserve amendments and structured prescriptions lock with the signed encounter", async () => {
    const fact = success(
      await workflow("doctor", "fact.record", {
        patient_id: patientId,
        kind: "history",
        content: "Synthetic clinical history",
        status: "active",
      }),
    ).data.id;
    success(
      await workflow("doctor", "fact.record", {
        patient_id: patientId,
        kind: "history",
        content: "Reviewed synthetic history",
        status: "resolved",
        supersedes_id: fact,
      }),
    );
    assert.ok(
      (
        await workflow("doctor", "fact.record", {
          patient_id: patientId,
          kind: "history",
          content: "Stale competing amendment",
          status: "active",
          supersedes_id: fact,
        })
      ).error,
    );
    assert.ok(
      (
        await clients.owner.rpc("history_page", {
          record_type: "clinical_facts",
          patient_id: patientId,
        })
      ).error,
    );
    draftId = success(
      await command("doctor", "encounter.save", {
        patient_id: patientId,
        chief_complaint: "Structured prescription test",
        allergies: "Reviewed synthetic allergies",
        diagnosis: "Synthetic finding",
        plan: "Synthetic plan",
      }),
    ).data.id;
    const payload = {
      patient_id: patientId,
      encounter_id: draftId,
      medicine: "Synthetic medicine only",
      strength: "Test strength",
      dose: "Test dose",
      route: "Test route",
      frequency: "Test schedule",
      duration: "Test duration",
    };
    const medication = success(
      await workflow("doctor", "prescription.add", payload),
    ).data.id;
    success(
      await command("doctor", "encounter.sign", { id: draftId, version: 1 }),
    );
    assert.ok((await workflow("doctor", "prescription.add", payload)).error);
    await assert.rejects(
      db.query(
        "update clinic.prescription_items set dose='Overwrite' where id=$1",
        [medication],
      ),
      /immutable/i,
    );
    const record = success(
      await clients.doctor.rpc("clinical_record", { patient_id: patientId }),
    ).data;
    assert.equal(
      record.facts.some((f: any) => f.id === fact),
      false,
    );
    assert.equal(
      record.encounters.find((e: any) => e.id === draftId).prescription_items[0]
        .id,
      medication,
    );
  });
  await test("Performed services invoice once with immutable patient and service identity", async () => {
    const performed = success(
      await workflow("doctor", "performed.record", {
        patient_id: patientId,
        encounter_id: draftId,
        service_id: serviceId,
        quantity: 1,
      }),
    ).data.id;
    const request = randomUUID();
    const result = success(
      await workflow(
        "receptionist",
        "performed.invoice",
        { id: performed },
        request,
      ),
    );
    assert.equal(
      success(
        await workflow(
          "receptionist",
          "performed.invoice",
          { id: performed },
          request,
        ),
      ).data.id,
      result.data.id,
    );
    assert.ok(
      (await workflow("receptionist", "performed.invoice", { id: performed }))
        .error,
    );
    await assert.rejects(
      db.query(
        "update clinic.performed_services set patient_id=$2 where id=$1",
        [performed, randomUUID()],
      ),
      /immutable/i,
    );
  });
  await test("Additional contacts and contact outcomes preserve their history and organization boundary", async () => {
    const contact = success(
      await workflow("receptionist", "contact.add", {
        patient_id: patientId,
        phone: "+9647700000001",
        owner_name: "Synthetic contact",
        relationship: "guardian",
        preferred: true,
      }),
    ).data.id;
    success(
      await workflow("receptionist", "contact.end", {
        id: contact,
        patient_id: patientId,
      }),
    );
    const history = success(
      await clients.receptionist.rpc("patient_contacts", {
        patient_id: patientId,
      }),
    ).data;
    assert.ok(history.find((r: any) => r.id === contact).valid_to);
    assert.ok(
      (
        await workflow("receptionist", "contact.add", {
          patient_id: patientId,
          phone: "invalid",
          owner_name: "Invalid",
        })
      ).error,
    );
    success(
      await workflow("receptionist", "contact.log", {
        patient_id: patientId,
        channel: "phone",
        purpose: "Schedule review",
        outcome: "no_answer",
        notes: "Synthetic attempt; no external message sent",
      }),
    );
    const foreign = (
      await db.query(
        "select id from clinic.patients where organization_id=$1 limit 1",
        [other],
      )
    ).rows[0].id;
    assert.ok(
      (
        await clients.receptionist.rpc("patient_contacts", {
          patient_id: foreign,
        })
      ).error,
    );
  });
  await test("Rescheduling and room reservations retain conflict, leave and version protections", async () => {
    const created = await admin.auth.admin.createUser({
      email: `resource-${randomUUID()}@clinicos.test`,
      password: `Resource-${randomUUID()}!`,
      email_confirm: true,
    });
    assert.equal(created.error, null);
    const doctor = created.data.user!.id;
    ids.push(doctor);
    await db.query(
      "insert into clinic.memberships(organization_id,user_id,display_name,role) values($1,$2,'Synthetic second doctor','doctor')",
      [org, doctor],
    );
    const resource = success(
      await workflow("owner", "resource.add", {
        name: "Synthetic room",
        kind: "room",
      }),
    ).data.id;
    const start = new Date(Date.now() + 864000000),
      end = new Date(start.getTime() + 1800000);
    const doctorId = success(await clients.doctor.auth.getUser()).data.user!.id;
    const payload = {
      patient_id: patientId,
      doctor_id: doctorId,
      starts_at: start.toISOString(),
      ends_at: end.toISOString(),
      resource_id: resource,
      service_name: "Room test",
    };
    const appt = success(
      await command("receptionist", "appointment.create", payload),
    ).data.id;
    assert.ok(
      (
        await command("receptionist", "appointment.create", {
          ...payload,
          doctor_id: doctor,
        })
      ).error,
    );
    success(
      await workflow("receptionist", "appointment.reschedule", {
        id: appt,
        version: 1,
        starts_at: new Date(start.getTime() + 3600000).toISOString(),
        ends_at: new Date(end.getTime() + 3600000).toISOString(),
        reason: "Synthetic reschedule",
        resource_id: resource,
      }),
    );
    assert.ok(
      (
        await workflow("receptionist", "appointment.reschedule", {
          id: appt,
          version: 1,
          starts_at: start.toISOString(),
          ends_at: end.toISOString(),
          reason: "Stale reschedule",
        })
      ).error,
    );
    const leaveId = success(
      await workflow("receptionist", "availability.add", {
        doctor_id: doctor,
        kind: "leave",
        starts_at: start.toISOString(),
        ends_at: end.toISOString(),
        description: "Synthetic leave",
      }),
    ).data.id;
    assert.ok(
      (
        await command("receptionist", "appointment.create", {
          ...payload,
          doctor_id: doctor,
          resource_id: null,
        })
      ).error,
    );
    success(
      await workflow("receptionist", "availability.end", {
        id: leaveId,
        reason: "Leave cancelled by clinic",
      }),
    );
    success(
      await command("receptionist", "appointment.create", {
        ...payload,
        doctor_id: doctor,
        resource_id: null,
      }),
    );
    assert.ok(
      (
        await workflow("receptionist", "availability.add", {
          doctor_id: doctor,
          kind: "leave",
          starts_at: start.toISOString(),
          ends_at: end.toISOString(),
          description: "Conflicting leave",
        })
      ).error,
    );
  });
  await test("Package cancellation refunds only unused value in the original tender and blocks further redemption", async () => {
    const pkg = success(
      await command("receptionist", "package.sell", {
        patient_id: patientId,
        name: "Synthetic refund package",
        sessions: 3,
        currency: "USD",
        amount: "12.34",
        method: "bank",
      }),
    ).data.id;
    success(
      await command("receptionist", "package.redeem", {
        patient_id: patientId,
        package_id: pkg,
        encounter_id: encounterId,
      }),
    );
    const correction = success(
      await workflow("owner", "package.cancel", {
        id: pkg,
        reason: "Synthetic unused session refund",
      }),
    ).data.id;
    const row = (
      await db.query(
        "select amount from clinic.package_corrections where id=$1",
        [correction],
      )
    ).rows[0];
    assert.equal(row.amount, "8.230");
    assert.equal(
      (
        await db.query(
          "select l.credit from clinic.journal_lines l join clinic.journals j on j.id=l.journal_id where j.source_id=$1 and l.account='bank'",
          [correction],
        )
      ).rows[0].credit,
      "8.230",
    );
    assert.ok(
      (
        await command("receptionist", "package.redeem", {
          patient_id: patientId,
          package_id: pkg,
          encounter_id: draftId,
        })
      ).error,
    );
    assert.ok(
      (
        await workflow("owner", "package.cancel", {
          id: pkg,
          reason: "Duplicate refund attempt",
        })
      ).error,
    );
  });
  await test("Stock counts create immutable adjustment movements and reject stale quantities", async () => {
    const lot = success(
      await command("owner", "stock.receive", {
        product: "Synthetic count item",
        lot_number: "COUNT-1",
        expires_on: "2099-01-01",
        unit: "unit",
        amount: "8",
      }),
    ).data.id;
    const adjustment = success(
      await workflow("owner", "stock.adjust", {
        id: lot,
        version: 1,
        counted: "5",
        reason: "Synthetic waste count",
      }),
    ).data.id;
    assert.equal(
      (
        await db.query(
          "select quantity from clinic.stock_movements where id=$1",
          [adjustment],
        )
      ).rows[0].quantity,
      "-3.000",
    );
    assert.equal(
      (
        await workflow("owner", "stock.adjust", {
          id: lot,
          version: 1,
          counted: "4",
          reason: "Stale count attempt",
        })
      ).error?.code,
      "40001",
    );
  });

  await test("Product alerts aggregate usable lots and reject inconsistent receipt metadata", async () => {
    const supplier = success(
      await workflow("owner", "supplier.create", {
        name: "Synthetic supplier",
        phone: "+9647700000011",
      }),
    ).data.id;
    const product = success(
      await workflow("owner", "product.create", {
        name: "Synthetic catalog product",
        unit: "vial",
        reorder_level: "5",
        supplier_id: supplier,
      }),
    ).data.id;
    assert.ok(
      (
        await workflow("receptionist", "product.create", {
          name: "Forbidden product",
          unit: "vial",
          reorder_level: "1",
        })
      ).error,
    );
    const lotPayload = {
      product_id: product,
      product: "Ignored client product",
      unit: "vial",
      lot_number: "CAT-001",
      expires_on: "2099-12-31",
      amount: "3",
    };
    assert.ok(
      (await command("owner", "stock.receive", { ...lotPayload, unit: "box" }))
        .error,
    );
    const lot = success(await command("owner", "stock.receive", lotPayload))
      .data.id;
    const stored = (
      await db.query(
        "select product,unit,product_id from clinic.stock_lots where id=$1",
        [lot],
      )
    ).rows[0];
    assert.equal(stored.product, "Synthetic catalog product");
    assert.equal(stored.unit, "vial");
    assert.equal(stored.product_id, product);
    assert.ok(
      (
        await command("owner", "stock.receive", {
          ...lotPayload,
          expires_on: "2098-12-31",
        })
      ).error,
    );
    const alerts = success(await clients.owner.rpc("inventory_alerts")).data
      .items;
    assert.equal(
      Number(
        alerts.find((r: any) => r.id === product && r.category === "reorder")
          .available,
      ),
      3,
    );
    success(
      await command("owner", "stock.receive", {
        ...lotPayload,
        lot_number: "CAT-002",
        amount: "4",
      }),
    );
    assert.ok(
      !success(await clients.owner.rpc("inventory_alerts")).data.items.some(
        (r: any) => r.id === product && r.category === "reorder",
      ),
    );
    assert.ok((await clients.receptionist.rpc("inventory_alerts")).error);
    success(
      await workflow("owner", "supplier.update", {
        id: supplier,
        version: 1,
        name: "Synthetic supplier revised",
        active: true,
      }),
    );
    assert.ok(
      (
        await workflow("owner", "supplier.update", {
          id: supplier,
          version: 1,
          name: "Stale name",
          active: true,
        })
      ).error,
    );
  });
  await test("Clinical histories paginate beyond the original workspace cap and deny financial roles", async () => {
    const doctor = success(await clients.doctor.auth.getUser()).data.user!.id;
    const branch = (
      await db.query(
        "select id from clinic.branches where organization_id=$1 limit 1",
        [org],
      )
    ).rows[0].id;
    await db.query(
      "insert into clinic.encounters(organization_id,patient_id,doctor_id,branch_id,chief_complaint) select $1,$2,$3,$4,'Synthetic paginated draft '||i from generate_series(1,305) i",
      [org, patientId, doctor, branch],
    );
    const seen = new Set<string>();
    let cursor_id: string | null = null;
    let more = true;
    while (more) {
      const result: { items: { id: string }[]; has_more: boolean } = success(
        await clients.doctor.rpc("history_page", {
          record_type: "encounters",
          patient_id: patientId,
          cursor_id,
          page_size: 100,
        }),
      ).data;
      for (const row of result.items) {
        assert.ok(!seen.has(row.id));
        seen.add(row.id);
      }
      more = result.has_more;
      cursor_id = result.items.at(-1)?.id ?? null;
    }
    assert.ok(seen.size > 300);
    assert.ok(
      (
        await clients.accountant.rpc("history_page", {
          record_type: "encounters",
          patient_id: patientId,
        })
      ).error,
    );
  });
  await test("Receivables reports total the full result set while paginating details and honor historical cutoffs", async () => {
    for (let i = 0; i < 105; i++)
      success(
        await command("receptionist", "invoice.issue", {
          patient_id: patientId,
          currency: "USD",
          lines: [{ service_id: serviceId, quantity: 1 }],
        }),
      );
    const today = (
      await db.query(
        "select (now() at time zone 'Asia/Baghdad')::date::text today",
      )
    ).rows[0].today;
    const args = {
      report_type: "receivables",
      from_day: "2000-01-01",
      to_day: today,
      page_number: 0,
    };
    const report = success(
      await clients.owner.rpc("financial_report", args),
    ).data;
    assert.equal(report.items.length, 100);
    assert.equal(report.has_more, true);
    assert.ok(report.records > 100);
    const expected = (
      await db.query(
        "with balances as (select i.total-coalesce((select sum(case when p.kind='refund' then -coalesce(p.invoice_amount,p.amount) else coalesce(p.invoice_amount,p.amount) end) from clinic.payments p where p.invoice_id=i.id and p.kind in ('payment','deposit_application','refund') and p.created_at<($2::date+1)::timestamp at time zone 'Asia/Baghdad'),0)-coalesce((select sum(c.amount) from clinic.credit_notes c where c.invoice_id=i.id and c.created_at<($2::date+1)::timestamp at time zone 'Asia/Baghdad'),0) balance from clinic.invoices i where i.organization_id=$1 and i.currency='USD' and i.created_at<($2::date+1)::timestamp at time zone 'Asia/Baghdad') select sum(balance) total from balances where balance>0",
        [org, today],
      )
    ).rows[0].total;
    assert.ok(
      new Decimal(
        report.totals.find((r: any) => r.currency === "USD").amount,
      ).eq(expected),
    );
    const yesterday = (
      await db.query("select ($1::date-1)::text yesterday", [today])
    ).rows[0].yesterday;
    assert.equal(
      success(
        await clients.owner.rpc("financial_report", {
          ...args,
          to_day: yesterday,
        }),
      ).data.records,
      0,
    );
    assert.ok((await clients.doctor.rpc("financial_report", args)).error);
    success(
      await command("receptionist", "invoice.issue", {
        patient_id: patientId,
        currency: "USD",
        lines: [{ service_id: serviceId, quantity: 1 }],
      }),
    );
    const fixed = success(
      await clients.owner.rpc("financial_report", {
        ...args,
        as_at: report.as_at,
        page_number: 1,
      }),
    ).data;
    assert.deepEqual(fixed.totals, report.totals);
    assert.equal(fixed.records, report.records);
    const refreshed = success(
      await clients.owner.rpc("financial_report", args),
    ).data;
    assert.equal(refreshed.records, report.records + 1);
    const statement = success(
      await clients.receptionist.rpc("financial_report", {
        ...args,
        report_type: "patient_statement",
        patient_id: patientId,
      }),
    ).data;
    assert.ok(statement.closing_balances.length > 0);
    for (const balance of statement.closing_balances) {
      const opening =
        statement.opening_balances.find(
          (r: any) => r.currency === balance.currency,
        )?.amount ?? 0;
      const movement =
        statement.totals.find((r: any) => r.currency === balance.currency)
          ?.amount ?? 0;
      assert.ok(new Decimal(opening).plus(movement).eq(balance.amount));
    }
    assert.ok(
      (
        await clients.owner.rpc("financial_report", {
          ...args,
          as_at: "1999-12-31T00:00:00Z",
        })
      ).error,
    );
  });
}

export async function accountingChecks(ctx: Context) {
  const { db, org, other, clients, patientId, test } = ctx;
  const finance = (
    role: string,
    kind: string,
    payload: Record<string, unknown>,
    request_id = randomUUID(),
  ) => clients[role].rpc("finance_workflow", { kind, payload, request_id });
  const dates = (
    await db.query(
      "select (now() at time zone 'Asia/Baghdad')::date::text today,((now() at time zone 'Asia/Baghdad')::date-1)::text yesterday,((now() at time zone 'Asia/Baghdad')::date+1)::text tomorrow",
    )
  ).rows[0];
  let mappingId = "",
    batchId = "";
  await test("Account mappings require a complete approved version and accounting batches never export a posting twice", async () => {
    const accounts = [
      "cash",
      "bank",
      "card",
      "receivable",
      "deposits",
      "revenue",
      "expense",
      "inventory",
      "payable",
      "equity",
      "owner_loan",
      "fx_clearing",
    ];
    assert.ok(
      (
        await finance("accountant", "finance.mapping.create", {
          name: "Invalid mapping",
          codes: { cash: "100" },
        })
      ).error,
    );
    mappingId = success(
      await finance("accountant", "finance.mapping.create", {
        name: "Synthetic chart v1",
        codes: Object.fromEntries(
          accounts.map((key, index) => [key, String(100 + index)]),
        ),
      }),
    ).data.id;
    assert.ok(
      (
        await finance("accountant", "finance.batch.create", {
          mapping_id: mappingId,
          from_day: dates.today,
          to_day: dates.today,
        })
      ).error,
    );
    success(
      await finance("owner", "finance.mapping.approve", { id: mappingId }),
    );
    await assert.rejects(
      db.query(
        "update clinic.account_mappings set name='Overwrite' where id=$1",
        [mappingId],
      ),
      /immutable/i,
    );
    const request = randomUUID();
    const payload = {
      mapping_id: mappingId,
      from_day: dates.today,
      to_day: dates.today,
    };
    batchId = success(
      await finance("accountant", "finance.batch.create", payload, request),
    ).data.id;
    assert.equal(
      success(
        await finance("accountant", "finance.batch.create", payload, request),
      ).data.id,
      batchId,
    );
    assert.ok(
      (await finance("accountant", "finance.batch.create", payload)).error,
    );
    const exported = success(
      await clients.accountant.rpc("accounting_batch_download", {
        batch_id: batchId,
      }),
    ).data;
    const total = (
      await db.query(
        "select count(*) from clinic.journal_lines where organization_id=$1",
        [org],
      )
    ).rows[0].count;
    assert.equal(exported.length, Number(total));
    assert.equal(
      new Set(exported.map((r: any) => r.line_id)).size,
      exported.length,
    );
    const sums = new Map<string, Decimal>();
    for (const row of exported)
      sums.set(
        row.currency,
        (sums.get(row.currency) ?? new Decimal(0))
          .plus(row.debit)
          .minus(row.credit),
      );
    for (const amount of sums.values()) assert.ok(amount.isZero());
    assert.ok(
      (
        await clients.receptionist.rpc("accounting_batch_download", {
          batch_id: batchId,
        })
      ).error,
    );
    success(
      await finance("accountant", "finance.batch.acknowledge", {
        id: batchId,
        external_reference: `TEST-${org}`,
        notes: "Synthetic counts and currency totals reconciled",
      }),
    );
    assert.ok(
      (
        await finance("accountant", "finance.batch.acknowledge", {
          id: batchId,
          external_reference: `DUP-${org}`,
          notes: "Duplicate acknowledgement",
        })
      ).error,
    );
  });
  await test("Statement imports reject changed identifiers and concurrent reconciliation cannot consume the same posting twice", async () => {
    const posting = (
      await db.query(
        "select l.id,l.account,j.currency,(l.debit-l.credit)::text amount from clinic.journal_lines l join clinic.journals j on j.id=l.journal_id where j.organization_id=$1 and l.account='bank' order by l.id limit 1",
        [org],
      )
    ).rows[0];
    assert.ok(posting);
    const line = {
      account: posting.account,
      currency: posting.currency,
      amount: posting.amount,
      posted_on: dates.today,
      reference: "Synthetic bank line",
      external_id: `BANK-${org}`,
    };
    const first = success(
      await finance("accountant", "finance.bank.import", { lines: [line] }),
    ).data.id;
    assert.equal(
      success(
        await finance("accountant", "finance.bank.import", { lines: [line] }),
      ).data.id,
      first,
    );
    assert.ok(
      (
        await finance("accountant", "finance.bank.import", {
          lines: [
            { ...line, amount: new Decimal(line.amount).plus(1).toString() },
          ],
        })
      ).error,
    );
    const second = success(
      await finance("accountant", "finance.bank.import", {
        lines: [{ ...line, external_id: `BANK-SECOND-${org}` }],
      }),
    ).data.id;
    const rs = await Promise.all(
      [first, second].map((id) =>
        finance("accountant", "finance.bank.match", {
          id,
          journal_line_id: posting.id,
          reason: "Synthetic statement verification",
        }),
      ),
    );
    assert.equal(rs.filter((r) => !r.error).length, 1);
    const match = rs.find((r) => !r.error)!.data.id;
    success(
      await finance("owner", "finance.bank.reverse_match", {
        id: match,
        reason: "Synthetic correction of matching evidence",
      }),
    );
    success(
      await finance("accountant", "finance.bank.match", {
        id: first,
        journal_line_id: posting.id,
        reason: "Reviewed synthetic match",
      }),
    );
    assert.equal(
      (
        await db.query(
          "select count(*) from clinic.bank_match_reversals where match_id=$1",
          [match],
        )
      ).rows[0].count,
      "1",
    );
    const foreign = (
      await db.query(
        "insert into clinic.bank_statement_lines(organization_id,account,currency,posted_on,amount,reference,external_id,created_by) values($1,$2,$3,$4,$5,'Foreign synthetic line','FOREIGN',$6) returning id",
        [
          other,
          line.account,
          line.currency,
          dates.today,
          line.amount,
          success(await clients.owner.auth.getUser()).data.user!.id,
        ],
      )
    ).rows[0].id;
    assert.ok(
      (
        await finance("accountant", "finance.bank.match", {
          id: foreign,
          journal_line_id: posting.id,
          reason: "Forbidden cross organization match",
        })
      ).error,
    );
  });
  await test("Closed periods reject backdated and future adjustments while open-period journals remain balanced", async () => {
    success(
      await finance("accountant", "finance.period.close", {
        from_day: dates.yesterday,
        to_day: dates.yesterday,
        reason: "Synthetic reconciled period close",
      }),
    );
    const payload = {
      posting_day: dates.yesterday,
      currency: "USD",
      amount: "1.23",
      debit_account: "expense",
      credit_account: "bank",
      description: "Synthetic accounting adjustment",
    };
    assert.ok(
      (await finance("accountant", "finance.journal.adjust", payload)).error,
    );
    assert.ok(
      (
        await finance("accountant", "finance.journal.adjust", {
          ...payload,
          posting_day: dates.tomorrow,
        })
      ).error,
    );
    assert.ok(
      (
        await finance("accountant", "finance.period.close", {
          from_day: dates.yesterday,
          to_day: dates.yesterday,
          reason: "Duplicate period close",
        })
      ).error,
    );
    const id = success(
      await finance("accountant", "finance.journal.adjust", {
        ...payload,
        posting_day: dates.today,
      }),
    ).data.id;
    const row = (
      await db.query(
        "select j.accounting_date::text as posting_day,sum(l.debit-l.credit) balance from clinic.journals j join clinic.journal_lines l on l.journal_id=j.id where j.id=$1 group by j.accounting_date",
        [id],
      )
    ).rows[0];
    assert.equal(row.posting_day, dates.today);
    assert.equal(Number(row.balance), 0);
  });
  await test("Non-finite financial amounts are rejected by database constraints", async () => {
    for (const amount of ["NaN", "Infinity", "-Infinity"]) {
      assert.ok(
        (
          await ctx.command("receptionist", "payment.record", {
            patient_id: patientId,
            currency: "USD",
            amount,
            method: "cash",
          })
        ).error,
      );
      assert.ok(
        (
          await finance("accountant", "finance.journal.adjust", {
            posting_day: dates.today,
            currency: "USD",
            amount,
            debit_account: "expense",
            credit_account: "bank",
            description: "Nonfinite amount rejection",
          })
        ).error,
      );
    }
  });
}

export async function accessChecks(ctx: Context) {
  const { db, clients, patientId, test, command } = ctx;
  const access = (
    role: string,
    kind: string,
    payload: Record<string, unknown>,
  ) =>
    clients[role].rpc("access_workflow", {
      kind,
      payload,
      request_id: randomUUID(),
    });
  await test("Additional roles are explicit, owner-controlled and revoked against an existing session", async () => {
    const user = success(await clients.receptionist.auth.getUser()).data.user!
      .id;
    assert.ok(
      (
        await access("administrator", "access.role.grant", {
          user_id: user,
          role: "doctor",
          reason: "Unauthorized clinical role grant",
        })
      ).error,
    );
    success(
      await access("owner", "access.role.grant", {
        user_id: user,
        role: "doctor",
        reason: "Synthetic explicit clinical authorization",
      }),
    );
    success(
      await clients.receptionist.rpc("clinical_record", {
        patient_id: patientId,
      }),
    );
    success(
      await access("owner", "access.role.revoke", {
        user_id: user,
        role: "doctor",
        reason: "Synthetic end of clinical authorization",
      }),
    );
    assert.ok(
      (
        await clients.receptionist.rpc("clinical_record", {
          patient_id: patientId,
        })
      ).error,
    );
  });
  await test("Assigned-care scope denies unassigned clinical records and exports without granting business access", async () => {
    const doctor = success(await clients.doctor.auth.getUser()).data.user!.id;
    const assignment = success(
      await access("owner", "care.assign", {
        user_id: doctor,
        patient_id: patientId,
        reason: "Synthetic assigned care responsibility",
      }),
    ).data.id;
    success(
      await access("owner", "care.scope.set", {
        scope: "assigned",
        reason: "Synthetic care-scope acceptance test",
      }),
    );
    success(
      await clients.doctor.rpc("clinical_record", { patient_id: patientId }),
    );
    const otherPatient = success(
      await command("receptionist", "patient.create", {
        full_name: "Unassigned synthetic patient",
        birth_precision: "unknown",
      }),
    ).data.id;
    assert.ok(
      (
        await clients.doctor.rpc("clinical_record", {
          patient_id: otherPatient,
        })
      ).error,
    );
    assert.ok(
      (
        await clients.doctor.rpc("patient_export", {
          patient_id: otherPatient,
          reason: "Synthetic unauthorized export attempt",
        })
      ).error,
    );
    assert.ok(
      (
        await clients.owner.rpc("patient_export", {
          patient_id: patientId,
          reason: "Business role must not export clinical records",
        })
      ).error,
    );
    const exported = success(
      await clients.doctor.rpc("patient_export", {
        patient_id: patientId,
        reason: "Synthetic authorized care-record transfer",
      }),
    ).data;
    assert.ok(exported.export_id);
    assert.equal(exported.patient.id, patientId);
    assert.ok(exported.encounters.length > 0);
    assert.equal(
      (
        await db.query(
          "select purpose from clinic.patient_exports where id=$1",
          [exported.export_id],
        )
      ).rows[0].purpose,
      "Synthetic authorized care-record transfer",
    );
    success(
      await access("owner", "care.revoke", {
        id: assignment,
        reason: "Synthetic care responsibility ended",
      }),
    );
    assert.ok(
      (await clients.doctor.rpc("clinical_record", { patient_id: patientId }))
        .error,
    );
    success(
      await access("owner", "care.scope.set", {
        scope: "organization",
        reason: "Restore synthetic clinic sharing policy",
      }),
    );
  });
  await test("Per-currency approval limits are enforced in original and dated financial operations", async () => {
    const user = success(await clients.accountant.auth.getUser()).data.user!.id;
    success(
      await access("owner", "access.limit.set", {
        user_id: user,
        currency: "USD",
        max_amount: "5",
        reason: "Synthetic delegated USD approval limit",
      }),
    );
    assert.ok(
      (
        await command("accountant", "journal.post", {
          currency: "USD",
          amount: "6",
          debit_account: "expense",
          credit_account: "bank",
          description: "Beyond delegated limit",
        })
      ).error,
    );
    const today = (
      await db.query(
        "select (now() at time zone 'Asia/Baghdad')::date::text today",
      )
    ).rows[0].today;
    assert.ok(
      (
        await clients.accountant.rpc("finance_workflow", {
          kind: "finance.journal.adjust",
          payload: {
            posting_day: today,
            currency: "USD",
            amount: "6",
            debit_account: "expense",
            credit_account: "bank",
            description: "Beyond delegated limit",
          },
          request_id: randomUUID(),
        })
      ).error,
    );
    success(
      await command("accountant", "journal.post", {
        currency: "USD",
        amount: "1",
        debit_account: "expense",
        credit_account: "bank",
        description: "Within delegated limit",
      }),
    );
  });
  await test("Retention policy approval and legal-hold release preserve immutable evidence and patient records", async () => {
    const rule = success(
      await access("owner", "retention.rule.create", {
        record_type: "clinical",
        retain_days: 3650,
        policy_reference: "Synthetic test policy only",
        reason: "Test policy recording without deletion",
      }),
    ).data.id;
    success(
      await access("owner", "retention.rule.approve", {
        id: rule,
        reason: "Synthetic policy review evidence",
      }),
    );
    await assert.rejects(
      db.query("update clinic.retention_rules set retain_days=1 where id=$1", [
        rule,
      ]),
      /immutable/i,
    );
    const hold = success(
      await access("owner", "retention.hold", {
        patient_id: patientId,
        reason: "Synthetic preservation requirement",
      }),
    ).data.id;
    assert.ok(
      (
        await access("administrator", "retention.release", {
          id: hold,
          reason: "Unauthorized hold release",
        })
      ).error,
    );
    success(
      await access("owner", "retention.release", {
        id: hold,
        reason: "Synthetic authorized hold release",
      }),
    );
    assert.ok(
      (
        await access("owner", "retention.release", {
          id: hold,
          reason: "Duplicate release attempt",
        })
      ).error,
    );
    assert.equal(
      (
        await db.query("select count(*) from clinic.patients where id=$1", [
          patientId,
        ])
      ).rows[0].count,
      "1",
    );
  });
  await test("Patient documents are signed once and corrections preserve the original document", async () => {
    const workflow = (payload: Record<string, unknown>) =>
      clients.doctor.rpc("workflow", {
        kind: "document.create",
        payload,
        request_id: randomUUID(),
      });
    const original = success(
      await workflow({
        patient_id: patientId,
        kind: "referral",
        title: "Synthetic referral",
        body: "Synthetic referral content for verification.",
      }),
    ).data.id;
    await assert.rejects(
      db.query(
        "update clinic.patient_documents set body='Overwrite' where id=$1",
        [original],
      ),
      /immutable/i,
    );
    const identity = (
      await db.query(
        "select identity_snapshot from clinic.patient_documents where id=$1",
        [original],
      )
    ).rows[0].identity_snapshot;
    const patientBefore = (
      await db.query("select full_name from clinic.patients where id=$1", [
        patientId,
      ])
    ).rows[0].full_name;
    assert.equal(identity.full_name, patientBefore);
    assert.ok(identity.clinician_name);
    await db.query(
      "update clinic.patients set full_name='Synthetic renamed patient' where id=$1",
      [patientId],
    );
    assert.equal(
      (
        await db.query(
          "select identity_snapshot from clinic.patient_documents where id=$1",
          [original],
        )
      ).rows[0].identity_snapshot.full_name,
      patientBefore,
    );
    const corrected = success(
      await workflow({
        patient_id: patientId,
        kind: "referral",
        title: "Corrected synthetic referral",
        body: "Corrected synthetic referral content.",
        supersedes_id: original,
        correction_reason: "Synthetic correction evidence",
      }),
    ).data.id;
    const result = success(
      await clients.doctor.rpc("history_page", {
        record_type: "patient_documents",
        patient_id: patientId,
      }),
    ).data;
    assert.ok(result.items.some((r: any) => r.id === original));
    assert.ok(result.items.some((r: any) => r.id === corrected));
    assert.ok(
      (
        await clients.owner.rpc("history_page", {
          record_type: "patient_documents",
          patient_id: patientId,
        })
      ).error,
    );
  });
}
