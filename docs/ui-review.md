# ClinicOS UI review — 25 October 2026

Reviewed the React/Electron desktop UI with the Apple design skill. The design goal is a readable clinical workspace with a clear patient identity, focused tasks and the supplied Stormy Morning blue and slate palette. Apple guidance is translated to HTML, CSS, native Electron menus and accessibility semantics; this is not a claim of AppKit conformance.

Two guiding recommendations were “Use font sizes that most people can read easily” (`typography.md › Ensuring legibility`) and “Consider letting people hide the sidebar” (`sidebars.md › Best practices`).

## Findings and changes

| Severity | Problem | Change | Reference |
| --- | --- | --- | --- |
| Critical | Small navigation text was 9px; branding reached 7px, and several secondary labels had insufficient contrast. | Utility text now starts at 12px; navigation and tables use 13px, panel titles 16px. Shared secondary text is darker. | `accessibility.md › Vision`; `typography.md › Ensuring legibility` |
| Critical | Search fields suppressed their focus outline; wide tables were awkward to reach using the keyboard. | Search containers have a visible focus ring. Table scroll regions are named and keyboard focusable. | `accessibility.md › Mobility`; `lists-and-tables.md › Desktop (macOS)` |
| Critical | Narrow layouts hid sign-out/account controls and removed navigation text from the accessibility tree. | Account and sign-out are in the persistent toolbar. Compact navigation is a labeled, scrollable drawer; hidden navigation is inert. | `sidebars.md › Desktop (macOS)`; `layout.md › Adaptability` |
| High | The skip link changed the app's hash route instead of moving keyboard focus. | It now focuses the main landmark without changing the route; its hidden position also handles taller Sorani text. | `accessibility.md › Mobility` |
| High | Patient contacts, records, prescriptions, media, documents and access controls formed one long page. | Patient section navigation presents one area at a time. Sections retain their existing permission checks, and section selection resets on account changes. | `layout.md › Visual hierarchy`; `sidebars.md › Best practices` |
| High | Billing put performed treatments and statements ahead of invoices; Finance stacked unrelated ledgers. | Billing opens with invoices and offers payments, packages, performed treatments and statements separately. Finance separates expenses, movements and till sessions. | `layout.md › Visual hierarchy` |
| High | Secondary appointment tools pushed the day's appointments down the page. | The daily appointment list appears first, followed by phone reminders and availability/resource tools. | `layout.md › Visual hierarchy` |
| High | Staff rows crowded four or more account/access actions together. | Authorized actions are grouped under each member's “Manage account” disclosure. | `lists-and-tables.md › Content`; grouping choice is design judgment |
| High | The renderer ignored macOS dark appearance. | System-following colors cover the shell, forms, dialogs, tables, clinical sections, statuses and sign-in. Clinical images are not recolored. | `dark-mode.md › Best practices` and `Dark Mode colors`; `color.md › Inclusive color` |
| Medium | Actions could run together or overflow; section controls could not wrap. | Action rows and section controls wrap; small buttons are at least 32px high, icon buttons 36px. Table actions have spacing. | `buttons.md › Style`; `layout.md › Adaptability` |
| Medium | Generic “Save” obscured financial or clinical intent; canceling an appointment had two “Cancel” buttons. | Submission labels identify the operation, including “Issue invoice” and “Cancel appointment.” Merge/cancellation use a destructive treatment. Busy command dialogs disable dismissal. | `buttons.md › Content` and `Role`; `modality.md › Best practices` |
| Medium | Empty reports instructed users to create a record, and loading could appear as an empty schedule. | Neutral empty-state wording; named loading feedback in shared, patient and appointment views. Billing/Finance empty states respect their loading state. Schedule date changes clear the prior day's rows. | `loading.md › Best practices` |
| Medium | Sign-in repeated account guidance, offered no password visibility control and had an oversized headline. | Smaller headline, one account explanation, a labeled Show/Hide control and localized supporting text. | `entering-data.md › Best practices`; visual simplification is design judgment |
| Medium | Sorani had untranslated shell/accounting labels and identifiers could inherit RTL direction. | Added translations for the changed UI, corrected back direction, and isolated phone/clinic-number display. Monospaced identifiers use LTR direction. | `layout.md › Adaptability`; `typography.md › Using custom fonts` |
| Medium | The overview showed metrics unrelated to the signed-in role and used decorative leading zeros. | Only authorized metric categories appear; counts use their actual value. Authorized shortcuts give the accountant a useful starting point. | `layout.md › Visual hierarchy`; role-specific selection is design judgment |

References above are the files read under `/Users/barzy/.codex/skills/apple-design/references/hig/`; the Electron translation follows `references/cross-platform.md`.

## Contrast measurements

Computed from the CSS hex values using sRGB relative luminance, not estimated from screenshots:

| Text/background | Contrast |
| --- | --- |
| Previous navigation label `#89928b` on `#fbfcfb` | 3.12:1 |
| Previous metric note `#849086` on white | 3.33:1 |
| Current secondary text `#526a80` on white | 5.63:1 |
| Slate text `#384959` on pale blue `#BDDDFC` | 6.58:1 |
| Slate `#384959` on white | 9.27:1 |

Apple's small-text threshold is 4.5:1 (`accessibility.md › Vision`). These are representative measured pairs, not an exhaustive contrast certification.

## Verification boundaries

Used only synthetic local accounts and records. Visually inspected owner, doctor, receptionist, administrator and accountant workspaces; English and Sorani; light and dark appearances; patient section navigation; staff management; billing; appointments; and enlarged/compact navigation. The live Vite/Electron development preview renders the changes.

Automated tests, type checking, database checks, release builds and packaging are deliberately deferred at the user's request. Earlier test results in the engineering handoff predate this UI pass. Full keyboard/screen-reader coverage, every form/data combination, print acceptance, supported release binaries and clinic/native-Sorani acceptance still belong to the final verification pass. No production deployment or financial/clinical submission was performed during this review.
