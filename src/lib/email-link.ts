// Capture one-time email proof in memory and remove it from browser history before rendering.
const fragment = new URLSearchParams(
  location.hash.startsWith("#auth?") ? location.hash.slice(6) : "",
);
const type = fragment.get("type");
const token = fragment.get("token_hash");
export let emailLink =
  token && (type === "invite" || type === "recovery")
    ? ({ token_hash: token, type } as const)
    : null;
if (emailLink)
  history.replaceState(
    null,
    "",
    `${location.pathname}${location.search}#account`,
  );

export function consumeEmailLink() {
  emailLink = null;
}
