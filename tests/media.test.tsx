// @vitest-environment happy-dom
import { afterEach, describe, expect, it, vi } from "vitest";
import { cleanup, render, screen, act } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { MediaPanel } from "../src/features/media";
import { invoke } from "../src/lib/functions";
import type { Snapshot } from "../src/domain/types";
vi.mock("../src/lib/functions", () => ({ invoke: vi.fn() }));
afterEach(() => {
  cleanup();
  vi.mocked(invoke).mockReset();
});
const data = {
  media: [
    {
      id: "media-a",
      patient_id: "a",
      title: "Photo A",
      status: "ready",
      mime_type: "image/jpeg",
      created_at: "2026-10-25",
    },
    {
      id: "media-b",
      patient_id: "b",
      title: "Photo B",
      status: "ready",
      mime_type: "image/jpeg",
      created_at: "2026-10-25",
    },
  ],
  consents: [],
  patients: [],
} as unknown as Snapshot;
describe("Clinical media request identity", () => {
  it.each(["patient", "session"])(
    "ignores an old image response after the %s changes",
    async (changed) => {
      let resolve!: (value: { url: string }) => void;
      vi.mocked(invoke).mockImplementationOnce(
        () =>
          new Promise((r) => {
            resolve = r;
          }),
      );
      const props = {
        data,
        t: (s: string) => s,
        onSaved: vi.fn(),
        sessionKey: "session-a",
        patientId: "a",
      };
      const view = render(<MediaPanel {...props} />);
      await userEvent.click(screen.getByRole("button", { name: /Photo A/ }));
      view.rerender(
        <MediaPanel
          {...props}
          patientId={changed === "patient" ? "b" : "a"}
          sessionKey={changed === "session" ? "session-b" : "session-a"}
        />,
      );
      await act(async () => {
        resolve({ url: "https://private.invalid/photo-a" });
      });
      expect(screen.queryByRole("img", { name: "Photo A" })).toBeNull();
    },
  );
  it("clears already displayed photos on patient change", async () => {
    vi.mocked(invoke).mockResolvedValue({
      url: "https://private.invalid/photo-a",
    });
    const props = {
      data,
      t: (s: string) => s,
      onSaved: vi.fn(),
      sessionKey: "session-a",
    };
    const view = render(<MediaPanel {...props} patientId="a" />);
    await userEvent.click(screen.getByRole("button", { name: /Photo A/ }));
    expect(await screen.findByRole("img", { name: "Photo A" })).toBeTruthy();
    view.rerender(<MediaPanel {...props} patientId="b" />);
    expect(screen.queryByRole("img", { name: "Photo A" })).toBeNull();
  });
});
