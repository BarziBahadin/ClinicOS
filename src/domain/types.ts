export type Currency = "USD" | "IQD";
export type Locale = "en" | "ckb";
export type Role =
  "owner" | "administrator" | "doctor" | "receptionist" | "accountant";
export type Row = { id: string; [key: string]: unknown };
export interface Patient extends Row {
  full_name: string;
  patient_number: string;
  phone: string | null;
  birth_date: string | null;
  birth_precision: string;
  gender: string;
  version: number;
  language: Locale;
  merged_into: string | null;
}
export interface Membership extends Row {
  user_id: string;
  display_name: string;
  role: Role;
  active: boolean;
}
export interface Snapshot {
  metrics: {
    today_appointments: number;
    waiting: number;
    followups_due: number;
    open_invoices: number;
  };
  trial_balance: {
    currency: Currency;
    account: string;
    debit: string | number;
    credit: string | number;
  }[];
  billable_encounters: Row[];
  organization: Row & { name: string; timezone: string };
  membership: Membership;
  permissions: string[];
  patients: Patient[];
  appointments: Row[];
  encounters: Row[];
  services: Row[];
  invoices: Row[];
  payments: Row[];
  expenses: Row[];
  tasks: Row[];
  results: Row[];
  consents: Row[];
  media: Row[];
  stock: Row[];
  movements: Row[];
  journals: Row[];
  tills: Row[];
  members: Membership[];
  audit: Row[];
  packages: Row[];
}
export type CommandName =
  | "patient.create"
  | "patient.update"
  | "patient.merge"
  | "appointment.create"
  | "appointment.status"
  | "encounter.save"
  | "encounter.sign"
  | "encounter.addendum"
  | "procedure.create"
  | "consent.record"
  | "result.create"
  | "result.update"
  | "task.create"
  | "task.complete"
  | "service.save"
  | "invoice.issue"
  | "invoice.credit"
  | "payment.record"
  | "deposit.apply"
  | "refund.record"
  | "expense.record"
  | "expense.pay"
  | "cash.record"
  | "fx.exchange"
  | "stock.receive"
  | "stock.use"
  | "till.open"
  | "till.close"
  | "member.update"
  | "settings.update"
  | "package.sell"
  | "package.redeem"
  | "journal.post";
