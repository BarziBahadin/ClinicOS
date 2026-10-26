import { createClient } from "@supabase/supabase-js";
const url = import.meta.env.VITE_SUPABASE_URL;
const key = import.meta.env.VITE_SUPABASE_PUBLISHABLE_KEY;
export const configured = Boolean(url && key && !key.startsWith("sb_secret_"));
export const supabase = configured
  ? createClient(url, key, {
      auth: {
        persistSession: false,
        autoRefreshToken: true,
        detectSessionInUrl: false,
        flowType: "pkce",
      },
    })
  : null;
export function client() {
  if (!supabase) throw new Error("Supabase connection is not configured.");
  return supabase;
}

// UI request identity only. Database/Edge authorization remains authoritative.
let authIdentity = "";
let authRevision = 0;
function identity(
  session: { user: { id: string }; access_token: string } | null,
) {
  if (!session) return "";
  try {
    const payload = JSON.parse(
      atob(
        session.access_token
          .split(".")[1]
          .replaceAll("-", "+")
          .replaceAll("_", "/"),
      ),
    );
    return `${session.user.id}:${payload.session_id ?? session.access_token}`;
  } catch {
    return `${session.user.id}:${session.access_token}`;
  }
}
supabase?.auth.onAuthStateChange((_event, session) => {
  const next = identity(session);
  if (next !== authIdentity) authRevision++;
  authIdentity = next;
});
export async function captureAuthorization() {
  const start = authIdentity;
  const revision = authRevision;
  const { data, error } = await client().auth.getSession();
  if (error) throw error;
  const current = identity(data.session);
  if (
    !data.session ||
    revision !== authRevision ||
    (start && start !== current) ||
    (authIdentity && authIdentity !== current)
  )
    throw new Error(
      "Session changed. Sign in and retry from the current record.",
    );
  authIdentity = current;
  return {
    token: data.session.access_token,
    isCurrent: () => authIdentity === current,
    assertCurrent() {
      if (authIdentity !== current)
        throw new Error(
          "Session changed. Sign in and retry from the current record.",
        );
    },
  };
}
