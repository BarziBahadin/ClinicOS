import { execFileSync, spawnSync } from "node:child_process";
import { mkdirSync, writeFileSync } from "node:fs";
try {
  execFileSync("docker", ["info"], { stdio: "ignore" });
} catch {
  throw new Error(
    "Start your Docker-compatible runtime first. On this Mac: colima start --cpu 4 --memory 6.",
  );
}
try {
  execFileSync("docker", ["network", "inspect", "clinicos-local"], {
    stdio: "ignore",
  });
} catch {
  execFileSync(
    "docker",
    [
      "network",
      "create",
      "-o",
      "com.docker.network.bridge.host_binding_ipv4=127.0.0.1",
      "clinicos-local",
    ],
    { stdio: "ignore" },
  );
}
console.log("Starting local Supabase…");
execFileSync(
  "npx",
  [
    "supabase",
    "start",
    "--network-id",
    "clinicos-local",
    "-x",
    "studio,postgres-meta,logflare,vector,supavisor,imgproxy",
  ],
  { stdio: ["ignore", "pipe", "inherit"] },
);
mkdirSync(".local", { recursive: true });
writeFileSync(
  ".local/functions.env",
  "CLAMAV_HOST=clinicos-scanner\nCLAMAV_PORT=3310\nAPP_ORIGIN=http://127.0.0.1:5173\nPUBLIC_SUPABASE_URL=http://127.0.0.1:54321\n",
  { mode: 0o600 },
);
const compose =
  spawnSync("docker", ["compose", "version"], { stdio: "ignore" }).status === 0
    ? ["docker", ["compose"]]
    : ["docker-compose", []];
execFileSync(
  compose[0] as string,
  [...(compose[1] as string[]), "-f", "compose.scanner.yml", "up", "-d"],
  { stdio: "inherit" },
);
console.log(
  "Supabase and scanner containers started. Scanner readiness is required before uploads.",
);
