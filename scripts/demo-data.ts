import { execFileSync } from "node:child_process";
import { createHash } from "node:crypto";
import { existsSync, readFileSync, writeFileSync } from "node:fs";
import { createClient, type SupabaseClient } from "@supabase/supabase-js";
import Decimal from "decimal.js";
import pg from "pg";

// This is additive training data. Never reset a database or alter existing records.
const status = JSON.parse(
  execFileSync("npx", ["supabase", "status", "--output", "json"], {
    encoding: "utf8",
    stdio: ["ignore", "pipe", "pipe"],
  }),
);
const localHosts = ["localhost", "127.0.0.1", "[::1]"];
const api = new URL(status.API_URL),
  database = new URL(status.DB_URL);
if (
  api.protocol !== "http:" ||
  !localHosts.includes(api.hostname) ||
  !localHosts.includes(database.hostname)
)
  throw new Error("Demo data is restricted to the local development stack.");
const organizationId = "10000000-0000-4000-8000-000000000001";
type Role =
  "owner" | "doctor" | "receptionist" | "administrator" | "accountant";
const accounts: Record<Role, { id: string; email: string; password: string }> =
  JSON.parse(readFileSync(".local/accounts.json", "utf8"));
const db = new pg.Client({
  connectionString: status.DB_URL,
  options: "-c default_transaction_read_only=on",
});
await db.connect();
const clients = {} as Record<Role, SupabaseClient>;
type Operation = {
  role: Role;
  kind: string;
  payload: Record<string, unknown>;
  result?: Record<string, unknown>;
};
type Manifest = {
  ownerId: string;
  day: string;
  operations: Record<string, Operation>;
};
const manifestPath = ".local/demo-data.json";
const previous: Manifest | undefined = existsSync(manifestPath)
  ? JSON.parse(readFileSync(manifestPath, "utf8"))
  : undefined;
const manifest: Manifest =
  previous?.ownerId === accounts.owner.id
    ? previous
    : {
        ownerId: accounts.owner.id,
        day: new Intl.DateTimeFormat("en-CA", {
          timeZone: "Asia/Baghdad",
          year: "numeric",
          month: "2-digit",
          day: "2-digit",
        }).format(new Date()),
        operations: {},
      };
const persist = () =>
  writeFileSync(manifestPath, JSON.stringify(manifest, null, 2) + "\n", {
    mode: 0o600,
  });
const date = (offset: number) =>
  new Date(Date.parse(`${manifest.day}T12:00:00+03:00`) + offset * 86400000)
    .toISOString()
    .slice(0, 10);
const at = (offset: number, time = "10:00") =>
  `${date(offset)}T${time}:00+03:00`;
async function operation(
  role: Role,
  key: string,
  kind: string,
  payload: Record<string, unknown>,
) {
  const saved = (manifest.operations[key] ??= { role, kind, payload });
  if (saved.role !== role || saved.kind !== kind)
    throw new Error(`Demo operation changed: ${key}`);
  if (saved.result) return saved.result;
  persist(); // Keep the original payload if a request is interrupted or retried another day.
  const hash = createHash("sha256")
    .update(`clinicos-demo-v1:${organizationId}:${key}`)
    .digest("hex");
  const request_id = `${hash.slice(0, 8)}-${hash.slice(8, 12)}-4${hash.slice(13, 16)}-8${hash.slice(17, 20)}-${hash.slice(20, 32)}`;
  const workflow =
    /^(service\.(propose|approve)|template\.|document\.|fact\.|prescription\.|contact\.|performed\.|resource\.|supplier\.|product\.)/.test(
      kind,
    );
  const rpc = kind.startsWith("finance.")
    ? "finance_workflow"
    : workflow
      ? "workflow"
      : "command";
  const { data, error } = await clients[role].rpc(rpc, {
    kind,
    payload: saved.payload,
    request_id,
  });
  if (error) throw new Error(`${key}: ${error.message}`);
  saved.result = data;
  persist();
  return data as Record<string, unknown>;
}
const id = async (
  role: Role,
  key: string,
  kind: string,
  payload: Record<string, unknown>,
) => String((await operation(role, key, kind, payload)).id);
try {
  const organization = (
    await db.query("select name from clinic.organizations where id=$1", [
      organizationId,
    ])
  ).rows[0];
  if (!organization || !/development|demo/i.test(organization.name))
    throw new Error(
      "Expected the synthetic development organization. Run local:setup first.",
    );
  for (const role of [
    "owner",
    "doctor",
    "receptionist",
    "administrator",
    "accountant",
  ] as const) {
    const client = createClient(status.API_URL, status.PUBLISHABLE_KEY, {
      auth: { persistSession: false, autoRefreshToken: false },
    });
    const { error } = await client.auth.signInWithPassword(accounts[role]);
    if (error)
      throw new Error(
        `Cannot sign in to local ${role} account: ${error.message}`,
      );
    const membership = await client.rpc("workspace");
    if (
      membership.error ||
      membership.data.organization.id !== organizationId ||
      membership.data.membership.user_id !== accounts[role].id
    )
      throw new Error(`Unexpected local demo membership for ${role}`);
    clients[role] = client;
  }
  console.log(
    "Adding fictional records to the local demo clinic; existing records are preserved.",
  );
  const template = await id("doctor", "consent-template", "template.create", {
    kind: "consent",
    name: "DEMO · training consent",
    language: "en",
    version: 1,
    content:
      "FICTIONAL DEMONSTRATION ONLY. No real person has consented. This template demonstrates the approval and consent workflow.",
  });
  await operation("doctor", "consent-template-approve", "template.approve", {
    id: template,
  });
  const serviceSpecs = [
    [
      "Dermatology consultation",
      "ڕاوێژی پزیشکیی پێست",
      "medical",
      "IQD",
      "25000",
      30,
    ],
    ["Follow-up visit", "سەردانی بەدواداچوون", "medical", "IQD", "15000", 20],
    ["Skin assessment", "هەڵسەنگاندنی پێست", "medical", "IQD", "40000", 30],
    ["Cosmetic consultation", "ڕاوێژی جوانکاری", "cosmetic", "USD", "30", 30],
    ["Procedure review", "پشکنینی پرۆسە", "medical", "USD", "50", 30],
    ["Treatment session", "دانیشتنی چارەسەر", "cosmetic", "USD", "100", 40],
    ["Skin-care review", "پشکنینی چاودێریی پێست", "cosmetic", "USD", "65", 25],
    ["Clinical assessment", "هەڵسەنگاندنی پزیشکی", "medical", "USD", "80", 30],
  ] as const;
  const services = [];
  for (const [
    i,
    [name, name_ckb, category, currency, price, duration],
  ] of serviceSpecs.entries()) {
    const service = await id(
      "receptionist",
      `service-${i}`,
      "service.propose",
      {
        name: `DEMO · ${name}`,
        name_ckb: `DEMO · ${name_ckb}`,
        category,
        currency,
        duration,
      },
    );
    await operation("owner", `service-approve-${i}`, "service.approve", {
      id: service,
      currency,
      price,
    });
    services.push({ id: service, name: `DEMO · ${name}`, currency, price });
  }
  await operation("receptionist", "service-pending", "service.propose", {
    name: "DEMO · new treatment awaiting price approval",
    name_ckb: "DEMO · چارەسەری چاوەڕوانی پەسەندکردن",
    category: "cosmetic",
    currency: "USD",
    duration: 30,
  });
  const room = await id("owner", "room", "resource.add", {
    name: "DEMO · consultation room",
    kind: "room",
  });
  await operation("owner", "device", "resource.add", {
    name: "DEMO · treatment device",
    kind: "device",
  });
  const names = [
    "Ava",
    "Dilan",
    "Rojin",
    "Aras",
    "Lana",
    "Soran",
    "Narin",
    "Azad",
    "Rona",
    "Shilan",
    "Dara",
    "Raman",
    "Hana",
    "Baran",
    "Lorin",
    "Alan",
    "نەخۆشی ١٧",
    "نەخۆشی ١٨",
    "نەخۆشی ١٩",
    "نەخۆشی ٢٠",
  ];
  const patients: string[] = [],
    contacts: string[] = [];
  for (const [i, name] of names.entries()) {
    const phone = `+9647500000${String(100 + Math.floor(i / 2)).padStart(3, "0")}`;
    const patient = await id("receptionist", `patient-${i}`, "patient.create", {
      full_name: `DEMO · ${name}`,
      phone,
      birth_date: i === 19 ? null : `${i === 18 ? 2015 : 1970 + i * 2}-04-12`,
      birth_precision: i === 19 ? "unknown" : "day",
      gender: i % 2 ? "male" : "female",
      language: i >= 16 ? "ckb" : "en",
      guardian_name: i === 18 ? "DEMO · guardian" : "",
      guardian_relationship: i === 18 ? "parent" : "",
      communication_consent: i % 5 !== 4,
    });
    patients.push(patient);
    contacts.push(
      await id("receptionist", `contact-${i}`, "contact.add", {
        patient_id: patient,
        phone,
        owner_name: `DEMO · ${name}`,
        relationship: "self",
        preferred: true,
        verified: true,
      }),
    );
    await operation("receptionist", `communication-${i}`, "consent.record", {
      patient_id: patient,
      purpose: "communication",
      granted: i % 5 !== 4,
      template_id: template,
      template_version: "1",
      evidence:
        "FICTIONAL demo consent selection. No real consent or phone contact took place.",
    });
  }
  const appointments: string[] = [];
  const times = [
    "09:30",
    "10:10",
    "10:50",
    "11:30",
    "13:30",
    "14:10",
    "14:50",
    "15:30",
  ];
  for (let i = 0; i < 20; i++) {
    const offset = i < 8 ? 0 : i < 12 ? 1 : i < 16 ? 2 : -1;
    const start = at(offset, times[i % 8]);
    const ends = new Date(Date.parse(start) + 25 * 60000).toISOString();
    const appointment = await id(
      "receptionist",
      `appointment-${i}`,
      "appointment.create",
      {
        patient_id: patients[i],
        doctor_id: accounts.doctor.id,
        resource_id: room,
        service_name: services[i % services.length].name,
        starts_at: start,
        ends_at: ends,
        walk_in: i === 2,
      },
    );
    appointments.push(appointment);
    const states =
      i < 2 || i >= 16
        ? ["checked_in", "in_care", "completed"]
        : i === 2
          ? ["in_care"]
          : i === 3 || i === 4
            ? ["checked_in"]
            : i === 6
              ? ["cancelled"]
              : i === 7
                ? ["no_show"]
                : [];
    for (const [step, state] of states.entries())
      await operation(
        "receptionist",
        `appointment-${i}-${state}`,
        "appointment.status",
        {
          id: appointment,
          version: step + 1,
          status: state,
          reason: "DEMO · simulated visit status for training",
        },
      );
  }
  console.log(
    "Patients, contacts, treatments and appointment states are ready.",
  );
  const encounters: string[] = [];
  for (let i = 0; i < 10; i++) {
    const encounter = await id("doctor", `encounter-${i}`, "encounter.save", {
      patient_id: patients[i],
      chief_complaint: `DEMO · ${["Skin review", "Follow-up visit", "Consultation", "Treatment review"][i % 4]}`,
      history: "Fictional training history. No real patient information.",
      allergies: "DEMO · allergy history reviewed for this fictional record",
      findings:
        "Synthetic examination field for demonstrating the clinical record.",
      diagnosis: "DEMO · fictional skin assessment",
      plan: "Demonstration of review and follow-up only. Not treatment guidance.",
    });
    encounters.push(encounter);
    await operation("doctor", `fact-${i}`, "fact.record", {
      patient_id: patients[i],
      kind: i % 2 ? "problem" : "history",
      content: "DEMO · fictional longitudinal entry, for training only.",
      status: "active",
    });
    if (i < 2)
      await operation("doctor", `prescription-${i}`, "prescription.add", {
        patient_id: patients[i],
        encounter_id: encounter,
        medicine: "DEMO item — not a medicine",
        strength: "Training field",
        dose: "Training field only",
        route: "DEMO",
        frequency: "DEMO",
        duration: "DEMO",
        quantity: "0",
        instructions:
          "Fictional record. Do not prescribe or administer this item.",
      });
    if (i < 8)
      await operation("doctor", `sign-${i}`, "encounter.sign", {
        id: encounter,
        version: 1,
      });
    if (i < 4) {
      await operation("doctor", `performed-${i}`, "performed.record", {
        patient_id: patients[i],
        encounter_id: encounter,
        service_id: services[i].id,
        quantity: 1,
      });
      await operation("doctor", `document-${i}`, "document.create", {
        patient_id: patients[i],
        kind: "care_letter",
        title: "DEMO · patient letter",
        body: "Fictional training document. This illustrates a signed patient letter and print layout. No clinical instructions or real patient details.",
      });
    }
  }
  await operation("doctor", "addendum", "encounter.addendum", {
    encounter_id: encounters[0],
    content:
      "DEMO · this is an addendum showing how a signed record is corrected without rewriting the original.",
  });
  await operation("doctor", "procedure-consent", "consent.record", {
    patient_id: patients[0],
    purpose: "procedure",
    granted: true,
    template_id: template,
    evidence: "DEMO only — no real procedure or consent.",
  });
  await operation("doctor", "procedure", "procedure.create", {
    patient_id: patients[0],
    encounter_id: encounters[0],
    name: "DEMO · procedure documentation",
    body_site: "Fictional training field",
    product: "DEMO",
    lot_number: "DEMO",
    settings: "Training only",
    quantity: "1",
    aftercare:
      "DEMO only. This is a print-layout example and contains no treatment instructions.",
    adverse_event: "No actual procedure took place.",
  });
  for (let i = 0; i < 6; i++) {
    const result = await id("doctor", `result-${i}`, "result.create", {
      patient_id: patients[i],
      order_name: `DEMO · ${i % 2 ? "Clinical review result" : "Laboratory result"}`,
      body_site: "Training field",
      specimen_reference: `DEMO-SPEC-${i + 1}`,
      due_at: at(i < 2 ? -1 : i - 1),
    });
    const states =
      i === 1
        ? ["received"]
        : i === 2
          ? ["received", "reviewed"]
          : i === 3
            ? ["received", "reviewed", "notified"]
            : [];
    for (const [step, state] of states.entries())
      await operation("doctor", `result-${i}-${state}`, "result.update", {
        id: result,
        version: step + 1,
        status: state,
        result_text:
          "DEMO · simulated result workflow. No real test, interpretation or patient notification.",
      });
    const task = await id("doctor", `task-${i}`, "task.create", {
      patient_id: patients[i],
      title: `DEMO · ${i % 2 ? "Review outstanding result" : "Arrange follow-up visit"}`,
      due_at: at(i < 3 ? -1 : i),
      assigned_to: accounts.doctor.id,
    });
    if (i === 5)
      await operation("doctor", "task-complete", "task.complete", { id: task });
  }
  for (const currency of ["IQD", "USD"]) {
    await operation("receptionist", `till-${currency}`, "till.open", {
      currency,
      opening: "0",
    });
    await operation("owner", `opening-${currency}`, "cash.record", {
      kind: "opening_balance",
      currency,
      amount: currency === "IQD" ? "2000000" : "5000",
      method: "cash",
      description: "DEMO · fictional opening float",
    });
    await operation("owner", `transfer-${currency}`, "cash.record", {
      kind: "transfer",
      currency,
      amount: currency === "IQD" ? "500000" : "1000",
      method: "cash",
      destination: "bank",
      description: "DEMO · fictional cash-to-bank transfer",
    });
  }
  for (let i = 4; i < 16; i++) {
    const service = services[(i - 4) % services.length];
    const invoice = await id("receptionist", `invoice-${i}`, "invoice.issue", {
      patient_id: patients[i],
      currency: service.currency,
      lines: [{ service_id: service.id, quantity: 1 }],
    });
    if (i % 3 !== 0)
      await operation("receptionist", `payment-${i}`, "payment.record", {
        patient_id: patients[i],
        invoice_id: invoice,
        currency: service.currency,
        amount: new Decimal(service.price)
          .div(i % 3 === 1 ? 1 : 2)
          .toFixed(service.currency === "USD" ? 2 : 3),
        method: i % 2 ? "cash" : "bank",
      });
  }
  await operation("receptionist", "deposit", "payment.record", {
    patient_id: patients[2],
    currency: "USD",
    amount: "75",
    method: "cash",
  });
  for (let i = 0; i < 2; i++) {
    const pkg = await id("receptionist", `package-${i}`, "package.sell", {
      patient_id: patients[i],
      name: "DEMO · three-session training package",
      sessions: 3,
      currency: "USD",
      amount: "240",
      method: "cash",
    });
    if (i === 0)
      await operation("receptionist", "package-redeem", "package.redeem", {
        patient_id: patients[0],
        package_id: pkg,
        encounter_id: encounters[0],
      });
  }
  for (let i = 0; i < 6; i++)
    await operation("owner", `expense-${i}`, "expense.record", {
      category: "operating",
      supplier: `DEMO · supplier ${(i % 2) + 1}`,
      description: `DEMO · ${["Clinic supplies", "Utilities", "Equipment maintenance", "Office supplies", "Consumables", "Training materials"][i]}`,
      currency: i % 2 ? "USD" : "IQD",
      amount: i % 2 ? "45" : "50000",
      paid: i % 3 !== 0,
      method: i % 2 ? "bank" : "cash",
    });
  console.log(
    "Clinical records, results, invoices, payments, deposits and packages are ready.",
  );
  const supplier = await id("administrator", "supplier", "supplier.create", {
    name: "DEMO · medical supplies",
    contact_person: "Fictional supplier contact",
    phone: "+9647500000199",
    address: "Fictional demo address",
  });
  for (const [i, name] of [
    "Gloves",
    "Gauze packs",
    "Dressings",
    "Applicators",
    "Sample containers",
    "Training consumables",
  ].entries()) {
    const product = await id(
      "administrator",
      `product-${i}`,
      "product.create",
      {
        name: `DEMO · ${name}`,
        unit: "pack",
        reorder_level: "10",
        supplier_id: supplier,
      },
    );
    const lot = await id("administrator", `stock-${i}`, "stock.receive", {
      product_id: product,
      product: `DEMO · ${name}`,
      unit: "pack",
      lot_number: `DEMO-LOT-${i + 1}`,
      expires_on: date(i === 0 ? 7 : i === 1 ? 20 : 180 + i * 10),
      amount: i < 2 ? "3" : "40",
    });
    if (i === 2)
      await operation("doctor", "stock-use", "stock.use", {
        patient_id: patients[0],
        encounter_id: encounters[0],
        lot_id: lot,
        amount: "2",
        reason: "DEMO · simulated stock use for training",
      });
  }
  for (const i of [8, 10, 11])
    await operation("receptionist", `reminder-${i}`, "contact.log", {
      patient_id: patients[i],
      appointment_id: appointments[i],
      appointment_version: 1,
      contact_id: contacts[i],
      channel: "phone",
      purpose: "appointment_reminder",
      outcome: i === 8 ? "reached" : "no_answer",
      notes: "DEMO · simulated reminder outcome. No phone call was made.",
    });
  const counts = (
    await db.query(
      `select
    (select count(*) from clinic.patients where organization_id=$1 and full_name like 'DEMO%') patients,
    (select count(*) from clinic.appointments where organization_id=$1 and service_name like 'DEMO%') appointments,
    (select count(*) from clinic.encounters where organization_id=$1 and chief_complaint like 'DEMO%') encounters,
    (select count(*) from clinic.invoices i join clinic.patients p on p.id=i.patient_id where i.organization_id=$1 and p.full_name like 'DEMO%') invoices,
    (select count(*) from clinic.stock_lots where organization_id=$1 and product like 'DEMO%') stock_lots`,
      [organizationId],
    )
  ).rows[0];
  console.log("Local demo records:", counts);
  console.log(
    `Appointment demo day: ${manifest.day}. All DEMO records and numbers are fictional. Do not dial demo numbers.`,
  );
} finally {
  for (const client of Object.values(clients))
    await client.auth.signOut({ scope: "local" });
  await db.end();
}
