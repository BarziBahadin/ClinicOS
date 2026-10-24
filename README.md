# ClinicOS

Dermatology practice management for Iraq, in **Sorani Kurdish and English**, with **IQD and USD**. A React/TypeScript application backed by real Supabase Postgres, Auth and private Storage, with an Electron desktop shell.

## Run locally

Requirements: Node 22.12+ (Node 24 recommended), npm, and a Docker-compatible runtime. On this Mac, the existing Colima runtime can be started with `colima start --cpu 4 --memory 6`.

```sh
npm ci
npm run setup
```

Then run these in separate terminals:

```sh
npm run functions:serve
npm run dev
```

Open **http://127.0.0.1:5173**. For the desktop shell while Vite is already running, use `npx electron .`. Alternatively, `npm run desktop` starts both.

`npm run setup` creates isolated local services, enables the private clinical bucket through migrations, and adds synthetic records and individual development accounts. Credentials are written to **`.local/accounts.json`**, which is ignored by Git. Development service prices and patient details are fictional. The setup script refuses hosted URLs.

Choose the account for the workflow you are testing: `owner`, `doctor`, `receptionist`, `administrator`, or `accountant`. The owner account deliberately has no clinical-record access. Sessions stay in memory and the interface signs out after 15 minutes without keyboard/pointer activity. Reloading requires sign-in.

The scanner must be healthy before uploading files. Check it with `docker inspect --format '{{.State.Health.Status}}' clinicos-scanner`. Files are never accepted through a fallback that bypasses scanning.

## Implemented workflows

- Patient registration, shared and historical phone contacts, partial/unknown birth dates, historical encounter identity snapshots, controlled profile merge, normalized server search and pagination.
- Appointments, walk-ins, check-in, queue states, cancellation and date-specific schedules in Baghdad time; concurrent double-booking protection.
- Clinical drafts, allergies/history/findings/diagnoses/plans/prescriptions, signing, immutable signed records, addenda, purpose-specific consent, procedure records, result review/notification steps and follow-up tasks.
- Private clinical photographs and PDF attachments, file-content validation, malware scanning, original-file preservation, short-lived authorized access, comparisons and consent withdrawal checks.
- Services, invoices with server-calculated prices, approved discounts/credits, partial payments, recorded-rate USD/IQD settlement in both directions, deposits, original-rate refunds, package sale/redemption and printable invoices/receipts.
- Expenses, supplier payables and settlement, salary disbursements with restricted details, owner funding/withdrawals/loans, transfers, opening entries, explicit currency exchange, manual adjustments, till close, balanced immutable journals and accounting CSV export.
- Role-scoped reporting/audit, individual staff invitations and access changes, MFA enrollment/verification, account password setup and protected configuration.
- Local encrypted database/media backup and verification tools, reviewed migrations, regression tests and CI configuration.

## Verification

```sh
npm run check
npm run functions:check
npm run db:test -- --media
npm run db:advisors
```

The database suite uses separate synthetic organizations/accounts, exercises actual Supabase APIs and Postgres transactions, and cleans only its own fixtures. Media tests require the functions process and healthy scanner. See [operations and release requirements](docs/operations.md) for recovery, deployment, remaining configuration and verification boundaries.

## Structure

`src/domain` contains identity, money, time and response-validation rules; `src/features` contains workflow screens; `src/components` contains accessible form/table/dialog primitives; `src/lib` contains API, localization and formatting support. `supabase/migrations` is the deployment history. The adjacent SQL source files are readable development references, not scripts to replay over an existing deployment. Trusted functions live under `supabase/functions`; `electron` holds the isolated desktop shell.

The [original research proposal](docs/clinic-management-proposal.md) and [implementation brief](docs/implementation-brief.md) explain the design decisions. Confirmed scope was subsequently refined to Iraq, IQD/USD, Sorani/English, medical/cosmetic care and no incumbent software.
# ClinicOS
