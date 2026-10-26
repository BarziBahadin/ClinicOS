# Development work and acceptance

The clinic uses administrator-created usernames and passwords. Staff email accounts, SMTP, invitation emails and recovery emails are not required. Reception/secretaries can extend the treatment list; an authorized approver activates prices. Clinical instructions remain clinician-approved.

“Implemented” below means code and local regression coverage exist. It does not mean production deployment or clinic acceptance has occurred. See [operations](operations.md) for release prerequisites, [English staff guide](user-guide.md) and [Sorani staff guide](user-guide.ckb.md). Both guides are accessible inside **Help & user guide**.

| Item | Work | Development status and remaining boundary |
| --- | --- | --- |
| Access change | Username sign-in and administrator-created accounts | Implemented: temporary-password change, role restrictions, protected reset and old-session denial. No email workflow. |
| 1 | Media patient/session identity | Implemented: scoped responses, cleared viewers, same-patient comparisons and regression tests. |
| 2 | Complete searchable histories | Implemented for clinical encounters, patient documents, consent, media, results/tasks, packages, stock, contacts, accounting and financial records. Searches and totals run in Postgres. |
| 3 | English/Sorani staff manual | Implemented: guides and in-app help. Native Sorani terminology and staff acceptance remain required. |
| 4 | Operational financial reports | Implemented: receivables/aging, statements with opening/closing balances, collections/refunds, deposit/package liabilities, payables, cash/bank register and till variances. Complete per-currency totals and fixed report cutoffs. Statutory statements and consolidated FX revaluation are outside this operational model. |
| 5 | Bank/card reconciliation | Implemented: CSV import, stable statement identifiers, exact original-currency matching, concurrency protection and append-only reversals. Bank API connections are not configured. |
| 6 | Accounting handoff | Implemented: approved account mappings, unique export batches, download and external acknowledgement. Actual external account codes, destination and accountant approval are still required. |
| 7 | Period controls/corrections | Implemented: closed periods, dated open-period adjustments and future-date rejection. Accountant approves the close/correction policy. |
| 8 | Treatment catalog/templates | Implemented: reception proposals, separate price approval, versioned immutable clinical/procedure/consent/aftercare/referral templates. Clinic staff supply and approve real content. |
| 9 | Structured prescriptions/clinical facts | Implemented: medication fields, author-only draft additions, signed immutability and append-only longitudinal amendments. No dose recommendation engine. |
| 10 | Purpose-specific clinical documents | Implemented: prescriptions, procedure aftercare, consent and signed patient letters/referrals, printing and linked corrections. Actual printers and clinician-approved wording require acceptance. |
| 11 | Performed-service billing handoff | Implemented: signed-encounter evidence and invoice-once transaction. |
| 12 | Versioned consent/patient copies | Implemented: approved template snapshot, purpose-specific permissions, withdrawal history and printing. Real consent wording needs clinical approval. |
| 13 | Multiple patient contacts | Implemented: owners/relationships, preferred numbers, retirement history and contact outcomes. |
| 14 | Rescheduling/resources | Implemented: versioned rescheduling, clinician availability/leave, cancellation evidence and room/device conflicts. Recurring rosters and branch-specific delegation are not implemented. |
| 15 | Package corrections | Implemented: expiry, signed-encounter redemption, unused-value cancellation/refund in proven original tender. Legacy sales without provable tender require reviewed accounting correction. |
| 16 | Stock management/alerts | Implemented: product/supplier catalogs, lot/unit/expiry validation, counts/waste, stock movements and complete reorder/expiry alerts. A full purchase-order, landed-cost and inventory-valuation subsystem remains separate development if required. |
| 17 | Media processing/recovery | Implemented: private bounded image processor, stripped previews, preserved originals, scanning, safe retry/cancellation and service-only expired failed-upload cleanup with evidence. Production private processor/scanner and maintenance scheduling still need deployment. |
| 18 | Staff phone-call reminders | Implemented as chosen by the clinic: paginated upcoming appointments, current communication consent, preferred contact/owner, actual call outcomes and safe retries. Reached/declined calls leave the open list; unanswered calls remain. Rescheduling creates a fresh reminder while preserving earlier calls. No automatic SMS/WhatsApp/email is required or sent. |
| 19 | Delegated access/care scope | Implemented: explicit additional roles/revocations, per-currency approval limits and assigned-care enforcement. Current app is one clinic/branch; branch-specific delegation remains separate development. |
| 20 | Retention/holds/patient exports | Implemented: approved policy evidence, legal holds/releases and purpose-audited clinical exports. Clinical-record deletion and backup-expiry execution remain disabled pending the clinic's approved legal/retention procedure. |
| 21 | Operations and independent audit copies | Local tools implemented: redacted health counts, scanner freshness, backup freshness, authenticated failed-upload cleanup, encrypted audit export and integrity verification. Production scheduling, independent destination, alert routing, incident ownership and authentication-failure telemetry remain deployment/integration work. |
| 22 | Signed desktop release/updates | Implemented release preflight/build path and packaged HTTPS update configuration, retaining signature verification. Signing certificates, notarization credentials, update hosting, signed installation/update tests and Windows acceptance are not available or completed. Current local macOS artifact is an unsigned development build. |

## Verification record

The final verification results are recorded in `docs/operations.md`. Deployment uses committed Supabase migrations; adjacent SQL files are development references. No hosted database was patched during this work.

## Decisions/configuration still needed

- Actual production Supabase/web hosts, protected operations credentials, private media services and independent backup/audit destinations.
- Clinician-approved treatment prices, templates, prescribing/consent/aftercare wording and native Sorani review.
- Accountant-approved chart codes, opening balances, close/recognition/FX policies and official-bookkeeping destination.
- Reminder provider and consent/delivery policy if automatic SMS/WhatsApp is wanted.
- Approved retention/deletion/backup expiry policy and legal holds procedure.
- Desktop certificates/update feed and clinic device, printer and supported-OS acceptance.

There is no staff-email/SMTP dependency in the chosen account workflow.
