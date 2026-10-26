# Engineering handoff — 25 October 2026

Photo-view crash fix: patient media and patient tools had identical sibling React keys. Opening Clinical media repeatedly remounted the photo component until React hit its maximum update depth and unmounted the screen. The two components now have separate identity prefixes while retaining their patient/session scope. Loaded photos scroll into view below the sticky navigation. `tests/patient-media.test.tsx` covers opening an image and moving between patient sections. Automated test execution remains deferred under the user's earlier instruction. The rebuilt desktop was manually checked with the doctor account, loading the sample image and switching patient sections without a blank screen.

Branding/demo follow-up: the user selected the Stormy Morning blue/slate palette (`#6A89A7`, `#BDDDFC`, `#88BDF2`, `#384959`). Native ClinicOS icon assets and Electron Dock/window wiring replace the default logo. `scripts/demo-data.ts` adds resumable, local-only fictional records through authenticated operations; see [demo walkthrough](demo.md). Existing accounts and records are preserved. The desktop preview is rebuilt without running the deferred automated test suites.

UI pass: see [UI review](ui-review.md) for marked findings and fixes across all five roles. Navigation/account controls, patient sections, Billing/Finance sections, staff-row actions, typography/contrast, dark appearance, Sorani labels and loading feedback were updated. The development UI was inspected visually. Automated checks and release packaging were explicitly deferred by the user; earlier results below do not verify these latest edits.

## Confirmed scope

Continue the 22-item ClinicOS development review. Accounts use administrator-created usernames/passwords without staff email. Reception/secretaries may add treatment names; approved prices and clinical content are controlled separately. The application is for one Iraqi clinic/initial branch, in English and Sorani RTL, with separate IQD/USD balances.

## Implemented and locally verified

See `docs/development-status.md` for all 22 rows. The work includes username provisioning/reset and mandatory first-password change; scoped asynchronous requests; complete searchable histories; treatment/template lists; structured prescriptions/facts; signed/printed documents and immutable identity snapshots; performed-service invoicing; contact history; resources/availability/rescheduling; package refunds/expiry; stock products/suppliers/counts/alerts; private scanned image previews; failed-upload recovery/cleanup; complete financial reports with fixed cutoffs; reconciliation, mappings, unique export batches and closed periods; additional roles/approval limits/assigned-care access; retention/hold evidence and purpose-audited clinical exports; health/audit-copy tools; and signed-release preparation.

Database queries aggregate postings as sets and resolve history labels once per distinct patient. Financial totals cover the complete set before detail pagination. Backend authorization and the existing statement timeout remain in place.

Deployment uses the committed migrations through `20261025114135_staff_phone_reminders.sql`. The workflow migration includes a journal-proven original-tender backfill and a full rejection grace period for existing failed uploads. Old signed records are not rewritten to invent historical identities. No hosted database was patched.

## Verification

- `npm run check`: 22 tests across eight files, TypeScript and production web build passed.
- `npm run functions:check` and `npm run functions:test`: trusted functions checked; exact desktop-origin CORS regression passed.
- `npm run db:test -- --media --recovery`: 57 database/API checks passed, including encrypted database/original/preview recovery, encrypted audit-copy tamper/wrong-key rejection, authorization, immutability and idempotency.
- `npm run db:advisors`: no warnings.
- `npm run db:migrations:check`: committed migrations replay successfully and match the local schema.
- Root and media-processor production dependency audits: zero reported vulnerabilities.
- Private media processor: its two image-processing tests passed during the Docker build.
- `npm run desktop:build`: unsigned macOS arm64 development build produced. Release preflight correctly refuses missing protected production settings.

Desktop UI checks cover username sign-in, role-scoped navigation, English/Sorani guides and staff call-list UI, RTL layout, protected image preview and a synthetic A4 clinical-document print preview. The app serves its bundle only from the fixed `clinicos://app` origin, with path containment, sandbox, CSP and restricted navigation. Trusted functions allow that exact origin plus the configured web origin while requiring bearer/session/permission checks. Full supported-OS/printer and signed-update acceptance remain external.

## Run and find the guides

Start local services with `npm run db:start`, then run `npm run functions:serve` and `npm run dev` in separate terminals. `npm run local:setup` preserves the existing synthetic credentials and refuses hosted targets. Individual development credentials are in ignored `.local/accounts.json`; usernames are `owner`, `doctor`, `receptionist`, `administrator` and `accountant`. Do not commit that file.

The desktop artifact is `release/mac-arm64/ClinicOS.app`. The guides are in `docs/user-guide.md`, `docs/user-guide.ckb.md` and the app's **Help & user guide** screen. Operations commands and production release prerequisites are in `docs/operations.md`.

## Remaining boundaries

The clinic chose manual staff phone-call reminders; automatic SMS/WhatsApp/email is outside that selected workflow. Branch-specific delegation, a full purchasing/valuation subsystem, and clinical-retention deletion/backup-expiry execution are not complete implementations. These require the clinic's confirmed operational scope or approved policy; the manual contact log does not send messages. Production operations still need independent destinations, scheduling and alert routing. Signed release installation/update tests need protected certificates, notarization and update hosting. Actual treatment/consent/prescribing content, official accounting policies and native Sorani/clinic acceptance are required before activation.

Do not report all 22 items as production-complete. No production deployment or external message delivery was performed.

## Next resumption

The reminder decision is resolved: staff use the in-app phone-call list. Upcoming scheduled appointments, communication consent, preferred contact/owner, actual outcomes, retry identity and appointment-version checks are implemented. No external provider or automated message delivery is needed for this workflow. Continue from the remaining boundaries above; do not restart completed work or repeat broad checks without a new change or concern.
