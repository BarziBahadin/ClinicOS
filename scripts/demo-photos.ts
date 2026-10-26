import { execFileSync } from "node:child_process";
import { createHash } from "node:crypto";
import { readFileSync } from "node:fs";
import { createClient } from "@supabase/supabase-js";

const status = JSON.parse(
  execFileSync("npx", ["supabase", "status", "--output", "json"], {
    encoding: "utf8",
    stdio: ["ignore", "pipe", "pipe"],
  }),
);
const url = new URL(status.API_URL);
if (
  url.protocol !== "http:" ||
  !["localhost", "127.0.0.1", "[::1]"].includes(url.hostname)
)
  throw new Error("Sample photographs are restricted to the local demo stack.");
const accounts = JSON.parse(readFileSync(".local/accounts.json", "utf8"));
const seed = JSON.parse(readFileSync(".local/demo-data.json", "utf8"));
if (seed.ownerId !== accounts.owner.id)
  throw new Error("Demo data belongs to another local setup.");
const samples = [
  {
    name: "cheek",
    title: "DEMO · AI-generated cheek sample",
    site: "Cheek — synthetic demo",
  },
  {
    name: "forearm",
    title: "DEMO · AI-generated forearm sample",
    site: "Forearm — synthetic demo",
  },
].map((sample) => ({
  ...sample,
  bytes: readFileSync(`.local/demo-media/sample-${sample.name}.png`),
}));
const requestId = (key: string) => {
  const hash = createHash("sha256")
    .update(`clinicos-sample-photos-v1:${key}`)
    .digest("hex");
  return `${hash.slice(0, 8)}-${hash.slice(8, 12)}-4${hash.slice(13, 16)}-8${hash.slice(17, 20)}-${hash.slice(20, 32)}`;
};
const doctor = createClient(status.API_URL, status.PUBLISHABLE_KEY, {
  auth: { persistSession: false, autoRefreshToken: false },
});
const signedIn = await doctor.auth.signInWithPassword(accounts.doctor);
if (signedIn.error) throw signedIn.error;
try {
  const workspace = await doctor.rpc("workspace");
  if (
    workspace.error ||
    workspace.data.organization.id !== "10000000-0000-4000-8000-000000000001" ||
    !/development|demo/i.test(workspace.data.organization.name)
  )
    throw new Error("Expected the local synthetic development clinic.");
  let total = 0;
  for (let i = 0; i < 20; i++) {
    const patient_id = seed.operations[`patient-${i}`]?.result?.id;
    if (!patient_id)
      throw new Error("Run demo:seed before adding sample photos.");
    const profile = await doctor.rpc("patient_profile", { patient_id });
    if (profile.error || !profile.data.full_name.startsWith("DEMO ·"))
      throw new Error(
        "Only explicitly labeled demo profiles may receive these samples.",
      );
    const consent = await doctor.rpc("command", {
      kind: "consent.record",
      payload: {
        patient_id,
        purpose: "care_photography",
        granted: true,
        template_version: "DEMO-AI-1",
        evidence:
          "SIMULATED DEMO CONSENT ONLY. These are AI-generated, watermarked sample images reused across fictional profiles. No real person, patient photograph or actual consent is represented.",
      },
      request_id: requestId(`${patient_id}:consent`),
    });
    if (consent.error) throw new Error(consent.error.message);
    for (const sample of samples) {
      const hash = createHash("sha256").update(sample.bytes).digest("hex");
      const form = new FormData();
      for (const [key, value] of Object.entries({
        upload_id: requestId(`${patient_id}:${sample.name}:${hash}`),
        patient_id,
        consent_id: consent.data.id,
        title: sample.title,
        body_site: sample.site,
      }))
        form.set(key, value);
      form.set(
        "file",
        new File([new Uint8Array(sample.bytes)], `sample-${sample.name}.png`, {
          type: "image/png",
        }),
      );
      const uploaded = await doctor.functions.invoke("clinical-media", {
        body: form,
      });
      if (uploaded.error) {
        const context =
          "context" in uploaded.error ? uploaded.error.context : null;
        const detail =
          context instanceof Response
            ? await context.text()
            : uploaded.error.message;
        throw new Error(`Sample upload failed: ${detail}`);
      }
      const preview = await doctor.functions.invoke("clinical-media", {
        body: { action: "preview", media_id: uploaded.data.id },
      });
      if (preview.error || !preview.data.url)
        throw new Error("The uploaded sample preview is unavailable.");
      total++;
    }
    console.log(`Sample photos ready in demo profile ${i + 1}/20.`);
  }
  console.log(
    `${total} private, scanned synthetic sample photos are ready across 20 demo profiles.`,
  );
} finally {
  await doctor.auth.signOut({ scope: "local" });
}
