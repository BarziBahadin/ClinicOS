import { execFileSync } from "node:child_process";
// Directory builds are development artifacts. Never discover a personal signing identity.
execFileSync("npx", ["electron-builder", "--dir"], {
  stdio: "inherit",
  env: { ...process.env, CSC_IDENTITY_AUTO_DISCOVERY: "false" },
});
