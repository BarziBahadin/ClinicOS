SET local check_function_bodies = off;

CREATE SCHEMA "clinic";

CREATE EXTENSION "pg_trgm" SCHEMA "extensions";

CREATE TABLE "clinic"."addenda" (
  "id"              uuid                     NOT NULL DEFAULT gen_random_uuid(),
  "organization_id" uuid                     NOT NULL,
  "encounter_id"    uuid                     NOT NULL,
  "content"         text                     NOT NULL,
  "created_at"      timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT "addenda_content_check" CHECK ((length(TRIM(BOTH FROM content)) > 0)),
  CONSTRAINT "addenda_pkey" PRIMARY KEY (id),
  "author_id"       uuid                     NOT NULL DEFAULT auth.uid()
);

ALTER TABLE "clinic"."addenda"
  ENABLE ROW LEVEL SECURITY;

CREATE TABLE "clinic"."appointments" (
  "id"                  uuid                     NOT NULL DEFAULT gen_random_uuid(),
  "organization_id"     uuid                     NOT NULL,
  "branch_id"           uuid                     NOT NULL,
  "patient_id"          uuid                     NOT NULL,
  "doctor_id"           uuid                     NOT NULL,
  "starts_at"           timestamp with time zone NOT NULL,
  "ends_at"             timestamp with time zone NOT NULL,
  "service_name"        text                     NOT NULL,
  "status"              text                     NOT NULL DEFAULT 'scheduled'::text,
  "walk_in"             boolean                  NOT NULL DEFAULT false,
  "cancellation_reason" text,
  "checked_in_at"       timestamp with time zone,
  "version"             integer                  NOT NULL DEFAULT 1,
  "created_at"          timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT "appointments_check" CHECK ((ends_at > starts_at)),
  CONSTRAINT "appointments_organization_id_id_key" UNIQUE (organization_id, id),
  CONSTRAINT "appointments_pkey" PRIMARY KEY (id),
  CONSTRAINT "appointments_status_check"
    CHECK ((status = ANY (ARRAY['scheduled'::text, 'checked_in'::text, 'in_care'::text, 'completed'::text, 'cancelled'::text, 'no_show'::text])))
);

ALTER TABLE "clinic"."appointments"
  ENABLE ROW LEVEL SECURITY;

CREATE TABLE "clinic"."audit_events" (
  "id"              uuid                     NOT NULL DEFAULT gen_random_uuid(),
  "organization_id" uuid                     NOT NULL,
  "actor_id"        uuid,
  "action"          text                     NOT NULL,
  "entity_id"       uuid,
  "entity_type"     text                     NOT NULL,
  "created_at"      timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT "audit_events_pkey" PRIMARY KEY (id)
);

ALTER TABLE "clinic"."audit_events"
  ENABLE ROW LEVEL SECURITY;

CREATE TABLE "clinic"."branches" (
  "id"              uuid NOT NULL DEFAULT gen_random_uuid(),
  "organization_id" uuid NOT NULL,
  "name"            text NOT NULL,
  CONSTRAINT "branches_organization_id_id_key" UNIQUE (organization_id, id),
  CONSTRAINT "branches_pkey" PRIMARY KEY (id)
);

ALTER TABLE "clinic"."branches"
  ENABLE ROW LEVEL SECURITY;

CREATE TABLE "clinic"."cash_movements" (
  "id"              uuid                     NOT NULL DEFAULT gen_random_uuid(),
  "organization_id" uuid                     NOT NULL,
  "kind"            text                     NOT NULL,
  "currency"        text                     NOT NULL,
  "amount"          numeric(18,3)            NOT NULL,
  "method"          text                     NOT NULL,
  "destination"     text,
  "description"     text                     NOT NULL,
  "fx_rate"         numeric(18,6),
  "related_id"      uuid,
  "created_at"      timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT "cash_movements_amount_check" CHECK ((amount > (0)::numeric)),
  CONSTRAINT "cash_movements_check" CHECK (((currency <> 'USD'::text) OR (amount = round(amount, 2)))),
  CONSTRAINT "cash_movements_currency_check" CHECK ((currency = ANY (ARRAY['IQD'::text, 'USD'::text]))),
  CONSTRAINT "cash_movements_destination_check" CHECK ((destination = ANY (ARRAY['cash'::text, 'bank'::text, 'card'::text]))),
  CONSTRAINT "cash_movements_kind_check"
    CHECK ((kind = ANY (ARRAY['owner_contribution'::text, 'owner_withdrawal'::text, 'owner_loan'::text, 'transfer'::text, 'opening_balance'::text, 'fx_exchange'::text]))),
  CONSTRAINT "cash_movements_method_check" CHECK ((method = ANY (ARRAY['cash'::text, 'bank'::text, 'card'::text]))),
  CONSTRAINT "cash_movements_pkey" PRIMARY KEY (id)
);

ALTER TABLE "clinic"."cash_movements"
  ENABLE ROW LEVEL SECURITY;

CREATE TABLE "clinic"."consents" (
  "id"               uuid                     NOT NULL DEFAULT gen_random_uuid(),
  "organization_id"  uuid                     NOT NULL,
  "patient_id"       uuid                     NOT NULL,
  "purpose"          text                     NOT NULL,
  "granted"          boolean                  NOT NULL,
  "template_version" text                     NOT NULL,
  "evidence"         text                     NOT NULL,
  "created_at"       timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT "consents_evidence_check" CHECK ((length(TRIM(BOTH FROM evidence)) > 0)),
  CONSTRAINT "consents_organization_id_id_key" UNIQUE (organization_id, id),
  CONSTRAINT "consents_pkey" PRIMARY KEY (id),
  CONSTRAINT "consents_purpose_check"
    CHECK ((purpose = ANY (ARRAY['care_photography'::text, 'procedure'::text, 'teaching'::text, 'publication'::text, 'marketing'::text, 'communication'::text]))),
  "recorded_by"      uuid                     NOT NULL DEFAULT auth.uid()
);

ALTER TABLE "clinic"."consents"
  ENABLE ROW LEVEL SECURITY;

CREATE TABLE "clinic"."contacts" (
  "id"              uuid                     NOT NULL DEFAULT gen_random_uuid(),
  "organization_id" uuid                     NOT NULL,
  "patient_id"      uuid                     NOT NULL,
  "phone"           text                     NOT NULL,
  "owner_name"      text,
  "relationship"    text,
  "valid_from"      timestamp with time zone NOT NULL DEFAULT now(),
  "valid_to"        timestamp with time zone,
  CONSTRAINT "contacts_pkey" PRIMARY KEY (id)
);

ALTER TABLE "clinic"."contacts"
  ENABLE ROW LEVEL SECURITY;

CREATE TABLE "clinic"."credit_notes" (
  "id"              uuid                     NOT NULL DEFAULT gen_random_uuid(),
  "organization_id" uuid                     NOT NULL,
  "invoice_id"      uuid                     NOT NULL,
  "amount"          numeric(18,3)            NOT NULL,
  "reason"          text                     NOT NULL,
  "created_at"      timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT "credit_notes_amount_check" CHECK ((amount > (0)::numeric)),
  CONSTRAINT "credit_notes_pkey" PRIMARY KEY (id)
);

ALTER TABLE "clinic"."credit_notes"
  ENABLE ROW LEVEL SECURITY;

CREATE TABLE "clinic"."encounters" (
  "id"                 uuid                     NOT NULL DEFAULT gen_random_uuid(),
  "organization_id"    uuid                     NOT NULL,
  "patient_id"         uuid                     NOT NULL,
  "doctor_id"          uuid                     NOT NULL,
  "branch_id"          uuid                     NOT NULL,
  "appointment_id"     uuid,
  "status"             text                     NOT NULL DEFAULT 'draft'::text,
  "chief_complaint"    text                     NOT NULL,
  "history"            text                     NOT NULL DEFAULT ''::text,
  "allergies"          text                     NOT NULL DEFAULT 'Not reviewed'::text,
  "findings"           text                     NOT NULL DEFAULT ''::text,
  "diagnosis"          text                     NOT NULL DEFAULT ''::text,
  "plan"               text                     NOT NULL DEFAULT ''::text,
  "prescriptions"      text                     NOT NULL DEFAULT ''::text,
  "clinical_sex_notes" text                     NOT NULL DEFAULT ''::text,
  "birth_snapshot"     jsonb                    NOT NULL DEFAULT '{}'::jsonb,
  "signed_at"          timestamp with time zone,
  "version"            integer                  NOT NULL DEFAULT 1,
  "created_at"         timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT "encounters_organization_id_id_key" UNIQUE (organization_id, id),
  CONSTRAINT "encounters_pkey" PRIMARY KEY (id),
  CONSTRAINT "encounters_status_check" CHECK ((status = ANY (ARRAY['draft'::text, 'signed'::text])))
);

ALTER TABLE "clinic"."encounters"
  ENABLE ROW LEVEL SECURITY;

CREATE TABLE "clinic"."expenses" (
  "id"              uuid                     NOT NULL DEFAULT gen_random_uuid(),
  "organization_id" uuid                     NOT NULL,
  "category"        text                     NOT NULL,
  "supplier"        text                     NOT NULL,
  "description"     text                     NOT NULL,
  "currency"        text                     NOT NULL,
  "amount"          numeric(18,3)            NOT NULL,
  "paid"            boolean                  NOT NULL,
  "method"          text                     NOT NULL,
  "created_at"      timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT "expenses_amount_check" CHECK ((amount > (0)::numeric)),
  CONSTRAINT "expenses_check" CHECK (((currency <> 'USD'::text) OR (amount = round(amount, 2)))),
  CONSTRAINT "expenses_currency_check" CHECK ((currency = ANY (ARRAY['IQD'::text, 'USD'::text]))),
  CONSTRAINT "expenses_method_check" CHECK ((method = ANY (ARRAY['cash'::text, 'bank'::text, 'card'::text]))),
  CONSTRAINT "expenses_organization_id_id_key" UNIQUE (organization_id, id),
  CONSTRAINT "expenses_pkey" PRIMARY KEY (id)
);

ALTER TABLE "clinic"."expenses"
  ENABLE ROW LEVEL SECURITY;

CREATE TABLE "clinic"."invoices" (
  "id"               uuid                     NOT NULL DEFAULT gen_random_uuid(),
  "organization_id"  uuid                     NOT NULL,
  "patient_id"       uuid                     NOT NULL,
  "invoice_number"   text                     NOT NULL,
  "patient_snapshot" jsonb                    NOT NULL,
  "currency"         text                     NOT NULL,
  "lines"            jsonb                    NOT NULL,
  "total"            numeric(18,3)            NOT NULL,
  "created_at"       timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT "invoices_check" CHECK (((currency <> 'USD'::text) OR (total = round(total, 2)))),
  CONSTRAINT "invoices_currency_check" CHECK ((currency = ANY (ARRAY['IQD'::text, 'USD'::text]))),
  CONSTRAINT "invoices_lines_check" CHECK ((jsonb_typeof(lines) = 'array'::text)),
  CONSTRAINT "invoices_organization_id_id_key" UNIQUE (organization_id, id),
  CONSTRAINT "invoices_organization_id_invoice_number_key" UNIQUE (organization_id, invoice_number),
  CONSTRAINT "invoices_pkey" PRIMARY KEY (id),
  CONSTRAINT "invoices_total_check" CHECK ((total > (0)::numeric)),
  "created_by"       uuid                     NOT NULL DEFAULT auth.uid()
);

ALTER TABLE "clinic"."invoices"
  ENABLE ROW LEVEL SECURITY;

CREATE TABLE "clinic"."journal_lines" (
  "id"              uuid          NOT NULL DEFAULT gen_random_uuid(),
  "organization_id" uuid          NOT NULL,
  "journal_id"      uuid          NOT NULL,
  "account"         text          NOT NULL,
  "debit"           numeric(18,3) NOT NULL DEFAULT 0,
  "credit"          numeric(18,3) NOT NULL DEFAULT 0,
  CONSTRAINT "journal_lines_account_check"
    CHECK
    ((account = ANY (ARRAY['cash'::text, 'bank'::text, 'card'::text, 'receivable'::text, 'deposits'::text, 'revenue'::text, 'expense'::text, 'inventory'::text, 'payable'::text,
    'equity'::text, 'owner_loan'::text, 'fx_clearing'::text]))),
  CONSTRAINT "journal_lines_check"
    CHECK
    (((debit >= (0)::numeric) AND (credit >= (0)::numeric) AND (((debit > (0)::numeric) AND (credit = (0)::numeric)) OR ((credit > (0)::numeric) AND (debit = (0)::numeric))))),
  CONSTRAINT "journal_lines_pkey" PRIMARY KEY (id)
);

ALTER TABLE "clinic"."journal_lines"
  ENABLE ROW LEVEL SECURITY;

CREATE TABLE "clinic"."journals" (
  "id"              uuid                     NOT NULL DEFAULT gen_random_uuid(),
  "organization_id" uuid                     NOT NULL,
  "currency"        text                     NOT NULL,
  "description"     text                     NOT NULL,
  "source_type"     text                     NOT NULL,
  "source_id"       uuid                     NOT NULL,
  "created_at"      timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT "journals_currency_check" CHECK ((currency = ANY (ARRAY['IQD'::text, 'USD'::text]))),
  CONSTRAINT "journals_organization_id_id_key" UNIQUE (organization_id, id),
  CONSTRAINT "journals_organization_id_source_type_source_id_currency_key" UNIQUE (organization_id, source_type, source_id, currency),
  CONSTRAINT "journals_pkey" PRIMARY KEY (id)
);

ALTER TABLE "clinic"."journals"
  ENABLE ROW LEVEL SECURITY;

CREATE TABLE "clinic"."media" (
  "id"              uuid                     NOT NULL DEFAULT gen_random_uuid(),
  "organization_id" uuid                     NOT NULL,
  "patient_id"      uuid                     NOT NULL,
  "encounter_id"    uuid,
  "object_key"      text                     NOT NULL,
  "title"           text                     NOT NULL,
  "body_site"       text                     NOT NULL,
  "purpose"         text                     NOT NULL DEFAULT 'care_photography'::text,
  "mime_type"       text                     NOT NULL,
  "status"          text                     NOT NULL DEFAULT 'pending'::text,
  "consent_id"      uuid                     NOT NULL,
  "created_at"      timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT "media_mime_type_check" CHECK ((mime_type = ANY (ARRAY['image/jpeg'::text, 'image/png'::text, 'image/webp'::text, 'application/pdf'::text]))),
  CONSTRAINT "media_object_key_key" UNIQUE (object_key),
  CONSTRAINT "media_organization_id_id_key" UNIQUE (organization_id, id),
  CONSTRAINT "media_pkey" PRIMARY KEY (id),
  CONSTRAINT "media_status_check" CHECK ((status = ANY (ARRAY['pending'::text, 'ready'::text, 'rejected'::text]))),
  "uploaded_by"     uuid                     NOT NULL DEFAULT auth.uid()
);

ALTER TABLE "clinic"."media"
  ENABLE ROW LEVEL SECURITY;

CREATE TABLE "clinic"."memberships" (
  "id"              uuid    NOT NULL DEFAULT gen_random_uuid(),
  "organization_id" uuid    NOT NULL,
  "user_id"         uuid    NOT NULL,
  "display_name"    text    NOT NULL,
  "role"            text    NOT NULL,
  "active"          boolean NOT NULL DEFAULT true,
  CONSTRAINT "memberships_organization_id_id_key" UNIQUE (organization_id, id),
  CONSTRAINT "memberships_organization_id_user_id_key" UNIQUE (organization_id, user_id),
  CONSTRAINT "memberships_pkey" PRIMARY KEY (id),
  CONSTRAINT "memberships_role_check" CHECK ((role = ANY (ARRAY['owner'::text, 'administrator'::text, 'doctor'::text, 'receptionist'::text, 'accountant'::text])))
);

ALTER TABLE "clinic"."memberships"
  ENABLE ROW LEVEL SECURITY;

CREATE TABLE "clinic"."organizations" (
  "id"            uuid                     NOT NULL DEFAULT gen_random_uuid(),
  "name"          text                     NOT NULL,
  "country"       text                     NOT NULL DEFAULT 'IQ'::text,
  "timezone"      text                     NOT NULL DEFAULT 'Asia/Baghdad'::text,
  "base_currency" text                     NOT NULL DEFAULT 'IQD'::text,
  "require_mfa"   boolean                  NOT NULL DEFAULT true,
  "created_at"    timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT "organizations_base_currency_check" CHECK ((base_currency = ANY (ARRAY['IQD'::text, 'USD'::text]))),
  CONSTRAINT "organizations_country_check" CHECK ((country = 'IQ'::text)),
  CONSTRAINT "organizations_name_check" CHECK (((length(name) >= 2) AND (length(name) <= 160))),
  CONSTRAINT "organizations_pkey" PRIMARY KEY (id)
);

ALTER TABLE "clinic"."organizations"
  ENABLE ROW LEVEL SECURITY;

CREATE TABLE "clinic"."package_redemptions" (
  "id"              uuid                     NOT NULL DEFAULT gen_random_uuid(),
  "organization_id" uuid                     NOT NULL,
  "package_id"      uuid                     NOT NULL,
  "encounter_id"    uuid                     NOT NULL,
  "created_at"      timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT "package_redemptions_package_id_encounter_id_key" UNIQUE (package_id, encounter_id),
  CONSTRAINT "package_redemptions_pkey" PRIMARY KEY (id)
);

ALTER TABLE "clinic"."package_redemptions"
  ENABLE ROW LEVEL SECURITY;

CREATE TABLE "clinic"."packages" (
  "id"              uuid                     NOT NULL DEFAULT gen_random_uuid(),
  "organization_id" uuid                     NOT NULL,
  "patient_id"      uuid                     NOT NULL,
  "name"            text                     NOT NULL,
  "sessions"        integer                  NOT NULL,
  "remaining"       integer                  NOT NULL,
  "currency"        text                     NOT NULL,
  "total"           numeric(18,3)            NOT NULL,
  "redeemed_value"  numeric(18,3)            NOT NULL DEFAULT 0,
  "created_at"      timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT "packages_check" CHECK (((remaining >= 0) AND (remaining <= sessions))),
  CONSTRAINT "packages_currency_check" CHECK ((currency = ANY (ARRAY['IQD'::text, 'USD'::text]))),
  CONSTRAINT "packages_organization_id_id_key" UNIQUE (organization_id, id),
  CONSTRAINT "packages_pkey" PRIMARY KEY (id),
  CONSTRAINT "packages_sessions_check" CHECK ((sessions > 0)),
  CONSTRAINT "packages_total_check" CHECK ((total > (0)::numeric))
);

ALTER TABLE "clinic"."packages"
  ENABLE ROW LEVEL SECURITY;

CREATE TABLE "clinic"."patient_merges" (
  "id"              uuid                     NOT NULL DEFAULT gen_random_uuid(),
  "organization_id" uuid                     NOT NULL,
  "source_id"       uuid                     NOT NULL,
  "target_id"       uuid                     NOT NULL,
  "reason"          text                     NOT NULL,
  "created_at"      timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT "patient_merges_pkey" PRIMARY KEY (id),
  "reviewed_by"     uuid                     NOT NULL DEFAULT auth.uid()
);

ALTER TABLE "clinic"."patient_merges"
  ENABLE ROW LEVEL SECURITY;

CREATE TABLE "clinic"."patients" (
  "id"                    uuid                     NOT NULL DEFAULT gen_random_uuid(),
  "organization_id"       uuid                     NOT NULL,
  "patient_number"        text                     NOT NULL,
  "full_name"             text                     NOT NULL,
  "phone"                 text,
  "contact_owner"         text,
  "birth_date"            date,
  "birth_precision"       text                     NOT NULL DEFAULT 'unknown'::text,
  "reported_age"          integer,
  "age_recorded_on"       date,
  "gender"                text                     NOT NULL DEFAULT 'unknown'::text,
  "language"              text                     NOT NULL DEFAULT 'ckb'::text,
  "guardian_name"         text,
  "guardian_relationship" text,
  "communication_consent" boolean                  NOT NULL DEFAULT false,
  "merged_into"           uuid,
  "version"               integer                  NOT NULL DEFAULT 1,
  "created_at"            timestamp with time zone NOT NULL DEFAULT now(),
  "updated_at"            timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT "patients_birth_precision_check" CHECK ((birth_precision = ANY (ARRAY['day'::text, 'month'::text, 'year'::text, 'unknown'::text]))),
  CONSTRAINT "patients_check1" CHECK (((birth_precision <> 'year'::text) OR (EXTRACT(doy FROM birth_date) = (1)::numeric))),
  CONSTRAINT "patients_check2" CHECK (((birth_precision <> 'month'::text) OR (EXTRACT(day FROM birth_date) = (1)::numeric))),
  CONSTRAINT "patients_check3" CHECK (((reported_age IS NULL) OR (age_recorded_on IS NOT NULL))),
  CONSTRAINT "patients_check4" CHECK (((merged_into IS NULL) OR (merged_into <> id))),
  CONSTRAINT "patients_check" CHECK ((((birth_precision = 'unknown'::text) AND (birth_date IS NULL)) OR ((birth_precision <> 'unknown'::text) AND (birth_date IS NOT NULL)))),
  CONSTRAINT "patients_full_name_check" CHECK (((length(TRIM(BOTH FROM full_name)) >= 2) AND (length(TRIM(BOTH FROM full_name)) <= 200))),
  CONSTRAINT "patients_gender_check" CHECK ((gender = ANY (ARRAY['female'::text, 'male'::text, 'other'::text, 'unknown'::text, 'not_disclosed'::text]))),
  CONSTRAINT "patients_language_check" CHECK ((language = ANY (ARRAY['en'::text, 'ckb'::text]))),
  CONSTRAINT "patients_organization_id_id_key" UNIQUE (organization_id, id),
  CONSTRAINT "patients_organization_id_patient_number_key" UNIQUE (organization_id, patient_number),
  CONSTRAINT "patients_phone_check" CHECK (((phone IS NULL) OR (phone ~ '^\+[1-9][0-9]{7,14}$'::text))),
  CONSTRAINT "patients_pkey" PRIMARY KEY (id),
  CONSTRAINT "patients_reported_age_check" CHECK (((reported_age >= 0) AND (reported_age <= 130)))
);

ALTER TABLE "clinic"."patients"
  ENABLE ROW LEVEL SECURITY;

CREATE TABLE "clinic"."payments" (
  "id"                  uuid                     NOT NULL DEFAULT gen_random_uuid(),
  "organization_id"     uuid                     NOT NULL,
  "patient_id"          uuid                     NOT NULL,
  "invoice_id"          uuid,
  "currency"            text                     NOT NULL,
  "amount"              numeric(18,3)            NOT NULL,
  "method"              text                     NOT NULL,
  "kind"                text                     NOT NULL DEFAULT 'payment'::text,
  "original_payment_id" uuid,
  "reason"              text,
  "created_at"          timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT "payments_amount_check" CHECK ((amount > (0)::numeric)),
  CONSTRAINT "payments_check" CHECK (((currency <> 'USD'::text) OR (amount = round(amount, 2)))),
  CONSTRAINT "payments_currency_check" CHECK ((currency = ANY (ARRAY['IQD'::text, 'USD'::text]))),
  CONSTRAINT "payments_kind_check" CHECK ((kind = ANY (ARRAY['payment'::text, 'deposit'::text, 'deposit_application'::text, 'refund'::text]))),
  CONSTRAINT "payments_method_check" CHECK ((method = ANY (ARRAY['cash'::text, 'bank'::text, 'card'::text, 'deposit'::text]))),
  CONSTRAINT "payments_organization_id_id_key" UNIQUE (organization_id, id),
  CONSTRAINT "payments_pkey" PRIMARY KEY (id),
  "created_by"          uuid                     NOT NULL DEFAULT auth.uid()
);

ALTER TABLE "clinic"."payments"
  ENABLE ROW LEVEL SECURITY;

CREATE TABLE "clinic"."procedures" (
  "id"              uuid                     NOT NULL DEFAULT gen_random_uuid(),
  "organization_id" uuid                     NOT NULL,
  "patient_id"      uuid                     NOT NULL,
  "encounter_id"    uuid                     NOT NULL,
  "name"            text                     NOT NULL,
  "body_site"       text                     NOT NULL,
  "product"         text,
  "lot_number"      text,
  "settings"        text,
  "quantity"        numeric(18,3),
  "aftercare"       text                     NOT NULL,
  "adverse_event"   text,
  "created_at"      timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT "procedures_pkey" PRIMARY KEY (id),
  "performed_by"    uuid                     NOT NULL DEFAULT auth.uid()
);

ALTER TABLE "clinic"."procedures"
  ENABLE ROW LEVEL SECURITY;

CREATE TABLE "clinic"."requests" (
  "organization_id" uuid                     NOT NULL,
  "actor_id"        uuid                     NOT NULL,
  "request_id"      uuid                     NOT NULL,
  "fingerprint"     text                     NOT NULL,
  "result"          jsonb                    NOT NULL,
  "created_at"      timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT "requests_pkey" PRIMARY KEY (organization_id, actor_id, request_id)
);

ALTER TABLE "clinic"."requests"
  ENABLE ROW LEVEL SECURITY;

CREATE TABLE "clinic"."results" (
  "id"                 uuid                     NOT NULL DEFAULT gen_random_uuid(),
  "organization_id"    uuid                     NOT NULL,
  "patient_id"         uuid                     NOT NULL,
  "order_name"         text                     NOT NULL,
  "body_site"          text                     NOT NULL,
  "specimen_reference" text                     NOT NULL,
  "status"             text                     NOT NULL DEFAULT 'ordered'::text,
  "result_text"        text,
  "due_at"             timestamp with time zone NOT NULL,
  "assigned_to"        uuid                     NOT NULL,
  "version"            integer                  NOT NULL DEFAULT 1,
  "created_at"         timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT "results_pkey" PRIMARY KEY (id),
  CONSTRAINT "results_status_check" CHECK ((status = ANY (ARRAY['ordered'::text, 'received'::text, 'reviewed'::text, 'notified'::text, 'closed'::text])))
);

ALTER TABLE "clinic"."results"
  ENABLE ROW LEVEL SECURITY;

CREATE TABLE "clinic"."services" (
  "id"              uuid          NOT NULL DEFAULT gen_random_uuid(),
  "organization_id" uuid          NOT NULL,
  "name"            text          NOT NULL,
  "name_ckb"        text          NOT NULL DEFAULT ''::text,
  "category"        text          NOT NULL,
  "currency"        text          NOT NULL,
  "price"           numeric(18,3) NOT NULL,
  "duration"        integer       NOT NULL DEFAULT 30,
  "active"          boolean       NOT NULL DEFAULT true,
  CONSTRAINT "services_category_check" CHECK ((category = ANY (ARRAY['medical'::text, 'cosmetic'::text]))),
  CONSTRAINT "services_check" CHECK (((currency <> 'USD'::text) OR (price = round(price, 2)))),
  CONSTRAINT "services_currency_check" CHECK ((currency = ANY (ARRAY['IQD'::text, 'USD'::text]))),
  CONSTRAINT "services_duration_check" CHECK (((duration >= 5) AND (duration <= 480))),
  CONSTRAINT "services_organization_id_id_key" UNIQUE (organization_id, id),
  CONSTRAINT "services_pkey" PRIMARY KEY (id),
  CONSTRAINT "services_price_check" CHECK ((price >= (0)::numeric))
);

ALTER TABLE "clinic"."services"
  ENABLE ROW LEVEL SECURITY;

CREATE TABLE "clinic"."stock_lots" (
  "id"              uuid          NOT NULL DEFAULT gen_random_uuid(),
  "organization_id" uuid          NOT NULL,
  "product"         text          NOT NULL,
  "lot_number"      text          NOT NULL,
  "expires_on"      date          NOT NULL,
  "unit"            text          NOT NULL,
  "quantity"        numeric(18,3) NOT NULL,
  "version"         integer       NOT NULL DEFAULT 1,
  CONSTRAINT "stock_lots_organization_id_id_key" UNIQUE (organization_id, id),
  CONSTRAINT "stock_lots_organization_id_product_lot_number_key" UNIQUE (organization_id, product, lot_number),
  CONSTRAINT "stock_lots_pkey" PRIMARY KEY (id),
  CONSTRAINT "stock_lots_quantity_check" CHECK ((quantity >= (0)::numeric))
);

ALTER TABLE "clinic"."stock_lots"
  ENABLE ROW LEVEL SECURITY;

CREATE TABLE "clinic"."stock_movements" (
  "id"              uuid                     NOT NULL DEFAULT gen_random_uuid(),
  "organization_id" uuid                     NOT NULL,
  "lot_id"          uuid                     NOT NULL,
  "encounter_id"    uuid,
  "quantity"        numeric(18,3)            NOT NULL,
  "reason"          text                     NOT NULL,
  "created_at"      timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT "stock_movements_pkey" PRIMARY KEY (id),
  CONSTRAINT "stock_movements_quantity_check" CHECK ((quantity <> (0)::numeric))
);

ALTER TABLE "clinic"."stock_movements"
  ENABLE ROW LEVEL SECURITY;

CREATE TABLE "clinic"."tasks" (
  "id"              uuid                     NOT NULL DEFAULT gen_random_uuid(),
  "organization_id" uuid                     NOT NULL,
  "patient_id"      uuid                     NOT NULL,
  "title"           text                     NOT NULL,
  "due_at"          timestamp with time zone NOT NULL,
  "assigned_to"     uuid                     NOT NULL,
  "completed_at"    timestamp with time zone,
  "created_at"      timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT "tasks_pkey" PRIMARY KEY (id)
);

ALTER TABLE "clinic"."tasks"
  ENABLE ROW LEVEL SECURITY;

CREATE TABLE "clinic"."tills" (
  "id"              uuid                     NOT NULL DEFAULT gen_random_uuid(),
  "organization_id" uuid                     NOT NULL,
  "currency"        text                     NOT NULL,
  "opening"         numeric(18,3)            NOT NULL,
  "opened_at"       timestamp with time zone NOT NULL DEFAULT now(),
  "closed_at"       timestamp with time zone,
  "expected"        numeric(18,3),
  "counted"         numeric(18,3),
  "reason"          text,
  CONSTRAINT "tills_currency_check" CHECK ((currency = ANY (ARRAY['USD'::text, 'IQD'::text]))),
  CONSTRAINT "tills_opening_check" CHECK ((opening >= (0)::numeric)),
  CONSTRAINT "tills_organization_id_id_key" UNIQUE (organization_id, id),
  CONSTRAINT "tills_pkey" PRIMARY KEY (id),
  "user_id"         uuid                     NOT NULL DEFAULT auth.uid()
);

ALTER TABLE "clinic"."tills"
  ENABLE ROW LEVEL SECURITY;

CREATE OR REPLACE FUNCTION clinic.allowed (
  perm text
)
  RETURNS boolean
  LANGUAGE sql
  STABLE
  SECURITY DEFINER
  SET search_path TO ''
  AS $function$
 select exists(select 1 from clinic.memberships m join clinic.organizations o on o.id=m.organization_id
 where m.user_id=(select auth.uid()) and m.active and m.organization_id=clinic.org_id()
 and perm=any(clinic.permissions(m.role)) and (not o.require_mfa or coalesce(auth.jwt()->>'aal','aal1')='aal2'))
$function$;

CREATE OR REPLACE FUNCTION clinic.audit_write()
  RETURNS TRIGGER
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO ''
  AS $function$
begin
 insert into clinic.audit_events(organization_id,actor_id,action,entity_id,entity_type)
 values(new.organization_id,auth.uid(),tg_op,new.id,tg_table_name);
 return new;
end $function$;

CREATE OR REPLACE FUNCTION clinic.balanced_journal()
  RETURNS TRIGGER
  LANGUAGE plpgsql
  SET search_path TO ''
  AS $function$
declare j uuid; d numeric; c numeric; n integer; curr text;
begin j:=new.journal_id;
 select sum(debit),sum(credit),count(*) into d,c,n from clinic.journal_lines where journal_id=j;
 select currency into curr from clinic.journals where id=j;
 if n<2 or d<>c or (curr='USD' and d<>round(d,2)) then raise exception 'Unbalanced or imprecise journal' using errcode='23514'; end if;
 return null;
end $function$;

CREATE OR REPLACE FUNCTION clinic.billable_encounters()
  RETURNS jsonb
  LANGUAGE sql
  STABLE
  SECURITY DEFINER
  SET search_path TO ''
  AS $function$
 select coalesce(jsonb_agg(x),'[]') from (select id,patient_id,status,created_at from clinic.encounters where organization_id=clinic.org_id() and clinic.allowed('billing') and status='signed' order by created_at desc limit 500) x
$function$;

CREATE OR REPLACE FUNCTION clinic.billing_encounter_patient (
  encounter_id uuid
)
  RETURNS uuid
  LANGUAGE sql
  STABLE
  SECURITY DEFINER
  SET search_path TO ''
  AS $function$
 select patient_id from clinic.encounters where id=encounter_id and organization_id=clinic.org_id() and status='signed' and clinic.allowed('billing')
$function$;

CREATE OR REPLACE FUNCTION clinic.branch_id()
  RETURNS uuid
  LANGUAGE sql
  STABLE
  SET search_path TO ''
  AS $function$ select id from clinic.branches where organization_id=clinic.org_id() order by id limit 1 $function$;

CREATE OR REPLACE FUNCTION clinic.immutable_record()
  RETURNS TRIGGER
  LANGUAGE plpgsql
  SET search_path TO ''
  AS $function$ begin raise exception 'Posted records are immutable; use an amendment or reversal' using errcode='23514'; end $function$;

CREATE OR REPLACE FUNCTION clinic.log_access (
  action      text,
  entity      uuid,
  entity_type text
)
  RETURNS void
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO ''
  AS $function$
begin if auth.uid() is null or clinic.org_id() is null then raise exception 'Not authenticated' using errcode='42501'; end if;
 insert into clinic.audit_events(organization_id,actor_id,action,entity_id,entity_type) values(clinic.org_id(),auth.uid(),action,entity,entity_type); end $function$;

CREATE OR REPLACE FUNCTION clinic.org_id()
  RETURNS uuid
  LANGUAGE sql
  STABLE
  SECURITY DEFINER
  SET search_path TO ''
  AS $function$
 select m.organization_id from clinic.memberships m where m.user_id=(select auth.uid()) and m.active order by m.organization_id limit 1
$function$;

CREATE OR REPLACE FUNCTION clinic.patient_ids (
  root uuid
)
  RETURNS TABLE (
    id uuid
  )
  LANGUAGE sql
  STABLE
  SET search_path TO ''
  AS $function$
 with recursive linked(id) as (select id from clinic.patients where id=root and organization_id=clinic.org_id() union select p.id from clinic.patients p join linked l on p.merged_into=l.id where p.organization_id=clinic.org_id()) select id from linked
$function$;

CREATE OR REPLACE FUNCTION clinic.permissions (
  p_role text
)
  RETURNS text[]
  LANGUAGE sql
  IMMUTABLE
  SET search_path TO ''
  AS $function$
 select case p_role
 when 'owner' then array['patients','schedule','billing','finance','approve','inventory','staff','settings','audit','export','payroll']
 when 'administrator' then array['patients','schedule','billing','finance','inventory','audit']
 when 'doctor' then array['patients','schedule','clinical','media','results','inventory.read']
 when 'receptionist' then array['patients','schedule','billing']
 when 'accountant' then array['finance','approve','export','audit','payroll'] else array[]::text[] end
$function$;

CREATE OR REPLACE FUNCTION clinic.post_journal (
  curr           text,
  description    text,
  source_type    text,
  source_id      uuid,
  debit_account  text,
  credit_account text,
  value          numeric
)
  RETURNS uuid
  LANGUAGE plpgsql
  SET search_path TO ''
  AS $function$
declare j uuid;
begin
 if value<=0 or (curr='USD' and value<>round(value,2)) or (curr='IQD' and value<>round(value,3)) then raise exception 'Invalid currency precision or amount' using errcode='23514'; end if;
 insert into clinic.journals(organization_id,currency,description,source_type,source_id) values(clinic.org_id(),curr,description,source_type,source_id) returning id into j;
 insert into clinic.journal_lines(organization_id,journal_id,account,debit,credit) values(clinic.org_id(),j,debit_account,value,0),(clinic.org_id(),j,credit_account,0,value);
 return j;
end $function$;

CREATE OR REPLACE FUNCTION clinic.protect_encounter()
  RETURNS TRIGGER
  LANGUAGE plpgsql
  SET search_path TO ''
  AS $function$
begin
 if old.status='signed' then raise exception 'Signed encounter is immutable; add an addendum' using errcode='23514'; end if;
 if new.patient_id<>old.patient_id or new.doctor_id<>old.doctor_id or new.organization_id<>old.organization_id then raise exception 'Encounter identity is immutable' using errcode='23514'; end if;
 return new;
end $function$;

CREATE OR REPLACE FUNCTION clinic.require_permission (
  perm text
)
  RETURNS void
  LANGUAGE plpgsql
  STABLE
  SET search_path TO ''
  AS $function$
begin if not clinic.allowed(perm) then raise exception 'Permission denied or multi-factor verification required' using errcode='42501'; end if; end $function$;

CREATE OR REPLACE FUNCTION clinic.search_key (
  value text
)
  RETURNS text
  LANGUAGE sql
  IMMUTABLE
  SET search_path TO ''
  AS $function$ select lower(normalize(translate(coalesce(value,''),'كيى٠١٢٣٤٥٦٧٨٩۰۱۲۳۴۵۶۷۸۹','کیی01234567890123456789'),NFKC)) $function$;

CREATE OR REPLACE FUNCTION clinic.valid_birth()
  RETURNS TRIGGER
  LANGUAGE plpgsql
  SET search_path TO ''
  AS $function$ begin if new.birth_date>(now() at time zone 'Asia/Baghdad')::date then raise exception 'Birth date cannot be in the future' using errcode='23514'; end if; return new; end $function$;

CREATE OR REPLACE FUNCTION public.accounting_export()
  RETURNS jsonb
  LANGUAGE plpgsql
  SET search_path TO ''
  AS $function$
begin perform clinic.require_permission('export'); perform clinic.log_access('EXPORT',null,'accounting');
 return coalesce((select jsonb_agg(x) from (select j.id,j.currency,j.description,j.source_type,j.source_id,j.created_at,l.account,l.debit,l.credit from clinic.journals j join clinic.journal_lines l on l.journal_id=j.id where j.organization_id=clinic.org_id() order by j.created_at,j.id,l.id) x),'[]'); end $function$;

CREATE OR REPLACE FUNCTION public.authorize (
  permission text
)
  RETURNS boolean
  LANGUAGE sql
  STABLE
  SET search_path TO ''
  AS $function$select clinic.allowed(permission)$function$;

CREATE OR REPLACE FUNCTION public.clinical_record (
  patient_id uuid
)
  RETURNS jsonb
  LANGUAGE plpgsql
  SET search_path TO ''
  AS $function$
begin
 perform clinic.require_permission('clinical');
 if not exists(select 1 from clinic.patients p where p.id=patient_id and organization_id=clinic.org_id()) then raise exception 'Patient not found'; end if;
 perform clinic.log_access('READ',patient_id,'clinical_record');
 return jsonb_build_object('encounters',coalesce((select jsonb_agg(x) from (select e.*, (select jsonb_agg(a) from clinic.addenda a where a.encounter_id=e.id) addenda from clinic.encounters e where e.patient_id in (select id from clinic.patient_ids(clinical_record.patient_id)) order by created_at desc) x),'[]'),'procedures',coalesce((select jsonb_agg(p) from clinic.procedures p where p.patient_id in (select id from clinic.patient_ids(clinical_record.patient_id))),'[]'));
end $function$;

CREATE OR REPLACE FUNCTION public.command (
  kind       text,
  payload    jsonb,
  request_id uuid
)
  RETURNS jsonb
  LANGUAGE plpgsql
  SET search_path TO ''
  AS $function$
declare
 o uuid:=clinic.org_id(); actor uuid:=auth.uid(); fingerprint text:=md5(kind||payload::text);
 previous clinic.requests; rid uuid; p uuid; e uuid; a uuid; amt numeric; due numeric; curr text; method text;
 row_patient clinic.patients; row_enc clinic.encounters; row_invoice clinic.invoices; row_payment clinic.payments;
 row_lot clinic.stock_lots; row_package clinic.packages; row_till clinic.tills; row_result clinic.results; row_appointment clinic.appointments;
 line jsonb; lines jsonb:='[]'; total numeric:=0; num text; result jsonb; rate numeric;
begin
 if o is null or actor is null then raise exception 'Not authenticated' using errcode='42501'; end if;
 if request_id is null or jsonb_typeof(payload)<>'object' or octet_length(payload::text)>200000 then raise exception 'Invalid request'; end if;
 perform pg_advisory_xact_lock(hashtextextended(o::text,0));
 select * into previous from clinic.requests r where r.organization_id=o and r.actor_id=actor and r.request_id=command.request_id;
 if found then if previous.fingerprint<>fingerprint then raise exception 'Request identifier was reused with different content' using errcode='23505'; end if; return previous.result; end if;
 p:=nullif(payload->>'patient_id','')::uuid; e:=nullif(payload->>'encounter_id','')::uuid;
 curr:=coalesce(payload->>'currency','IQD'); method:=coalesce(payload->>'method','cash');
 amt:=nullif(payload->>'amount','')::numeric;
 if amt is not null and (amt<=0 or curr not in ('USD','IQD') or amt<>round(amt,case when curr='USD' then 2 else 3 end)) then raise exception 'Invalid amount or currency precision' using errcode='23514'; end if;
 if p is not null then
 select * into row_patient from clinic.patients where id=p and organization_id=o;
 if not found then raise exception 'Patient not found' using errcode='P0002'; end if;
 if row_patient.merged_into is not null and kind<>'patient.merge' then raise exception 'Patient was merged; use the active profile' using errcode='23514'; end if;
 end if;
 case kind
 when 'patient.create' then
 perform clinic.require_permission('patients');
 num:='P-'||lpad(((select count(*) from clinic.patients where organization_id=o)+1)::text,6,'0');
 insert into clinic.patients(organization_id,patient_number,full_name,phone,contact_owner,birth_date,birth_precision,gender,language,guardian_name,guardian_relationship,communication_consent,reported_age,age_recorded_on)
 values(o,num,trim(payload->>'full_name'),nullif(payload->>'phone',''),payload->>'contact_owner',nullif(payload->>'birth_date','')::date,coalesce(payload->>'birth_precision','unknown'),coalesce(payload->>'gender','unknown'),coalesce(payload->>'language','ckb'),payload->>'guardian_name',payload->>'guardian_relationship',coalesce((payload->>'communication_consent')::boolean,false),nullif(payload->>'reported_age','')::integer,case when nullif(payload->>'reported_age','') is not null then (now() at time zone 'Asia/Baghdad')::date end) returning id into rid;
 when 'patient.update' then
 perform clinic.require_permission('patients');
 if row_patient.version<>(payload->>'version')::integer then raise exception 'This profile changed on another device. Refresh and compare your changes.' using errcode='40001'; end if;
 if row_patient.phone is distinct from nullif(payload->>'phone','') and row_patient.phone is not null then insert into clinic.contacts(organization_id,patient_id,phone,owner_name,valid_to) values(o,p,row_patient.phone,row_patient.contact_owner,now()); end if;
 update clinic.patients set full_name=trim(payload->>'full_name'),phone=nullif(payload->>'phone',''),contact_owner=payload->>'contact_owner',birth_date=nullif(payload->>'birth_date','')::date,birth_precision=coalesce(payload->>'birth_precision','unknown'),gender=coalesce(payload->>'gender','unknown'),language=coalesce(payload->>'language','ckb'),guardian_name=payload->>'guardian_name',guardian_relationship=payload->>'guardian_relationship',communication_consent=coalesce((payload->>'communication_consent')::boolean,false),version=version+1,updated_at=now() where id=p returning id into rid;
 when 'patient.merge' then
 perform clinic.require_permission('approve');
 a:=(payload->>'target_id')::uuid;
 if p=a or length(trim(coalesce(payload->>'reason','')))<8 then raise exception 'A different target and documented identity review are required'; end if;
 if row_patient.merged_into is not null or not exists(select 1 from clinic.patients where id=a and organization_id=o and merged_into is null) then raise exception 'Invalid merge target'; end if;
 update clinic.patients set merged_into=a,version=version+1 where id=p returning id into rid;
 insert into clinic.patient_merges(organization_id,source_id,target_id,reason) values(o,p,a,payload->>'reason');
 perform clinic.log_access('PATIENT_MERGE',p,'patient');
 when 'appointment.create' then
 perform clinic.require_permission('schedule');
 a:=(payload->>'doctor_id')::uuid;
 if not exists(select 1 from clinic.memberships where user_id=a and organization_id=o and active and role='doctor') then raise exception 'Select an active clinician'; end if;
 if exists(select 1 from clinic.appointments where organization_id=o and doctor_id=a and status not in ('cancelled','no_show') and starts_at<(payload->>'ends_at')::timestamptz and ends_at>(payload->>'starts_at')::timestamptz) then raise exception 'The clinician already has an appointment at this time' using errcode='23P01'; end if;
 insert into clinic.appointments(organization_id,branch_id,patient_id,doctor_id,starts_at,ends_at,service_name,walk_in,status,checked_in_at) values(o,clinic.branch_id(),p,a,(payload->>'starts_at')::timestamptz,(payload->>'ends_at')::timestamptz,payload->>'service_name',coalesce((payload->>'walk_in')::boolean,false),case when (payload->>'walk_in')::boolean then 'checked_in' else 'scheduled' end,case when (payload->>'walk_in')::boolean then now() end) returning id into rid;
 when 'appointment.status' then
 perform clinic.require_permission('schedule');
 select * into row_appointment from clinic.appointments where id=(payload->>'id')::uuid;
 if not found then raise exception 'Appointment not found'; end if;
 if row_appointment.version<>(payload->>'version')::integer then raise exception 'Appointment changed. Refresh first.' using errcode='40001'; end if;
 if not ((row_appointment.status='scheduled' and payload->>'status' in ('checked_in','cancelled','no_show')) or (row_appointment.status='checked_in' and payload->>'status' in ('in_care','cancelled')) or (row_appointment.status='in_care' and payload->>'status'='completed')) then raise exception 'Invalid appointment status transition'; end if;
 if payload->>'status' in ('cancelled','no_show') and length(trim(coalesce(payload->>'reason','')))<3 then raise exception 'A reason is required'; end if;
 update clinic.appointments set status=payload->>'status',checked_in_at=case when payload->>'status'='checked_in' then now() else checked_in_at end,cancellation_reason=payload->>'reason',version=version+1 where id=row_appointment.id returning id into rid;
 when 'encounter.save' then
 perform clinic.require_permission('clinical');
 if nullif(payload->>'id','') is null then
 insert into clinic.encounters(organization_id,patient_id,doctor_id,branch_id,appointment_id,chief_complaint,history,allergies,findings,diagnosis,plan,prescriptions,clinical_sex_notes,birth_snapshot)
 values(o,p,actor,clinic.branch_id(),nullif(payload->>'appointment_id','')::uuid,payload->>'chief_complaint',coalesce(payload->>'history',''),coalesce(payload->>'allergies','Not reviewed'),coalesce(payload->>'findings',''),coalesce(payload->>'diagnosis',''),coalesce(payload->>'plan',''),coalesce(payload->>'prescriptions',''),coalesce(payload->>'clinical_sex_notes',''),jsonb_build_object('birth_date',row_patient.birth_date,'precision',row_patient.birth_precision,'reported_age',row_patient.reported_age,'age_recorded_on',row_patient.age_recorded_on)) returning id into rid;
 else
 select * into row_enc from clinic.encounters where id=(payload->>'id')::uuid;
 if not found or row_enc.doctor_id<>actor then raise exception 'Only the author may edit this draft' using errcode='42501'; end if;
 if row_enc.version<>(payload->>'version')::integer then raise exception 'Encounter changed. Refresh and compare your changes.' using errcode='40001'; end if;
 update clinic.encounters set chief_complaint=payload->>'chief_complaint',history=coalesce(payload->>'history',''),allergies=coalesce(payload->>'allergies','Not reviewed'),findings=coalesce(payload->>'findings',''),diagnosis=coalesce(payload->>'diagnosis',''),plan=coalesce(payload->>'plan',''),prescriptions=coalesce(payload->>'prescriptions',''),clinical_sex_notes=coalesce(payload->>'clinical_sex_notes',''),version=version+1 where id=row_enc.id returning id into rid;
 end if;
 when 'encounter.sign' then
 perform clinic.require_permission('clinical');
 select * into row_enc from clinic.encounters where id=(payload->>'id')::uuid;
 if not found or row_enc.doctor_id<>actor then raise exception 'Only the author may sign' using errcode='42501'; end if;
 if row_enc.version<>(payload->>'version')::integer then raise exception 'Encounter changed. Refresh first.' using errcode='40001'; end if;
 if length(trim(row_enc.diagnosis))=0 or length(trim(row_enc.plan))=0 or row_enc.allergies in ('','Not reviewed') then raise exception 'Review allergies, diagnosis and plan before signing'; end if;
 update clinic.encounters set status='signed',signed_at=now(),version=version+1 where id=row_enc.id returning id into rid;
 when 'encounter.addendum' then
 perform clinic.require_permission('clinical');
 if not exists(select 1 from clinic.encounters where id=e and status='signed') then raise exception 'Select a signed encounter'; end if;
 insert into clinic.addenda(organization_id,encounter_id,content) values(o,e,payload->>'content') returning id into rid;
 when 'procedure.create' then
 perform clinic.require_permission('clinical');
 if not exists(select 1 from clinic.encounters where id=e and patient_id=p) then raise exception 'Encounter does not belong to patient'; end if;
 if not exists(select 1 from clinic.consents c where patient_id=p and purpose='procedure' and granted and not exists(select 1 from clinic.consents n where n.patient_id=p and n.purpose=c.purpose and n.created_at>c.created_at)) then raise exception 'Current procedure consent is required'; end if;
 insert into clinic.procedures(organization_id,patient_id,encounter_id,name,body_site,product,lot_number,settings,quantity,aftercare,adverse_event) values(o,p,e,payload->>'name',payload->>'body_site',payload->>'product',payload->>'lot_number',payload->>'settings',nullif(payload->>'quantity','')::numeric,payload->>'aftercare',payload->>'adverse_event') returning id into rid;
 when 'consent.record' then
 perform clinic.require_permission('patients');
 if payload->>'purpose'<>'communication' then perform clinic.require_permission('clinical'); end if;
 insert into clinic.consents(organization_id,patient_id,purpose,granted,template_version,evidence) values(o,p,payload->>'purpose',(payload->>'granted')::boolean,payload->>'template_version',payload->>'evidence') returning id into rid;
 when 'task.create' then
 perform clinic.require_permission('results');
 if not exists(select 1 from clinic.memberships where user_id=(payload->>'assigned_to')::uuid and organization_id=o and active and role='doctor') then raise exception 'Select an active clinician'; end if;
 insert into clinic.tasks(organization_id,patient_id,title,due_at,assigned_to) values(o,p,payload->>'title',(payload->>'due_at')::timestamptz,(payload->>'assigned_to')::uuid) returning id into rid;
 when 'task.complete' then
 perform clinic.require_permission('results');
 update clinic.tasks set completed_at=now() where id=(payload->>'id')::uuid and completed_at is null returning id into rid;
 when 'result.create' then
 perform clinic.require_permission('results');
 insert into clinic.results(organization_id,patient_id,order_name,body_site,specimen_reference,due_at,assigned_to) values(o,p,payload->>'order_name',payload->>'body_site',payload->>'specimen_reference',(payload->>'due_at')::timestamptz,actor) returning id into rid;
 when 'result.update' then
 perform clinic.require_permission('results');
 select * into row_result from clinic.results where id=(payload->>'id')::uuid;
 if not found then raise exception 'Result not found'; end if;
 if row_result.version<>(payload->>'version')::integer then raise exception 'Result changed. Refresh first.' using errcode='40001'; end if;
 if not ((row_result.status='ordered' and payload->>'status'='received') or (row_result.status='received' and payload->>'status'='reviewed') or (row_result.status='reviewed' and payload->>'status'='notified') or (row_result.status='notified' and payload->>'status'='closed')) then raise exception 'Review and patient notification must happen in order'; end if;
 if length(trim(coalesce(payload->>'result_text','')))<3 then raise exception 'Document the result, review or communication evidence'; end if;
 update clinic.results set status=payload->>'status',result_text=coalesce(result_text||E'\n','')||'['||(payload->>'status')||'] '||(payload->>'result_text'),version=version+1 where id=row_result.id returning id into rid;
 when 'service.save' then
 perform clinic.require_permission('settings');
 insert into clinic.services(organization_id,name,name_ckb,category,currency,price,duration) values(o,payload->>'name',coalesce(payload->>'name_ckb',''),payload->>'category',curr,(payload->>'price')::numeric,(payload->>'duration')::integer) returning id into rid;
 when 'invoice.issue' then
 perform clinic.require_permission('billing');
 if jsonb_typeof(payload->'lines')<>'array' or jsonb_array_length(payload->'lines') not between 1 and 100 then raise exception 'Invoice must have 1–100 lines'; end if;
 for line in select * from jsonb_array_elements(payload->'lines') loop
 select to_jsonb(s) into result from clinic.services s where s.id=(line->>'service_id')::uuid and organization_id=o and active;
 if result is null or result->>'currency'<>curr then raise exception 'Invoice lines must use active services in the invoice currency'; end if;
 amt:=(result->>'price')::numeric * (line->>'quantity')::integer;
 if (line->>'quantity')::integer not between 1 and 1000 then raise exception 'Invalid quantity'; end if;
 total:=total+amt;
 lines:=lines||jsonb_build_array(jsonb_build_object('service_id',result->>'id','description',result->>'name','quantity',(line->>'quantity')::integer,'unit_price',result->>'price','amount',amt));
 end loop;
 num:='INV-'||lpad(((select count(*) from clinic.invoices where organization_id=o)+1)::text,6,'0');
 insert into clinic.invoices(organization_id,patient_id,invoice_number,patient_snapshot,currency,lines,total) values(o,p,num,jsonb_build_object('full_name',row_patient.full_name,'patient_number',row_patient.patient_number),curr,lines,total) returning id into rid;
 perform clinic.post_journal(curr,num,'invoice',rid,'receivable','revenue',total);
 when 'payment.record' then
 perform clinic.require_permission('billing');
 a:=nullif(payload->>'invoice_id','')::uuid;
 if amt is null then raise exception 'Payment amount is required'; end if;
 if a is not null then
 select * into row_invoice from clinic.invoices where id=a and patient_id=p;
 if not found or row_invoice.currency<>curr then raise exception 'Invoice or currency mismatch'; end if;
 select row_invoice.total-coalesce((select sum(amount) from clinic.payments pm where invoice_id=a and pm.kind in ('payment','deposit_application')),0)-coalesce((select sum(amount) from clinic.credit_notes where invoice_id=a),0)+coalesce((select sum(amount) from clinic.payments pm where invoice_id=a and pm.kind='refund'),0) into due;
 if amt>due then raise exception 'Payment exceeds the outstanding invoice balance'; end if;
 end if;
 if method='deposit' then raise exception 'Use Apply deposit for existing patient credit'; end if;
 insert into clinic.payments(organization_id,patient_id,invoice_id,currency,amount,method,kind) values(o,p,a,curr,amt,method,case when a is null then 'deposit' else 'payment' end) returning id into rid;
 perform clinic.post_journal(curr,'Patient receipt','payment',rid,method,case when a is null then 'deposits' else 'receivable' end,amt);
 when 'deposit.apply' then
 perform clinic.require_permission('billing');
 a:=(payload->>'invoice_id')::uuid;
 select * into row_invoice from clinic.invoices where id=a and patient_id=p;
 if not found or row_invoice.currency<>curr then raise exception 'Invoice or currency mismatch'; end if;
 select coalesce(sum(case when pm.kind='deposit' then amount when pm.kind='deposit_application' then -amount when pm.kind='refund' and invoice_id is null then -amount else 0 end),0) into total from clinic.payments pm where patient_id=p and currency=curr;
 select row_invoice.total-coalesce((select sum(amount) from clinic.payments pm where invoice_id=a and pm.kind in ('payment','deposit_application')),0)-coalesce((select sum(amount) from clinic.credit_notes where invoice_id=a),0)+coalesce((select sum(amount) from clinic.payments pm where invoice_id=a and pm.kind='refund'),0) into due;
 if amt is null or amt>total or amt>due then raise exception 'Insufficient deposit or invoice balance'; end if;
 insert into clinic.payments(organization_id,patient_id,invoice_id,currency,amount,method,kind) values(o,p,a,curr,amt,'deposit','deposit_application') returning id into rid;
 perform clinic.post_journal(curr,'Apply patient deposit','deposit_application',rid,'deposits','receivable',amt);
 when 'refund.record' then
 perform clinic.require_permission('approve');
 select * into row_payment from clinic.payments pm where id=(payload->>'payment_id')::uuid and pm.kind in ('payment','deposit');
 if not found then raise exception 'Original payment not found'; end if;
 if length(trim(coalesce(payload->>'reason','')))<5 then raise exception 'A refund reason is required'; end if;
 if amt is null or curr<>row_payment.currency or amt>row_payment.amount-coalesce((select sum(amount) from clinic.payments pm where original_payment_id=row_payment.id and pm.kind='refund'),0) then raise exception 'Refund exceeds the unrefunded original payment'; end if;
 if row_payment.kind='deposit' then
 select coalesce(sum(case when pm.kind='deposit' then amount when pm.kind='deposit_application' then -amount when pm.kind='refund' and invoice_id is null then -amount else 0 end),0) into total from clinic.payments pm where patient_id=row_payment.patient_id and currency=curr;
 if amt>total then raise exception 'Deposit has already been used'; end if;
 else
 insert into clinic.credit_notes(organization_id,invoice_id,amount,reason) values(o,row_payment.invoice_id,amt,payload->>'reason') returning id into a;
 perform clinic.post_journal(curr,'Service credit','credit_note',a,'revenue','receivable',amt);
 end if;
 insert into clinic.payments(organization_id,patient_id,invoice_id,currency,amount,method,kind,original_payment_id,reason) values(o,row_payment.patient_id,row_payment.invoice_id,curr,amt,row_payment.method,'refund',row_payment.id,payload->>'reason') returning id into rid;
 perform clinic.post_journal(curr,'Patient refund','refund',rid,case when row_payment.kind='deposit' then 'deposits' else 'receivable' end,row_payment.method,amt);
 when 'expense.record' then
 perform clinic.require_permission('finance');
 if payload->>'category'='salary' then perform clinic.require_permission('payroll'); end if;
 if amt is null then raise exception 'Amount is required'; end if;
 insert into clinic.expenses(organization_id,category,supplier,description,currency,amount,paid,method) values(o,payload->>'category',payload->>'supplier',payload->>'description',curr,amt,(payload->>'paid')::boolean,method) returning id into rid;
 perform clinic.post_journal(curr,payload->>'description','expense',rid,'expense',case when (payload->>'paid')::boolean then method else 'payable' end,amt);
 when 'cash.record' then
 perform clinic.require_permission('approve');
 if amt is null then raise exception 'Amount is required'; end if;
 insert into clinic.cash_movements(organization_id,kind,currency,amount,method,destination,description) values(o,payload->>'kind',curr,amt,method,nullif(payload->>'destination',''),payload->>'description') returning id into rid;
 perform clinic.post_journal(curr,payload->>'description','cash_movement',rid,
 case when payload->>'kind'='owner_withdrawal' then 'equity' when payload->>'kind'='transfer' then payload->>'destination' else method end,
 case when payload->>'kind'='owner_withdrawal' or payload->>'kind'='transfer' then method when payload->>'kind'='owner_loan' then 'owner_loan' else 'equity' end,amt);
 when 'fx.exchange' then
 perform clinic.require_permission('approve'); rate:=(payload->>'rate')::numeric;
 if amt is null or rate<=0 or rate<>round(rate,6) or curr=payload->>'destination_currency' or payload->>'destination_currency' not in ('IQD','USD') then raise exception 'Provide two currencies and a positive explicit conversion rate'; end if;
 total:=round(amt*rate,case when payload->>'destination_currency'='USD' then 2 else 3 end);
 insert into clinic.cash_movements(organization_id,kind,currency,amount,method,description,fx_rate) values(o,'fx_exchange',curr,amt,method,'FX out: '||(payload->>'description'),rate) returning id into rid;
 insert into clinic.cash_movements(organization_id,kind,currency,amount,method,description,fx_rate,related_id) values(o,'fx_exchange',payload->>'destination_currency',total,method,'FX in: '||(payload->>'description'),rate,rid) returning id into a;
 perform clinic.post_journal(curr,'FX out','fx',rid,'fx_clearing',method,amt);
 perform clinic.post_journal(payload->>'destination_currency','FX in','fx',a,method,'fx_clearing',total);
 when 'stock.receive' then
 perform clinic.require_permission('inventory');
 if amt is null then raise exception 'Quantity required'; end if;
 insert into clinic.stock_lots(organization_id,product,lot_number,expires_on,unit,quantity) values(o,payload->>'product',payload->>'lot_number',(payload->>'expires_on')::date,payload->>'unit',amt)
 on conflict(organization_id,product,lot_number) do update set quantity=clinic.stock_lots.quantity+excluded.quantity,version=clinic.stock_lots.version+1 returning id into rid;
 insert into clinic.stock_movements(organization_id,lot_id,quantity,reason) values(o,rid,amt,'Receipt');
 when 'stock.use' then
 perform clinic.require_permission('clinical');
 select * into row_lot from clinic.stock_lots where id=(payload->>'lot_id')::uuid;
 if not found or row_lot.expires_on<(now() at time zone 'Asia/Baghdad')::date or amt is null or amt>row_lot.quantity then raise exception 'Insufficient or expired stock'; end if;
 if not exists(select 1 from clinic.encounters where id=e) then raise exception 'A clinical encounter is required'; end if;
 update clinic.stock_lots set quantity=quantity-amt,version=version+1 where id=row_lot.id;
 insert into clinic.stock_movements(organization_id,lot_id,encounter_id,quantity,reason) values(o,row_lot.id,e,-amt,payload->>'reason') returning id into rid;
 when 'till.open' then
 perform clinic.require_permission('billing');
 if (payload->>'opening')::numeric<0 then raise exception 'Opening amount must not be negative'; end if;
 insert into clinic.tills(organization_id,currency,opening) values(o,curr,(payload->>'opening')::numeric) returning id into rid;
 when 'till.close' then
 perform clinic.require_permission('billing');
 select * into row_till from clinic.tills where id=(payload->>'id')::uuid and closed_at is null;
 if not found then raise exception 'Open till not found'; end if;
 select row_till.opening+coalesce(sum(l.debit-l.credit),0) into total from clinic.journal_lines l join clinic.journals j on j.id=l.journal_id where j.currency=row_till.currency and l.account='cash' and j.created_at>=row_till.opened_at;
 if (payload->>'counted')::numeric<0 or ((payload->>'counted')::numeric<>total and length(trim(coalesce(payload->>'reason','')))<5) then raise exception 'Document the reason for a cash discrepancy'; end if;
 update clinic.tills set closed_at=now(),expected=total,counted=(payload->>'counted')::numeric,reason=payload->>'reason' where id=row_till.id returning id into rid;
 when 'settings.update' then
 perform clinic.require_permission('settings');
 update clinic.organizations set name=payload->>'name',require_mfa=coalesce((payload->>'require_mfa')::boolean,true) where id=o returning id into rid;
 when 'package.sell' then
 perform clinic.require_permission('billing');
 if amt is null or (payload->>'sessions')::integer not between 1 and 1000 then raise exception 'Package amount and valid session count are required'; end if;
 insert into clinic.packages(organization_id,patient_id,name,sessions,remaining,currency,total) values(o,p,payload->>'name',(payload->>'sessions')::integer,(payload->>'sessions')::integer,curr,amt) returning id into rid;
 perform clinic.post_journal(curr,'Prepaid treatment package','package_sale',rid,method,'deposits',amt);
 when 'package.redeem' then
 perform clinic.require_permission('billing');
 select * into row_package from clinic.packages where id=(payload->>'package_id')::uuid and patient_id=p;
 e:=(payload->>'encounter_id')::uuid;
 if not found or row_package.remaining<=0 then raise exception 'Package has no available sessions'; end if;
 if clinic.billing_encounter_patient(e) is distinct from p then raise exception 'A signed encounter for this patient is required'; end if;
 total:=case when row_package.remaining=1 then row_package.total-row_package.redeemed_value else round(row_package.total/row_package.sessions,case when row_package.currency='USD' then 2 else 3 end) end;
 insert into clinic.package_redemptions(organization_id,package_id,encounter_id) values(o,row_package.id,e) returning id into rid;
 update clinic.packages set remaining=remaining-1,redeemed_value=redeemed_value+total where id=row_package.id;
 if total>0 then perform clinic.post_journal(row_package.currency,'Treatment package session','package_redemption',rid,'deposits','revenue',total); end if;
 when 'expense.pay' then
 perform clinic.require_permission('finance');
 select amount,currency into total,curr from clinic.expenses where id=(payload->>'expense_id')::uuid and not paid;
 if not found or exists(select 1 from clinic.journals where source_type='expense_payment' and source_id=(payload->>'expense_id')::uuid) then raise exception 'Unpaid expense not found or already settled'; end if;
 rid:=clinic.post_journal(curr,'Supplier payable settlement','expense_payment',(payload->>'expense_id')::uuid,'payable',method,total);
 when 'member.update' then
 perform clinic.require_permission('staff');
 a:=(payload->>'user_id')::uuid;
 if a=actor then raise exception 'You cannot change your own access'; end if;
 if payload->>'role' not in ('owner','administrator','doctor','receptionist','accountant') then raise exception 'Invalid role'; end if;
 update clinic.memberships set role=payload->>'role',active=(payload->>'active')::boolean where user_id=a and organization_id=o returning id into rid;
 else raise exception 'Unsupported operation: %',kind using errcode='22023';
 end case;
 if rid is null then raise exception 'No record was changed. Refresh and verify your access.' using errcode='P0002'; end if;
 result:=jsonb_build_object('id',rid);
 insert into clinic.requests(organization_id,actor_id,request_id,fingerprint,result) values(o,actor,command.request_id,fingerprint,result);
 return result;
end $function$;

CREATE OR REPLACE FUNCTION public.media_access (
  media_id uuid
)
  RETURNS text
  LANGUAGE plpgsql
  SET search_path TO ''
  AS $function$
declare m clinic.media;
begin
 perform clinic.require_permission('media');
 select * into m from clinic.media where id=media_id and organization_id=clinic.org_id() and status='ready';
 if not found then raise exception 'Media not found or not ready' using errcode='42501'; end if;
 if not coalesce((select granted from clinic.consents where patient_id=m.patient_id and purpose=m.purpose order by created_at desc limit 1),false) then raise exception 'Current consent does not permit access' using errcode='42501'; end if;
 perform clinic.log_access('MEDIA_ACCESS',m.id,'media'); return m.object_key;
end $function$;

CREATE OR REPLACE FUNCTION public.media_finalize (
  media_id uuid,
  approved boolean
)
  RETURNS void
  LANGUAGE plpgsql
  SET search_path TO ''
  AS $function$
begin
 if current_user<>'service_role' then raise exception 'Server-only operation' using errcode='42501'; end if;
 update clinic.media set status=case when approved then 'ready' else 'rejected' end where id=media_id and status='pending';
end $function$;

CREATE OR REPLACE FUNCTION public.media_prepare (
  media_id     uuid,
  patient_id   uuid,
  consent_id   uuid,
  title        text,
  body_site    text,
  mime_type    text,
  content_hash text
)
  RETURNS jsonb
  LANGUAGE plpgsql
  SET search_path TO ''
  AS $function$
declare c clinic.consents; existing clinic.media; key text;
begin
 perform clinic.require_permission('media');
 select * into c from clinic.consents where id=consent_id and organization_id=clinic.org_id() and clinic.consents.patient_id=media_prepare.patient_id and purpose='care_photography' and granted;
 if not found or exists(select 1 from clinic.consents n where n.patient_id=media_prepare.patient_id and n.purpose=c.purpose and n.created_at>c.created_at) then raise exception 'Valid current photography consent is required'; end if;
 if length(trim(title))=0 or length(trim(body_site))=0 or content_hash !~ '^[a-f0-9]{64}$' then raise exception 'Invalid media metadata'; end if;
 select * into existing from clinic.media where id=media_id;
 if found then
 if existing.patient_id<>patient_id or existing.title<>title or existing.body_site<>body_site or existing.object_key not like '%'||content_hash then raise exception 'Upload identifier already used for a different file'; end if;
 return jsonb_build_object('id',existing.id,'key',existing.object_key,'status',existing.status);
 end if;
 key:=clinic.org_id()::text||'/'||media_id::text||'/'||content_hash;
 insert into clinic.media(id,organization_id,patient_id,consent_id,title,body_site,mime_type,object_key) values(media_id,clinic.org_id(),patient_id,consent_id,title,body_site,mime_type,key);
 return jsonb_build_object('id',media_id,'key',key,'status','pending');
end $function$;

CREATE OR REPLACE FUNCTION public.patient_profile (
  patient_id uuid
)
  RETURNS jsonb
  LANGUAGE sql
  STABLE
  SET search_path TO ''
  AS $function$ select to_jsonb(p) from clinic.patients p where id=patient_id and organization_id=clinic.org_id() $function$;

CREATE OR REPLACE FUNCTION public.patient_search (
  search_term text    DEFAULT ''::text,
  cursor_id   uuid    DEFAULT NULL::uuid,
  page_size   integer DEFAULT 50
)
  RETURNS jsonb
  LANGUAGE plpgsql
  STABLE
  SET search_path TO ''
  AS $function$
declare items jsonb; more boolean; sz integer:=least(greatest(page_size,1),100);
begin
 perform clinic.require_permission('patients');
 select coalesce(jsonb_agg(x),'[]') into items from (select * from clinic.patients where organization_id=clinic.org_id() and merged_into is null and (cursor_id is null or id>cursor_id) and (clinic.search_key(full_name) like '%'||clinic.search_key(left(search_term,200))||'%' or phone like '%'||clinic.search_key(left(search_term,200))||'%' or patient_number ilike '%'||left(search_term,200)||'%') order by id limit sz+1) x;
 more:=jsonb_array_length(items)>sz;
 if more then items:=items-sz; end if;
 return jsonb_build_object('items',items,'has_more',more);
end $function$;

CREATE OR REPLACE FUNCTION public.provision_member (
  org_id      uuid,
  member_id   uuid,
  member_name text,
  member_role text
)
  RETURNS uuid
  LANGUAGE plpgsql
  SET search_path TO ''
  AS $function$
declare r uuid;
begin
 if current_user<>'service_role' then raise exception 'Server-only operation' using errcode='42501'; end if;
 insert into clinic.memberships(organization_id,user_id,display_name,role) values(org_id,member_id,member_name,member_role) returning id into r; return r;
end $function$;

CREATE OR REPLACE FUNCTION public.workspace()
  RETURNS jsonb
  LANGUAGE plpgsql
  SET search_path TO ''
  AS $function$
declare o uuid:=clinic.org_id(); m clinic.memberships; r jsonb;
begin
 if o is null then raise exception 'No active clinic membership. Ask the owner to invite your account.' using errcode='42501'; end if;
 select * into m from clinic.memberships where organization_id=o and user_id=auth.uid();
 r:=jsonb_build_object('organization',(select to_jsonb(x) from clinic.organizations x where id=o),'membership',to_jsonb(m),'permissions',case when exists(select 1 from clinic.organizations where id=o and (not require_mfa or auth.jwt()->>'aal'='aal2')) then to_jsonb(clinic.permissions(m.role)) else '[]'::jsonb end);
 r:=r || jsonb_build_object(
 'patients',coalesce((select jsonb_agg(x) from (select * from clinic.patients where organization_id=o order by created_at desc limit 300) x),'[]'),
 'appointments',coalesce((select jsonb_agg(x) from (select * from clinic.appointments where organization_id=o and starts_at>now()-interval '30 days' order by starts_at limit 500) x),'[]'),
 'encounters',coalesce((select jsonb_agg(x) from (select id,patient_id,doctor_id,status,chief_complaint,created_at,version from clinic.encounters where organization_id=o order by created_at desc limit 300) x),'[]'),
 'services',coalesce((select jsonb_agg(x) from clinic.services x where organization_id=o and active),'[]'),
 'invoices',coalesce((select jsonb_agg(x) from (select i.*,i.total-coalesce((select sum(pm.amount) from clinic.payments pm where pm.invoice_id=i.id and pm.kind in ('payment','deposit_application')),0)-coalesce((select sum(c.amount) from clinic.credit_notes c where c.invoice_id=i.id),0)+coalesce((select sum(pm.amount) from clinic.payments pm where pm.invoice_id=i.id and pm.kind='refund'),0) balance from clinic.invoices i where organization_id=o order by created_at desc limit 300) x),'[]'),
 'payments',coalesce((select jsonb_agg(x) from (select * from clinic.payments pm where organization_id=o order by created_at desc limit 500) x),'[]'),
 'expenses',coalesce((select jsonb_agg(x) from (select * from clinic.expenses where organization_id=o order by created_at desc limit 300) x),'[]'),
 'tasks',coalesce((select jsonb_agg(x) from (select * from clinic.tasks where organization_id=o order by due_at limit 300) x),'[]'),
 'results',coalesce((select jsonb_agg(x) from (select * from clinic.results where organization_id=o order by created_at desc limit 300) x),'[]'),
 'consents',coalesce((select jsonb_agg(x) from (select * from clinic.consents where organization_id=o order by created_at desc limit 500) x),'[]'),
 'media',coalesce((select jsonb_agg(x) from (select * from clinic.media where organization_id=o order by created_at desc limit 300) x),'[]'),
 'stock',coalesce((select jsonb_agg(x) from clinic.stock_lots x where organization_id=o),'[]'),
 'movements',coalesce((select jsonb_agg(x) from (select * from clinic.cash_movements where organization_id=o order by created_at desc limit 300) x),'[]'),
 'journals',coalesce((select jsonb_agg(x) from (select j.*, (select jsonb_agg(l) from clinic.journal_lines l where l.journal_id=j.id) lines from clinic.journals j where organization_id=o order by created_at desc limit 500) x),'[]'),
 'tills',coalesce((select jsonb_agg(x) from (select * from clinic.tills where organization_id=o order by opened_at desc limit 100) x),'[]'),
 'members',coalesce((select jsonb_agg(x) from clinic.memberships x where organization_id=o),'[]'),
 'audit',coalesce((select jsonb_agg(x) from (select * from clinic.audit_events where organization_id=o order by created_at desc limit 200) x),'[]'),
 'packages',coalesce((select jsonb_agg(x) from clinic.packages x where organization_id=o),'[]'),
 'billable_encounters',clinic.billable_encounters(),
 'trial_balance',coalesce((select jsonb_agg(x) from (select j.currency,l.account,sum(l.debit) debit,sum(l.credit) credit from clinic.journal_lines l join clinic.journals j on j.id=l.journal_id where j.organization_id=o group by j.currency,l.account) x),'[]'));
 if clinic.allowed('clinical') then perform clinic.log_access('WORKSPACE_READ',null,'clinical_summary'); end if;
 return r;
end $function$;

ALTER TABLE "clinic"."appointments"
  ADD CONSTRAINT "appointments_doctor_id_fkey" FOREIGN KEY (doctor_id) REFERENCES auth.users(id);

ALTER TABLE "clinic"."appointments"
  ADD CONSTRAINT "appointments_organization_id_branch_id_fkey" FOREIGN KEY (organization_id, branch_id) REFERENCES clinic.branches(organization_id, id);

ALTER TABLE "clinic"."encounters"
  ADD CONSTRAINT "encounters_doctor_id_fkey" FOREIGN KEY (doctor_id) REFERENCES auth.users(id);

ALTER TABLE "clinic"."encounters"
  ADD CONSTRAINT "encounters_organization_id_appointment_id_fkey" FOREIGN KEY (organization_id, appointment_id) REFERENCES clinic.appointments(organization_id, id);

ALTER TABLE "clinic"."encounters"
  ADD CONSTRAINT "encounters_organization_id_branch_id_fkey" FOREIGN KEY (organization_id, branch_id) REFERENCES clinic.branches(organization_id, id);

ALTER TABLE "clinic"."addenda"
  ADD CONSTRAINT "addenda_organization_id_encounter_id_fkey" FOREIGN KEY (organization_id, encounter_id) REFERENCES clinic.encounters(organization_id, id);

ALTER TABLE "clinic"."credit_notes"
  ADD CONSTRAINT "credit_notes_organization_id_invoice_id_fkey" FOREIGN KEY (organization_id, invoice_id) REFERENCES clinic.invoices(organization_id, id);

ALTER TABLE "clinic"."journal_lines"
  ADD CONSTRAINT "journal_lines_organization_id_journal_id_fkey" FOREIGN KEY (organization_id, journal_id) REFERENCES clinic.journals(organization_id, id);

ALTER TABLE "clinic"."media"
  ADD CONSTRAINT "media_organization_id_consent_id_fkey" FOREIGN KEY (organization_id, consent_id) REFERENCES clinic.consents(organization_id, id);

ALTER TABLE "clinic"."media"
  ADD CONSTRAINT "media_organization_id_encounter_id_fkey" FOREIGN KEY (organization_id, encounter_id) REFERENCES clinic.encounters(organization_id, id);

ALTER TABLE "clinic"."memberships"
  ADD CONSTRAINT "memberships_user_id_fkey" FOREIGN KEY (user_id) REFERENCES auth.users(id);

ALTER TABLE "clinic"."appointments"
  ADD CONSTRAINT "appointments_organization_id_fkey" FOREIGN KEY (organization_id) REFERENCES clinic.organizations(id);

ALTER TABLE "clinic"."branches"
  ADD CONSTRAINT "branches_organization_id_fkey" FOREIGN KEY (organization_id) REFERENCES clinic.organizations(id);

ALTER TABLE "clinic"."encounters"
  ADD CONSTRAINT "encounters_organization_id_fkey" FOREIGN KEY (organization_id) REFERENCES clinic.organizations(id);

ALTER TABLE "clinic"."memberships"
  ADD CONSTRAINT "memberships_organization_id_fkey" FOREIGN KEY (organization_id) REFERENCES clinic.organizations(id);

ALTER TABLE "clinic"."package_redemptions"
  ADD CONSTRAINT "package_redemptions_organization_id_encounter_id_fkey" FOREIGN KEY (organization_id, encounter_id) REFERENCES clinic.encounters(organization_id, id);

ALTER TABLE "clinic"."package_redemptions"
  ADD CONSTRAINT "package_redemptions_organization_id_package_id_fkey" FOREIGN KEY (organization_id, package_id) REFERENCES clinic.packages(organization_id, id);

ALTER TABLE "clinic"."patients"
  ADD CONSTRAINT "patients_organization_id_fkey" FOREIGN KEY (organization_id) REFERENCES clinic.organizations(id);

ALTER TABLE "clinic"."appointments"
  ADD CONSTRAINT "appointments_organization_id_patient_id_fkey" FOREIGN KEY (organization_id, patient_id) REFERENCES clinic.patients(organization_id, id);

ALTER TABLE "clinic"."consents"
  ADD CONSTRAINT "consents_organization_id_patient_id_fkey" FOREIGN KEY (organization_id, patient_id) REFERENCES clinic.patients(organization_id, id);

ALTER TABLE "clinic"."contacts"
  ADD CONSTRAINT "contacts_organization_id_patient_id_fkey" FOREIGN KEY (organization_id, patient_id) REFERENCES clinic.patients(organization_id, id);

ALTER TABLE "clinic"."encounters"
  ADD CONSTRAINT "encounters_organization_id_patient_id_fkey" FOREIGN KEY (organization_id, patient_id) REFERENCES clinic.patients(organization_id, id);

ALTER TABLE "clinic"."invoices"
  ADD CONSTRAINT "invoices_organization_id_patient_id_fkey" FOREIGN KEY (organization_id, patient_id) REFERENCES clinic.patients(organization_id, id);

ALTER TABLE "clinic"."media"
  ADD CONSTRAINT "media_organization_id_patient_id_fkey" FOREIGN KEY (organization_id, patient_id) REFERENCES clinic.patients(organization_id, id);

ALTER TABLE "clinic"."packages"
  ADD CONSTRAINT "packages_organization_id_patient_id_fkey" FOREIGN KEY (organization_id, patient_id) REFERENCES clinic.patients(organization_id, id);

ALTER TABLE "clinic"."patient_merges"
  ADD CONSTRAINT "patient_merges_organization_id_source_id_fkey" FOREIGN KEY (organization_id, source_id) REFERENCES clinic.patients(organization_id, id);

ALTER TABLE "clinic"."patient_merges"
  ADD CONSTRAINT "patient_merges_organization_id_target_id_fkey" FOREIGN KEY (organization_id, target_id) REFERENCES clinic.patients(organization_id, id);

ALTER TABLE "clinic"."patients"
  ADD CONSTRAINT "patients_organization_id_merged_into_fkey" FOREIGN KEY (organization_id, merged_into) REFERENCES clinic.patients(organization_id, id);

ALTER TABLE "clinic"."payments"
  ADD CONSTRAINT "payments_organization_id_invoice_id_fkey" FOREIGN KEY (organization_id, invoice_id) REFERENCES clinic.invoices(organization_id, id);

ALTER TABLE "clinic"."payments"
  ADD CONSTRAINT "payments_organization_id_original_payment_id_fkey" FOREIGN KEY (organization_id, original_payment_id) REFERENCES clinic.payments(organization_id, id);

ALTER TABLE "clinic"."payments"
  ADD CONSTRAINT "payments_organization_id_patient_id_fkey" FOREIGN KEY (organization_id, patient_id) REFERENCES clinic.patients(organization_id, id);

ALTER TABLE "clinic"."procedures"
  ADD CONSTRAINT "procedures_organization_id_encounter_id_fkey" FOREIGN KEY (organization_id, encounter_id) REFERENCES clinic.encounters(organization_id, id);

ALTER TABLE "clinic"."procedures"
  ADD CONSTRAINT "procedures_organization_id_patient_id_fkey" FOREIGN KEY (organization_id, patient_id) REFERENCES clinic.patients(organization_id, id);

ALTER TABLE "clinic"."results"
  ADD CONSTRAINT "results_assigned_to_fkey" FOREIGN KEY (assigned_to) REFERENCES auth.users(id);

ALTER TABLE "clinic"."results"
  ADD CONSTRAINT "results_organization_id_patient_id_fkey" FOREIGN KEY (organization_id, patient_id) REFERENCES clinic.patients(organization_id, id);

ALTER TABLE "clinic"."services"
  ADD CONSTRAINT "services_organization_id_fkey" FOREIGN KEY (organization_id) REFERENCES clinic.organizations(id);

ALTER TABLE "clinic"."stock_movements"
  ADD CONSTRAINT "stock_movements_organization_id_encounter_id_fkey" FOREIGN KEY (organization_id, encounter_id) REFERENCES clinic.encounters(organization_id, id);

ALTER TABLE "clinic"."stock_movements"
  ADD CONSTRAINT "stock_movements_organization_id_lot_id_fkey" FOREIGN KEY (organization_id, lot_id) REFERENCES clinic.stock_lots(organization_id, id);

ALTER TABLE "clinic"."tasks"
  ADD CONSTRAINT "tasks_assigned_to_fkey" FOREIGN KEY (assigned_to) REFERENCES auth.users(id);

ALTER TABLE "clinic"."tasks"
  ADD CONSTRAINT "tasks_organization_id_patient_id_fkey" FOREIGN KEY (organization_id, patient_id) REFERENCES clinic.patients(organization_id, id);

CREATE INDEX addenda_organization_id_encounter_id_fkey_idx ON clinic.addenda USING btree (organization_id, encounter_id);

CREATE INDEX appointment_clinician ON clinic.appointments USING btree (organization_id, doctor_id, starts_at, ends_at)
  WHERE (status <> ALL (ARRAY['cancelled'::text, 'no_show'::text]));

CREATE INDEX appointment_day ON clinic.appointments USING btree (organization_id, starts_at);

CREATE INDEX appointments_doctor_id_fkey_idx ON clinic.appointments USING btree (doctor_id);

CREATE INDEX appointments_organization_id_branch_id_fkey_idx ON clinic.appointments USING btree (organization_id, branch_id);

CREATE INDEX appointments_organization_id_fkey_idx ON clinic.appointments USING btree (organization_id);

CREATE INDEX appointments_organization_id_patient_id_fkey_idx ON clinic.appointments USING btree (organization_id, patient_id);

CREATE INDEX audit_time ON clinic.audit_events USING btree (organization_id, created_at DESC);

CREATE INDEX branches_organization_id_fkey_idx ON clinic.branches USING btree (organization_id);

CREATE INDEX consents_organization_id_patient_id_fkey_idx ON clinic.consents USING btree (organization_id, patient_id);

CREATE INDEX contacts_organization_id_patient_id_fkey_idx ON clinic.contacts USING btree (organization_id, patient_id);

CREATE INDEX credit_notes_organization_id_invoice_id_fkey_idx ON clinic.credit_notes USING btree (organization_id, invoice_id);

CREATE INDEX encounter_history ON clinic.encounters USING btree (organization_id, patient_id, created_at DESC);

CREATE INDEX encounters_doctor_id_fkey_idx ON clinic.encounters USING btree (doctor_id);

CREATE INDEX encounters_organization_id_appointment_id_fkey_idx ON clinic.encounters USING btree (organization_id, appointment_id);

CREATE INDEX encounters_organization_id_branch_id_fkey_idx ON clinic.encounters USING btree (organization_id, branch_id);

CREATE INDEX encounters_organization_id_fkey_idx ON clinic.encounters USING btree (organization_id);

CREATE INDEX encounters_organization_id_patient_id_fkey_idx ON clinic.encounters USING btree (organization_id, patient_id);

CREATE INDEX invoices_organization_id_patient_id_fkey_idx ON clinic.invoices USING btree (organization_id, patient_id);

CREATE INDEX journal_account ON clinic.journal_lines USING btree (organization_id, account, journal_id);

CREATE INDEX journal_lines_organization_id_journal_id_fkey_idx ON clinic.journal_lines USING btree (organization_id, journal_id);

CREATE INDEX media_organization_id_consent_id_fkey_idx ON clinic.media USING btree (organization_id, consent_id);

CREATE INDEX media_organization_id_encounter_id_fkey_idx ON clinic.media USING btree (organization_id, encounter_id);

CREATE INDEX media_organization_id_patient_id_fkey_idx ON clinic.media USING btree (organization_id, patient_id);

CREATE INDEX membership_identity ON clinic.memberships USING btree (user_id, organization_id)
  WHERE active;

CREATE INDEX memberships_organization_id_fkey_idx ON clinic.memberships USING btree (organization_id);

CREATE INDEX memberships_user_id_fkey_idx ON clinic.memberships USING btree (user_id);

CREATE INDEX package_redemptions_organization_id_encounter_id_fkey_idx ON clinic.package_redemptions USING btree (organization_id, encounter_id);

CREATE INDEX package_redemptions_organization_id_package_id_fkey_idx ON clinic.package_redemptions USING btree (organization_id, package_id);

CREATE INDEX packages_organization_id_patient_id_fkey_idx ON clinic.packages USING btree (organization_id, patient_id);

CREATE INDEX patient_merges_organization_id_source_id_fkey_idx ON clinic.patient_merges USING btree (organization_id, source_id);

CREATE INDEX patient_merges_organization_id_target_id_fkey_idx ON clinic.patient_merges USING btree (organization_id, target_id);

CREATE INDEX patient_phone ON clinic.patients USING btree (organization_id, phone);

CREATE INDEX patient_search ON clinic.patients USING btree (organization_id, lower(full_name));

CREATE INDEX patients_organization_id_fkey_idx ON clinic.patients USING btree (organization_id);

CREATE INDEX patients_organization_id_merged_into_fkey_idx ON clinic.patients USING btree (organization_id, merged_into);

CREATE INDEX payment_invoice ON clinic.payments USING btree (organization_id, invoice_id);

CREATE INDEX payments_organization_id_invoice_id_fkey_idx ON clinic.payments USING btree (organization_id, invoice_id);

CREATE INDEX payments_organization_id_original_payment_id_fkey_idx ON clinic.payments USING btree (organization_id, original_payment_id);

CREATE INDEX payments_organization_id_patient_id_fkey_idx ON clinic.payments USING btree (organization_id, patient_id);

CREATE INDEX procedures_organization_id_encounter_id_fkey_idx ON clinic.procedures USING btree (organization_id, encounter_id);

CREATE INDEX procedures_organization_id_patient_id_fkey_idx ON clinic.procedures USING btree (organization_id, patient_id);

CREATE INDEX results_assigned_to_fkey_idx ON clinic.results USING btree (assigned_to);

CREATE INDEX results_organization_id_patient_id_fkey_idx ON clinic.results USING btree (organization_id, patient_id);

CREATE INDEX services_organization_id_fkey_idx ON clinic.services USING btree (organization_id);

CREATE INDEX stock_movements_organization_id_encounter_id_fkey_idx ON clinic.stock_movements USING btree (organization_id, encounter_id);

CREATE INDEX stock_movements_organization_id_lot_id_fkey_idx ON clinic.stock_movements USING btree (organization_id, lot_id);

CREATE INDEX task_due ON clinic.tasks USING btree (organization_id, due_at)
  WHERE (completed_at IS NULL);

CREATE INDEX tasks_assigned_to_fkey_idx ON clinic.tasks USING btree (assigned_to);

CREATE INDEX tasks_organization_id_patient_id_fkey_idx ON clinic.tasks USING btree (organization_id, patient_id);

CREATE UNIQUE INDEX till_open ON clinic.tills USING btree (organization_id, currency)
  WHERE (closed_at IS NULL);

CREATE TRIGGER audit_write
  AFTER INSERT OR UPDATE ON clinic.addenda
  FOR EACH ROW
  EXECUTE FUNCTION clinic.audit_write();

CREATE TRIGGER immutable_record
  BEFORE DELETE OR UPDATE ON clinic.addenda
  FOR EACH ROW
  EXECUTE FUNCTION clinic.immutable_record();

CREATE TRIGGER audit_write
  AFTER INSERT OR UPDATE ON clinic.appointments
  FOR EACH ROW
  EXECUTE FUNCTION clinic.audit_write();

CREATE TRIGGER immutable_record
  BEFORE DELETE OR UPDATE ON clinic.audit_events
  FOR EACH ROW
  EXECUTE FUNCTION clinic.immutable_record();

CREATE TRIGGER audit_write
  AFTER INSERT OR UPDATE ON clinic.cash_movements
  FOR EACH ROW
  EXECUTE FUNCTION clinic.audit_write();

CREATE TRIGGER immutable_record
  BEFORE DELETE OR UPDATE ON clinic.cash_movements
  FOR EACH ROW
  EXECUTE FUNCTION clinic.immutable_record();

CREATE TRIGGER audit_write
  AFTER INSERT OR UPDATE ON clinic.consents
  FOR EACH ROW
  EXECUTE FUNCTION clinic.audit_write();

CREATE TRIGGER immutable_record
  BEFORE DELETE OR UPDATE ON clinic.consents
  FOR EACH ROW
  EXECUTE FUNCTION clinic.immutable_record();

CREATE TRIGGER audit_write
  AFTER INSERT OR UPDATE ON clinic.contacts
  FOR EACH ROW
  EXECUTE FUNCTION clinic.audit_write();

CREATE TRIGGER audit_write
  AFTER INSERT OR UPDATE ON clinic.credit_notes
  FOR EACH ROW
  EXECUTE FUNCTION clinic.audit_write();

CREATE TRIGGER immutable_record
  BEFORE DELETE OR UPDATE ON clinic.credit_notes
  FOR EACH ROW
  EXECUTE FUNCTION clinic.immutable_record();

CREATE TRIGGER audit_write
  AFTER INSERT OR UPDATE ON clinic.encounters
  FOR EACH ROW
  EXECUTE FUNCTION clinic.audit_write();

CREATE TRIGGER protect_signed
  BEFORE DELETE OR UPDATE ON clinic.encounters
  FOR EACH ROW
  EXECUTE FUNCTION clinic.protect_encounter();

CREATE TRIGGER audit_write
  AFTER INSERT OR UPDATE ON clinic.expenses
  FOR EACH ROW
  EXECUTE FUNCTION clinic.audit_write();

CREATE TRIGGER immutable_record
  BEFORE DELETE OR UPDATE ON clinic.expenses
  FOR EACH ROW
  EXECUTE FUNCTION clinic.immutable_record();

CREATE TRIGGER audit_write
  AFTER INSERT OR UPDATE ON clinic.invoices
  FOR EACH ROW
  EXECUTE FUNCTION clinic.audit_write();

CREATE TRIGGER immutable_record
  BEFORE DELETE OR UPDATE ON clinic.invoices
  FOR EACH ROW
  EXECUTE FUNCTION clinic.immutable_record();

CREATE TRIGGER audit_write
  AFTER INSERT OR UPDATE ON clinic.journal_lines
  FOR EACH ROW
  EXECUTE FUNCTION clinic.audit_write();

CREATE TRIGGER immutable_record
  BEFORE DELETE OR UPDATE ON clinic.journal_lines
  FOR EACH ROW
  EXECUTE FUNCTION clinic.immutable_record();

CREATE CONSTRAINT TRIGGER journal_must_balance
  AFTER INSERT ON clinic.journal_lines DEFERRABLE INITIALLY DEFERRED
  FOR EACH ROW
  EXECUTE FUNCTION clinic.balanced_journal();

CREATE TRIGGER audit_write
  AFTER INSERT OR UPDATE ON clinic.journals
  FOR EACH ROW
  EXECUTE FUNCTION clinic.audit_write();

CREATE TRIGGER immutable_record
  BEFORE DELETE OR UPDATE ON clinic.journals
  FOR EACH ROW
  EXECUTE FUNCTION clinic.immutable_record();

CREATE TRIGGER audit_write
  AFTER INSERT OR UPDATE ON clinic.media
  FOR EACH ROW
  EXECUTE FUNCTION clinic.audit_write();

CREATE TRIGGER audit_write
  AFTER INSERT OR UPDATE ON clinic.memberships
  FOR EACH ROW
  EXECUTE FUNCTION clinic.audit_write();

CREATE TRIGGER audit_write
  AFTER INSERT OR UPDATE ON clinic.package_redemptions
  FOR EACH ROW
  EXECUTE FUNCTION clinic.audit_write();

CREATE TRIGGER immutable_record
  BEFORE DELETE OR UPDATE ON clinic.package_redemptions
  FOR EACH ROW
  EXECUTE FUNCTION clinic.immutable_record();

CREATE TRIGGER audit_write
  AFTER INSERT OR UPDATE ON clinic.packages
  FOR EACH ROW
  EXECUTE FUNCTION clinic.audit_write();

CREATE TRIGGER audit_write
  AFTER INSERT ON clinic.patient_merges
  FOR EACH ROW
  EXECUTE FUNCTION clinic.audit_write();

CREATE TRIGGER immutable_record
  BEFORE DELETE OR UPDATE ON clinic.patient_merges
  FOR EACH ROW
  EXECUTE FUNCTION clinic.immutable_record();

CREATE TRIGGER audit_write
  AFTER INSERT OR UPDATE ON clinic.patients
  FOR EACH ROW
  EXECUTE FUNCTION clinic.audit_write();

CREATE TRIGGER validate_birth
  BEFORE INSERT OR UPDATE ON clinic.patients
  FOR EACH ROW
  EXECUTE FUNCTION clinic.valid_birth();

CREATE TRIGGER audit_write
  AFTER INSERT OR UPDATE ON clinic.payments
  FOR EACH ROW
  EXECUTE FUNCTION clinic.audit_write();

CREATE TRIGGER immutable_record
  BEFORE DELETE OR UPDATE ON clinic.payments
  FOR EACH ROW
  EXECUTE FUNCTION clinic.immutable_record();

CREATE TRIGGER audit_write
  AFTER INSERT OR UPDATE ON clinic.procedures
  FOR EACH ROW
  EXECUTE FUNCTION clinic.audit_write();

CREATE TRIGGER audit_write
  AFTER INSERT OR UPDATE ON clinic.results
  FOR EACH ROW
  EXECUTE FUNCTION clinic.audit_write();

CREATE TRIGGER audit_write
  AFTER INSERT OR UPDATE ON clinic.services
  FOR EACH ROW
  EXECUTE FUNCTION clinic.audit_write();

CREATE TRIGGER audit_write
  AFTER INSERT OR UPDATE ON clinic.stock_lots
  FOR EACH ROW
  EXECUTE FUNCTION clinic.audit_write();

CREATE TRIGGER audit_write
  AFTER INSERT OR UPDATE ON clinic.stock_movements
  FOR EACH ROW
  EXECUTE FUNCTION clinic.audit_write();

CREATE TRIGGER immutable_record
  BEFORE DELETE OR UPDATE ON clinic.stock_movements
  FOR EACH ROW
  EXECUTE FUNCTION clinic.immutable_record();

CREATE TRIGGER audit_write
  AFTER INSERT OR UPDATE ON clinic.tasks
  FOR EACH ROW
  EXECUTE FUNCTION clinic.audit_write();

CREATE TRIGGER audit_write
  AFTER INSERT OR UPDATE ON clinic.tills
  FOR EACH ROW
  EXECUTE FUNCTION clinic.audit_write();

CREATE POLICY "scoped_insert" ON "clinic"."addenda"
  FOR INSERT
  TO "authenticated"
  WITH CHECK (((organization_id = clinic.org_id()) AND clinic.allowed('clinical'::text)));

CREATE POLICY "scoped_read" ON "clinic"."addenda"
  FOR SELECT
  TO "authenticated"
  USING (((organization_id = clinic.org_id()) AND clinic.allowed('clinical'::text)));

CREATE POLICY "scoped_update" ON "clinic"."addenda"
  FOR UPDATE
  TO "authenticated"
  USING (((organization_id = clinic.org_id()) AND clinic.allowed('clinical'::text)))
  WITH CHECK (((organization_id = clinic.org_id()) AND clinic.allowed('clinical'::text)));

CREATE POLICY "scoped_insert" ON "clinic"."appointments"
  FOR INSERT
  TO "authenticated"
  WITH CHECK (((organization_id = clinic.org_id()) AND clinic.allowed('schedule'::text)));

CREATE POLICY "scoped_read" ON "clinic"."appointments"
  FOR SELECT
  TO "authenticated"
  USING (((organization_id = clinic.org_id()) AND clinic.allowed('schedule'::text)));

CREATE POLICY "scoped_update" ON "clinic"."appointments"
  FOR UPDATE
  TO "authenticated"
  USING (((organization_id = clinic.org_id()) AND clinic.allowed('schedule'::text)))
  WITH CHECK (((organization_id = clinic.org_id()) AND clinic.allowed('schedule'::text)));

CREATE POLICY "audit_read" ON "clinic"."audit_events"
  FOR SELECT
  TO "authenticated"
  USING (((organization_id = clinic.org_id()) AND clinic.allowed('audit'::text)));

CREATE POLICY "branch_read" ON "clinic"."branches"
  FOR SELECT
  TO "authenticated"
  USING ((organization_id = clinic.org_id()));

CREATE POLICY "scoped_insert" ON "clinic"."cash_movements"
  FOR INSERT
  TO "authenticated"
  WITH CHECK (((organization_id = clinic.org_id()) AND clinic.allowed('finance'::text)));

CREATE POLICY "scoped_read" ON "clinic"."cash_movements"
  FOR SELECT
  TO "authenticated"
  USING (((organization_id = clinic.org_id()) AND clinic.allowed('finance'::text)));

CREATE POLICY "scoped_update" ON "clinic"."cash_movements"
  FOR UPDATE
  TO "authenticated"
  USING (((organization_id = clinic.org_id()) AND clinic.allowed('finance'::text)))
  WITH CHECK (((organization_id = clinic.org_id()) AND clinic.allowed('finance'::text)));

CREATE POLICY "scoped_insert" ON "clinic"."consents"
  FOR INSERT
  TO "authenticated"
  WITH CHECK (((organization_id = clinic.org_id()) AND (clinic.allowed('clinical'::text) OR clinic.allowed('patients'::text))));

CREATE POLICY "scoped_read" ON "clinic"."consents"
  FOR SELECT
  TO "authenticated"
  USING (((organization_id = clinic.org_id()) AND clinic.allowed('clinical'::text)));

CREATE POLICY "scoped_update" ON "clinic"."consents"
  FOR UPDATE
  TO "authenticated"
  USING (((organization_id = clinic.org_id()) AND clinic.allowed('clinical'::text)))
  WITH CHECK (((organization_id = clinic.org_id()) AND clinic.allowed('clinical'::text)));

CREATE POLICY "scoped_insert" ON "clinic"."contacts"
  FOR INSERT
  TO "authenticated"
  WITH CHECK (((organization_id = clinic.org_id()) AND clinic.allowed('patients'::text)));

CREATE POLICY "scoped_read" ON "clinic"."contacts"
  FOR SELECT
  TO "authenticated"
  USING (((organization_id = clinic.org_id()) AND clinic.allowed('patients'::text)));

CREATE POLICY "scoped_update" ON "clinic"."contacts"
  FOR UPDATE
  TO "authenticated"
  USING (((organization_id = clinic.org_id()) AND clinic.allowed('patients'::text)))
  WITH CHECK (((organization_id = clinic.org_id()) AND clinic.allowed('patients'::text)));

CREATE POLICY "scoped_insert" ON "clinic"."credit_notes"
  FOR INSERT
  TO "authenticated"
  WITH CHECK (((organization_id = clinic.org_id()) AND clinic.allowed('billing'::text)));

CREATE POLICY "scoped_read" ON "clinic"."credit_notes"
  FOR SELECT
  TO "authenticated"
  USING (((organization_id = clinic.org_id()) AND (clinic.allowed('billing'::text) OR clinic.allowed('finance'::text) OR clinic.allowed('billing'::text))));

CREATE POLICY "scoped_update" ON "clinic"."credit_notes"
  FOR UPDATE
  TO "authenticated"
  USING (((organization_id = clinic.org_id()) AND clinic.allowed('billing'::text)))
  WITH CHECK (((organization_id = clinic.org_id()) AND clinic.allowed('billing'::text)));

CREATE POLICY "scoped_insert" ON "clinic"."encounters"
  FOR INSERT
  TO "authenticated"
  WITH CHECK (((organization_id = clinic.org_id()) AND clinic.allowed('clinical'::text)));

CREATE POLICY "scoped_read" ON "clinic"."encounters"
  FOR SELECT
  TO "authenticated"
  USING (((organization_id = clinic.org_id()) AND clinic.allowed('clinical'::text)));

CREATE POLICY "scoped_update" ON "clinic"."encounters"
  FOR UPDATE
  TO "authenticated"
  USING (((organization_id = clinic.org_id()) AND clinic.allowed('clinical'::text)))
  WITH CHECK (((organization_id = clinic.org_id()) AND clinic.allowed('clinical'::text)));

CREATE POLICY "scoped_insert" ON "clinic"."expenses"
  FOR INSERT
  TO "authenticated"
  WITH CHECK (((organization_id = clinic.org_id()) AND clinic.allowed('finance'::text)));

CREATE POLICY "scoped_read" ON "clinic"."expenses"
  FOR SELECT
  TO "authenticated"
  USING (((organization_id = clinic.org_id()) AND clinic.allowed('finance'::text) AND ((category <> 'salary'::text) OR clinic.allowed('payroll'::text))));

CREATE POLICY "scoped_update" ON "clinic"."expenses"
  FOR UPDATE
  TO "authenticated"
  USING (((organization_id = clinic.org_id()) AND clinic.allowed('finance'::text)))
  WITH CHECK (((organization_id = clinic.org_id()) AND clinic.allowed('finance'::text)));

CREATE POLICY "scoped_insert" ON "clinic"."invoices"
  FOR INSERT
  TO "authenticated"
  WITH CHECK (((organization_id = clinic.org_id()) AND clinic.allowed('billing'::text)));

CREATE POLICY "scoped_read" ON "clinic"."invoices"
  FOR SELECT
  TO "authenticated"
  USING (((organization_id = clinic.org_id()) AND (clinic.allowed('billing'::text) OR clinic.allowed('finance'::text) OR clinic.allowed('billing'::text))));

CREATE POLICY "scoped_update" ON "clinic"."invoices"
  FOR UPDATE
  TO "authenticated"
  USING (((organization_id = clinic.org_id()) AND clinic.allowed('billing'::text)))
  WITH CHECK (((organization_id = clinic.org_id()) AND clinic.allowed('billing'::text)));

CREATE POLICY "scoped_insert" ON "clinic"."journal_lines"
  FOR INSERT
  TO "authenticated"
  WITH CHECK (((organization_id = clinic.org_id()) AND (clinic.allowed('finance'::text) OR clinic.allowed('billing'::text) OR clinic.allowed('clinical'::text))));

CREATE POLICY "scoped_read" ON "clinic"."journal_lines"
  FOR SELECT
  TO "authenticated"
  USING (((organization_id = clinic.org_id()) AND (clinic.allowed('finance'::text) OR clinic.allowed('finance'::text) OR clinic.allowed('billing'::text))));

CREATE POLICY "scoped_update" ON "clinic"."journal_lines"
  FOR UPDATE
  TO "authenticated"
  USING (((organization_id = clinic.org_id()) AND clinic.allowed('finance'::text)))
  WITH CHECK (((organization_id = clinic.org_id()) AND clinic.allowed('finance'::text)));

CREATE POLICY "scoped_insert" ON "clinic"."journals"
  FOR INSERT
  TO "authenticated"
  WITH CHECK (((organization_id = clinic.org_id()) AND (clinic.allowed('finance'::text) OR clinic.allowed('billing'::text) OR clinic.allowed('clinical'::text))));

CREATE POLICY "scoped_read" ON "clinic"."journals"
  FOR SELECT
  TO "authenticated"
  USING (((organization_id = clinic.org_id()) AND (clinic.allowed('finance'::text) OR clinic.allowed('finance'::text) OR clinic.allowed('billing'::text))));

CREATE POLICY "scoped_update" ON "clinic"."journals"
  FOR UPDATE
  TO "authenticated"
  USING (((organization_id = clinic.org_id()) AND clinic.allowed('finance'::text)))
  WITH CHECK (((organization_id = clinic.org_id()) AND clinic.allowed('finance'::text)));

CREATE POLICY "scoped_insert" ON "clinic"."media"
  FOR INSERT
  TO "authenticated"
  WITH CHECK (((organization_id = clinic.org_id()) AND clinic.allowed('media'::text)));

CREATE POLICY "scoped_read" ON "clinic"."media"
  FOR SELECT
  TO "authenticated"
  USING (((organization_id = clinic.org_id()) AND clinic.allowed('media'::text)));

CREATE POLICY "scoped_update" ON "clinic"."media"
  FOR UPDATE
  TO "authenticated"
  USING (((organization_id = clinic.org_id()) AND clinic.allowed('media'::text)))
  WITH CHECK (((organization_id = clinic.org_id()) AND clinic.allowed('media'::text)));

CREATE POLICY "membership_read" ON "clinic"."memberships"
  FOR SELECT
  TO "authenticated"
  USING ((organization_id = clinic.org_id()));

CREATE POLICY "membership_update" ON "clinic"."memberships"
  FOR UPDATE
  TO "authenticated"
  USING (((organization_id = clinic.org_id()) AND clinic.allowed('staff'::text) AND (user_id <> ( SELECT auth.uid() AS uid))))
  WITH CHECK (((organization_id = clinic.org_id()) AND clinic.allowed('staff'::text) AND (user_id <> ( SELECT auth.uid() AS uid))));

CREATE POLICY "organization_read" ON "clinic"."organizations"
  FOR SELECT
  TO "authenticated"
  USING ((id = clinic.org_id()));

CREATE POLICY "organization_update" ON "clinic"."organizations"
  FOR UPDATE
  TO "authenticated"
  USING (((id = clinic.org_id()) AND clinic.allowed('settings'::text)))
  WITH CHECK (((id = clinic.org_id()) AND clinic.allowed('settings'::text)));

CREATE POLICY "redemption_billing_insert" ON "clinic"."package_redemptions"
  FOR INSERT
  TO "authenticated"
  WITH CHECK (((organization_id = clinic.org_id()) AND clinic.allowed('billing'::text)));

CREATE POLICY "redemption_billing_read" ON "clinic"."package_redemptions"
  FOR SELECT
  TO "authenticated"
  USING (((organization_id = clinic.org_id()) AND clinic.allowed('billing'::text)));

CREATE POLICY "scoped_insert" ON "clinic"."package_redemptions"
  FOR INSERT
  TO "authenticated"
  WITH CHECK (((organization_id = clinic.org_id()) AND clinic.allowed('clinical'::text)));

CREATE POLICY "scoped_read" ON "clinic"."package_redemptions"
  FOR SELECT
  TO "authenticated"
  USING (((organization_id = clinic.org_id()) AND clinic.allowed('clinical'::text)));

CREATE POLICY "scoped_update" ON "clinic"."package_redemptions"
  FOR UPDATE
  TO "authenticated"
  USING (((organization_id = clinic.org_id()) AND clinic.allowed('clinical'::text)))
  WITH CHECK (((organization_id = clinic.org_id()) AND clinic.allowed('clinical'::text)));

CREATE POLICY "scoped_insert" ON "clinic"."packages"
  FOR INSERT
  TO "authenticated"
  WITH CHECK (((organization_id = clinic.org_id()) AND clinic.allowed('billing'::text)));

CREATE POLICY "scoped_read" ON "clinic"."packages"
  FOR SELECT
  TO "authenticated"
  USING (((organization_id = clinic.org_id()) AND (clinic.allowed('billing'::text) OR clinic.allowed('clinical'::text) OR clinic.allowed('billing'::text))));

CREATE POLICY "scoped_update" ON "clinic"."packages"
  FOR UPDATE
  TO "authenticated"
  USING (((organization_id = clinic.org_id()) AND clinic.allowed('billing'::text)))
  WITH CHECK (((organization_id = clinic.org_id()) AND clinic.allowed('billing'::text)));

CREATE POLICY "insert_scope" ON "clinic"."patient_merges"
  FOR INSERT
  TO "authenticated"
  WITH CHECK (((organization_id = clinic.org_id()) AND clinic.allowed('approve'::text)));

CREATE POLICY "scope" ON "clinic"."patient_merges"
  FOR SELECT
  TO "authenticated"
  USING (((organization_id = clinic.org_id()) AND clinic.allowed('patients'::text)));

CREATE POLICY "scoped_insert" ON "clinic"."patients"
  FOR INSERT
  TO "authenticated"
  WITH CHECK (((organization_id = clinic.org_id()) AND clinic.allowed('patients'::text)));

CREATE POLICY "scoped_read" ON "clinic"."patients"
  FOR SELECT
  TO "authenticated"
  USING (((organization_id = clinic.org_id()) AND clinic.allowed('patients'::text)));

CREATE POLICY "scoped_update" ON "clinic"."patients"
  FOR UPDATE
  TO "authenticated"
  USING (((organization_id = clinic.org_id()) AND clinic.allowed('patients'::text)))
  WITH CHECK (((organization_id = clinic.org_id()) AND clinic.allowed('patients'::text)));

CREATE POLICY "scoped_insert" ON "clinic"."payments"
  FOR INSERT
  TO "authenticated"
  WITH CHECK (((organization_id = clinic.org_id()) AND clinic.allowed('billing'::text)));

CREATE POLICY "scoped_read" ON "clinic"."payments"
  FOR SELECT
  TO "authenticated"
  USING (((organization_id = clinic.org_id()) AND (clinic.allowed('billing'::text) OR clinic.allowed('finance'::text) OR clinic.allowed('billing'::text))));

CREATE POLICY "scoped_update" ON "clinic"."payments"
  FOR UPDATE
  TO "authenticated"
  USING (((organization_id = clinic.org_id()) AND clinic.allowed('billing'::text)))
  WITH CHECK (((organization_id = clinic.org_id()) AND clinic.allowed('billing'::text)));

CREATE POLICY "scoped_insert" ON "clinic"."procedures"
  FOR INSERT
  TO "authenticated"
  WITH CHECK (((organization_id = clinic.org_id()) AND clinic.allowed('clinical'::text)));

CREATE POLICY "scoped_read" ON "clinic"."procedures"
  FOR SELECT
  TO "authenticated"
  USING (((organization_id = clinic.org_id()) AND clinic.allowed('clinical'::text)));

CREATE POLICY "scoped_update" ON "clinic"."procedures"
  FOR UPDATE
  TO "authenticated"
  USING (((organization_id = clinic.org_id()) AND clinic.allowed('clinical'::text)))
  WITH CHECK (((organization_id = clinic.org_id()) AND clinic.allowed('clinical'::text)));

CREATE POLICY "request_insert" ON "clinic"."requests"
  FOR INSERT
  TO "authenticated"
  WITH CHECK (((organization_id = clinic.org_id()) AND (actor_id = ( SELECT auth.uid() AS uid))));

CREATE POLICY "request_read" ON "clinic"."requests"
  FOR SELECT
  TO "authenticated"
  USING (((organization_id = clinic.org_id()) AND (actor_id = ( SELECT auth.uid() AS uid))));

CREATE POLICY "scoped_insert" ON "clinic"."results"
  FOR INSERT
  TO "authenticated"
  WITH CHECK (((organization_id = clinic.org_id()) AND clinic.allowed('results'::text)));

CREATE POLICY "scoped_read" ON "clinic"."results"
  FOR SELECT
  TO "authenticated"
  USING (((organization_id = clinic.org_id()) AND clinic.allowed('results'::text)));

CREATE POLICY "scoped_update" ON "clinic"."results"
  FOR UPDATE
  TO "authenticated"
  USING (((organization_id = clinic.org_id()) AND clinic.allowed('results'::text)))
  WITH CHECK (((organization_id = clinic.org_id()) AND clinic.allowed('results'::text)));

CREATE POLICY "scoped_insert" ON "clinic"."services"
  FOR INSERT
  TO "authenticated"
  WITH CHECK (((organization_id = clinic.org_id()) AND clinic.allowed('schedule'::text)));

CREATE POLICY "scoped_read" ON "clinic"."services"
  FOR SELECT
  TO "authenticated"
  USING (((organization_id = clinic.org_id()) AND (clinic.allowed('schedule'::text) OR clinic.allowed('clinical'::text) OR clinic.allowed('billing'::text))));

CREATE POLICY "scoped_update" ON "clinic"."services"
  FOR UPDATE
  TO "authenticated"
  USING (((organization_id = clinic.org_id()) AND clinic.allowed('schedule'::text)))
  WITH CHECK (((organization_id = clinic.org_id()) AND clinic.allowed('schedule'::text)));

CREATE POLICY "scoped_insert" ON "clinic"."stock_lots"
  FOR INSERT
  TO "authenticated"
  WITH CHECK (((organization_id = clinic.org_id()) AND clinic.allowed('inventory'::text)));

CREATE POLICY "scoped_read" ON "clinic"."stock_lots"
  FOR SELECT
  TO "authenticated"
  USING (((organization_id = clinic.org_id()) AND (clinic.allowed('inventory'::text) OR clinic.allowed('inventory.read'::text))));

CREATE POLICY "scoped_update" ON "clinic"."stock_lots"
  FOR UPDATE
  TO "authenticated"
  USING (((organization_id = clinic.org_id()) AND (clinic.allowed('inventory'::text) OR clinic.allowed('clinical'::text))))
  WITH CHECK (((organization_id = clinic.org_id()) AND (clinic.allowed('inventory'::text) OR clinic.allowed('clinical'::text))));

CREATE POLICY "scoped_insert" ON "clinic"."stock_movements"
  FOR INSERT
  TO "authenticated"
  WITH CHECK (((organization_id = clinic.org_id()) AND (clinic.allowed('inventory'::text) OR clinic.allowed('clinical'::text))));

CREATE POLICY "scoped_read" ON "clinic"."stock_movements"
  FOR SELECT
  TO "authenticated"
  USING (((organization_id = clinic.org_id()) AND (clinic.allowed('inventory'::text) OR clinic.allowed('inventory.read'::text))));

CREATE POLICY "scoped_update" ON "clinic"."stock_movements"
  FOR UPDATE
  TO "authenticated"
  USING (((organization_id = clinic.org_id()) AND clinic.allowed('inventory'::text)))
  WITH CHECK (((organization_id = clinic.org_id()) AND clinic.allowed('inventory'::text)));

CREATE POLICY "scoped_insert" ON "clinic"."tasks"
  FOR INSERT
  TO "authenticated"
  WITH CHECK (((organization_id = clinic.org_id()) AND clinic.allowed('results'::text)));

CREATE POLICY "scoped_read" ON "clinic"."tasks"
  FOR SELECT
  TO "authenticated"
  USING (((organization_id = clinic.org_id()) AND clinic.allowed('results'::text)));

CREATE POLICY "scoped_update" ON "clinic"."tasks"
  FOR UPDATE
  TO "authenticated"
  USING (((organization_id = clinic.org_id()) AND clinic.allowed('results'::text)))
  WITH CHECK (((organization_id = clinic.org_id()) AND clinic.allowed('results'::text)));

CREATE POLICY "scoped_insert" ON "clinic"."tills"
  FOR INSERT
  TO "authenticated"
  WITH CHECK (((organization_id = clinic.org_id()) AND clinic.allowed('billing'::text)));

CREATE POLICY "scoped_read" ON "clinic"."tills"
  FOR SELECT
  TO "authenticated"
  USING (((organization_id = clinic.org_id()) AND clinic.allowed('billing'::text)));

CREATE POLICY "scoped_update" ON "clinic"."tills"
  FOR UPDATE
  TO "authenticated"
  USING (((organization_id = clinic.org_id()) AND clinic.allowed('billing'::text)))
  WITH CHECK (((organization_id = clinic.org_id()) AND clinic.allowed('billing'::text)));

COMMENT ON EXTENSION "pg_trgm" IS 'text similarity measurement and index searching based on trigrams';

REVOKE ALL ON FUNCTION "clinic"."allowed"(text) FROM PUBLIC;

GRANT EXECUTE ON FUNCTION "clinic"."allowed"(text) TO "authenticated";

REVOKE ALL ON FUNCTION "clinic"."allowed"(text) FROM "postgres";

GRANT EXECUTE ON FUNCTION "clinic"."allowed"(text) TO "postgres";

REVOKE ALL ON FUNCTION "clinic"."audit_write"() FROM PUBLIC;

REVOKE ALL ON FUNCTION "clinic"."audit_write"() FROM "postgres";

GRANT EXECUTE ON FUNCTION "clinic"."audit_write"() TO "postgres";

REVOKE ALL ON FUNCTION "clinic"."balanced_journal"() FROM PUBLIC;

REVOKE ALL ON FUNCTION "clinic"."balanced_journal"() FROM "postgres";

GRANT EXECUTE ON FUNCTION "clinic"."balanced_journal"() TO "postgres";

REVOKE ALL ON FUNCTION "clinic"."billable_encounters"() FROM PUBLIC;

GRANT EXECUTE ON FUNCTION "clinic"."billable_encounters"() TO "authenticated";

REVOKE ALL ON FUNCTION "clinic"."billable_encounters"() FROM "postgres";

GRANT EXECUTE ON FUNCTION "clinic"."billable_encounters"() TO "postgres";

REVOKE ALL ON FUNCTION "clinic"."billing_encounter_patient"(uuid) FROM PUBLIC;

GRANT EXECUTE ON FUNCTION "clinic"."billing_encounter_patient"(uuid) TO "authenticated";

REVOKE ALL ON FUNCTION "clinic"."billing_encounter_patient"(uuid) FROM "postgres";

GRANT EXECUTE ON FUNCTION "clinic"."billing_encounter_patient"(uuid) TO "postgres";

REVOKE ALL ON FUNCTION "clinic"."branch_id"() FROM PUBLIC;

GRANT EXECUTE ON FUNCTION "clinic"."branch_id"() TO "authenticated";

REVOKE ALL ON FUNCTION "clinic"."branch_id"() FROM "postgres";

GRANT EXECUTE ON FUNCTION "clinic"."branch_id"() TO "postgres";

REVOKE ALL ON FUNCTION "clinic"."immutable_record"() FROM PUBLIC;

REVOKE ALL ON FUNCTION "clinic"."immutable_record"() FROM "postgres";

GRANT EXECUTE ON FUNCTION "clinic"."immutable_record"() TO "postgres";

REVOKE ALL ON FUNCTION "clinic"."log_access"(text, uuid, text) FROM PUBLIC;

GRANT EXECUTE ON FUNCTION "clinic"."log_access"(text, uuid, text) TO "authenticated";

REVOKE ALL ON FUNCTION "clinic"."log_access"(text, uuid, text) FROM "postgres";

GRANT EXECUTE ON FUNCTION "clinic"."log_access"(text, uuid, text) TO "postgres";

REVOKE ALL ON FUNCTION "clinic"."org_id"() FROM PUBLIC;

GRANT EXECUTE ON FUNCTION "clinic"."org_id"() TO "authenticated";

REVOKE ALL ON FUNCTION "clinic"."org_id"() FROM "postgres";

GRANT EXECUTE ON FUNCTION "clinic"."org_id"() TO "postgres";

REVOKE ALL ON FUNCTION "clinic"."patient_ids"(uuid) FROM PUBLIC;

GRANT EXECUTE ON FUNCTION "clinic"."patient_ids"(uuid) TO "authenticated";

REVOKE ALL ON FUNCTION "clinic"."patient_ids"(uuid) FROM "postgres";

GRANT EXECUTE ON FUNCTION "clinic"."patient_ids"(uuid) TO "postgres";

REVOKE ALL ON FUNCTION "clinic"."permissions"(text) FROM PUBLIC;

GRANT EXECUTE ON FUNCTION "clinic"."permissions"(text) TO "authenticated";

REVOKE ALL ON FUNCTION "clinic"."permissions"(text) FROM "postgres";

GRANT EXECUTE ON FUNCTION "clinic"."permissions"(text) TO "postgres";

REVOKE ALL ON FUNCTION "clinic"."post_journal"(text, text, text, uuid, text, text, numeric) FROM PUBLIC;

GRANT EXECUTE ON FUNCTION "clinic"."post_journal"(text, text, text, uuid, text, text, numeric) TO "authenticated";

REVOKE ALL ON FUNCTION "clinic"."post_journal"(text, text, text, uuid, text, text, numeric) FROM "postgres";

GRANT EXECUTE ON FUNCTION "clinic"."post_journal"(text, text, text, uuid, text, text, numeric) TO "postgres";

REVOKE ALL ON FUNCTION "clinic"."protect_encounter"() FROM PUBLIC;

REVOKE ALL ON FUNCTION "clinic"."protect_encounter"() FROM "postgres";

GRANT EXECUTE ON FUNCTION "clinic"."protect_encounter"() TO "postgres";

REVOKE ALL ON FUNCTION "clinic"."require_permission"(text) FROM PUBLIC;

GRANT EXECUTE ON FUNCTION "clinic"."require_permission"(text) TO "authenticated";

REVOKE ALL ON FUNCTION "clinic"."require_permission"(text) FROM "postgres";

GRANT EXECUTE ON FUNCTION "clinic"."require_permission"(text) TO "postgres";

REVOKE ALL ON FUNCTION "clinic"."search_key"(text) FROM PUBLIC;

GRANT EXECUTE ON FUNCTION "clinic"."search_key"(text) TO "authenticated";

REVOKE ALL ON FUNCTION "clinic"."search_key"(text) FROM "postgres";

GRANT EXECUTE ON FUNCTION "clinic"."search_key"(text) TO "postgres";

REVOKE ALL ON FUNCTION "clinic"."valid_birth"() FROM PUBLIC;

REVOKE ALL ON FUNCTION "clinic"."valid_birth"() FROM "postgres";

GRANT EXECUTE ON FUNCTION "clinic"."valid_birth"() TO "postgres";

REVOKE ALL ON FUNCTION "public"."accounting_export"() FROM PUBLIC;

GRANT EXECUTE ON FUNCTION "public"."accounting_export"() TO "anon", "authenticated";

REVOKE ALL ON FUNCTION "public"."accounting_export"() FROM "postgres";

GRANT EXECUTE ON FUNCTION "public"."accounting_export"() TO "postgres";

GRANT EXECUTE ON FUNCTION "public"."accounting_export"() TO "service_role";

REVOKE ALL ON FUNCTION "public"."authorize"(text) FROM PUBLIC;

GRANT EXECUTE ON FUNCTION "public"."authorize"(text) TO "anon", "authenticated";

REVOKE ALL ON FUNCTION "public"."authorize"(text) FROM "postgres";

GRANT EXECUTE ON FUNCTION "public"."authorize"(text) TO "postgres";

GRANT EXECUTE ON FUNCTION "public"."authorize"(text) TO "service_role";

REVOKE ALL ON FUNCTION "public"."clinical_record"(uuid) FROM PUBLIC;

GRANT EXECUTE ON FUNCTION "public"."clinical_record"(uuid) TO "anon", "authenticated";

REVOKE ALL ON FUNCTION "public"."clinical_record"(uuid) FROM "postgres";

GRANT EXECUTE ON FUNCTION "public"."clinical_record"(uuid) TO "postgres";

GRANT EXECUTE ON FUNCTION "public"."clinical_record"(uuid) TO "service_role";

REVOKE ALL ON FUNCTION "public"."command"(text, jsonb, uuid) FROM PUBLIC;

GRANT EXECUTE ON FUNCTION "public"."command"(text, jsonb, uuid) TO "anon", "authenticated";

REVOKE ALL ON FUNCTION "public"."command"(text, jsonb, uuid) FROM "postgres";

GRANT EXECUTE ON FUNCTION "public"."command"(text, jsonb, uuid) TO "postgres";

GRANT EXECUTE ON FUNCTION "public"."command"(text, jsonb, uuid) TO "service_role";

REVOKE ALL ON FUNCTION "public"."media_access"(uuid) FROM PUBLIC;

GRANT EXECUTE ON FUNCTION "public"."media_access"(uuid) TO "anon", "authenticated";

REVOKE ALL ON FUNCTION "public"."media_access"(uuid) FROM "postgres";

GRANT EXECUTE ON FUNCTION "public"."media_access"(uuid) TO "postgres";

GRANT EXECUTE ON FUNCTION "public"."media_access"(uuid) TO "service_role";

REVOKE ALL ON FUNCTION "public"."media_finalize"(uuid, boolean) FROM PUBLIC;

GRANT EXECUTE ON FUNCTION "public"."media_finalize"(uuid, boolean) TO "anon", "authenticated";

REVOKE ALL ON FUNCTION "public"."media_finalize"(uuid, boolean) FROM "postgres";

GRANT EXECUTE ON FUNCTION "public"."media_finalize"(uuid, boolean) TO "postgres";

GRANT EXECUTE ON FUNCTION "public"."media_finalize"(uuid, boolean) TO "service_role";

REVOKE ALL ON FUNCTION "public"."media_prepare"(uuid, uuid, uuid, text, text, text, text) FROM PUBLIC;

GRANT EXECUTE ON FUNCTION "public"."media_prepare"(uuid, uuid, uuid, text, text, text, text) TO "anon", "authenticated";

REVOKE ALL ON FUNCTION "public"."media_prepare"(uuid, uuid, uuid, text, text, text, text) FROM "postgres";

GRANT EXECUTE ON FUNCTION "public"."media_prepare"(uuid, uuid, uuid, text, text, text, text) TO "postgres";

GRANT EXECUTE ON FUNCTION "public"."media_prepare"(uuid, uuid, uuid, text, text, text, text) TO "service_role";

REVOKE ALL ON FUNCTION "public"."patient_profile"(uuid) FROM PUBLIC;

GRANT EXECUTE ON FUNCTION "public"."patient_profile"(uuid) TO "anon", "authenticated";

REVOKE ALL ON FUNCTION "public"."patient_profile"(uuid) FROM "postgres";

GRANT EXECUTE ON FUNCTION "public"."patient_profile"(uuid) TO "postgres";

GRANT EXECUTE ON FUNCTION "public"."patient_profile"(uuid) TO "service_role";

REVOKE ALL ON FUNCTION "public"."patient_search"(text, uuid, integer) FROM PUBLIC;

GRANT EXECUTE ON FUNCTION "public"."patient_search"(text, uuid, integer) TO "anon", "authenticated";

REVOKE ALL ON FUNCTION "public"."patient_search"(text, uuid, integer) FROM "postgres";

GRANT EXECUTE ON FUNCTION "public"."patient_search"(text, uuid, integer) TO "postgres";

GRANT EXECUTE ON FUNCTION "public"."patient_search"(text, uuid, integer) TO "service_role";

REVOKE ALL ON FUNCTION "public"."provision_member"(uuid, uuid, text, text) FROM PUBLIC;

GRANT EXECUTE ON FUNCTION "public"."provision_member"(uuid, uuid, text, text) TO "anon", "authenticated";

REVOKE ALL ON FUNCTION "public"."provision_member"(uuid, uuid, text, text) FROM "postgres";

GRANT EXECUTE ON FUNCTION "public"."provision_member"(uuid, uuid, text, text) TO "postgres";

GRANT EXECUTE ON FUNCTION "public"."provision_member"(uuid, uuid, text, text) TO "service_role";

REVOKE ALL ON FUNCTION "public"."workspace"() FROM PUBLIC;

GRANT EXECUTE ON FUNCTION "public"."workspace"() TO "anon", "authenticated";

REVOKE ALL ON FUNCTION "public"."workspace"() FROM "postgres";

GRANT EXECUTE ON FUNCTION "public"."workspace"() TO "postgres";

GRANT EXECUTE ON FUNCTION "public"."workspace"() TO "service_role";

GRANT USAGE ON SCHEMA "clinic" TO "authenticated", "service_role";

GRANT INSERT, SELECT, UPDATE ON TABLE "clinic"."addenda" TO "authenticated";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "clinic"."addenda" TO "service_role";

GRANT INSERT, SELECT, UPDATE ON TABLE "clinic"."appointments" TO "authenticated";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "clinic"."appointments" TO "service_role";

GRANT SELECT ON TABLE "clinic"."audit_events" TO "authenticated";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "clinic"."audit_events" TO "service_role";

GRANT SELECT ON TABLE "clinic"."branches" TO "authenticated";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "clinic"."branches" TO "service_role";

GRANT INSERT, SELECT, UPDATE ON TABLE "clinic"."cash_movements" TO "authenticated";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "clinic"."cash_movements" TO "service_role";

GRANT INSERT, SELECT, UPDATE ON TABLE "clinic"."consents" TO "authenticated";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "clinic"."consents" TO "service_role";

GRANT INSERT, SELECT, UPDATE ON TABLE "clinic"."contacts" TO "authenticated";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "clinic"."contacts" TO "service_role";

GRANT INSERT, SELECT, UPDATE ON TABLE "clinic"."credit_notes" TO "authenticated";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "clinic"."credit_notes" TO "service_role";

GRANT INSERT, SELECT, UPDATE ON TABLE "clinic"."encounters" TO "authenticated";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "clinic"."encounters" TO "service_role";

GRANT INSERT, SELECT, UPDATE ON TABLE "clinic"."expenses" TO "authenticated";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "clinic"."expenses" TO "service_role";

GRANT INSERT, SELECT, UPDATE ON TABLE "clinic"."invoices" TO "authenticated";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "clinic"."invoices" TO "service_role";

GRANT INSERT, SELECT, UPDATE ON TABLE "clinic"."journal_lines" TO "authenticated";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "clinic"."journal_lines" TO "service_role";

GRANT INSERT, SELECT, UPDATE ON TABLE "clinic"."journals" TO "authenticated";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "clinic"."journals" TO "service_role";

GRANT INSERT, SELECT, UPDATE ON TABLE "clinic"."media" TO "authenticated";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "clinic"."media" TO "service_role";

GRANT SELECT, UPDATE ON TABLE "clinic"."memberships" TO "authenticated";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "clinic"."memberships" TO "service_role";

GRANT SELECT, UPDATE ON TABLE "clinic"."organizations" TO "authenticated";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "clinic"."organizations" TO "service_role";

GRANT INSERT, SELECT, UPDATE ON TABLE "clinic"."package_redemptions" TO "authenticated";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "clinic"."package_redemptions" TO "service_role";

GRANT INSERT, SELECT, UPDATE ON TABLE "clinic"."packages" TO "authenticated";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "clinic"."packages" TO "service_role";

GRANT INSERT, SELECT ON TABLE "clinic"."patient_merges" TO "authenticated";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "clinic"."patient_merges" TO "service_role";

GRANT INSERT, SELECT, UPDATE ON TABLE "clinic"."patients" TO "authenticated";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "clinic"."patients" TO "service_role";

GRANT INSERT, SELECT, UPDATE ON TABLE "clinic"."payments" TO "authenticated";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "clinic"."payments" TO "service_role";

GRANT INSERT, SELECT, UPDATE ON TABLE "clinic"."procedures" TO "authenticated";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "clinic"."procedures" TO "service_role";

GRANT INSERT, SELECT ON TABLE "clinic"."requests" TO "authenticated";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "clinic"."requests" TO "service_role";

GRANT INSERT, SELECT, UPDATE ON TABLE "clinic"."results" TO "authenticated";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "clinic"."results" TO "service_role";

GRANT INSERT, SELECT, UPDATE ON TABLE "clinic"."services" TO "authenticated";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "clinic"."services" TO "service_role";

GRANT INSERT, SELECT, UPDATE ON TABLE "clinic"."stock_lots" TO "authenticated";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "clinic"."stock_lots" TO "service_role";

GRANT INSERT, SELECT, UPDATE ON TABLE "clinic"."stock_movements" TO "authenticated";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "clinic"."stock_movements" TO "service_role";

GRANT INSERT, SELECT, UPDATE ON TABLE "clinic"."tasks" TO "authenticated";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "clinic"."tasks" TO "service_role";

GRANT INSERT, SELECT, UPDATE ON TABLE "clinic"."tills" TO "authenticated";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "clinic"."tills" TO "service_role";

ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" REVOKE ALL ON FUNCTIONS FROM PUBLIC;

CREATE INDEX patient_name_trigram ON clinic.patients USING gin (clinic.search_key(full_name) extensions.gin_trgm_ops);

