# ClinicOS engineering rules

This is a medical and cosmetic dermatology application for Iraq, in Sorani Kurdish (RTL) and English, with IQD and USD. Read `README.md` and `docs/operations.md` before changing runtime behavior.

- Preserve individual accounts, backend permission enforcement, private media, and organization scope. Business administration does not imply clinical access.
- Treat committed Supabase migrations as the deployment contract. Develop against local Postgres, run the advisor and integration suite, generate reviewed migrations, and verify replay. Never patch a hosted database as a substitute for a migration.
- Public API functions are narrow operations. Base tables remain in the non-exposed `clinic` schema. Keep function privileges, RLS, fixed search paths and backend identity checks explicit.
- Financial operations must be transactional and idempotent. Use decimal arithmetic, original currency, and explicit historical FX rates. Do not combine IQD and USD balances without a defined conversion policy.
- Signed clinical records and posted finances are immutable. Correct through addenda, credits, refunds or authorized journals. Never erase the original event.
- Keep asynchronous results tied to their request, patient and authenticated session. A stale response must never appear in another patient's record.
- Search and aggregate in the database. A page of records is not a financial report or a complete patient index.
- Never put privileged credentials or patient data in frontend bundles, telemetry, source control or development fixtures. Development seed scripts must refuse hosted targets.
- Use `npm run check`, `npm run functions:check`, `npm run db:test -- --media`, and `npm run db:advisors`. Add regression coverage for data-integrity and authorization fixes. Do not weaken a test or authorization check to make a failure disappear.
- Verify English and Sorani UI, mixed-direction identifiers, printing, interrupted submissions and at least the supported desktop release before production rollout.
- Production activation requires configured hosting, SMTP, scanning, independent database/object recovery, protected signing/update credentials and clinic acceptance. Report verification limits accurately.
