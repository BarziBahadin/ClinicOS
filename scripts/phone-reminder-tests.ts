import assert from "node:assert/strict";
import { randomUUID } from "node:crypto";
import type { Context } from "./workflow-tests";
export async function phoneReminderChecks({
  db,
  org,
  other,
  clients,
  patientId,
  command,
  test,
}: Context) {
  const success = (result: { data: any; error: any }) => {
    assert.equal(result.error, null, JSON.stringify(result.error));
    return result.data;
  };
  const workflow = (
    payload: Record<string, unknown>,
    request_id = randomUUID(),
  ) =>
    clients.receptionist.rpc("workflow", {
      kind: "contact.log",
      payload,
      request_id,
    });
  const dates = (
    await db.query(
      "select ((now()+interval '5 days') at time zone 'Asia/Baghdad')::date::text call_day,((now()+interval '15 days') at time zone 'Asia/Baghdad')::date::text page_start,((now()+interval '20 days') at time zone 'Asia/Baghdad')::date::text page_end",
    )
  ).rows[0];
  const doctor = success(await clients.doctor.auth.getUser()).user.id;
  await test("Staff call reminders enforce current consent, appointment identity/version and immutable idempotent call outcomes", async () => {
    const start = new Date(Date.now() + 5 * 86400000),
      end = new Date(start.getTime() + 1800000);
    const appointment = success(
      await command("receptionist", "appointment.create", {
        patient_id: patientId,
        doctor_id: doctor,
        starts_at: start.toISOString(),
        ends_at: end.toISOString(),
        service_name: "Synthetic phone reminder",
      }),
    ).id;
    const contact = success(
      await clients.receptionist.rpc("workflow", {
        kind: "contact.add",
        payload: {
          patient_id: patientId,
          phone: "+9647700000018",
          owner_name: "Synthetic guardian",
          relationship: "guardian",
          preferred: true,
        },
        request_id: randomUUID(),
      }),
    ).id;
    const args = {
      from_day: dates.call_day,
      to_day: dates.call_day,
      include_contacted: true,
    };
    const list = async (include_contacted = true) =>
      success(
        await clients.receptionist.rpc("phone_reminders", {
          ...args,
          include_contacted,
        }),
      );
    const blocked = (await list()).items.find((r: any) => r.id === appointment);
    assert.ok(blocked);
    assert.equal(blocked.communication_allowed, false);
    assert.equal(blocked.phone, null);
    const payload = {
      patient_id: patientId,
      appointment_id: appointment,
      appointment_version: 1,
      contact_id: contact,
      channel: "phone",
      purpose: "appointment_reminder",
      outcome: "no_answer",
      notes: "Synthetic unanswered reminder call",
    };
    assert.ok((await workflow(payload)).error);
    success(
      await command("receptionist", "consent.record", {
        patient_id: patientId,
        purpose: "communication",
        granted: true,
        template_version: "Synthetic policy",
        evidence: "Synthetic permission for manual appointment calls",
      }),
    );
    const receptionWorkspace = success(
      await clients.receptionist.rpc("workspace"),
    );
    assert.ok(receptionWorkspace.consents.length > 0);
    assert.ok(
      receptionWorkspace.consents.every(
        (consent: any) => consent.purpose === "communication",
      ),
    );
    assert.ok(
      (
        await command("receptionist", "consent.record", {
          patient_id: patientId,
          purpose: "care_photography",
          granted: true,
          template_version: "Forbidden",
          evidence: "Cannot grant clinical consent",
        })
      ).error,
    );
    const allowed = (await list()).items.find((r: any) => r.id === appointment);
    assert.equal(allowed.phone, "+9647700000018");
    assert.equal(allowed.contact_owner, "Synthetic guardian");
    assert.ok((await clients.accountant.rpc("phone_reminders", args)).error);
    const request = randomUUID(),
      logged = success(await workflow(payload, request)).id;
    assert.equal(success(await workflow(payload, request)).id, logged);
    assert.equal(
      (
        await db.query(
          "select count(*) from clinic.contact_log where appointment_id=$1",
          [appointment],
        )
      ).rows[0].count,
      "1",
    );
    assert.equal(
      (await list(false)).items.find((r: any) => r.id === appointment)
        .last_outcome,
      "no_answer",
    );
    success(
      await workflow({
        ...payload,
        outcome: "reached",
        notes: "Synthetic reminder delivered by staff phone call",
      }),
    );
    assert.ok(
      !(await list(false)).items.some((r: any) => r.id === appointment),
    );
    assert.equal(
      (await list(true)).items.find((r: any) => r.id === appointment)
        .last_outcome,
      "reached",
    );
    const foreignPatient = (
      await db.query(
        "select id from clinic.patients where organization_id=$1 limit 1",
        [other],
      )
    ).rows[0].id;
    const foreignContact = (
      await db.query(
        "insert into clinic.contacts(organization_id,patient_id,phone,owner_name) values($1,$2,'+9647700000019','Foreign synthetic contact') returning id",
        [other, foreignPatient],
      )
    ).rows[0].id;
    assert.ok(
      (await workflow({ ...payload, contact_id: foreignContact })).error,
    );
    success(
      await clients.receptionist.rpc("workflow", {
        kind: "appointment.reschedule",
        payload: {
          id: appointment,
          version: 1,
          starts_at: new Date(start.getTime() + 3600000).toISOString(),
          ends_at: new Date(end.getTime() + 3600000).toISOString(),
          reason: "Synthetic changed appointment",
        },
        request_id: randomUUID(),
      }),
    );
    assert.equal((await workflow(payload)).error?.code, "40001");
    const rescheduled = (await list(false)).items.find(
      (r: any) => r.id === appointment,
    );
    assert.ok(rescheduled);
    assert.equal(rescheduled.last_outcome, null);
    success(
      await command("receptionist", "consent.record", {
        patient_id: patientId,
        purpose: "communication",
        granted: false,
        template_version: "Synthetic policy",
        evidence: "Synthetic communication withdrawal",
      }),
    );
    assert.equal(
      (await list()).items.find((r: any) => r.id === appointment).phone,
      null,
    );
    assert.ok((await workflow({ ...payload, appointment_version: 2 })).error);
    success(
      await command("receptionist", "appointment.status", {
        id: appointment,
        version: 2,
        status: "cancelled",
        reason: "Synthetic reminder test finished",
      }),
    );
    assert.ok(!(await list()).items.some((r: any) => r.id === appointment));
    await assert.rejects(
      db.query(
        "update clinic.contact_log set notes='Overwrite call' where id=$1",
        [logged],
      ),
      /immutable/i,
    );
  });
  await test("Call reminder pages cover all upcoming appointments without exposing another organization", async () => {
    const branch = (
      await db.query(
        "select id from clinic.branches where organization_id=$1 limit 1",
        [org],
      )
    ).rows[0].id;
    await db.query(
      "insert into clinic.appointments(organization_id,branch_id,patient_id,doctor_id,starts_at,ends_at,service_name) select $1,$2,$3,$4,now()+interval '15 days'+i*interval '1 hour',now()+interval '15 days'+i*interval '1 hour'+interval '30 minutes','Synthetic paginated reminder' from generate_series(1,105) i",
      [org, branch, patientId, doctor],
    );
    const args = {
      from_day: dates.page_start,
      to_day: dates.page_end,
      include_contacted: true,
    };
    const first = success(
      await clients.receptionist.rpc("phone_reminders", {
        ...args,
        page_number: 0,
      }),
    );
    const second = success(
      await clients.receptionist.rpc("phone_reminders", {
        ...args,
        page_number: 1,
      }),
    );
    assert.equal(first.records, 105);
    assert.equal(first.items.length, 100);
    assert.equal(first.has_more, true);
    assert.equal(second.items.length, 5);
    assert.equal(second.has_more, false);
    assert.equal(
      new Set([...first.items, ...second.items].map((r) => r.id)).size,
      105,
    );
    assert.ok(
      [...first.items, ...second.items].every(
        (r) => r.patient_id === patientId,
      ),
    );
  });
}
