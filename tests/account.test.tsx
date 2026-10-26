// @vitest-environment happy-dom
import { afterEach, expect, it, vi } from "vitest";
import { render, screen, act, cleanup } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { AccountPanel } from "../src/features/account";
import { invoke } from "../src/lib/functions";
const signOut = vi.hoisted(() => vi.fn());
vi.mock("../src/lib/functions", () => ({ invoke: vi.fn() }));
vi.mock("../src/lib/supabase", () => ({
  client: () => ({ auth: { signOut } }),
}));
vi.mock("../src/features/security", () => ({ MfaPanel: () => null }));
afterEach(() => {
  cleanup();
  vi.clearAllMocks();
});
it("does not sign out a subsequent user when an earlier password form completes", async () => {
  let resolve!: (value: unknown) => void;
  vi.mocked(invoke).mockImplementationOnce(
    () =>
      new Promise((r) => {
        resolve = r;
      }),
  );
  const changed = vi.fn(),
    user = userEvent.setup();
  const view = render(
    <AccountPanel
      t={(s) => s}
      onVerified={vi.fn()}
      onPasswordChanged={changed}
    />,
  );
  await user.type(
    screen.getByLabelText("Current password"),
    "Synthetic-current-password",
  );
  await user.type(
    screen.getByLabelText("New password"),
    "Synthetic-new-password",
  );
  await user.type(
    screen.getByLabelText("Confirm password"),
    "Synthetic-new-password",
  );
  await user.click(screen.getByRole("button", { name: "Update password" }));
  view.unmount();
  await act(async () => {
    resolve({ ok: true });
  });
  expect(changed).not.toHaveBeenCalled();
  expect(signOut).not.toHaveBeenCalled();
});
