// @vitest-environment happy-dom
import { afterEach, beforeEach, expect, it, vi } from "vitest";
import { cleanup, render, screen, within } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { App } from "../src/App";
import { snapshot, clinicalRecord } from "../src/lib/api";
import { invoke } from "../src/lib/functions";
import type { Snapshot } from "../src/domain/types";

const session = vi.hoisted(() => ({
  user: { id: "doctor" },
  access_token: "synthetic-session",
}));
const rpc = vi.hoisted(() => vi.fn());
vi.mock("../src/lib/supabase", () => ({
  configured: true,
  client: () => ({
    auth: {
      onAuthStateChange: () => ({
        data: { subscription: { unsubscribe: vi.fn() } },
      }),
      getSession: async () => ({ data: { session } }),
      signOut: vi.fn(),
    },
    rpc,
  }),
}));
vi.mock("../src/lib/api", () => ({
  snapshot: vi.fn(),
  clinicalRecord: vi.fn(),
}));
vi.mock("../src/lib/functions", () => ({ invoke: vi.fn() }));
const patientId = "11111111-1111-4111-8111-111111111111";
const photo = {
  id: "sample-photo",
  patient_id: patientId,
  title: "Synthetic case photo",
  status: "ready",
  mime_type: "image/png",
  created_at: "2026-10-25",
  body_site: "Demo site",
};
const workspace = {
  organization: {
    id: "demo-clinic",
    name: "Synthetic clinic",
    timezone: "Asia/Baghdad",
  },
  membership: {
    id: "membership",
    user_id: "doctor",
    display_name: "Synthetic doctor",
    role: "doctor",
    active: true,
  },
  permissions: ["patients", "clinical", "media"],
  metrics: {
    today_appointments: 0,
    waiting: 0,
    followups_due: 0,
    open_invoices: 0,
  },
  patients: [
    {
      id: patientId,
      full_name: "Synthetic patient",
      patient_number: "DEMO-1",
      phone: null,
      birth_date: null,
      birth_precision: "unknown",
      gender: "unknown",
      version: 1,
      language: "en",
      merged_into: null,
    },
  ],
  trial_balance: [],
  billable_encounters: [],
  appointments: [],
  encounters: [],
  services: [],
  invoices: [],
  payments: [],
  expenses: [],
  tasks: [],
  results: [],
  consents: [],
  media: [],
  stock: [],
  movements: [],
  journals: [],
  tills: [],
  members: [],
  audit: [],
  packages: [],
} as Snapshot;

beforeEach(() => {
  localStorage.clear();
  window.location.hash = `patients/${patientId}`;
  vi.mocked(snapshot).mockResolvedValue(workspace);
  vi.mocked(clinicalRecord).mockResolvedValue({
    encounters: [],
    procedures: [],
    facts: [],
  });
  vi.mocked(invoke).mockResolvedValue({
    url: "https://private.invalid/synthetic-photo.png",
    mime_type: "image/png",
  });
  rpc.mockImplementation(
    async (name: string, args: { record_type?: string }) => ({
      data:
        name === "patient_contacts"
          ? []
          : {
              items: args?.record_type === "media" ? [photo] : [],
              has_more: false,
            },
      error: null,
    }),
  );
});
afterEach(() => {
  cleanup();
  vi.clearAllMocks();
  window.location.hash = "";
});

it("opens patient photos and returns between sections without remounting into a render loop", async () => {
  const user = userEvent.setup();
  render(<App />);
  const sections = await screen.findByRole("navigation", {
    name: "Patient sections",
  });
  await user.click(
    within(sections).getByRole("button", { name: "Clinical media" }),
  );
  await user.click(
    await screen.findByRole("button", { name: /Synthetic case photo/ }),
  );
  expect(await screen.findByRole("img", { name: photo.title })).toBeTruthy();
  await user.click(
    within(sections).getByRole("button", { name: "Contacts", exact: true }),
  );
  expect(screen.queryByRole("img", { name: photo.title })).toBeNull();
  await user.click(
    within(sections).getByRole("button", { name: "Clinical media" }),
  );
  await user.click(
    await screen.findByRole("button", { name: /Synthetic case photo/ }),
  );
  expect(await screen.findByRole("img", { name: photo.title })).toBeTruthy();
});
