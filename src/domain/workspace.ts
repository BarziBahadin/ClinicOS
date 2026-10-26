import { z } from "zod";
const RowSchema = z.object({ id: z.uuid() }).passthrough();
const MemberSchema = RowSchema.extend({
  additional_roles: z
    .array(
      z.enum([
        "owner",
        "administrator",
        "doctor",
        "receptionist",
        "accountant",
      ]),
    )
    .optional(),
  username: z.string().nullable().optional(),
  user_id: z.uuid(),
  display_name: z.string(),
  role: z.enum([
    "owner",
    "administrator",
    "doctor",
    "receptionist",
    "accountant",
  ]),
  active: z.boolean(),
});
export const WorkspaceSchema = z.object({
  account: z
    .object({
      username: z.string().nullable(),
      password_change_required: z.boolean(),
    })
    .optional(),
  metrics: z.object({
    today_appointments: z.number(),
    waiting: z.number(),
    followups_due: z.number(),
    open_invoices: z.number(),
  }),
  organization: RowSchema.extend({ name: z.string(), timezone: z.string() }),
  membership: MemberSchema,
  permissions: z.array(z.string()),
  patients: z.array(
    RowSchema.extend({
      full_name: z.string(),
      patient_number: z.string(),
      phone: z.string().nullable(),
      birth_date: z.string().nullable(),
      birth_precision: z.enum(["unknown", "day", "month", "year"]),
      gender: z.string(),
      version: z.number().int(),
      language: z.enum(["en", "ckb"]),
      merged_into: z.uuid().nullable(),
    }),
  ),
  appointments: z.array(RowSchema),
  encounters: z.array(RowSchema),
  services: z.array(RowSchema),
  invoices: z.array(RowSchema),
  payments: z.array(RowSchema),
  expenses: z.array(RowSchema),
  tasks: z.array(RowSchema),
  results: z.array(RowSchema),
  consents: z.array(RowSchema),
  media: z.array(RowSchema),
  stock: z.array(RowSchema),
  movements: z.array(RowSchema),
  journals: z.array(RowSchema),
  tills: z.array(RowSchema),
  members: z.array(MemberSchema),
  audit: z.array(RowSchema),
  packages: z.array(RowSchema),
  trial_balance: z.array(
    z.object({
      currency: z.enum(["USD", "IQD"]),
      account: z.string(),
      debit: z.union([z.string(), z.number()]),
      credit: z.union([z.string(), z.number()]),
    }),
  ),
  billable_encounters: z.array(RowSchema),
});
