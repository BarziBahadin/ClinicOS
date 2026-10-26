import { beforeEach, describe, expect, it, vi } from "vitest";
const auth = vi.hoisted(() => ({
  callback: null as null | ((event: string, session: any) => void),
  getSession: vi.fn(),
}));
vi.mock("@supabase/supabase-js", () => ({
  createClient: () => ({
    auth: {
      getSession: auth.getSession,
      onAuthStateChange: (callback: any) => {
        auth.callback = callback;
      },
    },
  }),
}));
const session = (id: string, token = "token") => ({
  user: { id: "user" },
  access_token: `header.${btoa(JSON.stringify({ session_id: id, marker: token }))}.signature`,
});
beforeEach(() => {
  vi.resetModules();
  vi.stubEnv("VITE_SUPABASE_URL", "http://127.0.0.1:54321");
  vi.stubEnv("VITE_SUPABASE_PUBLISHABLE_KEY", "sb_publishable_test");
  auth.getSession.mockReset();
});
describe("Authenticated request identity", () => {
  it("rejects a session lookup overtaken by logout", async () => {
    const { captureAuthorization } = await import("../src/lib/supabase");
    const a = session("a");
    auth.callback!("SIGNED_IN", a);
    let resolve!: (value: any) => void;
    auth.getSession.mockReturnValueOnce(
      new Promise((r) => {
        resolve = r;
      }),
    );
    const pending = captureAuthorization();
    auth.callback!("SIGNED_OUT", null);
    resolve({ data: { session: a }, error: null });
    await expect(pending).rejects.toThrow("Session changed");
  });
  it("keeps refreshes in the same session but invalidates captured work on a new sign-in", async () => {
    const { captureAuthorization } = await import("../src/lib/supabase");
    const a = session("a");
    auth.callback!("SIGNED_IN", a);
    auth.getSession.mockResolvedValue({ data: { session: a }, error: null });
    const captured = await captureAuthorization();
    expect(captured.token).toBe(a.access_token);
    auth.callback!("TOKEN_REFRESHED", session("a", "refreshed"));
    expect(captured.isCurrent()).toBe(true);
    auth.callback!("SIGNED_IN", session("b"));
    expect(captured.isCurrent()).toBe(false);
    expect(() => captured.assertCurrent()).toThrow("Session changed");
  });
});
