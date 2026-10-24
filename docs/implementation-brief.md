# ClinicOS implementation brief

Proposal dated 24 October 2026. Read the [full proposal](clinic-management-proposal.md) for rationale, sources, workflow details and permission matrix. Subsequent confirmations: Iraq, IQD and USD, and cross-currency receipts using a recorded IQD-per-USD rate. The repository README and operations guide describe implemented behavior and release requirements.

**Objective:** Build ClinicOS for reception, medical and cosmetic dermatology, and business administration, in Sorani Kurdish RTL and English. Each staff member uses an individual account. Preserve patient safety, accurate financial records and controlled access.

**Architecture:** One modular TypeScript frontend and Supabase backend. Prefer browser delivery; use the same frontend in a thin Electron shell if verified device/desktop requirements justify it. Use Postgres transactions and constraints for integrity, Auth for identity, private Storage for media, controlled APIs for audited sensitive operations, and an outbox for external effects. Final UI library remains undecided; use `apple-design` for relevant later design review.

**Launch behavior:** Patient registration/search and controlled merge; appointments/walk-ins/queue; history/allergies/encounters/prescriptions; purpose-specific consent and private clinical photos; procedure/session records; results and follow-up tasks; service pricing, invoices, partial payments, deposits if taken, refunds and receipts; all cash movements, expenses and supplier/staff/owner payments; opening balances, daily reconciliation and an accountant-approved financial handoff. Include lot/expiry/usage tracking and package entitlement only where offered services require them.

**Identity/data rules:** Immutable patient UUID plus non-reused clinic number; phone is nonunique and optional. Preserve original names and contacts. Support partial/unknown birth information and dated reported age. Compute current and historical age with appropriate uncertainty and preserve signed-record provenance. Keep clinical sex-related information distinct from administrative gender where necessary.

**Access and integrity:** Apply the matrix in section 6 through backend permissions, organization/branch policies and protected table boundaries. Administrator/owner status grants no automatic clinical access. Signed records use addenda; posted finance uses corrective records. Enforce idempotency, allocation/refund limits, optimistic draft versions and transaction-safe concurrent updates.

**Finance:** Default to ClinicOS patient subledger/cashbook plus a selected accounting product. A reconciled file exchange is acceptable initially. If all books must be inside ClinicOS, add a complete balanced ledger and accountant-approved statements before claiming that scope is complete. Do not implement statutory tax/payroll rules from assumptions.

**Verification:** Direct API permission tests, clinical/financial concurrent-write scenarios, retried operations, original/derived media protection, bilingual RTL and printing checks, reconciliation examples, full database-plus-object restore and staff pilot acceptance. No production patient data in development.

**Decisions required before dependent implementation:** Country/region; currency and any exchange; users/visits/branches; internet/offline needs; exact treatments and devices; accounting boundary; deposit/package/insurance use; retention/consent rules; print/integration requirements; recovery objectives. See section 3. No application code should start until these decisions are reflected in the agreed implementation scope.
