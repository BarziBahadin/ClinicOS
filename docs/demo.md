# Local demonstration

Open the macOS preview at `release/mac-arm64/ClinicOS.app`. The app now uses the supplied **Stormy Morning** palette: `#6A89A7`, `#BDDDFC`, `#88BDF2` and `#384959`, with readable light and dark surfaces. The desktop icon matches the sidebar stethoscope.

Existing individual development accounts are unchanged: `owner`, `doctor`, `receptionist`, `administrator` and `accountant`. Their local passwords are in ignored `.local/accounts.json`. Staff email is not required.

The added records are prefixed **DEMO**. All names, numbers, clinical notes, consent selections, prescriptions and financial activity are fictional; no calls, messages, actual treatments or external payments took place. Do not dial the demo phone numbers. The demonstration is in the existing local development clinic; existing records were preserved.

## Explore the workflows

- **Owner:** open Overview to see today's appointments, waiting patients and outstanding invoices. Open Treatments to see eight approved demo treatments and one proposal awaiting approval. Review Finance and Reports in each currency separately.
- **Receptionist:** open Appointments on **25 October 2026** to see completed visits, a walk-in in care, two checked-in patients, a scheduled visit, a cancellation and a no-show. Future bookings appear on 26 and 27 October. The phone-call list has simulated reached/unanswered outcomes and a booking blocked by missing communication consent.
- **Doctor:** open **DEMO · Ava** for a signed encounter, addendum, clinical history, fictional prescription, procedure and printable patient letter. **DEMO · Rona** and **DEMO · Shilan** have draft encounters to edit. Results & follow-up contains ordered, received, reviewed and notified examples, with overdue and future follow-ups.
- **Sample photos:** all twenty DEMO patient profiles have two private case-photo samples under **Clinical media**, visible to authorized clinical accounts such as `doctor`. They show an AI-generated cheek and forearm, each watermarked “SYNTHETIC DEMO — NOT A REAL PATIENT.” The same two examples are intentionally reused across fictional profiles. They illustrate the photo workflow and carry no diagnostic or treatment claim.
- **Billing:** twelve demo invoices include fully paid, partially paid and unpaid examples, in IQD and USD. There is a USD patient deposit, two three-session packages and four performed treatments awaiting invoicing. No combined-currency balance is invented.
- **Administrator:** Inventory contains six catalog items and six lots, including two low-stock and upcoming-expiry examples, a fictional supplier and a linked stock-use event. Existing staff-account permissions remain in place.
- **Accountant:** Finance and Reports contain posted receipts, expenses, supplier payables, opening floats and cash-to-bank transfers. Reporting reads the actual posted demo records. Bank reconciliation/import and period closing remain available for you to demonstrate interactively.

## Add or resume the demo

With the existing local stack running, use `npm run demo:seed`. The script refuses hosted targets and verifies the development organization. It writes through authenticated application operations, preserving authorization, version checks and immutable postings. Progress and original request payloads are kept in ignored `.local/demo-data.json`, so an interrupted run resumes without duplicating completed operations. Its anchor day is retained for predictable scheduling.

This command adds records; it does not reset, erase or rewrite existing data. Do not remove the manifest to attempt a reset. Use the date selector above when revisiting the demo on another day.

The sample originals are saved in `.local/demo-media/sample-cheek.png` and `.local/demo-media/sample-forearm.png`; `.local/demo-media/generation.json` records the built-in image-generation prompts and file paths. `npm run demo:photos` adds or resumes their upload to the existing DEMO profiles through the authenticated, consent-gated, scanned media service. It refuses hosted targets and does not change staff access or expose the private bucket.

Automated test suites remain deferred at the user's request. The preview is an unsigned local development artifact; signed distribution and final clinic acceptance remain separate work.
