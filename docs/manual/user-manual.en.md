# ClinicOS complete user manual

## 01 Sign in and find your way

Use your own staff account. The administrator creates usernames and temporary passwords; staff email is not needed.
## Sign in and secure your account
1. Open ClinicOS. Enter your username and password and select Sign in. Username capitalization does not matter; password capitalization does.
2. If asked to change a temporary password, open Account & security. Enter the current password, a different new password of 16–128 characters, and the same new password again. Select Update password, then sign in again.
3. For authenticator verification, open your account from the toolbar. Select Enroll authenticator. Scan the displayed QR code with your authenticator app, enter its six-digit code, and select Verify. For an existing authenticator, use its current code.
4. If you forget your password or lose the authenticator, contact the administrator. Password recovery is through the administrator, not email.
## Navigate the workspace
1. Use the toolbar language button to switch between English and Sorani. Sorani uses right-to-left navigation. Patient numbers, usernames and currency codes keep their own reading direction.
2. Use the sidebar button to show or hide navigation. Select a workspace such as Patients, Appointments or Billing. Only authorized workspaces appear.
3. Use the section buttons inside a patient profile, Billing or Finance. Use search and Previous or Next to find older records; a visible page is not the full history.
4. Select Refresh when you need current saved records. Confirm unsaved work before leaving a form. Select Sign out when leaving the workstation.
The app signs out after 15 minutes without keyboard or pointer activity. Reloading requires sign-in. Unsaved form entries are not a saved clinical or financial record.

## 02 Roles and the daily workflow

Your available buttons depend on your role, additional grants and approval limits. A hidden or denied action should be referred to the authorized person.
## Who does what
- Receptionist: register patients, maintain contacts, book and check in visits, propose treatments, handle authorized billing, deposits and reminder calls.
- Doctor: review authorized patient records, write and sign encounters, prescribe, record procedures and consent, review results and view private photographs.
- Administrator: manage permitted staff accounts, reception operations, inventory and other assigned administrative work.
- Owner: oversee the business, clinic configuration, privileged staff accounts, access policies and financial approvals.
- Accountant: review authorized finances, journals, reconciliation, account mappings, accounting batches and period controls.
Business authority does not automatically give access to clinical notes or photographs. An owner account may correctly be unable to open a clinical photo. Use a clinical account with the appropriate patient scope.
## A normal visit from arrival to completion
1. Reception searches for an existing patient before creating a new profile. Confirm name and clinic number.
2. Book the correct clinician and time, or record a walk-in. Check the patient in on arrival.
3. The clinician starts care, reviews history and consent, saves the encounter, records relevant prescriptions or procedures, and signs after review.
4. Record performed treatments against signed care evidence. Reception opens Billing → Performed treatments and invoices the correct entry once.
5. Record payment or apply an eligible deposit. Print the saved invoice and receipt. Create follow-up work where required.
6. Complete the appointment after care is finished. At day end, count cash, close tills, review outstanding work and sign out.
## Before each submission
Confirm patient, date, currency and amount. Read any confirmation and wait for the saved result. A clinical signature, receipt or posted journal preserves the original event; later corrections follow their own workflow.

## 03 Patients profiles and contacts

## Find or register a patient
1. Open Patients. Search by name, clinic number or phone, and use the page controls for further matches. Shared family phone numbers are allowed, so a phone match alone does not prove identity.
2. Open the correct record and confirm two identifiers. If there is no matching person, select New patient.
3. Enter the full name, optional phone and contact owner. Choose birth precision: exact date, month and year, year only, or unknown. Enter YYYY-MM-DD, YYYY-MM or YYYY to match. Do not invent a birth date. Reported age, where used, is in years.
4. Select the recorded gender and preferred language. Add guardian name and relationship when relevant. Record communication consent only after the actual discussion.
5. Save and confirm the new clinic number. Use Edit profile for later demographic corrections; historical signed records retain their earlier identity snapshot.
## Keep contacts current
1. Open the patient's Contacts section and choose Add contact. Enter the number, its owner and relationship; mark preferred or verified only when appropriate.
2. Review which number belongs to the patient and which belongs to a relative. Use the preferred current contact for authorized communication.
3. Use End contact with a reason when a number is no longer current. Its history remains preserved.
4. Under Contact log, choose Record contact. Enter channel, actual outcome and notes. A saved log records work already done; it does not send a message.
## Resolve a duplicate profile
An authorized user can select Merge patient profiles. Review both identities, choose the surviving patient and record the reason. Confirm only after checking the records belong to the same person. Do not merge people merely because they share a telephone number. Ask the authorized administrator to review uncertainty before submission.

## 04 Appointments rooms and clinician availability

All appointment times use Baghdad time. Check the selected day before booking or changing a visit.
## Book and manage a visit
1. Open Appointments and choose the day. Select New appointment, or start from the patient's profile.
2. Select the patient and clinician. Enter start and end times. Select the room or device when the visit requires one. Mark Walk-in for an unplanned arrival.
3. Save and confirm the visit appears on the intended day. Conflicting clinician or resource reservations are rejected; choose another time or resource.
4. On arrival select Check in. When care begins, select Start care. Select Complete after the visit finishes.
5. For a schedule change, select Reschedule appointment, enter the new time/resource and reason, then save. Review the new appointment rather than creating a duplicate.
6. Use Cancel or No-show with the actual reason. Do not mark a cancelled visit as completed to remove it from the queue.
## Configure working time and resources
1. Under Appointments choose Clinician availability. Select the clinician, status available or leave, start, end and description.
2. If working windows have been configured, new appointments must fit a valid window and must not conflict with leave. Review existing bookings before adding leave.
3. To retire a window, use End availability window with a reason. Retain its history.
4. An authorized settings user can select Add room or device, enter its name and choose room or device. Use that resource on later bookings.
Expected result: the schedule shows the correct patient, clinician, Baghdad time, resource and current visit state. If another user changed the booking, refresh and review the latest version before submitting again.

## 05 Staff phone call reminders

ClinicOS supplies a staff call list. Staff make the calls themselves; saving a reminder does not dial a number or send SMS, WhatsApp or email.
## Load and work through the call list
1. Open Appointments → Staff phone-call reminders.
2. Choose the date range and select Load call list. The initial range is today through the next seven days. A request may cover up to 32 calendar days.
3. Check the appointment time, patient name and clinic number. Read the contact owner/relationship and current communication-consent status before using the displayed number.
4. If a current phone or permission is missing, correct the contact record or record the actual consent discussion first. Refresh the call list. Do not invent consent to make an entry callable.
5. Call the patient or authorized contact outside the app. In the demo, never dial fictional numbers.
6. Select Record reminder call. Choose the actual outcome and enter useful factual notes, then save.
7. Work through further pages. Unanswered calls remain open. Reached or declined calls leave the open list; select Include contacted appointments to review them.
## Changed appointments and requests
Refresh after a change to the appointment, contact or consent. A moved appointment needs a current reminder for the new booking details; earlier call history remains preserved.
If the patient requests a cancellation or new time, use the appointment's Cancel or Reschedule action separately. A call outcome alone does not change an appointment. Record contact attempts honestly and keep unnecessary clinical details out of reminder notes.
Expected result: the call outcome is saved against the intended appointment and current contact. Review the saved entry before making a second submission after an interruption.

## 06 Treatment list and document templates

## Add a treatment to the clinic list
1. Open Treatments and select Add treatment. Reception or the secretary can extend this list.
2. Enter the treatment name, Sorani name when available, medical or cosmetic category, duration in minutes and currency. Save the proposal.
3. A proposed treatment remains Draft. An authorized price approver selects Approve price, enters the approved price and currency, and saves.
4. Confirm the treatment is Approved before using it on an invoice. A draft is not a billable treatment. Have the clinic's authorized approver correct price or catalog issues through the permitted settings workflow.
## Create and use a versioned template
1. Open Treatments → Document templates. A clinician selects New template version.
2. Choose the type: clinical, procedure, consent, aftercare or referral. Enter a clear title, English or Sorani, version number and the clinic-approved content. Save the draft.
3. Review the complete wording and language. The authorized clinician selects Approve template after review. Do not use demo instructions for real patient care.
4. Select Use template on an approved version. Choose the correct patient and complete the patient-specific fields in the resulting encounter, procedure, consent or patient-document workflow.
5. Read the completed content before saving or signing. A template is starting content, not evidence that an examination, discussion or treatment occurred.
6. Use Print on the approved template if a blank reference copy is needed. For a patient's actual document, print the completed patient-specific record.
Approved template versions cannot be edited. Create a new numbered version for changed wording. Previously signed records preserve the version used at that time. Real treatment protocols, prices and wording require the clinic's own approval.

## 07 Clinical encounters and lasting patient history

## Review and document a visit
1. Open Patients, confirm the correct name and clinic number, then select Clinical records. The separate Clinical records workspace also opens authorized records.
2. Review prior signed encounters and Clinical history, including allergies and medicines. If assigned-care access blocks the record, ask the authorized administrator to check the care team.
3. Select New encounter, or use an approved clinical template. Enter the chief complaint, history, allergy review, findings, diagnosis, treatment plan, prescription text where relevant, and relevant clinical sex information.
4. Save the draft. Reopen your own draft using Clinical note to continue or correct it. Confirm the saved content rather than assuming typing saved it.
5. Add structured prescription items before signing. Review the entire encounter, the patient identity, allergy review, diagnosis and plan.
6. Select Sign encounter only when the record is complete and accurate. Signing preserves the record and its prescription items; they cannot be overwritten afterward.
7. For a later correction or additional information, choose Add addendum on the signed encounter. State the correction and reason clearly; do not attempt to replace the original text.
## Maintain longitudinal clinical facts
1. Open the patient's Clinical history section and select Record clinical fact.
2. Choose the appropriate kind: allergy, problem, medication or history. Enter the Content and select active, resolved or entered in error as appropriate.
3. Save and verify it appears in the patient's lasting history. A fact is separate from a single visit's narrative.
4. Use Amend clinical fact for an update or correction. Preserve the earlier event and explain the change.
Clinical records belong to the selected patient and authenticated session. Recheck the patient banner whenever moving between profiles. The application records clinical decisions; the clinician remains responsible for the accuracy of care documentation.

## 08 Prescriptions procedures and performed treatments

## Add and print a prescription
1. In the correct patient's Clinical history section, find Prescriptions and performed treatments. Select Add prescription item.
2. Select your own draft encounter. Enter medicine, strength, dose, route, frequency, duration, quantity and patient instructions as applicable.
3. Save each item and review the complete prescription with the allergy history. The system does not select a medicine or recommend a dose.
4. Sign the encounter in Clinical records after review. Return to Clinical history, select Print prescription for the signed encounter, and check the patient, language and printer preview.
## Record a procedure and aftercare
1. Select Record procedure from the patient profile, or start with an approved procedure template.
2. Choose the correct patient and encounter. Enter procedure name and body site, product and lot, device/settings, quantity, aftercare and any adverse event relevant to the actual procedure.
3. Review and save. Check Procedure and aftercare documents for the saved entry, and print the appropriate aftercare copy if needed.
4. Record actual stock consumption separately through Inventory → Use stock, linking it to the correct encounter. A procedure description is not a stock movement.
## Hand completed treatment to reception
1. After signing the encounter, select Record performed treatment in Prescriptions and performed treatments.
2. Select the signed encounter, approved service and quantity. Save and verify the treatment appears in the handoff list.
3. Reception opens Billing → Performed treatments and selects Invoice performed treatment. Review the patient, evidence, service and quantity before confirming.
4. Verify the resulting invoice. Each performed-treatment entry can be invoiced once. Payment collection remains a separate step.
Expected result: the clinical record, prescription, procedure and billing evidence refer to the same patient. A charge does not establish that care occurred; record the actual performed care first.

## 09 Consent signed letters and patient copies

Consent is purpose-specific. Care photography, procedure, teaching, publication, marketing and communication are separate choices. One purpose does not authorize another.
## Record a grant or withdrawal
1. Confirm the patient and open Documents & consent, or select Record consent from the profile.
2. Choose the actual purpose. Use an approved consent template when available and preserve its version.
3. Record whether consent is granted or withdrawn and the actual evidence/discussion. Review the purpose, version and patient before saving.
4. Check Consent history to confirm the event appears. Use a new consent event for a later change; keep the earlier discussion in history.
5. Print the patient-specific consent copy when required. Clinical purposes need clinical permission; authorized administrative staff may record communication consent.
Withdrawing photography consent prevents new authorized media access. Clinical record retention is a separate policy; withdrawing consent is not a command to erase the record.
## Create a signed letter or referral
1. In Documents & consent, under Signed patient documents choose New patient letter. Alternatively, start from an approved aftercare/referral template in Treatments.
2. Confirm the patient and document purpose, enter the title and complete content, and review patient-specific details and language. The direct letter action uses the open patient; a template asks you to select the patient.
3. Sign only after the author has reviewed the finished document. Confirm it appears in Signed patient documents.
4. Use Print for the appropriate patient copy. Check the recipient, patient, date, language, page size and printer in preview.
5. For an error in a signed letter, select Add corrected document. Sign the corrected content linked to the original; the earlier signed document remains preserved.
Store and hand over copies through the clinic's approved process. A printed blank template does not substitute for a completed patient-specific consent or signed letter.

## 10 View upload and compare clinical photographs

Use a doctor account with clinical-media permission and the correct patient access. Owner or other business access alone does not open photographs.
## View an existing photo
1. Open Patients and select the correct patient. Choose Clinical media inside the profile. You can also use the Clinical media workspace and its patient selection.
2. Find a Ready photo card using search and page controls. Select the card to open its preview. The loaded image scrolls into view below the section navigation.
3. Select another image for the same patient to compare the available views. Check titles, body sites and dates. Do not treat demo images as real before-and-after evidence.
4. Choose View original when the preserved source file is required. A PDF opens through the viewer's PDF link. If an older image has no preview, use Generate preview.
5. Switching patient or session clears the viewer. Reopen the desired record rather than expecting the earlier photo to remain visible.
## Upload a new file
1. Record current care-photography consent for the correct patient.
2. Choose Upload document / photo. Confirm the patient, enter a descriptive title and body site, choose current photography consent, and select the original file.
3. Supported files are static JPEG, PNG, WebP and PDF, up to 10 MB. Select Save and wait for the result.
4. Pending is not ready to view. Files must pass format checks, malware scanning and processing. Ready images have resized PNG previews with metadata removed; originals are preserved separately.
5. If interrupted, choose Retry upload and use the same original file and metadata. Use Cancel upload with a reason for an abandoned pending upload. Rejected files cannot be viewed.
If no photo opens, check status, current consent and care access, then refresh. A scanner or processor outage needs the system operator. Do not bypass scanning or share private links through personal messaging accounts.

## 11 Results and follow up tasks

Use Results & follow-up for the work that remains after an order or visit. A status records an actual step; it should not be advanced simply to clear a list.
## Track an ordered result
1. Open Results & follow-up and choose New result order.
2. Select the patient. Enter the order name, body site, specimen reference and due date. Confirm specimen and patient identity, then save.
3. Find the order using the list search or page controls. Check its due date and current status.
4. When the result actually arrives, select Record next step and document the result/evidence. The order moves from Ordered to Received.
5. After clinical review, record the next step with the actual review findings. The status becomes Reviewed.
6. After communicating with the patient or authorized contact, record the notification evidence. The status becomes Notified. Advancing this step does not send a message or make a call.
7. Close only after the required review, communication and resulting actions are complete. The sequence is Ordered, Received, Reviewed, Notified, Closed.
## Assign and complete follow-up work
1. Choose New follow-up. Select the patient, enter a clear task title and due date, and assign an active clinician.
2. Save and confirm the task appears under Follow-up. Check overdue and due work at the start and end of the day.
3. Open the appropriate patient record and complete the actual clinical or communication work. Record supporting care or contact evidence in its relevant workflow.
4. Select Complete on the task only when the work is finished. Confirm the completed state.
Expected result: staff can identify who owns the next action, when it is due and which steps have already occurred. Follow the clinic's escalation process for an urgent result; the application is not a substitute for timely clinical communication.

## 12 Invoices payments and receipts

## Issue an invoice
1. Confirm the patient and open New invoice from the available billing action. For documented performed care, prefer Billing → Performed treatments → Invoice performed treatment.
2. Select approved treatment lines and quantities. Check each service's currency and the invoice currency. The server calculates prices and totals.
3. If a discount is appropriate, enter the amount and reason. Obtain the required approval; staff approval limits apply separately to each currency.
4. Review the patient, services, quantities, discount, currency and final amount. Save and verify the invoice number and outstanding balance in Billing → Invoice.
5. Select Print on the saved invoice. Check the patient and clinic details in print preview before printing.
## Collect full or partial payment
1. On the correct outstanding invoice, choose Record payment.
2. Enter the amount actually received and the payment method, such as cash, bank or card. Confirm the received currency.
3. If cross-currency settlement is enabled and the received currency differs from the invoice, enter the actual historical rate in IQD per USD. Example: an illustrative USD 100 balance paid in IQD at 1,500 IQD per USD requires IQD 150,000. This is an example, not a current market rate.
4. Review both the money received and the amount applied to the invoice. Save once and check the new outstanding balance.
5. Open Billing → Payments, locate the receipt and select Receipt to print. The saved record preserves original tender and any exchange rate.
Use only actual receipts; recording a bank/card method does not itself transfer or charge money. Partial payments leave the remaining balance open. IQD and USD totals stay separate. After an interruption, review the invoice/payment list and retry the same unchanged form before starting a new operation.

## 13 Deposits packages credits and refunds

## Receive and apply a patient deposit
1. Open Billing and select Patient deposit. Select the patient, amount, currency and actual payment method. Save and verify the receipt.
2. When an invoice is issued, select Apply deposit on that invoice. Enter the amount to allocate. Deposit and invoice must belong to the same patient and use the same currency.
3. Confirm the reduced invoice balance and remaining deposit. A deposit is prepayment; it is not automatically an invoice payment until allocated.
## Sell and redeem a package
1. Select Sell package. Enter the patient, package name, number of sessions, total price, currency and actual payment method. Review and save.
2. In Treatment packages, confirm the total and remaining sessions. After care has been signed, select Redeem session and choose that patient's signed encounter.
3. Save and confirm the remaining count decreased once. Expired, cancelled or exhausted packages cannot be redeemed.
4. An authorized approver can select Set package expiry with a date and reason, or Cancel and refund unused sessions with a reason. Review the unused-value correction. Previously used sessions remain recorded.
## Correct money records
1. For an invoice reduction, an authorized approver uses Credit note on the invoice, with amount and reason, subject to the available correctable balance.
2. For money to return, open Payments, locate the original payment/deposit and choose Refund. Enter the amount and reason, and obtain required approval.
3. Review the saved correction and receipt/balance. Refunds preserve proven original tender and the original allocation/rate. A credit and a refund are different events; review both the invoice balance and money actually returned.
Never erase an issued invoice or original payment. If the required tender evidence is unavailable, ask the accountant for a reviewed correction. Do not invent a replacement receipt or exchange rate to force a refund.

## 14 Expenses cash movements and tills

## Expenses and supplier payables
1. Open Finance and select Record expense. Enter supplier/payee, category, description, amount, currency and payment method as required.
2. Mark Paid now only if money has actually been paid. Otherwise save it as payable. Salaries require payroll permission; do not expose restricted salary details to other roles.
3. Under Expenses, find an unpaid entry and select Settle payable when payment actually occurs. Choose the correct method, save and confirm its paid status. Do not create a second expense to settle the first one.
## Owner money transfers and currency exchange
1. An authorized approver selects Cash movement. Choose owner contribution, owner withdrawal, owner loan, transfer or opening balance.
2. Enter currency, amount, source/payment method, destination when required, and a clear description. Confirm the actual movement before saving.
3. For a currency conversion use Exchange currency. Enter source currency and amount, destination currency, actual rate, method and description. Keep both currency effects distinct.
4. Use Accounting adjustment only with the authorized accountant's debit, credit, currency, amount and explanation. Do not classify owner funding as treatment revenue or use a journal to conceal an incorrect receipt.
## Open and close a till
1. Select Open till. Choose the currency and actual opening float. Verify the saved till session.
2. Record the day's receipts, refunds and movements through their proper workflows.
3. At close, select Finance → Till sessions and locate the correct open session. Physically count that currency's cash.
4. Select Close till, enter Counted cash and explain any difference. Save and review expected, counted and variance with the authorized reviewer.
Each currency has its own cash count. An app entry records a real-world financial event; it does not make the payment or physical transfer itself.

## 15 Inventory suppliers and stock control

## Set up products and suppliers
1. Open Inventory and expand Suppliers. An authorized user selects Add supplier and enters name, contact person, phone and address. Use Edit profile to maintain details or active status.
2. Expand Product catalog and select Add inventory product. Enter product name, unit, reorder threshold and preferred supplier.
3. Define units consistently before receiving stock. A vial, mL, box and individual item are different units; do not mix them for the same stock movement.
## Receive and use stock
1. Select Receive stock for the product. Enter the lot number, expiry date, matching unit and actual quantity received, then save.
2. Confirm the saved lot and balance. An existing lot's unit and expiry are protected; do not invent a new description to bypass a mismatch.
3. For actual clinical consumption, select Use stock on the correct lot. Enter quantity and the correct encounter. Save and confirm the reduction.
4. Never consume expired stock. Check patient, product, lot and available quantity before recording use.
## Count waste and alerts
1. Physically count the usable product/lot. Select Count / adjust stock on the correct lot.
2. Enter Counted quantity as the actual remaining total, not the quantity lost. Record the reason, including any waste. For example, if 10 units were recorded and 2 were wasted, the counted remaining quantity is 8.
3. Save and confirm the corrected balance and retained movement history. If the count is stale because another user changed stock, refresh and recount before submitting again.
4. Review Stock alerts for expired, expiring and low-stock products. Adjust Expiry warning days to the review horizon and work through all alert pages.
5. Arrange replacement stock through the clinic's purchasing process. Supplier bills and payments are recorded separately through Finance.
The current inventory tracks catalog, lots, stock movements and alerts. A full purchase-order, landed-cost and stock-valuation system is outside these screens.

## 16 Reports patient statements and audit history

## Run an operational report
1. Open Reports → Operational reports. Billing users can use Billing → Patient statements and collections for their authorized reports.
2. Choose the report, From and To dates, and patient where required. Submit the report filters.
3. Review each currency's complete total and use Previous or Next for detail pages. A page of rows is not the complete report total.
4. Check the report cutoff. Paging keeps the initial cutoff so new postings do not change earlier page totals. Run the report again to include later activity.
5. Use the available Print action for a copy and confirm dates, patient, currency and included detail in print preview.
## Choose the right report
- Receivables and aging: outstanding invoice balances and how long they have been open.
- Patient statement: opening invoiced balance, movements in the period and closing invoiced balance. Review prepayments separately before applying them.
- Collections and refunds: actual recorded receipts/refunds grouped by currency and payment method.
- Deposits and package liabilities: remaining prepaid obligations; these are not interchangeable with invoice debt.
- Supplier payables: unpaid supplier/payee amounts.
- Cash and bank register: recorded account movements and references.
- Till variances: expected versus physically counted cash and explanations.
## Check accounts and activity
Select Trial balance to review debit, credit and balance by account separately in IQD and USD. Select Audit trail to review authorized event dates, actors, actions and record types; search/page through the history.
Use the accountant's approved interpretation for official books and recognition policies. The operational reports do not create a consolidated IQD/USD balance, a statutory tax return or a full set of legal financial statements.

## 17 Bank and card statement reconciliation

Reconciliation links a statement line to an existing recorded transaction. It does not create a payment or connect automatically to a bank.
## Prepare and import a statement
1. Open Accounting → Bank/card reconciliation and choose Import statement CSV. Download the template from the import workflow.
2. Keep these exact column headings: Date, Account, Currency, Amount, Reference, Statement ID.
3. Use dates in YYYY-MM-DD format. Account must be bank or card; Currency must be IQD or USD. Amount uses a signed decimal value with the correct direction. Statement ID must be a stable identifier from the source statement.
4. Check dates, currency, signs and identifiers with the accountant. Import no more than 1,000 lines or 180 KB at a time.
5. Select the prepared CSV and import. Review any errors before making another file. Confirm the expected statement lines appear; avoid changing IDs to reimport the same activity.
## Match and correct
1. On an Unmatched statement line, select Match. Choose the existing posting with the same account, currency and amount.
2. Enter matching evidence and confirm the reference/date make sense. Save and check the Reconciled status.
3. If a fee or genuine transaction was never recorded, create it through its appropriate authorized Finance workflow first. Return and match the resulting posting. Do not force a match to unrelated activity with the same amount.
4. To correct a mistaken match, open Reconciliation history. An authorized approver selects Reverse match and records a reason. The original match remains in history.
5. Return to the unmatched line and match it to the correct posting. Review unresolved lines and independent statement totals before considering the account reconciled.
Keep original statements in the clinic's approved finance storage. Use a synthetic CSV for training; this workflow handles real financial information when used with live statements.

## 18 Accounting exports and period closing

## Map accounts and hand off a batch
1. Obtain the destination system's account codes from the clinic accountant. Open Accounting → Account mappings and select New mapping version.
2. Enter a clear version name and the external code for each required account. Review the mapping with the accountant. An authorized approver selects Approve mapping. Approved versions cannot be edited.
3. On the approved mapping, select Create accounting batch. Choose the From and To dates and save. A posting belongs to only one batch.
4. Open Accounting batches and select Download CSV for that batch. Check record counts, source references and balanced debit/credit totals separately by original currency.
5. Import once into the intended accounting system through the accountant's process. Downloading again gives the same batch; it is not permission to post duplicates.
6. After confirming the external import, select Acknowledge. Enter the accounting-system reference and reconciliation notes. Verify the acknowledged state.
Finance → Export accounting provides an authorized accounting CSV. For controlled external handoff, use approved mapping versions, unique batches and acknowledgement so imports can be traced.
## Close dates and correct errors
1. Reconcile cash, bank/card, receivables, deposits/packages, payables and batches for the intended period.
2. An authorized approver opens Accounting periods and selects Close accounting period. Enter From and To dates plus close evidence. Review and save.
3. New postings into closed dates are rejected. Do not change a date or reopen another workflow merely to bypass the close.
4. For a justified correction, select Dated accounting adjustment in an open period. Enter posting date, currency, amount, debit, credit and reason under the accountant's approval. Future dates are rejected.
Official bookkeeping, tax, payroll calculations and recognition policies follow the clinic accountant's approved process. These exports do not establish that an external import or legal filing has occurred.

## 19 Staff accounts permissions and clinic settings

## Create an individual account
1. As an authorized administrator or owner, open Team & access and choose Create staff account.
2. Enter the person's full display name, unique username, permitted primary role and temporary password. Usernames start with a Latin letter and use 3–32 Latin letters, numbers, dots, hyphens or underscores. Use a temporary password of 16–128 characters.
3. Save and confirm the new staff row. Give the credentials privately to that person. They must change the temporary password at first sign-in.
4. Administrators manage only permitted non-privileged staff. The owner manages privileged business roles. The normal staff screen does not create or replace the owner account.
## Change or revoke access
1. Expand Manage account beside the intended staff member. Confirm username and name before any action.
2. Use Edit profile to change the permitted primary role or active status. Deactivate departing staff promptly.
3. The owner can Grant an additional role or Revoke additional role with a reason. Review the resulting access; business administration alone does not grant clinical access.
4. Use Set approval limit for the intended currency and amount. Review IQD and USD limits separately.
5. For a forgotten password, select Reset password for the correct permitted account. Set a new temporary password and give it privately. Previous sessions are denied, and the user changes it at next sign-in.
## Configure the clinic
Open Settings → Edit profile to maintain clinic name, Require MFA and Allow cross-currency settlement. Review the impact with the clinic before saving. Clinical access scope is managed separately, as described in chapter 20.
Do not share accounts or print passwords in this manual. MFA enrollment and personal password changes belong to each person's Account & security workflow.

## 20 Care access retention holds and clinical exports

## Assign care access
1. In the patient's Care team & access section, an authorized user selects Assign clinician, chooses the active clinician and records the assignment reason.
2. Review Assigned care team. Use End care assignment with a reason when the assignment ends; history is preserved.
3. The authorized owner chooses Clinical access scope: All clinic clinicians or Assigned care team. Assign clinicians to patients before enabling assigned-care access so care is not unexpectedly blocked.
4. Confirm the affected staff can open only the intended patients. Role permission and patient scope both apply. Do not use another person's account to work around a denial.
## Record policy and legal holds
1. Open Retention & holds. The owner selects Record retention policy, chooses clinical, media, finance, audit or contact records, and enters retention days, approved policy reference and reason.
2. Review the clinic-approved policy, then select Approve retention policy with approval evidence.
3. For a patient hold, open the patient access section and choose Place legal hold. Enter the Hold authorization, including the reason and evidence from the clinic's approved process.
4. Review holds under Retention & holds. Release legal hold only with the required authority and documented reason/evidence.
Recording or approving a policy does not delete data. Automatic clinical deletion and backup expiry remain disabled until the approved operating procedure is configured.
## Export an authorized clinical record
1. Confirm patient identity and the authorized purpose. Select Export clinical record where permitted in the patient access section.
2. Enter the documented export purpose, review it, and submit. Save the resulting JSON only to the clinic's approved destination.
3. The export contains clinical text, prescriptions, results and document metadata. Original photos are accessed separately through Clinical media; this JSON is not a bundle of image files.
Business access alone does not authorize clinical export. Exported files remain sensitive after download; follow the clinic's access, handover and retention rules.

## 21 Printing common problems and daily checks

## Print the correct saved record
1. Open the saved invoice, receipt, signed prescription, aftercare, consent, letter or available report. Choose its Print or Receipt action.
2. Check patient identity, record/reference number, date, language, amounts and currency. For Sorani, check right-to-left text and mixed-direction numbers.
3. Select the intended printer and paper size in preview; check every page before printing. Collect the copy promptly and hand it to the authorized recipient.
## Resolve common problems
- Login or password failure: check username and password capitalization. Ask the administrator for a temporary-password reset if needed.
- MFA required: open Account & security and verify the current authenticator code. For lost access, contact the administrator/system operator.
- Access denied or missing buttons: check role and assigned care scope with the authorized administrator. Business accounts do not automatically see clinical data.
- No records: check patient, date range, search and page controls; wait for loading. Use Refresh for saved updates from other staff.
- Record changed: refresh, compare the newer saved version and resubmit only the intended change.
- Interrupted save/payment: keep the form and retry the unchanged request. Inspect saved results before starting another transaction.
- Photo missing: choose Clinical media and a Ready card; check current consent and care access. Retry Pending uploads with the same file; ask the operator to restore scanning/processing outages.
- Wrong signed/posted content: use an addendum, corrected document, credit, refund or authorized accounting adjustment. Preserve the original.
## Start and finish the day
At opening: sign in, check today's Baghdad schedule, waiting patients, overdue results/follow-ups, reminder calls, stock alerts and the actual till float for your role.
At closing: finish actual care and documentation, review outstanding tasks/unpaid invoices, count and close tills, secure printed/downloaded records, and sign out. Report a fault with time, screen and action; omit passwords and unnecessary patient details.

## 22 Practice demonstration and feature boundaries

## Practice with the local demonstration
1. Ask the administrator for the appropriate individual demo account: receptionist, doctor, administrator, owner or accountant. Passwords are supplied privately and are not included here.
2. Use only profiles prefixed DEMO. Appointments are anchored to 25 October 2026, with further bookings on 26 and 27 October. Select those days if today's list is empty.
3. As doctor, open DEMO · Ava for a signed encounter, addendum, history, fictional prescription, procedure, letter and sample photographs. DEMO · Rona and DEMO · Shilan provide draft encounters for practice.
4. In any of the twenty DEMO profiles, open Clinical media. The cheek and forearm images are AI-generated and watermarked SYNTHETIC DEMO — NOT A REAL PATIENT. The same samples are reused for training; they are not clinical evidence.
5. As reception, examine scheduled, checked-in, in-care, completed, cancelled and no-show visits. Practice with reminder outcomes without dialing the fictional numbers.
6. Review paid, partial and unpaid invoices, deposits, packages and unbilled performed treatments. In Inventory review demo lots, low-stock alerts and approaching expiries. Accountant/owner roles can inspect expenses, transfers and per-currency reports.
## Know the current boundaries
- Reminders are staff phone calls. There is no automatic SMS, WhatsApp or email delivery, and no staff-email account requirement.
- Bank reconciliation uses CSV imports; no live bank connection is configured. Accounting handoff requires the accountant's external codes and destination.
- The application supports a single clinic/branch. Branch-specific delegation, recurring rosters and a full purchasing/stock-valuation system are separate work.
- Automatic record deletion is disabled. Retention approval is policy evidence, not deletion execution.
- The local desktop preview is an unsigned development build. Production hosting, private scanning/processing, independent recovery, signed distribution and clinic acceptance require the operator's release process.
Before live use, the clinic approves real prices, consent/treatment wording, opening balances, printer output and Sorani terminology. This manual explains application operation; it does not prescribe clinical treatment or replace official accounting procedures.

