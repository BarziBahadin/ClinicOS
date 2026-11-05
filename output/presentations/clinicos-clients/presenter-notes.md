# ClinicOS client presentation

A concise sales presentation for clinic owners and prospective clients. Prepared 5 November 2026.

## 1. ClinicOS

ClinicOS brings patient care and the daily business of a dermatology clinic into one workspace. This introduction focuses on how the clinic team can use connected records, clear responsibilities and local language and currency support.
Present the product as a demonstration of implemented workflows. Discuss clinic-specific deployment and acceptance before making a live-use commitment.

Sources: README.md; docs/operations.md

## 2. A clinic day depends on clear handoffs

A clinic day involves many handoffs. Reception needs accurate identity and scheduling information, clinicians need patient context, and management needs clear financial records.
ClinicOS provides connected workflows for these needs. Describe the intended value as easier coordination rather than a measured time-saving or revenue claim.

Sources: docs/user-guide.md, reception, clinical, billing and finance workflows; README.md

## 3. One patient journey connects the team

Follow a single fictional patient through a typical visit. Reception finds or registers the patient and prepares the appointment. The clinician records and reviews the visit, and reception handles invoicing and payment.
This is an example of a typical workflow, not a claim that every clinic must perform each action in this exact order. Follow-up work continues after the visit.

Sources: docs/user-guide.md, Reception: start and manage a visit; Doctor: clinical records; Reception: billing and payments

## 4. Patient context at the next visit

The patient profile provides a place for visits, ongoing history, care documents, reports and photographs. The clinical team can return to the patient record when preparing for the next visit.
The screen shows a fictional patient in the Sorani interface. Scanned paper reports must first be saved as PDFs using the computer scanner software, then uploaded. Existing clinical media consent and file scanning checks apply.

Sources: src/App.tsx, patient profile sections; src/features/media.tsx; docs/user-guide.md, Clinical photographs and documents. Image: local ClinicOS synthetic demonstration screenshot captured 4 November 2026.

## 5. Reports and photos stay with the patient

Clinical files remain linked to the patient rather than becoming loose files on a shared desktop. Staff can give a PDF a useful name and browse photographs in a thumbnail gallery with a larger viewer.
Files use private authorized access. Images and PDFs pass the existing scanning workflow. The displayed image is AI-generated synthetic demo content, not a real patient case or a treatment outcome claim. The PDF upload limit is 10 MB.

Sources: src/features/media.tsx; docs/user-guide.md, Clinical photographs and documents; docs/operations.md, Private image processing. Image: local synthetic ClinicOS gallery screenshot captured 4 November 2026.

## 6. A clearer view of clinic finances

ClinicOS supports the payment patterns the intended clinic context requires, including IQD, USD, partial payments, deposits, packages and refunds. Separate currency totals make each balance easier to interpret.
When a receipt crosses currencies, the operator records the historical IQD-per-USD rate. Never imply the system adds IQD and USD without a defined conversion. The finance features provide operational bookkeeping and exports, not certified statutory statements or automatic tax and payroll calculations.

Sources: docs/user-guide.md, Reception: billing and payments; Finance: close, report and reconcile; docs/operations.md, Scope and financial boundaries

## 7. Daily follow-through beyond the consultation

The clinic also needs visibility into what happens outside the consultation. Results and follow-up tasks support clinical continuity. Inventory records lots, expiry and use. Management can review receivables, expenses, cash movements and till differences.
Patient notification and reminder-call outcomes are recorded by staff. The current app does not send automatic SMS, WhatsApp or email messages. Stock alerts are operational tools, and the clinic still defines its purchasing and stock-unit policies.

Sources: docs/user-guide.md, Results & follow-up, Inventory, Finance and Accounting; docs/development-status.md, stock management and reminders

## 8. Clear responsibility for each staff member

Separate staff identities support clear responsibility. Clinical access follows permissions and can also follow assigned care teams. Business administration does not automatically include access to clinical records or photographs.
Signed clinical records and posted financial events preserve the original, using addenda, credits, refunds or authorized corrections. Do not describe these controls as a legal-compliance certification or a guarantee that every operational risk disappears.

Sources: AGENTS.md; docs/user-guide.md, Owner and administrator; docs/operations.md, Credentials and identity; README.md

## 9. Built around the clinic's local working context

ClinicOS is designed for the intended Iraqi dermatology-clinic context, with English and Sorani Kurdish, right-to-left layouts, Baghdad time and IQD/USD workflows. These details are part of everyday staff use, rather than an optional translation layer.
Native Sorani users and clinic staff still need to validate terminology and documents during acceptance. The current scope is one clinic organization and its initial branch, not a completed multi-branch operating system.

Sources: README.md; docs/operations.md, Scope and production activation requirements; src/lib/i18n.ts

## 10. A clinic pilot makes the fit clear

Close by proposing a practical evaluation using a fictional case. Discuss the clinic workflow, staff roles, patient records, report/gallery use and billing, then agree what the clinic needs for setup and acceptance.
The demonstration is not a production activation claim. Before live use, agree hosting, private media processing, independent recovery, access configuration, clinical/accounting approval and accepted devices and desktop distribution. Pricing, service commitments and onboarding terms must come from the clinic-specific proposal. No price or guaranteed business outcome is supplied here.

Sources: docs/operations.md, Production activation requirements and current verification limits; docs/development-status.md, Decisions/configuration still needed
