# Operation, recovery and release

## Scope and financial boundaries

The local build supports one clinic organization and its initial branch. Organization/branch keys are present for growth; branch-specific delegation, multi-tenant sales, insurance claims, regulatory e-invoicing, full offline synchronization and external messaging/accounting connectors require separately configured workflows. No integration is silently simulated.

The internal journals provide balanced operational bookkeeping in each original currency, with a trial balance and accountant export. They do not implement Iraqi statutory tax/payroll calculations, automatic inventory valuation/depreciation, statutory financial statements or consolidated FX revaluation. Payroll entries record authorized amounts, rather than calculating legal payroll. An accountant must approve opening entries, chart mapping, recognition, exchange policies and reporting before live financial use. Revenue, deposits, owner movements and cash remain distinct.

Appointments and age calculations use the clinic's Baghdad calendar. Financial records retain original currency; exchange movements store the rate supplied at the time. Receipts may settle USD invoices with IQD or IQD invoices with USD. The operator enters IQD per one USD, to at most six decimal places. The system stores the actual tender, historical rate and invoice allocation, rounded to the invoice currency precision (USD two decimals, IQD three). Cross-currency receipts and refunds use balanced clearing entries in both currencies. Refunds return the original tender at its recorded allocation; the final refund carries any rounding residual. A partial refund that would strand an unallocatable remainder is rejected with guidance to return the full remaining receipt. A change to a future rate does not rewrite prior records.

## Credentials and identity

- `.env.local` contains only the public Supabase URL and publishable key. Never put a secret key, database password or signing certificate in a `VITE_` variable.
- Production staff accounts are invited individually. Keep public registration disabled at `[auth].enable_signup=false`, while keeping the email/password provider enabled with `[auth.email].enable_signup=true`. The CLI maps the latter to the whole email provider; disabling it also prevents existing password logins ([Supabase CLI issue and reproduction](https://github.com/supabase/cli/issues/7055)). Verify both sign-in and anonymous signup rejection after changing Auth configuration. Owner/administrator permissions do not grant clinical access. Deactivate memberships when staff leave; backend membership checks deny subsequent requests even with an earlier access token.
- TOTP must be enabled in Supabase Auth, and clinic MFA enforcement should remain enabled in production. Staff can enroll/verify under their account/security view. Invitation recipients should set their password there before signing out.
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
2. Configure the exact app origin, Auth redirect allowlist, production SMTP/invitation templates, password recovery and enabled TOTP. Configure trusted Edge functions with the app origin and a reachable private scanner host/port. Deploy the scanner with pinned images, updated signatures, monitoring and network isolation.
3. Deploy the web build with its generated security headers and HTTPS. The `_headers` file targets hosts that support that format; configure equivalent headers on other hosts. Verify public schema exposure is limited to the intended API and the clinical bucket stays private.
4. Establish backups, restore drills, a retention schedule, incident contacts and downtime procedures. Confirm actual clinic workload, staffing, treatment catalog, product traceability and device/printing requirements.
5. Have a dermatologist approve templates, prescribing/procedure records, consent wording, results escalation and aftercare. Have native Sorani users validate terminology and documents. Have a local accountant approve the financial model and required Iraqi documents. Legal/regulatory requirements are not certified by this implementation.
6. For distributed desktop releases, provide protected Windows/macOS signing credentials, macOS notarization and an HTTPS update feed. Build and test on each supported OS; require verified signed updates. Local directory packaging is an unsigned development artifact, not a production release.
7. Run staff acceptance with synthetic data, then create reviewed opening balances and an explicit cutover. Do not run development seed scripts against production.

## Current verification limits

Local verification on 25 October 2026 passed `npm run check` (10 tests and the web build), `npm run functions:check`, `npm run db:migrations:check`, `npm run db:test -- --media --recovery` (32 integration checks, including an encrypted database/private-object recovery drill), and `npm run db:advisors` (no warnings). The migration check replays committed migrations into an isolated shadow database and fails if the local application schema differs. CI runs this check before the integration suite. The deployment-parity migration captures previously local-only financial pagination, invoice balance projections, stale merge protection and appointment identity validation.

`npm run desktop:build` produced an unsigned macOS arm64 development app. A smoke check of the running development desktop patient directory covered English, Sorani RTL, mixed-script names, patient numbers and phone numbers. This was not a full workflow acceptance run; printing, Windows and signed updates were not verified in this pass.

The application has been developed and tested against a real local Supabase stack and local antivirus service. Production infrastructure, mail deliverability, independently scheduled/off-site backups, signed desktop distribution, actual clinic devices and legal/clinical/accounting acceptance require the clinic's configuration and credentials. Those are release requirements; local tests do not establish production compliance or replace staff acceptance.
