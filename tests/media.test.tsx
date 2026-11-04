// @vitest-environment happy-dom
import { afterEach, describe, expect, it, vi } from "vitest";
import {
  cleanup,
  render,
  screen,
  act,
  waitFor,
  within,
  fireEvent,
} from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { MediaPanel } from "../src/features/media";
import { invoke } from "../src/lib/functions";
import type { Snapshot } from "../src/domain/types";
vi.mock("../src/lib/functions", () => ({ invoke: vi.fn() }));
const rpc = vi.hoisted(() => vi.fn());
vi.mock("../src/lib/supabase", () => ({ client: () => ({ rpc }) }));
afterEach(() => {
  cleanup();
  vi.mocked(invoke).mockReset();
  rpc.mockReset();
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

function uploadFile() {
  const file = new File(["synthetic-image"], "case-photo.png", {
    type: "image/png",
  });
  Object.defineProperty(file, "arrayBuffer", {
    value: async () => new TextEncoder().encode("synthetic-image").buffer,
  });
  return file;
}
const uploadProps = {
  data,
  t: (s: string) => s,
  onSaved: vi.fn().mockResolvedValue(undefined),
  sessionKey: "session-a",
  patientId: "a",
};
it("uploads the selected file immediately using the current patient and consent, and safely retries an interrupted upload", async () => {
  rpc.mockResolvedValue({ data: [{ id: "consent-a" }], error: null });
  vi.mocked(invoke)
    .mockRejectedValueOnce(new Error("Connection interrupted"))
    .mockResolvedValueOnce({ id: "upload" });
  const onSaved = vi.fn().mockResolvedValue(undefined);
  render(<MediaPanel {...uploadProps} onSaved={onSaved} />);
  const user = userEvent.setup();
  await user.click(
    screen.getByRole("button", { name: "Upload document / photo" }),
  );
  expect(screen.queryByRole("dialog")).toBeNull();
  await user.upload(screen.getByLabelText("File"), uploadFile());
  expect(await screen.findByText("Connection interrupted")).toBeTruthy();
  const first = vi.mocked(invoke).mock.calls[0][1] as FormData;
  expect(first.get("patient_id")).toBe("a");
  expect(first.get("consent_id")).toBe("consent-a");
  expect(first.get("title")).toBe("case-photo.png");
  expect(first.get("body_site")).toBe("Not recorded");
  await user.click(
    screen.getByRole("button", { name: "Upload document / photo" }),
  );
  await user.upload(screen.getByLabelText("File"), uploadFile());
  await waitFor(() => expect(onSaved).toHaveBeenCalledOnce());
  expect(
    (vi.mocked(invoke).mock.calls[1][1] as FormData).get("upload_id"),
  ).toBe(first.get("upload_id"));
});
it("requires photography consent before uploading", async () => {
  rpc.mockResolvedValue({ data: [], error: null });
  render(<MediaPanel {...uploadProps} />);
  await userEvent.click(
    screen.getByRole("button", { name: "Upload document / photo" }),
  );
  await userEvent.upload(screen.getByLabelText("File"), uploadFile());
  expect(
    await screen.findByText("Record photography consent before uploading."),
  ).toBeTruthy();
  expect(invoke).not.toHaveBeenCalled();
});
it.each(["patient", "session"])(
  "does not start an old upload after the %s changes during consent lookup",
  async (changed) => {
    let resolve!: (value: unknown) => void;
    rpc.mockImplementationOnce(
      () =>
        new Promise((r) => {
          resolve = r;
        }),
    );
    const view = render(<MediaPanel {...uploadProps} />);
    await userEvent.click(
      screen.getByRole("button", { name: "Upload document / photo" }),
    );
    await userEvent.upload(screen.getByLabelText("File"), uploadFile());
    view.rerender(
      <MediaPanel
        {...uploadProps}
        patientId={changed === "patient" ? "b" : "a"}
        sessionKey={changed === "session" ? "session-b" : "session-a"}
      />,
    );
    await act(async () => {
      resolve({ data: [{ id: "consent-a" }], error: null });
    });
    expect(invoke).not.toHaveBeenCalled();
  },
);

it("discards a file chosen from a picker opened for an earlier patient", async () => {
  const view = render(<MediaPanel {...uploadProps} />);
  await userEvent.click(
    screen.getByRole("button", { name: "Upload document / photo" }),
  );
  view.rerender(<MediaPanel {...uploadProps} patientId="b" />);
  await userEvent.upload(screen.getByLabelText("File"), uploadFile());
  expect(rpc).not.toHaveBeenCalled();
  expect(invoke).not.toHaveBeenCalled();
});

it("opens a gallery viewer, navigates only within the same patient, and ignores an earlier selection response", async () => {
  let resolveFirst!: (value: { url: string }) => void;
  vi.mocked(invoke)
    .mockImplementationOnce(
      () =>
        new Promise((resolve) => {
          resolveFirst = resolve;
        }),
    )
    .mockResolvedValue({ url: "https://private.invalid/second" });
  render(
    <MediaPanel
      {...uploadProps}
      data={{
        ...data,
        media: [
          data.media[0],
          { ...data.media[0], id: "second", title: "Second photo" },
          data.media[1],
        ],
      }}
    />,
  );
  await userEvent.click(screen.getByRole("button", { name: /Photo A/ }));
  await userEvent.keyboard("{ArrowRight}");
  const viewer = screen.getByRole("dialog", { name: "Second photo" });
  expect(
    await within(viewer).findByRole("img", { name: "Second photo" }),
  ).toBeTruthy();
  expect(
    within(viewer)
      .getByRole("button", { name: "Next" })
      .hasAttribute("disabled"),
  ).toBe(true);
  await act(async () => {
    resolveFirst({ url: "https://private.invalid/first" });
  });
  expect(screen.queryByRole("dialog", { name: "Photo A" })).toBeNull();
  expect(screen.queryByRole("img", { name: "Photo A" })).toBeNull();
  fireEvent(
    screen.getByRole("dialog"),
    new Event("cancel", { bubbles: true, cancelable: true }),
  );
  expect(screen.queryByRole("dialog")).toBeNull();
});

it("uploads a named PDF report to the patient and opens PDFs through authorized original access", async () => {
  rpc.mockResolvedValue({ data: [{ id: "consent-a" }], error: null });
  vi.mocked(invoke).mockResolvedValue({
    id: "report",
    url: "https://private.invalid/report",
  });
  const onSaved = vi.fn().mockResolvedValue(undefined);
  const report = {
    ...data.media[0],
    id: "report",
    title: "Blood test",
    mime_type: "application/pdf",
  };
  render(
    <MediaPanel
      {...uploadProps}
      onSaved={onSaved}
      documentsOnly
      data={{ ...data, media: [...data.media, report] }}
    />,
  );
  expect(screen.queryByRole("button", { name: /Photo A/ })).toBeNull();
  const upload = screen.getByRole("button", { name: "Upload PDF report" });
  expect(upload.hasAttribute("disabled")).toBe(true);
  await userEvent.type(
    screen.getByLabelText("Report title"),
    "Blood test results",
  );
  await userEvent.click(upload);
  const file = new File(["%PDF-synthetic"], "scan.pdf", {
    type: "application/pdf",
  });
  Object.defineProperty(file, "arrayBuffer", {
    value: async () => new TextEncoder().encode("%PDF-synthetic").buffer,
  });
  await userEvent.upload(screen.getByLabelText("File"), file);
  await waitFor(() => expect(onSaved).toHaveBeenCalledOnce());
  const form = vi.mocked(invoke).mock.calls[0][1] as FormData;
  expect(form.get("title")).toBe("Blood test results");
  expect(form.get("patient_id")).toBe("a");
  expect(form.get("file")).toBe(file);
  await userEvent.click(screen.getByRole("button", { name: /Blood test/ }));
  expect(await screen.findByRole("link", { name: "Open PDF" })).toBeTruthy();
  expect(invoke).toHaveBeenLastCalledWith("clinical-media", {
    action: "read",
    media_id: "report",
  });
});

it("discards an old thumbnail response after the authenticated session changes", async () => {
  let resolve!: (value: { url: string }) => void;
  vi.mocked(invoke)
    .mockImplementationOnce(
      () =>
        new Promise((r) => {
          resolve = r;
        }),
    )
    .mockResolvedValue({ url: "https://private.invalid/new" });
  const props = {
    ...uploadProps,
    data: {
      ...data,
      media: [{ ...data.media[0], preview_key: "private-preview" }],
    },
  };
  const view = render(<MediaPanel {...props} />);
  view.rerender(<MediaPanel {...props} sessionKey="session-b" />);
  await act(async () => {
    resolve({ url: "https://private.invalid/old" });
  });
  expect(
    document.querySelector('img[src="https://private.invalid/old"]'),
  ).toBeNull();
  await waitFor(() =>
    expect(
      document.querySelector('img[src="https://private.invalid/new"]'),
    ).toBeTruthy(),
  );
});
