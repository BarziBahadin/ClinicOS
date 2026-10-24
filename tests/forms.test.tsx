// @vitest-environment happy-dom
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { cleanup, render, screen, waitFor } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { CommandDialog } from "../src/components/ui";
import { patientAction } from "../src/features/actions";
import type { Snapshot } from "../src/domain/types";
import { execute } from "../src/lib/api";
vi.mock("../src/lib/api", () => ({ execute: vi.fn() }));
afterEach(() => {
  cleanup();
  vi.restoreAllMocks();
});
beforeEach(() => {
  Object.defineProperty(window, "confirm", {
    value: () => true,
    configurable: true,
    writable: true,
  });
  vi.mocked(execute).mockReset();
});
const data = { services: [] } as unknown as Snapshot;
describe("Patient form integrity", () => {
  it("keeps entered data on failure and reuses the same request ID for a safe retry", async () => {
    const onClose = vi.fn(),
      onSaved = vi.fn().mockResolvedValue(undefined);
    vi.mocked(execute)
      .mockRejectedValueOnce(new Error("Connection interrupted"))
      .mockResolvedValueOnce({ id: "patient-id" });
    const user = userEvent.setup();
    render(
      <CommandDialog
        action={patientAction()}
        t={(s) => s}
        data={data}
        onClose={onClose}
        onSaved={onSaved}
      />,
    );
    await user.type(screen.getByLabelText("Full name *"), "Test patient");
    await user.click(screen.getByRole("button", { name: /^Save$/ }));
    await screen.findByRole("alert");
    expect(
      (screen.getByLabelText("Full name *") as HTMLInputElement).value,
    ).toBe("Test patient");
    expect(onClose).not.toHaveBeenCalled();
    await user.click(screen.getByRole("button", { name: /^Save$/ }));
    await waitFor(() => expect(onClose).toHaveBeenCalledOnce());
    expect(vi.mocked(execute).mock.calls[0][2]).toBe(
      vi.mocked(execute).mock.calls[1][2],
    );
    expect(vi.mocked(execute).mock.calls[0][1].birth_date).toBeNull();
  });
  it("does not send invalid phone numbers to the API", async () => {
    const user = userEvent.setup();
    render(
      <CommandDialog
        action={patientAction()}
        t={(s) => s}
        data={data}
        onClose={vi.fn()}
        onSaved={vi.fn()}
      />,
    );
    await user.type(screen.getByLabelText("Full name *"), "Test patient");
    await user.type(screen.getByLabelText("Phone number"), "123");
    await user.click(screen.getByRole("button", { name: /^Save$/ }));
    expect((await screen.findByRole("alert")).textContent).toContain(
      "valid Iraqi",
    );
    expect(execute).not.toHaveBeenCalled();
  });
  it("asks before discarding unsaved registration data", async () => {
    const confirm = vi.spyOn(window, "confirm").mockReturnValue(false),
      onClose = vi.fn(),
      user = userEvent.setup();
    render(
      <CommandDialog
        action={patientAction()}
        t={(s) => s}
        data={data}
        onClose={onClose}
        onSaved={vi.fn()}
      />,
    );
    await user.type(screen.getByLabelText("Full name *"), "Unsaved patient");
    await user.click(screen.getByRole("button", { name: /^Cancel$/ }));
    expect(confirm).toHaveBeenCalled();
    expect(onClose).not.toHaveBeenCalled();
  });
});
