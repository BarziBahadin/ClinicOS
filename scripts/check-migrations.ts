import { execFileSync } from "node:child_process";

// Replay in an isolated shadow database; never target a linked/hosted project.
const output = execFileSync(
  "npx",
  [
    "supabase",
    "db",
    "diff",
    "--local",
    "--schema",
    "clinic,public",
    "--output-format",
    "json",
  ],
  { encoding: "utf8", stdio: ["ignore", "pipe", "inherit"] },
);
const result: { diff?: unknown } = JSON.parse(output);
if (typeof result.diff !== "string") {
  throw new Error("Migration verification did not return a schema comparison.");
}
if (result.diff.trim()) {
  throw new Error(
    "The local schema differs from committed migrations. Review `npx supabase db diff --local --schema clinic,public`, generate the missing migration, and rerun this check.",
  );
}
console.log(
  "Committed migrations replay successfully and match the local application schema.",
);
