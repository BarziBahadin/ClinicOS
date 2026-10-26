/** Internal Auth identifier only; staff never need an email account. */
export function normalizeUsername(value: string): string {
  const username = value.trim().toLowerCase();
  if (!/^[a-z][a-z0-9._-]{2,31}$/.test(username)) {
    throw new Error("Use 3–32 letters, numbers, dots, hyphens or underscores, starting with a letter.");
  }
  return username;
}
export function usernameIdentity(value: string): string {
  return `${normalizeUsername(value)}@clinicos.test`;
}
