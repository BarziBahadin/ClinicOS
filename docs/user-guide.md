# ClinicOS staff guide

English guide · [ڕێنمایی سۆرانی](user-guide.ckb.md) · [Technical operations](operations.md)

This guide describes the implemented workflows. Use synthetic records for training. The clinic must approve its treatment instructions, consent wording, opening balances and printed documents before live use.

## Sign in and manage your account

1. Obtain your **username** and **temporary password** from your clinic administrator in person. No staff email account is required.
2. Open ClinicOS and enter your username and password. Usernames use 3–32 Latin letters, numbers, dots, hyphens or underscores and start with a letter. Capitalization does not matter for usernames; it matters for passwords.
3. On first sign-in or after an administrator resets your password, change the temporary password under **Account & security**. Enter your current password, a different new password of 16–128 characters, and its confirmation. Then sign in again with the new password.
4. If the clinic requires an authenticator, open **Account & security**, enroll your authenticator and enter its six-digit code. Verification is required before protected clinic operations become available.
5. Sign out when leaving the workstation. The application also signs out after 15 minutes without keyboard or pointer activity. Reloading requires sign-in.

If you forget your password, ask your administrator for a reset. Existing sessions are denied after reset. There are no email invitations or email recovery links. Keep your own account; do not share credentials.

| Role | Main work |
| --- | --- |
| Receptionist | Patient demographics/contacts, appointments, treatment proposals, invoices, receipts, deposits and contact logging |
| Doctor | Authorized clinical records, prescriptions, procedures, consent, results, private media and care-record exports |
| Administrator | Reception/operational work, inventory and permitted staff-account management |
| Owner | Business oversight, configuration, privileged staff management, approvals, access policies and financial controls |
| Accountant | Authorized financial records, reconciliation, journals, mappings and accounting exports |

Business roles receive no automatic access to clinical records or photographs. The owner can authorize additional roles explicitly and document the reason. If assigned-care access is enabled, staff must assign the responsible clinician to each patient.

## Reception: start and manage a visit

Use the toolbar's sidebar button to show or hide navigation. Your account and sign-out remain in the toolbar. Within a patient profile, choose **Clinical records**, **Clinical history**, **Documents & consent**, **Clinical media**, **Contacts**, or **Care team & access** as available to your role. Billing and Finance also have section buttons above their records. In **Team & access**, expand **Manage account** beside a member to see your authorized actions.

1. Open **Patients** and search by name, clinic number or phone. Shared family phone numbers are allowed. Confirm the patient's name and clinic number before opening a record.
2. If needed, choose **New patient**. Enter the name as provided. A phone is optional. Select exact date, month/year, year only or unknown birth information; enter only what is known. Reported age is entered in years.
3. Use **Edit profile** for demographic corrections. Use **Contacts** to add additional numbers, identify the contact's owner/relationship and retain historical contacts. **End contact** retires an old number without erasing its history.
4. Choose **New appointment**, select the patient and clinician, and enter the start/end in Baghdad time. Select a room/device when required. Record a walk-in when there was no advance booking.
5. Move the visit through **Check in → Start care → Complete**. Record a reason for cancellation, no-show or rescheduling. The backend checks conflicting clinician/resource reservations and configured availability/leave.
6. Under **Treatments**, add treatment names and Sorani names to the clinic's list. A proposal is a draft until an authorized price approver activates it. Draft treatments cannot be billed.
7. Record calls and other attempts under **Contact log**. Choose the channel and actual outcome; writing a log does not send an SMS or WhatsApp message.

**Clinician availability** records working windows and leave. When working windows have been configured, new bookings must fit one. Review existing appointments before recording leave.

## Staff phone-call reminders

1. Open **Appointments → Staff phone-call reminders**. The default range is today through the next seven days, in Baghdad time. Choose a range of up to 32 calendar days and select **Load call list**.
2. Review the patient's name/clinic number, appointment, contact owner and current communication consent. If needed, record the actual communication consent or add a current phone contact. Clinical consent is separate.
3. Call the displayed number yourself. The application sends no messages and makes no phone call.
4. Choose **Record reminder call** and record the actual outcome and notes. Unanswered calls stay in the open list. Reached or declined calls are hidden unless **Include contacted appointments** is selected.
5. A changed appointment/contact or withdrawn consent requires a refresh before another linked reminder is recorded. Call logs remain immutable; this does not cancel or change the appointment. Handle a requested schedule change through the appointment workflow.

## Doctor: clinical records, prescriptions and procedures

1. Confirm the patient using two identifiers. Open the patient's **Clinical records**. If access is restricted to an assigned care team, ask the authorized administrator to review the assignment.
2. Choose **New encounter** or start from an approved clinical template under **Treatments → Document templates**. Record the complaint, history, allergy review, findings, diagnosis, plan and relevant clinical information.
3. Use **Longitudinal clinical history** for allergies, problems, medicines and history that should remain visible across visits. Amend an item through a new entry; the earlier event remains preserved.
4. Add structured prescription items to your own draft encounter. Enter medicine, strength, dose, route, frequency, duration, quantity and instructions as applicable. Review the complete prescription before signing.
5. Choose **Sign encounter** only after reviewing allergies, diagnosis and plan. Signed content and its prescription items cannot be overwritten. Correct it with an **Addendum**.
6. Use **Print prescription** on a signed encounter for a dedicated prescription document.
7. Record a procedure against the correct patient and encounter. Enter the actual body site, product/lot, device settings, quantity, aftercare and adverse events relevant to the clinic's approved treatment protocol.
8. Record a **Performed treatment** after the encounter is signed. Reception can turn it into an invoice once; the clinical record remains preserved.
9. Use **Results & follow-up** to record orders and move results through receipt, review, notification and closure. Document the review and actual patient communication, and complete assigned follow-up tasks.

The application records the clinician's prescribing decisions; it does not choose medicines or calculate a clinical dose.

## Templates, consent and patient documents

- Under **Treatments → Document templates**, clinicians create a named, numbered English or Sorani version and review it before approval. Approved versions are immutable; revisions use a new version.
- Choose **Use template** to start the appropriate clinical, procedure, consent or patient-document workflow. Review patient-specific details before signing.
- Record the consent purpose, grant/withdrawal and actual discussion/evidence. Administrative staff can record communication consent; clinical purposes require clinical permission. A template version is preserved with the event when selected.
- Use **Signed patient documents** for referrals, aftercare and care letters. **Add corrected document** creates a new signed document linked to the original.
- Print the selected prescription, aftercare, consent or patient document. Confirm the patient, language, printer and paper size in print preview before sending it to a printer.

## Clinical photographs and documents

1. Record current photography consent for the patient.
2. Open **Clinical media → Upload document / photo**. Select the patient, current consent, title, body site and original file. Supported files are static JPEG, PNG, WebP and PDF, up to 10 MB.
3. **Pending** means the upload has not completed safely. Retry with the same file and metadata, or cancel your pending upload with a reason. A **Rejected** upload is not available for viewing.
4. Images must pass file validation, malware scanning and decoding. The viewer uses a resized PNG preview with metadata removed. **View original** opens the separately preserved original bytes. Old images can use **Generate preview**.
5. Compare images only within the same patient's record. Switching patients clears the viewer and ignores earlier responses.
6. Consent withdrawal prevents new authorized access. Do not distribute clinical files through personal accounts or general messaging tools.

**Export clinical record** requires clinical export permission, the correct care scope and a documented purpose. The JSON export contains clinical text, prescriptions, results and document metadata. Original photographs are accessed separately through the clinical media viewer. Store authorized exports only in the clinic's approved destination.

## Reception: billing and payments

1. Choose the patient and approved service lines. Enter quantities; the backend calculates prices and totals.
2. Use **Record payment** for full or partial settlement. Select the currency actually received and the payment method. If payment and invoice currencies differ, enter the historical **IQD per USD** rate used for that receipt.
3. Print the invoice and receipt after confirming the saved records. IQD and USD remain separate; do not add the balances together.
4. Record money received before treatment as a **Patient deposit**. Use **Apply deposit** to allocate it to an invoice in the same currency.
5. Discounts, credit notes, refunds and adjustments require the relevant approval. Never edit an issued invoice or erase a payment. Refunds preserve the original tender and recorded allocation/rate.
6. Sell packages with the agreed number of sessions. Redeem a session only against a signed encounter for that patient. Cancel/refund unused sessions or change expiry through the authorized corrective workflows; cancelled/expired packages cannot be redeemed.
7. After an interrupted submission, retry the unchanged form to check the same request. Review the saved result before starting a separate operation.

## Finance: close, report and reconcile

- Record expenses and whether they are paid now or payable later. Use **Settle payable** for an unpaid bill. Salaries require payroll permission.
- Keep owner contributions, withdrawals, loans and transfers distinct from service revenue and operating expenses. Use the appropriate **Cash movement** or **Exchange currency** operation.
- Open the till with its actual float. Close it with the physically counted cash and a reason for any difference. Review differences with the authorized approver.
- Use **Operational financial reports** for receivables/aging, patient statements, collections/refunds, deposit/package liabilities, payables, cash/bank movements and till variances. Choose the dates carefully. Totals cover the complete matching set; detail rows are paginated. Each currency has its own total.
- Reports retain the first request's cutoff while paging; run the report again to include new postings. A patient statement includes opening and closing invoiced balances. Its invoiced balance and prepayments are separate concepts. Review deposits/packages separately before applying them to invoices.

### Bank and card reconciliation

1. Open **Accounting → Bank/card reconciliation** and download the CSV template.
2. Use the template headings: `Date, Account, Currency, Amount, Reference, Statement ID`. Dates use `YYYY-MM-DD`; account is `bank` or `card`; currency is `IQD` or `USD`. Use signed decimal amounts and a stable identifier from the statement. Import at most 1,000 lines / 180 KB at a time.
3. Importing a statement does not create cash movements. Match each line to an existing posting with the same account, currency and amount.
4. Record fees or genuine missing transactions separately through the appropriate authorized financial workflow, then match their postings.
5. Correct a mistaken match with **Reverse match** and documented authorization. The original matching event remains in history.

### Accounting handoff and period close

1. Obtain external account codes from the accountant. Create and approve a named **Account mapping** version.
2. From the approved version, create an **Accounting batch** for the date range. A posting can belong to only one batch.
3. Download the batch CSV. Confirm source IDs, record counts and balanced totals in each original currency before importing it into the accounting system.
4. Record the external system reference through **Acknowledge** after reconciliation. A repeated download is the same batch, not permission to repost it.
5. Close an accounting period only after reconciliation. New postings into closed dates are rejected. Correct through an authorized **Dated accounting adjustment** in an open period.

Statutory statements, payroll/tax calculations and accounting recognition require the clinic's accountant-approved process.

## Inventory

Add products with their unit, reorder level and preferred supplier under **Product catalog**. Maintain supplier contact details under **Suppliers**. **Stock alerts** shows expired/expiring lots and reorder needs from all usable stock. Record the correct product, lot, expiry, unit and quantity when receiving stock. Use **Use stock** for actual encounter consumption. Record a physical count or waste under **Count / adjust stock**, with a reason; a stale count is rejected so another user's work is not overwritten. Keep expired stock out of clinical use. The clinic must define its stock units, reorder thresholds and purchasing/accounting policy.

## Owner and administrator

- Under **Team & access**, create individual usernames and temporary passwords, change permitted roles/active status and reset permitted accounts. The owner controls privileged business accounts, additional roles and approval limits.
- Set approval limits separately for IQD and USD. An additional role is an explicit grant, not a change to a person's identity. Review it when duties change and deactivate departing staff.
- Under **Settings**, choose organization-wide clinical sharing or assigned-care access. Assign clinicians before enabling assigned care. Administrative access never automatically grants clinical access.
- Under **Retention & holds**, record the clinic-approved policy reference and retention period, approve the policy and record/release legal holds with evidence. Approval records policy; automatic deletion remains disabled until an approved deletion and backup-expiry procedure is configured.
- Review monitoring, backup/recovery results and audit exports with the system operator. Production setup and signed desktop distribution are described in the operations guide.

## When something fails

- **Password forgotten:** ask the administrator for a temporary-password reset, then change it and sign in again.
- **MFA required:** verify the authenticator under Account & security.
- **Patient access denied:** confirm the account/role and care assignment; do not use another person's login.
- **Record changed:** refresh, compare the other edit and submit the intended correction again.
- **Network interrupted:** keep the form and retry the same request; confirm the saved record before making a new one.
- **Upload pending:** retry the same original file. Scanner/processor outages must be restored before the upload can complete.
- **Invoice or journal needs correction:** use a credit, refund, addendum or authorized journal; preserve the original event.
