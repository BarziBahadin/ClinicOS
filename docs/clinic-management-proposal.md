# ClinicOS: requirements and architecture proposal

Research date: 24 October 2026. Status: original requirements proposal; see the repository README for implementation and verification status.

**Confirmed:** Iraq; Sorani Kurdish RTL and English; IQD and USD; settlement in either currency with an explicitly recorded IQD-per-USD rate; medical dermatology and cosmetic services; no existing software or data migration. **Unresolved:** staffing, daily visits, branch expansion, connectivity, production devices, hosting and statutory accounting requirements.

Throughout this report, proposed behavior is a recommendation. Linked sources establish technical capabilities or professional principles, rather than a claim that a particular law applies.

## 1. Executive recommendation

Build one maintainable application with clear modules for reception, clinical care, billing, and business administration. Use Supabase Postgres, Auth, and private Storage, subject to a jurisdiction and hosting review. Prefer a shared TypeScript web frontend; React is a reasonable implementation candidate, pending team experience. Add a thin Electron shell only if desktop requirements justify it.

| Direction | Benefit | Cost or limitation | Recommendation |
| --- | --- | --- | --- |
| Browser application | Central updates; access from approved computers; useful for administration and accounting | Browser limits on some hardware and printing integrations | Default starting point |
| Electron using the same frontend | Desktop integration, controlled windows, native printing or scanner bridges | Separate packaging, signing, updates, OS testing, larger runtime | Use when a concrete device or desktop workflow requires it |
| Full offline desktop system | Work can continue during extended outages | Local patient data, conflict resolution, synchronization, payment and stock reconciliation | Separate scope decision before implementation |

**Electron does not itself make an online application work offline.** A web frontend can also run in Electron later if device boundaries are designed early. Supabase provides a relational Postgres foundation, but application authorization and business controls remain our responsibility. [Supabase database overview](https://supabase.com/docs/guides/database/overview).

For finances, recommend clinic billing and a complete cash-movement register connected to an accountant-approved accounting product. The requested payroll, equity, liabilities, and financial statements exceed ordinary billing. If everything must be maintained inside ClinicOS, a proper double-entry ledger becomes a separate required workstream.

The supplied [Apple design skill](https://github.com/dickwu/apple-design-skill) is installed as `apple-design` at `/Users/barzy/.codex/skills/apple-design`. It provides design-review guidance, rather than a component library. Keep the final UI library undecided. Use its guidance alongside native platform expectations, accessibility, Sorani usability, and dense clinical workflows.

## 2. Missing requirements and risky assumptions

| Assumption or omission | Consequence | Proposed resolution |
| --- | --- | --- |
| One unique phone identifies one patient | Families, minors, changed numbers, and recycled numbers cause errors | Immutable patient ID; shared and historical contacts |
| Exact birth date always exists | Invented dates create false clinical precision | Partial birth dates and dated age estimates |
| Administrator means access to everything | Unnecessary exposure of notes, photos, and salaries | Separate operational, clinical, and financial permissions |
| A visit, appointment, and invoice are the same object | Walk-ins, repeat visits, unpaid visits, and advance payments break the model | Separate records linked explicitly |
| Photo consent covers every use | Treatment images may be reused inappropriately | Separate care, teaching, publication, and marketing purposes |
| Results are just uploaded documents | Abnormal findings may never be reviewed or communicated | Assigned results inbox, due dates, escalation, and completion evidence |
| Cosmetic sessions are ordinary appointments | Product details, device settings, complications, and package balances are lost | Treatment-specific session records |
| Money received equals revenue | Deposits, owner funding, and debt collections distort reports | Separate cash, receivables, revenue, liabilities, and equity |
| A clean start means zero opening balances | Existing cash, bank funds, stock, debts, and owner funding disappear | Verified opening balances and cutover date |
| Hosted services remove operational responsibility | Backups, account recovery, and incident response are neglected | Named owners and restore drills |
| Clinical records can be overwritten or deleted | Loss of medical and financial accountability | Signed versions, amendments, reversals, and retention rules |
| A disabled Save button prevents duplicates | Retries and concurrent devices still create duplicate entries | Backend idempotency and integrity constraints |

Also define guardian authority, chaperone documentation where applicable, deceased/inactive patient handling, referral ownership, staff absence coverage, cancellation/deposit policy, and who handles urgent follow-up. A clinician must approve clinical templates and escalation rules.

## 3. Essential clarification questions

Answers already supplied are incorporated above. These decisions remain open; research and requirements can proceed, while dependent implementation needs answers.

| Priority | Question | Why it changes the design |
| --- | --- | --- |
| P0 | In which country and region will the clinic operate? | Hosting, privacy, retention, prescribing, consent, invoices, and breach obligations |
| P0 | What currency or currencies are used? Are prices and receipts in different currencies? | Precision, rounding, exchange rates, and cash reconciliation |
| P0 | How many staff, simultaneous users, daily visits, and branches at launch and expected growth? | Scheduling, branch access, capacity testing |
| P0 | How frequent and long are internet outages? Must clinical work and payments continue during them? | Online-first versus an offline synchronization project |
| P0 | Which cosmetic treatments, devices, injections, medicines, biopsies, and laboratory workflows are offered? | Required safety fields, stock lots, resource scheduling, results tracking |
| P0 | Will an accountant use separate software, or must ClinicOS provide all accounting? | Integration versus a complete ledger; payroll and reporting scope |
| P0 | Which desktop OS, printers, scanners, cameras, and other devices are mandatory? | Whether Electron is justified and which platforms need support |
| P1 | Are deposits, prepaid packages, insurance, credit sales, or third-party payers used? | Billing, allocation, liabilities, refunds, claims |
| P1 | Who owns the clinic, approves refunds, manages access, and independently reviews cash? | Permission assignments and compensating controls |
| P1 | Which Sorani terminology, numeral style, calendar/date format, and bilingual print formats are preferred? | Localization and document acceptance |
| P1 | Which integrations are necessary: messaging, payments, labs, pharmacy, government invoicing, accounting? | Provider contracts and trustworthy data exchange |
| P1 | How much data loss and downtime can the clinic accept? What retention and patient-access policies apply? | Backup design, costs, recovery procedures |

There is no existing software to migrate, but confirm whether paper records need scanning and whether unpaid balances or prepaid treatments already exist.

## 4. End-to-end workflows

1. **Find or register:** search clinic patient number, phone, name, and birth information. Show possible matches; receptionist verifies identity before creating a new record. Record contact owner, language, guardian where relevant, and communication preferences. WHO recommends verification using at least two identifiers; software search is not a substitute for checking the patient. [WHO patient identification guidance](https://www.who.int/docs/default-source/integrated-health-services-%28ihs%29/psf/patient-safety-solutions/ps-solution2-patient-identification.pdf).
2. **Schedule or accept a walk-in:** choose clinician, service, branch, duration, and any room/device. Keep appointment status separate from the day's queue. Record cancellation/no-show reason. Overrides of resource conflicts require authorization and a reason.
3. **Check in:** confirm identity and changed demographics; record arrival and assign a queue entry. Display a discreet queue number publicly rather than diagnoses or a full patient list. Reception can flag urgent concerns for clinical triage without making clinical decisions.
4. **Clinical encounter:** clinician reviews allergies, medication/history, prior encounters, and outstanding results. Document findings, diagnoses, body site/laterality, treatment plan, prescriptions, procedures, and follow-up. Sign the encounter; later corrections become dated addenda. Financial status must not automatically determine whether care records can be completed.
5. **Photos and procedures:** confirm permitted purpose before capture; verify patient, encounter, and body site. Preserve original images and dated comparison views. For relevant cosmetic services, record product, batch/lot, expiry, quantity, operator, device/settings, procedure consent, aftercare, and adverse events. A clinician defines treatment-specific required fields.
6. **Charge and collect:** completed services produce proposed charge lines. Reception confirms allowed prices and discounts; the backend issues the invoice. Record one or more payments and their allocation, issue receipts, and show remaining balance. Record deposits separately from earned revenue.
7. **Follow up and close results:** clinician creates a task with owner and due date; staff schedule follow-up and send permitted reminders. Track specimen/order, result received, clinician reviewed, patient notified, and next action. AAD describes clinician review and patient communication after biopsy; the proposed task workflow makes that responsibility visible. [AAD skin biopsy guidance](https://www.aad.org/public/diseases/a-z/what-is-skin-biopsy).
8. **End of day:** receptionist closes the till by payment method, counts actual cash, records discrepancies, and hands over for review. Administrator checks receipts, refunds, discounts, expenses, deposits, open encounters, unreviewed results, and accounting export failures. Carry clinical tasks forward explicitly; a cash close does not close care tasks.

Photography guidance varies by context: some professional guidance distinguishes consent for care from express consent for secondary use. Record the discussion and purpose; approve local consent forms before launch. [CMPA clinical photography guidance](https://www.cmpa-acpm.ca/en/advice-publications/browse-articles/2011/using-clinical-photography-and-video-for-educational-purposes), [BAD teledermatology information](https://www.bad.org.uk/pils/teledermatology).

## 5. Prioritized feature matrix

“Launch if used” means the associated service cannot launch in the system without that capability.

| Area | Priority | Rationale and dependencies |
| --- | --- | --- |
| Individual staff accounts, roles, branch scope, audit | Launch | Foundation for every protected workflow |
| Sorani RTL and English, keyboard navigation, bilingual print | Launch | Confirmed language requirement; validate with native speakers |
| Patient search, shared contacts, unknown/partial birth date | Launch | Safe registration and continuity |
| Duplicate review and controlled merge | Launch | Prevent fragmented records without automatic misidentification |
| Appointments, walk-ins, queue, clinician availability | Launch | Core reception workflow |
| Encounters, history, allergy status, diagnoses, plan, prescriptions | Launch | Core medical record; clinician-approved templates |
| Private photos, consent, body site, dated comparison | Launch | Dermatology continuity and sensitive media protection |
| Procedure and treatment-session documentation | Launch | Both medical and cosmetic services confirmed |
| Lab/biopsy tracking and escalation | Launch if ordered | Prevent unattended results; attachments alone are insufficient |
| Product lots, expiry, usage, wastage, recall lookup | Launch if products administered/dispensed | Traceability; depends on actual treatment catalog |
| Services, prices, invoices, partial payments, receipts, refunds | Launch | Complete patient billing lifecycle |
| Cashbook, expenses, supplier payments, salary disbursements, owner movements | Launch | Covers all money movements with restricted detail |
| Opening balances, till closure, reconciliation, accounting handoff | Launch | Reliable cash and accounting continuity |
| Deposits | Launch if accepted | Liability and refund tracking before service delivery |
| Prepaid packages and session entitlements | Launch if sold; otherwise next | Requires liability, redemption, expiry, refund policies |
| Consent preferences, manual contact log, follow-up tasks | Launch | Communication accountability without choosing a provider |
| Documents, referrals, result attachments | Launch | Controlled document lifecycle and assigned clinical review |
| Automated reminders | Next | Depends on permitted channel, provider, and delivery tracking |
| Broader purchasing, reorder points, stock counts | Next | Extend required clinical traceability into inventory operations |
| Automated accounting connector | Next if reconciled file exchange works at launch | Requires selected product and stable posting rules |
| Advanced reports and branch expansion interfaces | Next | Start with operational reports and a branch-aware model |
| Patient portal, online booking, teleconsultation, insurance claims | Optional unless business requires them | Each introduces additional identity and workflow requirements |
| Marketing campaigns, loyalty, AI diagnosis, 3D body maps | Optional | Separate value, safety, privacy, and scope assessment |
| Full offline editing and synchronization | Separate decision | Changes storage, identity, conflict, and recovery design |

Clinical safety records required by the offered cosmetic services belong at launch. Cosmetic marketing and loyalty do not follow automatically from offering those services.

## 6. Roles and permissions matrix

Each staff member has an individual account and one or more assigned roles. Scope every permission to an organization, branch, and care relationship where relevant. “Limited” means an explicit subset, not unrestricted access.

| Capability | Receptionist | Doctor | Administrator | Owner/finance approver | Accountant |
| --- | --- | --- | --- | --- | --- |
| Demographics and contacts | Create/edit | Read; request/correct with audit | Manage | Limited for business need | Minimum billing identity |
| Duplicate merge | Propose | Confirm clinical identity when needed | Execute approved merge | No default | No |
| Appointments/check-in/queue | Manage | Own schedule and care status | Manage | Aggregate view | No |
| Clinical notes/history/prescriptions | No | Assigned/covering care; author/sign | No default | No default | No |
| Clinical photos and body-site records | No default | Care-related access/manage | No default | No default | No |
| Consent administration | Record administrative evidence | Explain/confirm clinical consent | Manage forms and versions | Approve policies | No |
| Routine invoices and receipts | Create/collect within limits | Record performed services; view necessary balance | Manage | Approve exceptions | Read/reconcile |
| Discounts/refunds/financial corrections | Request or limited threshold | Request | Within delegated threshold | Approve higher threshold | Post/reconcile with grant |
| Supplier bills and operating expenses | Submit evidence if delegated | No default | Enter/manage | Approve | Reconcile/post |
| Salaries and sensitive payroll | No | Own information if provided | Only explicit payroll grant | Approve | Explicit payroll grant |
| Equity, owner withdrawals, journals, period close | No | No | Only delegated | Approve | Manage accounting |
| Reports | Own till and queue | Clinical workload | Operational/authorized finance | Business finance | Finance |
| Exports | Individual receipts only | Authorized patient care packet | Approved scoped exports | Business exports | Finance exports |
| Staff accounts and access | No | No default | Provision approved roles | Approve privileged grants | No |
| Audit logs | Own transaction history | Own clinical actions | Operational/security scope | Authorized oversight | Financial scope |

The owner role is useful for approvals without automatically granting clinical access. An accountant role is useful even for an external part-time accountant. If one person holds several roles, preserve explicit grants and flag self-approval. Where staffing prevents separation, require documented owner review of exceptions and cash variances.

Enforce grants in the database and trusted server operations. A hidden screen is not authorization. Store protected memberships and permission assignments server-side; never derive authority from editable user profile metadata. Supabase supports custom claims and RBAC, but the application must define its permissions. [Supabase RBAC](https://supabase.com/docs/guides/api/custom-claims-and-role-based-access-control-rbac).

## 7. Proposed data model and integrity rules

### Main entities

| Domain | Entities and relationships |
| --- | --- |
| Organization/access | `organization`, `branch`, `staff_profile` linked to Auth user, `membership`, `role`, `permission`, assignments and branch scopes |
| Patient identity | `patient`, `patient_identifier`, `patient_contact`, guardian/related-person relationship, identity correction history, `patient_merge` |
| Scheduling | `appointment` links patient, clinician, branch, service and resources; separate `queue_entry`; staff availability and resource reservations |
| Clinical care | `encounter` links patient, branch, responsible clinician and optional appointment; versioned notes, allergy/medication/history records, diagnosis and prescription items |
| Dermatology | `body_site`/lesion reference, `clinical_media` with encounter, capture time, object key, hash, purpose and consent reference; `procedure`, `treatment_plan`, `treatment_session` |
| Consent and documents | Versioned consent template, consent decision/evidence, withdrawal; document metadata, referral, laboratory/specimen order, result, assigned follow-up task |
| Catalog/pricing | `service`, effective-dated price, performed service/charge proposal; invoice lines snapshot the agreed description and price |
| Patient finance | `invoice`, `invoice_line`, `credit_note`, `payment`, `payment_allocation`, `refund`, patient deposit/credit liability; receipt/numbering records |
| Business finance | Supplier, supplier bill/expense recognition, expense category, payable settlement, restricted salary disbursement, cash/bank account, movement, transfer, till session and reconciliation |
| Accounting handoff | Account mapping, accounting batch/export items, external IDs, acknowledgement/error status; if internal ledger chosen: account, journal entry, journal line, accounting period |
| Packages | Package sale, entitlement, redemption, adjustment; link redemption to actual session and financial recognition |
| Inventory | Product, unit of measure, stock location, lot/batch, expiry, stock movement, session usage/waste, supplier receipt |
| Accountability/reliability | Append-only audit event, request idempotency record, integration outbox, notification preference/delivery record |

### Patient identification

Use an immutable UUID as the internal patient key. Add a readable patient number unique within the organization, assigned atomically and never reused. Do not encode phone, birth date, gender, or diagnoses into it. A person can be a patient without an application login.

**Phone numbers are not unique across patients.** Allow zero or several contacts; record the number's owner, relationship, preferred use, validity interval and verification status. Preserve the entered value; normalize valid international numbers using a maintained phone-number parser and known country context. Do not invent a country code. A verified number establishes reachability, not patient identity. Prevent accidental duplicate active contact rows within the same patient where appropriate, while permitting shared family numbers.

Search patient number exactly, phone in normalized and original forms, and names using language-aware matching. Display additional identifiers before staff select a record. Flag similar name/birth/contact combinations for review; do not auto-merge based on phone, name, or similarity scores.

Merge requires authorized identity review, a reason, a survivor record and a permanent redirect from the retired ID. Lock affected records, preserve provenance, reconcile contacts, and review clinical conflicts and balances. Never rewrite issued invoice identity snapshots or erase historical attribution. An incorrect merge requires supervised corrective reassignment with evidence, rather than a casual Undo button.

### Birth date, age, sex and gender

Represent birth information as known year/month/day components with precision and estimated status; validate real dates and disallow impossible/future birth information. Allow completely unknown birth information. Separately allow a reported age, unit, recorded-at date, and source when birth information is unavailable. Do not fabricate 1 January birthdays.

Calculate current age from exact birth date using the clinic's local date; use months/days where clinically needed. Calculate age at a historical encounter from its service date, not today's date. If the birth information is partial, display an approximate age or range. Preserve the birth-information version or documented age snapshot used at a signed encounter so later corrections do not silently alter the historical record. FHIR permits partial birth dates and distinguishes administrative gender from specific sex/gender observations. [HL7 Patient definitions](https://www.hl7.org/fhir/patient-definitions.html).

Record gender respectfully with unknown/not-disclosed options. Any clinically necessary sex-related information belongs in separately permissioned clinical fields or observations, with a defined purpose and provenance. Neither field should be inferred from a name, appearance, or the other field.

### Important integrity rules

- Put organization scope on domain records; carry branch where it matters. Use scoped foreign keys so a child cannot reference a patient, invoice, lot, or account in another organization.
- Store monetary amounts in exact decimal types with a currency code and explicit rounding rules. Never use floating-point for money; never total unrelated currencies without a defined conversion.
- Keep service, issue, payment, settlement, and posting dates distinct. Store instants consistently and use branch timezone/business date for schedules and daily close.
- Posted invoices, financial entries and signed encounters are immutable through ordinary edits. Use credit notes, refunds, reversals and addenda.
- A payment can cover several invoices; an invoice can have several payments. Enforce allocation limits and prevent the same payment or refund being counted twice.
- Validate state transitions server-side. An appointment is not proof of attendance, a delivered session is not proof of payment, and a sent reminder is not proof of consent.
- Use unique organization/operation/idempotency keys and provider-event IDs. A replay with different content must fail rather than silently reuse an earlier result.
- Use optimistic record versions for drafts; reject stale edits with a comparison view. Lock relevant balances/entitlements for concurrent financial or package updates.
- Index scoped patient numbers, normalized contact search, encounter history, schedules, open balances, task due dates, membership checks and foreign keys. Preserve original names; make any Sorani/Arabic character normalization a separate search representation validated with native speakers.
- Use bounded, consistently ordered pagination; begin with ordinary indexed reporting and add materialized summaries only when measured load requires them.

Transactions and locking must protect cross-record rules; a frontend sequence of successful requests is not an atomic transaction. Serialization failures require controlled retries. [PostgreSQL transaction isolation](https://www.postgresql.org/docs/current/transaction-iso.html).

## 8. Accounting recommendation

### Choose a financial boundary deliberately

| Approach | What it provides | Assessment |
| --- | --- | --- |
| Billing plus a simple expense list | Charges, receipts and basic cash summaries | Insufficient for the stated full financial scope |
| Clinic subledger/cashbook plus accounting software | Clinic-specific patient balances with full books, payroll and statutory reporting elsewhere | Recommended, with reconciliation and clear ownership |
| Full accounting inside ClinicOS | One application for billing, journals, assets, liabilities, equity and financial statements | Feasible only as explicit additional scope with accountant-designed rules and validation |

There is no incumbent accounting software. Select a product with a local accountant after country, currency, language, tax and payroll needs are known; do not select a brand from this incomplete context. A reconciled accountant-approved file exchange can precede an automated connector.

**System ownership:** ClinicOS owns patient charges, invoices, payments, deposits, refunds, clinic cash movements and supporting evidence. The accounting product owns the official general ledger, chart of accounts, statutory rules, payroll calculation and financial statements. Capture each non-patient cash movement once, with its business classification and source reference; exchange it with the accounting system rather than re-entering an independent transaction. Accountants may originate adjusting journals externally; synchronize a reference and reconciliation effect where needed, without pretending they are new receipts.

Every cash/bank account needs one authoritative transaction register. If bank imports are introduced, match imported lines to existing movements instead of creating duplicates. Supplier payments, salary payments, rent, utilities, supplies, owner funding, withdrawals and transfers must all appear in reconciliation even where their full accounting treatment resides externally.

### Distinguish performance from money movement

The following examples illustrate a proposed accrual model in unspecified currency units; they are not tax or jurisdiction-specific instructions. An accountant must approve the actual recognition policy. The IFRS conceptual framework separates owner contributions/distributions from income/expenses; that distinction is useful here without assuming the clinic reports under IFRS. [IFRS conceptual framework, paragraphs 4.68–4.70](https://www.ifrs.org/content/dam/ifrs/publications/pdf-standards/english/2021/issued/part-a/conceptual-framework-for-financial-reporting.pdf?bypass=on).

| Example | Accounting meaning |
| --- | --- |
| Service delivered for 100; patient pays 40 | Revenue 100, cash received 40, receivable 60 |
| Patient pays the remaining 60 later | Cash increases and receivable decreases; no second revenue |
| Patient prepays 200 for future treatment | Cash increases and a deposit/unearned-service liability arises; recognize revenue as applicable services are delivered |
| Supplier bill for supplies is unpaid | Record a payable and the appropriate expense or inventory asset; payment is a separate settlement |
| Salary earned but not yet paid | Accrued expense/payable under the approved policy; disbursement later settles it |
| Owner contributes capital or withdraws equity | Equity movement, rather than service revenue or an operating expense; owner loans need separate liability treatment |
| Transfer money from till to bank | Transfer between assets, rather than revenue or expense |

Inventory purchases, equipment purchases, prepaid rent, payroll deductions, discounts and refunds require appropriate classification. Do not treat every outgoing payment as an expense. Do not recognize all package sales as earned revenue solely because cash was collected.

### Required controls

- Record invoice lines, taxes if applicable, discounts, service dates, payment methods, allocation, receipts and evidence. Configure legal numbering only after jurisdiction review; preserve issued numbers and documented voids.
- Restrict discounts, credit notes and refunds by permission/threshold. Require reason and approval where applicable; enforce total refundable amount and link refunds to original payments and credit treatment.
- Separate draft cancellation, issued-invoice correction, refund of cash and write-off of debt. Each has a different effect.
- Record supplier bills separately from payments; attach evidence, due date, category and approval. Keep payroll details restricted even when a salary movement appears in a cash summary.
- Verify opening cash, bank, receivables, deposits, payables, stock and equity/loan balances at an agreed cutover date. The accountant approves balancing entries.
- Close each till using opening float plus cash receipts minus cash refunds/payments/transfers. Compare expected with physically counted cash; record variance and reviewer. Separate drawer movement from card/bank settlement.
- Reconcile card settlements, processor fees and timing differences; reconcile bank statements independently. Review deposits and package liabilities, receivables, payables and accounting handoff totals.
- Export stable source IDs with batch totals and mapping version. Retried batches must not repost entries. Track acknowledgement and reconcile both record counts and amounts; make failures visible.
- Lock closed periods and correct through authorized dated adjustments. If staffing permits, separate collection, approval and reconciliation; otherwise require independent owner review.

**Launch reports:** patient statement and aging; invoices/credit notes; receipts/refunds by method; daily till and variances; outstanding deposits and packages; expense/payable summary; supplier/salary disbursements; owner contributions/withdrawals/loans; cash/bank movement; failed accounting batches. Clearly label billed services, recognized revenue and cash collected as different measures. Profit and loss, balance sheet, trial balance and cash-flow reporting come from reconciled complete books, not an unreconciled billing dashboard.

If an internal ledger is chosen, require a chart of accounts, balanced journal lines, posting rules, control accounts, period locks, reversals, opening journals, trial balance, and accountant-approved financial reports. Debits must equal credits in each journal under its currency policy. Billing-only release must not be presented as satisfying the full accounting requirement.

## 9. Security, privacy and reliability design

### Identity and authorization

Use invitation-only individual accounts, staff offboarding, protected account recovery, and periodic permission review. Recommend MFA for everyone, required at least for privileged financial actions, exports and access administration. Enforce the required authentication assurance in the backend; a frontend MFA screen alone is insufficient. [Supabase MFA](https://supabase.com/docs/guides/auth/auth-mfa).

Implement an application screen lock plus server-enforced session policy. Choose timeout values with clinic staff. Supabase sessions can otherwise persist indefinitely, and configured session limits are not equivalent to immediate access-token revocation. Sensitive operations must check active membership and, where immediate revocation is required, current session validity. [Supabase sessions](https://supabase.com/docs/guides/auth/sessions).

Enable RLS on exposed domain tables and explicitly grant only necessary operations. Policies must check identity, active membership, organization, branch and relevant permission. Include both existing-row and proposed-row checks on updates. Test denied cross-organization and cross-role requests directly against APIs. RLS limits rows, not the clinical columns within a permitted patient row: separate demographics, clinical and payroll tables rather than mixing sensitive fields. [Supabase RLS](https://supabase.com/docs/guides/database/postgres/row-level-security), [column privileges](https://supabase.com/docs/guides/database/postgres/column-level-security).

Shipped web and Electron applications receive only publishable configuration and the signed-in user's session. Never ship a secret/service-role key, database password or signing credential, including in Electron's main process. Desktop packages are inspectable. Keep exceptional administrative credentials in controlled backend services with explicit authorization and rotation. [Supabase API keys](https://supabase.com/docs/guides/getting-started/api-keys).

### Media, documents and devices

Use private buckets and authorization based on the linked patient/media record, not merely who uploaded a file. Generate opaque object keys without names or phone numbers. Protect thumbnails, previews and derived exports like originals. Permit short-lived signed URLs only after access checks; URLs remain usable until expiry, so use a checked streaming endpoint if immediate revocation is mandatory. Record authorized URL issuance separately from proof of actual file retrieval. [Supabase Storage access control](https://supabase.com/docs/guides/storage/security/access-control).

Validate allowed file types, actual content, size and image dimensions. Quarantine uploads until validation/scanning finishes; show pending or rejected state explicitly. Keep originals immutable, produce safe previews, remove unnecessary location metadata from derivatives, and avoid beauty filters or undocumented edits. Use a clinic-approved image capture protocol and avoid personal cloud photo backups. File validation and malware scanning address different risks. [OWASP file upload guidance](https://cheatsheetseries.owasp.org/cheatsheets/File_Upload_Cheat_Sheet.html).

Require managed OS accounts, disk encryption, supported operating systems, screen locking and controlled exports. Minimize local caches and clear them at logout. Do not put patient content in notifications, clipboard automation, public queue displays or unprotected print folders. For Electron, use OS-protected token storage through a narrow bridge with verified behavior on each supported OS; do not assume every platform has equivalent protection.

### Audit, corrections and monitoring

Maintain append-only application audit events containing actor, organization, action, affected IDs, time, request ID, outcome and reason. Protect audit administration from ordinary application users. Record note signing/amendment, demographic edits, merge, media access authorization, exports, invoice posting, refunds, reconciliations and permission changes. Sensitive prior values belong in protected version history, rather than being copied indiscriminately into operational logs.

Database change triggers cannot capture ordinary SELECT reads. Route audited clinical reads and exports through controlled endpoints and close alternative access paths. Distinguish an audit of authorized access from a claim to record every screenshot or copied image. Export audit records to a separately controlled destination for tamper evidence; database administrators remain a privileged trust boundary.

Monitor failures, suspicious access, overdue clinical tasks, queue backlogs, backup failures, stock anomalies and accounting mismatches using IDs and redacted context. Exclude patient notes, photos, names, contact details, tokens and signed URLs from general telemetry. Disable production session replay unless a separately justified, verified privacy design exists. [OWASP logging guidance](https://cheatsheetseries.owasp.org/cheatsheets/Logging_Cheat_Sheet.html).

Signed clinical records use addenda; posted finances use reversals/credit records. Define retention by record type, legal hold and lawful deletion; soft deletion is not a complete retention policy. Restrict hard deletion and ensure authorized deletion also addresses derivatives and eventual backup expiry.

### Backup and recovery

Supabase database backups contain database data and Storage metadata, **not the uploaded objects themselves**. Plan a separate encrypted media/document backup with recoverable versions and an independently controlled copy. Retention, backup frequency and PITR availability depend on the selected plan. [Supabase database backups](https://supabase.com/docs/guides/platform/backups).

Propose, for discussion, an initial whole-system recovery-point objective of at most one hour of lost committed data and a recovery-time objective of four hours from incident declaration. These are targets requiring infrastructure, cost review and a measured drill, not vendor guarantees. Database recovery may be finer with PITR, while media replication may be the limiting factor. The clinic must explicitly accept or tighten the targets.

Restore into isolation and verify database/object consistency, photographs, signed notes, patient balances, user access and audit records. Test before launch, after material backup changes and periodically thereafter. Recovery includes keys/configuration, identity/provider dependencies, accounting handoff state and queued jobs. Reconcile external transactions before restarting workers to prevent duplicate payments/messages/postings.

Document incident ownership, contact routes, credential revocation, containment, evidence protection, patient-care downtime procedures and recovery authorization. Determine reporting duties only after jurisdiction is known.

### Jurisdiction-dependent decisions

Confirm applicable privacy/medical-record laws, hosting and transfer restrictions, controller/processor contracts, consent and guardian rules, sensitive photo handling, retention, patient access/correction, prescribing, payroll/tax/invoicing and breach notification. A technology stack does not establish HIPAA, GDPR or any other legal compliance. Professional sources from the UK, Canada and elsewhere inform workflow design without establishing local law.

## 10. Architecture proposal

### Components and boundaries

| Component | Responsibility |
| --- | --- |
| Shared frontend | Sorani/English views; forms, validation feedback, role-aware navigation, accessible interactions and presentation |
| Optional Electron shell | Approved device/printing integration, application lifecycle, protected session-storage bridge and updates |
| Supabase Auth | Staff authentication and supported MFA/session mechanisms |
| Controlled API/Edge Functions | Request validation, user-context checks, access logging, integration webhooks, credentialed administrative operations |
| Postgres | Authoritative domain records, permissions/RLS, constraints, transaction functions, versioning and financial integrity |
| Private Storage | Media/documents, quarantine and approved objects; independent backup pipeline |
| Outbox worker | Reliable retries for accounting, reminders and other external side effects |
| Accounting product | General ledger, approved payroll/statutory logic and complete financial statements |

Organize a single codebase into reception, patients, scheduling, clinical, media, finance and access modules. Use one authoritative database initially. Avoid microservices, a search cluster, event sourcing and premature multi-region architecture.

Use a dedicated exposed API schema with narrowly scoped RPCs/views; keep clinical and financial base tables in non-exposed schemas with necessary grants and RLS. Audited clinical reads go through explicit endpoints. User-context invoker functions can access these tables without exposing arbitrary table reads through the Data API. Do not rely on schema separation alone for authorization.

Prefer invoker database functions. Where a privileged helper is genuinely necessary, keep it in a non-exposed schema, constrain its owner/execute grants, pin its search path and check the caller explicitly. It is not a general workaround for failed permissions. [Supabase database functions](https://supabase.com/docs/guides/database/functions).

### Transaction and integration behavior

Invoice posting, payment allocation, refund authorization/recording and package redemption each execute as a bounded database transaction. The transaction validates permission and state, locks relevant records, applies changes, writes audit/outbox records and commits. Server code must not split these into unrelated database calls.

External processors and Postgres cannot share an ordinary transaction. Use pending/confirmed/failed states, signed webhook verification, unique provider IDs, idempotent retries and reconciliation. Do not hold database locks while waiting on a provider. An outbox records committed work before a worker attempts external delivery.

Likewise, object upload and database insertion are not atomic. Use pending upload records, quarantine, validation/finalization, safe retry and orphan cleanup. An encounter must show when expected media is still pending or failed.

For uncertain network outcomes, display “confirmation pending” and query by operation ID; never treat a timeout as proof of failure. Prevent duplicate submission server-side. Show last successful refresh and explicit unsaved states. Realtime updates may improve queues but do not replace authoritative reads or constraints.

### Branches, tenancy and growth

Begin with one organization and one branch provisionally, while including organization/branch scope now. Patients can have organization-wide identity with controlled cross-branch care; encounters, tills, stock and schedules belong to branches. Confirm sharing policy before implementation. Separate branches of one business from unrelated clinics: a multi-tenant SaaS product introduces onboarding, isolation, billing, support and residency requirements beyond this project.

Choose a suitable region after legal review and latency checks. Use connection pooling for server connections, bounded queries and scoped indexes. Assess growth using measured query plans, concurrent-user tests and media storage/egress estimates. Add capacity, read reporting models or replicas when evidence justifies them, not from an assumed patient count.

### Localization and design

Treat `ckb`/Sorani and English as first-class locales. Set semantic text direction, use logical layout properties, and isolate phone numbers, patient numbers, dates and English medical text inside RTL views. W3C recommends HTML direction markup and bidirectional isolation for mixed content. [Structural RTL guidance](https://www.w3.org/International/questions/qa-html-dir), [inline bidirectional text](https://www.w3.org/International/articles/inline-bidi-markup/).

Preserve entered patient names and original clinical text. Separate UI translation from medical content translation; do not silently machine-translate notes. Validate fonts, glyph shaping, keyboard input, search, numerals, date/calendar preference, currency and printed prescriptions/receipts with native Sorani users. Do not assume Arabic translations or typography cover Sorani correctly.

Evaluate candidate UI libraries later for RTL, accessible tables/forms/dialogs, keyboard use and printing. Use WCAG 2.2 AA as an engineering acceptance target, alongside platform review; this is not a jurisdictional compliance claim. [WCAG 2.2](https://www.w3.org/TR/WCAG22/).

### Electron, if selected

Bundle the UI locally; enable context isolation and renderer sandboxing, disable renderer Node integration, use a restrictive CSP and expose only narrow validated IPC commands. Validate IPC senders and arguments, restrict navigation/window creation and external URL schemes, and deny permissions unless required. Never pass untrusted attachments to privileged executable APIs. [Electron security checklist](https://www.electronjs.org/docs/latest/tutorial/security).

Sign supported Windows builds and sign/notarize macOS builds. Use an authenticated release process, protected signing credentials, staged updates and tested installation/recovery. Keep Chromium/Electron dependencies current, preserve backward compatibility during rollout and install updates at safe workflow points. [Electron signing](https://www.electronjs.org/docs/latest/tutorial/code-signing), [application updates](https://www.electronjs.org/docs/latest/tutorial/updates).

One current compatibility item: Supabase has announced removal of certain older TLS cipher suites from 10 November 2026 at the earliest. Validate supported operating systems/devices; do not weaken TLS validation to accommodate obsolete clients. [Supabase TLS change](https://supabase.com/changelog/cbc-tls-ciphers-deprecated).

### Environments and quality

Separate local/development, staging and production projects and credentials. Use synthetic patient data outside production. Version and review database migrations, policies, function grants and storage configuration; test rebuilding a fresh environment. Pin dependency versions, commit lockfiles and scan releases for leaked secrets.

Require direct API authorization tests, patient merge and partial-birth-date cases, concurrent payments/refunds, posting invariants, outbox replay, upload interruption, session revocation, RTL/print checks and end-to-end role workflows. Test restore and outage procedures with staff. Use relevant OWASP ASVS requirements as a verification baseline and document coverage; do not claim certification from using a checklist. [OWASP ASVS](https://asvs.owasp.org/).

## 11. Phased implementation roadmap

No time or cost estimate is justified until the open decisions and service catalog are agreed.

| Phase | Dependencies and work | Acceptance criteria |
| --- | --- | --- |
| 0. Decisions and workflow validation | Country/currency, users/branches, connectivity, treatments, devices, accounting, retention and approved consent | Owner, clinician and accountant agree scope, permissions, downtime policy and financial ownership |
| 1. Foundation and prototype | Identity, organization scope, migrations, audit, localization, selected UI library; assess Electron with actual hardware | Direct API denial tests pass; Sorani/English flows and print examples accepted; desktop choice documented |
| 2. Reception and care | Patient identity/search/merge, scheduling, walk-ins, encounters, consent, photos, prescriptions and results tasks | Staff complete realistic care scenarios; shared phones and unknown birth date work; signed records cannot be silently overwritten |
| 3. Medical/cosmetic procedure support | Approved service templates, product lots where needed, session safety fields, aftercare; packages if sold | Each offered launch treatment has a complete record; usage is traceable and entitlement cannot be redeemed twice |
| 4. Finance and accounting | Invoices, allocations, refunds, expenses, all cash movements, till close, opening balances and accounting exchange or internal ledger | Partial payment, deposit, refund, supplier, salary, owner and transfer examples reconcile; retries cannot double-post; accountant approves reports |
| 5. Production readiness and pilot | Backup/object recovery, monitoring, incident/downtime drill, permissions review and release process | Measured restore meets accepted objectives; end-to-end role workflows pass; pilot discrepancies resolved before broad rollout |
| 6. Expansion | Observed needs after stable operation | Reminders, richer inventory, automated integrations, added branches or offline work each have explicit scope and acceptance tests |

Build and test security throughout; phase 5 verifies readiness rather than introducing safeguards for the first time. A clinical-only pilot does not satisfy the original finance requirement; production scope must include the agreed financial solution.

## 12. Key risks and unresolved decisions

| Risk | Decision or mitigation |
| --- | --- |
| Unknown jurisdiction and currency | Resolve before selecting hosting region and implementing legal documents, tax or payroll behavior |
| Unreliable internet | Measure actual outages; approve downtime process or budget full offline scope before architecture commitment |
| Cosmetic scope expands late | Obtain treatment/device catalog; promote safety and traceability dependencies into launch |
| Unreviewed pathology or adverse events | Named clinical owner, due dates, escalation, coverage and audit |
| Full accounting hidden inside “expenses” | Choose external complete books or fund internal double-entry scope explicitly |
| Identity errors or unsafe merge | Two-identifier verification, candidate review, immutable IDs, controlled merge correction |
| Photos exposed through copies or signed URLs | Private storage, brief validity, protected derivatives, managed devices and documented limits |
| RLS or privileged-function mistake | Least privilege, negative API tests, protected schemas and independent review |
| Backup restores database but loses photos | Independent object backup and combined restore drill |
| Small staff approve their own transactions | Owner reviews exception reports and reconciliations; no invisible self-approval |
| Sorani layout works on screen but fails in print/search | Native-speaker acceptance across complete workflows and documents |
| Vendor dependence and operating cost | Verify plan features, storage/egress, signing and integration costs; maintain export/restore procedures |

No sources reviewed establish that this particular clinic is legally compliant. Photography consent practices vary across professional contexts; use explicit purpose recording and local professional/legal review instead of imposing another country's rules. Recognition examples are a proposed accounting basis, not a determination of the clinic's statutory reporting obligations.

## 13. Refined implementation brief

**Objective:** Build ClinicOS for reception, medical and cosmetic dermatology, and business administration, in Sorani Kurdish RTL and English. Each staff member uses an individual account. Preserve patient safety, accurate financial records and controlled access.

**Architecture:** One modular TypeScript frontend and Supabase backend. Prefer browser delivery; use the same frontend in a thin Electron shell if verified device/desktop requirements justify it. Use Postgres transactions and constraints for integrity, Auth for identity, private Storage for media, controlled APIs for audited sensitive operations, and an outbox for external effects. Final UI library remains undecided; use `apple-design` for relevant later design review.

**Launch behavior:** Patient registration/search and controlled merge; appointments/walk-ins/queue; history/allergies/encounters/prescriptions; purpose-specific consent and private clinical photos; procedure/session records; results and follow-up tasks; service pricing, invoices, partial payments, deposits if taken, refunds and receipts; all cash movements, expenses and supplier/staff/owner payments; opening balances, daily reconciliation and an accountant-approved financial handoff. Include lot/expiry/usage tracking and package entitlement only where offered services require them.

**Identity/data rules:** Immutable patient UUID plus non-reused clinic number; phone is nonunique and optional. Preserve original names and contacts. Support partial/unknown birth information and dated reported age. Compute current and historical age with appropriate uncertainty and preserve signed-record provenance. Keep clinical sex-related information distinct from administrative gender where necessary.

**Access and integrity:** Apply the matrix in section 6 through backend permissions, organization/branch policies and protected table boundaries. Administrator/owner status grants no automatic clinical access. Signed records use addenda; posted finance uses corrective records. Enforce idempotency, allocation/refund limits, optimistic draft versions and transaction-safe concurrent updates.

**Finance:** Default to ClinicOS patient subledger/cashbook plus a selected accounting product. A reconciled file exchange is acceptable initially. If all books must be inside ClinicOS, add a complete balanced ledger and accountant-approved statements before claiming that scope is complete. Do not implement statutory tax/payroll rules from assumptions.

**Verification:** Direct API permission tests, clinical/financial concurrent-write scenarios, retried operations, original/derived media protection, bilingual RTL and printing checks, reconciliation examples, full database-plus-object restore and staff pilot acceptance. No production patient data in development.

**Decisions required before dependent implementation:** Country/region; currency and any exchange; users/visits/branches; internet/offline needs; exact treatments and devices; accounting boundary; deposit/package/insurance use; retention/consent rules; print/integration requirements; recovery objectives. See section 3. No application code should start until these decisions are reflected in the agreed implementation scope.
