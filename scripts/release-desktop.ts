import { execFileSync } from "node:child_process";
import { mkdirSync, writeFileSync } from "node:fs";
const required = (name: string) => {
  const value = process.env[name]?.trim();
  if (!value)
    throw new Error(
      `Release requires ${name} in protected environment settings`,
    );
  return value;
};
const https = (value: string) => {
  const url = new URL(value);
  if (
    url.protocol !== "https:" ||
    url.username ||
    url.password ||
    url.search ||
    url.hash ||
    ["localhost", "127.0.0.1", "::1"].includes(url.hostname)
  )
    throw new Error(
      "Release backend and update feed require credential-free production HTTPS URLs",
    );
  return url.href;
};
const backend = https(required("VITE_SUPABASE_URL"));
if (!required("VITE_SUPABASE_PUBLISHABLE_KEY").startsWith("sb_publishable_"))
  throw new Error("A public Supabase publishable key is required");
const update = https(required("CLINICOS_UPDATE_URL"));
required("CSC_LINK");
required("CSC_KEY_PASSWORD");
const config: Record<string, unknown> = {
  forceCodeSigning: true,
  publish: { provider: "generic", url: update },
};
if (process.platform === "darwin") {
  const identity = required("CLINICOS_MAC_IDENTITY");
  if (!identity.startsWith("Developer ID Application:"))
    throw new Error("A Developer ID Application signing identity is required");
  const api =
    process.env.APPLE_API_KEY &&
    process.env.APPLE_API_KEY_ID &&
    process.env.APPLE_API_ISSUER;
  const account =
    process.env.APPLE_ID &&
    process.env.APPLE_APP_SPECIFIC_PASSWORD &&
    process.env.APPLE_TEAM_ID;
  if (!api && !account)
    throw new Error("Protected Apple notarization credentials are required");
  config.mac = {
    identity,
    notarize: true,
    hardenedRuntime: true,
    target: ["dmg", "zip"],
  };
} else if (process.platform === "win32") {
  config.win = {
    target: "nsis",
    publisherName: required("CLINICOS_PUBLISHER_NAME"),
    verifyUpdateCodeSignature: true,
  };
} else
  throw new Error(
    "Build signed releases on their supported macOS or Windows host",
  );
if (process.argv.includes("--preflight")) {
  console.log(
    "Release prerequisites passed. Signing, OS acceptance and update installation still require verification.",
  );
} else {
  mkdirSync(".local", { recursive: true, mode: 0o700 });
  writeFileSync(".local/release-config.json", JSON.stringify(config), {
    mode: 0o600,
  });
  const npm = process.platform === "win32" ? "npm.cmd" : "npm",
    npx = process.platform === "win32" ? "npx.cmd" : "npx";
  execFileSync(npm, ["run", "check"], {
    stdio: "inherit",
    env: { ...process.env, VITE_SUPABASE_URL: backend },
  });
  execFileSync(
    npx,
    [
      "electron-builder",
      "--config",
      ".local/release-config.json",
      "--publish",
      "never",
    ],
    {
      stdio: "inherit",
      env: { ...process.env, CSC_IDENTITY_AUTO_DISCOVERY: "false" },
    },
  );
  console.log(
    "Signed artifacts prepared locally. Verify signatures, notarization and clinic acceptance before publishing.",
  );
}
