import { execFileSync } from "node:child_process";
import { mkdirSync, readFileSync, existsSync, writeFileSync } from "node:fs";
import { randomBytes } from "node:crypto";
import { createClient } from "@supabase/supabase-js";
import pg from "pg";
const raw = execFileSync("npx", ["supabase", "status", "--output", "json"], {
  encoding: "utf8",
  stdio: ["ignore", "pipe", "pipe"],
});
const status = JSON.parse(raw);
const url = status.API_URL;
if (!/^http:\/\/(127\.0\.0\.1|localhost):/.test(url))
  throw new Error("This script only seeds the local development stack.");
const admin = createClient(url, status.SECRET_KEY ?? status.SERVICE_ROLE_KEY, {
  auth: { persistSession: false, autoRefreshToken: false },
});
const db = new pg.Client({ connectionString: status.DB_URL });
await db.connect();
const roles = [
  "owner",
  "doctor",
  "receptionist",
  "administrator",
  "accountant",
] as const;
mkdirSync(".local", { recursive: true });
const accounts: Record<
  string,
  { username?: string; email: string; password: string; id: string }
> = existsSync(".local/accounts.json")
  ? JSON.parse(readFileSync(".local/accounts.json", "utf8"))
  : {};
const { data: users, error: usersError } = await admin.auth.admin.listUsers({
  perPage: 1000,
});
if (usersError) throw usersError;
for (const role of roles) {
  const email = `${role}@clinicos.test`;
  let user = users.users.find((u) => u.email === email);
  const password =
    accounts[role]?.password ??
    `Local-${randomBytes(18).toString("base64url")}!`;
  if (!user) {
    const { data, error } = await admin.auth.admin.createUser({
      email,
      password,
      email_confirm: true,
    });
    if (error) throw error;
    user = data.user;
  }
  accounts[role] = { username: role, email, password, id: user.id };
}
writeFileSync(
  ".local/accounts.json",
  JSON.stringify(accounts, null, 2) + "\n",
  { mode: 0o600 },
);
const org = "10000000-0000-4000-8000-000000000001",
  branch = "10000000-0000-4000-8000-000000000002";
await db.query("begin");
try {
  await db.query(
    "insert into clinic.organizations(id,name,require_mfa) values($1,'Derma Clinic · Development',false) on conflict do nothing",
    [org],
  );
  await db.query(
    "insert into clinic.branches(id,organization_id,name) values($1,$2,'Main clinic') on conflict do nothing",
    [branch, org],
  );
  for (const role of roles)
    await db.query(
      "insert into clinic.memberships(organization_id,user_id,display_name,role,username) values($1,$2,$3,$4,$4) on conflict(organization_id,user_id) do update set username=coalesce(clinic.memberships.username,excluded.username)",
      [org, accounts[role].id, `Development ${role}`, role],
    );
  const {
    rows: [count],
  } = await db.query(
    "select count(*) from clinic.services where organization_id=$1",
    [org],
  );
  if (Number(count.count) === 0) {
    for (const [name, nameCkb, category, currency, price, duration] of [
      [
        "Dermatology consultation",
        "ڕاوێژی پزیشکی پێست",
        "medical",
        "IQD",
        25000,
        30,
      ],
      [
        "Follow-up consultation",
        "بەدواداچوونی پزیشکی",
        "medical",
        "IQD",
        15000,
        20,
      ],
      ["Clinical procedure", "چارەسەری پزیشکی", "medical", "USD", 50, 30],
      ["Cosmetic consultation", "ڕاوێژی جوانکاری", "cosmetic", "USD", 30, 30],
      ["Treatment session", "دانیشتنی چارەسەر", "cosmetic", "USD", 100, 45],
    ])
      await db.query(
        "insert into clinic.services(organization_id,name,name_ckb,category,currency,price,duration) values($1,$2,$3,$4,$5,$6,$7)",
        [org, name, nameCkb, category, currency, price, duration],
      );
  }
  const {
    rows: [patientCount],
  } = await db.query(
    "select count(*) from clinic.patients where organization_id=$1",
    [org],
  );
  if (Number(patientCount.count) === 0) {
    for (const [i, name, phone, birth, gender] of [
      [1, "Demo patient A", "+9647501234567", "1994-04-12", "female"],
      [2, "Demo patient B", "+9647501234567", "1987-09-21", "male"],
      [3, "نەخۆشی تاقیکردنەوە", "+9647701234567", null, "unknown"],
    ] as const)
      await db.query(
        "insert into clinic.patients(organization_id,patient_number,full_name,phone,birth_date,birth_precision,gender) values($1,$2,$3,$4,$5,$6,$7)",
        [
          org,
          `P-${String(i).padStart(6, "0")}`,
          name,
          phone,
          birth,
          birth ? "day" : "unknown",
          gender,
        ],
      );
  }
  await db.query("commit");
} catch (e) {
  await db.query("rollback");
  throw e;
} finally {
  await db.end();
}
writeFileSync(
  ".env.local",
  `VITE_SUPABASE_URL=${url}\nVITE_SUPABASE_PUBLISHABLE_KEY=${status.PUBLISHABLE_KEY ?? status.ANON_KEY}\n`,
  { mode: 0o600 },
);
console.log(
  "Local Supabase configured. Synthetic development records created.",
);
console.log(
  "Individual development credentials are in .local/accounts.json (ignored by Git).",
);
