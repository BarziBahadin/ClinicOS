# Operation, recovery and release

## Scope and financial boundaries

The local build supports one clinic organization and its initial branch. Organization/branch keys are present for growth; branch-specific delegation, multi-tenant sales, insurance claims, regulatory e-invoicing, full offline synchronization and external messaging/accounting connectors require separately configured workflows. No integration is silently simulated.

The internal journals provide balanced operational bookkeeping in each original currency, with a trial balance and accountant export. They do not implement Iraqi statutory tax/payroll calculations, automatic inventory valuation/depreciation, statutory financial statements or consolidated FX revaluation. Payroll entries record authorized amounts, rather than calculating legal payroll. An accountant must approve opening entries, chart mapping, recognition, exchange policies and reporting before live financial use. Revenue, deposits, owner movements and cash remain distinct.

Appointments and age calculations use the clinic's Baghdad calendar. Financial records retain original currency; exchange movements store the rate supplied at the time. Receipts may settle USD invoices with IQD or IQD invoices with USD. The operator enters IQD per one USD, to at most six decimal places. The system stores the actual tender, historical rate and invoice allocation, rounded to the invoice currency precision (USD two decimals, IQD three). Cross-currency receipts and refunds use balanced clearing entries in both currencies. Refunds return the original tender at its recorded allocation; the final refund carries any rounding residual. A partial refund that would strand an unallocatable remainder is rejected with guidance to return the full remaining receipt. A change to a future rate does not rewrite prior records.

## Credentials and identity

- `.env.local` contains only the public Supabase URL and publishable key. Never put a secret key, database password or signing certificate in a `VITE_` variable.
- Production staff accounts use administrator-created **usernames and temporary passwords**. No staff email, invitation mail, password-recovery email or SMTP service is required. Supabase Auth stores a private synthetic alias derived from the username; it is an identifier, not a mailbox. Do not use that alias for delivery. Keep public registration disabled at `[auth].enable_signup=false` while retaining the password provider (`[auth.email].enable_signup=true` in local CLI configuration). Verify password login and anonymous signup rejection after changing Auth configuration.
- Users must change a temporary password before accessing records and sign in again afterward. Resets require an authorized administrator, revoke old sessions in the database and require another password change. No business role automatically receives clinical access. Deactivate departing memberships; checks apply to earlier tokens too.
- TOTP must be enabled in Auth. Production organizations require MFA by default. Staff enroll/verify under **Account & security**. A password reset does not bypass an existing verified authenticator; lost-factor recovery needs the clinic's separately authorized operator procedure.
- Development MFA policy is relaxed only for the synthetic development organization. Production organizations default to MFA required in the database.
- The desktop renderer has no Node integration. Credentials are not persisted by the renderer. Packaged builds use exact backend origins in CSP, a sandbox, denied permissions and restricted navigation.

## Local encrypted recovery check

Generate and store a 32-byte base64 encryption key separately from backup copies, then supply it through `CLINICOS_BACKUP_KEY` in the environment. Do not put it in source control or command arguments.

```sh
npm run backup:local -- create
npm run backup:local -- verify .local/backups/<timestamp>/clinicos.backup
```

The tool exports the local Postgres database, downloads every ready clinical object, verifies object hashes, encrypts the archive with AES-256-GCM, and verifies archive completion and database checksum on recovery. Unfinished archives use `.partial`. Verified output includes sensitive plaintext restore inputs in a permission-restricted `.local/backups/verified-*` folder; remove those working copies after the drill.

A local restore drill must use an **independent empty database**, not overwrite the working database. Supabase system schemas retain their owners; use the local `supabase_admin` restore role for that drill, rather than stripping ownership/ACLs to force an import. Verify patient/staff counts, schema versions, role denials, signed-note invariants, journal balance and object hashes. The local-only tool deliberately refuses hosted targets.

## Production recovery

Choose and configure the hosting region and Supabase plan. Enable the appropriate managed database backup/PITR policy and independent encrypted, versioned object backups. Supabase database backups alone do not contain Storage objects. Keep a protected copy outside the project/account failure boundary and keep its key separately controlled.

Agree recovery-point and recovery-time objectives with the clinic, then measure a restore into an isolated project. Recovery includes database/Auth state, object bytes, configuration, encryption/signing keys, staff access, media links and accounting reconciliation. Do not claim the proposal's suggested recovery targets until the selected production environment passes the drill.

Monitor service health, scanner definition freshness, rejected/pending uploads, authentication failures, permission changes, overdue results, failed backups and reconciliation exceptions. Use redacted identifiers; do not enable patient-content session replay or put notes, images, contact details or signed URLs in general logs. Define who receives incidents and who authorizes recovery. After recovery, reconcile external transactions before resuming any integration workers.

## Production activation requirements

1. Select the actual Supabase project/region and web host; supply credentials through protected environment settings. Apply the committed migrations to staging first and verify direct API permission tests there.
2. Configure the exact web app origin, administrator-provisioned username accounts and TOTP. Configure trusted Edge functions with `APP_ORIGIN`, `PUBLIC_SUPABASE_URL`, private `CLAMAV_HOST`/`CLAMAV_PORT`, `MEDIA_PROCESSOR_URL` and protected `MEDIA_PROCESSOR_TOKEN`. Deploy scanner and processor on private networks, with updated scanner definitions and monitoring. Staff-email/SMTP setup is not required. The desktop uses the fixed `clinicos://app` origin; the Edge allowlist accepts that exact origin and the configured web origin. Bearer identity, session and permissions are still required.
3. Deploy the web build with its generated security headers and HTTPS. The `_headers` file targets hosts that support that format; configure equivalent headers on other hosts. Verify public schema exposure is limited to the intended API and the clinical bucket stays private.
4. Establish backups, restore drills, a retention schedule, incident contacts and downtime procedures. Confirm actual clinic workload, staffing, treatment catalog, product traceability and device/printing requirements.
5. Have a dermatologist approve templates, prescribing/procedure records, consent wording, results escalation and aftercare. Have native Sorani users validate terminology and documents. Have a local accountant approve the financial model and required Iraqi documents. Legal/regulatory requirements are not certified by this implementation.
6. For distributed desktop releases, provide protected Windows/macOS signing credentials, macOS notarization and an HTTPS update feed. Build and test on each supported OS; require verified signed updates. Local directory packaging is an unsigned development artifact, not a production release.
7. Run staff acceptance with synthetic data, then create reviewed opening balances and an explicit cutover. Do not run development seed scripts against production.

## Private image processing

`compose.scanner.yml` runs the scanner and the bounded image processor on the private local Docker network, without publishing their ports. The processor uses a protected bearer token, permits static JPEG/PNG/WebP up to 40 megapixels and 10 MB, and produces a PNG within 1600 × 1600 pixels with metadata removed. Original bytes remain separate and unchanged. The original and preview both pass scanning before the upload becomes ready. Missing/unhealthy scanner or processor blocks completion; the operator restores the service and staff retry the same file/metadata.

The processor image uses the committed lockfile and pinned Node base image. Deploy it privately in production and rotate its token through protected environment settings. Store ready originals and previews in private Storage and include both in independent object recovery. A local image test covers metadata removal, size bounds, original preservation and rejection of invalid/unsupported images.

## Health, audit copies and failed uploads

These tools deliberately refuse hosted targets:

```sh
npm run ops:local -- health
npm run ops:local -- media-inspect
npm run ops:local -- media-cleanup
npm run ops:local -- audit-export
npm run ops:local -- audit-verify /absolute/path/to/audit-copy.aes
```

`health` emits service health and redacted counts for pending/rejected uploads, overdue tasks/results and membership changes. Its exit status fails if private media services are unhealthy, scanner definitions are over 48 hours old, or no completed local database/media backup exists from the previous 24 hours. Backup freshness does not establish off-site durability or successful restoration. No patient content, contact details, credentials or signed URLs are printed. Production authentication-failure alerts and incident routing need a protected monitoring deployment.

For audit exports, supply a separately controlled 32-byte base64 key through `CLINICOS_AUDIT_KEY` and the protected destination through `CLINICOS_AUDIT_DIR`. The default `.local/audit-copies` is a development copy, **not independent recovery**. Exports stream a consistent read-only snapshot, encrypt it using AES-256-GCM, and include record counts/checksums/completion evidence. Incomplete files end in `.partial`. Verification rejects changed bytes, wrong keys and missing completion evidence. Store the destination outside the project/account failure boundary with versioning or retention locks; keep keys separate. The application cannot prove a destination's independence merely from its path.

`media-cleanup` rejects abandoned pending uploads older than seven days. It removes only rejected temporary objects after a further 30-day rejection grace period, in batches of 100, and appends cleanup evidence. It preserves upload records and all ready clinical originals/previews. Retry after interruption is safe; deletion is idempotent. Existing rejected uploads receive a full grace period when the migration is deployed. Clinical-record deletion is not implemented by this tool; approved retention, legal holds and backup expiry require a separate reviewed execution procedure.

Production scheduling, independent destinations, alert recipients, incident ownership and retention policy remain clinic/operator configuration. No SMS, WhatsApp or email is sent by these tools or by the manual contact log.

## Signed desktop preparation

`npm run desktop:build` explicitly creates an **unsigned development directory build**. It does not discover or use a personal signing certificate.

Use `npm run desktop:release:preflight` on the actual supported macOS or Windows build host after supplying protected settings. `npm run desktop:release` reruns the application checks, requires signing, prepares installation/update artifacts and uses `--publish never`; publication is a separate operator action.

Required settings are `VITE_SUPABASE_URL` (production HTTPS), `VITE_SUPABASE_PUBLISHABLE_KEY`, `CLINICOS_UPDATE_URL` (HTTPS), `CSC_LINK` and `CSC_KEY_PASSWORD`. On macOS, also set the public `CLINICOS_MAC_IDENTITY` (`Developer ID Application: …`) and Apple notarization credentials (`APPLE_API_KEY`, `APPLE_API_KEY_ID`, `APPLE_API_ISSUER`, or `APPLE_ID`, `APPLE_APP_SPECIFIC_PASSWORD`, `APPLE_TEAM_ID`). On Windows set the expected `CLINICOS_PUBLISHER_NAME`. Never put protected credentials in frontend variables or command arguments.

The packaged update URL is stored in public runtime configuration; no launch-time shell environment is needed. Downgrades and web installers are disabled. Windows publisher verification remains enabled; macOS requires a matching signed application. See the versioned [electron-builder signing documentation](https://www.electron.build/v26/docs/features/code-signing/) and [update requirements](https://www.electron.build/v26/docs/features/auto-update/).

Verify code signatures, macOS notarization/stapling, a clean installation, upgrade from the previous signed version, rejection of a mismatched signature and recovery when the feed is unavailable. Protect the update host and signing credentials separately. The available local build does not prove these checks or Windows compatibility. The desktop app uses the ClinicOS stethoscope icon from `electron/assets`, with native macOS and Windows assets. Signing, installation and supported-device acceptance still require verification.

## Current verification limits

Local verification on 25 October 2026 passed `npm run check` (22 tests plus TypeScript/web build), `npm run functions:check`, `npm run functions:test`, `npm run db:test -- --media --recovery` (57 checks), `npm run db:advisors` (no warnings), and `npm run db:migrations:check` (clean replay/parity). Root and media-processor production dependency audits reported zero vulnerabilities. See the [engineering handoff](engineering-handoff.md). The automated suite covers username creation/reset, organization/care-scope authorization, immutable clinical and financial events, interrupted form/media responses, complete report totals and fixed cutoffs, reconciliation/export idempotency, stock/resource guards, original/preview recovery and encrypted audit tamper rejection. Committed migrations are replayed into an isolated shadow database and compared with the live local application schema.

The rebuilt macOS arm64 development app has been smoke-tested with username login, role-scoped navigation and English/Sorani RTL guides, protected image preview and a synthetic A4 print preview. Actual clinic printers, Windows, signed installation/updates and professional/native-language acceptance are still production release requirements. See [development status](development-status.md) for each of the 22 items and the remaining automation/integration development.

Production hosting, private media services, independently scheduled/off-site recovery, signed distribution and actual clinic devices still require the clinic's configuration and credentials. Local tests do not establish production compliance or replace staff acceptance.
