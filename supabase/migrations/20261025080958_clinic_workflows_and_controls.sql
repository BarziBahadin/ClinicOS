-- Reviewed local schema: care scope, immutable workflow evidence, accounting and media.
-- Policies below are replaced atomically by Supabase migration transactions.
SET local check_function_bodies = off;

DROP POLICY "scoped_insert" ON "clinic"."addenda";

DROP POLICY "scoped_read" ON "clinic"."addenda";

DROP POLICY "scoped_update" ON "clinic"."addenda";

DROP POLICY "scoped_insert" ON "clinic"."appointments";

DROP POLICY "scoped_read" ON "clinic"."appointments";

DROP POLICY "scoped_update" ON "clinic"."appointments";

DROP POLICY "audit_read" ON "clinic"."audit_events";

DROP POLICY "branch_read" ON "clinic"."branches";

DROP POLICY "scoped_insert" ON "clinic"."cash_movements";

DROP POLICY "scoped_read" ON "clinic"."cash_movements";

DROP POLICY "scoped_update" ON "clinic"."cash_movements";

DROP POLICY "scoped_insert" ON "clinic"."consents";

DROP POLICY "scoped_read" ON "clinic"."consents";

DROP POLICY "scoped_update" ON "clinic"."consents";

DROP POLICY "scoped_insert" ON "clinic"."contacts";

DROP POLICY "scoped_read" ON "clinic"."contacts";

DROP POLICY "scoped_update" ON "clinic"."contacts";

DROP POLICY "scoped_insert" ON "clinic"."credit_notes";

DROP POLICY "scoped_read" ON "clinic"."credit_notes";

DROP POLICY "scoped_update" ON "clinic"."credit_notes";

DROP POLICY "scoped_insert" ON "clinic"."encounters";

DROP POLICY "scoped_read" ON "clinic"."encounters";

DROP POLICY "scoped_update" ON "clinic"."encounters";

DROP POLICY "scoped_insert" ON "clinic"."expenses";

DROP POLICY "scoped_read" ON "clinic"."expenses";

DROP POLICY "scoped_update" ON "clinic"."expenses";

DROP POLICY "scoped_insert" ON "clinic"."invoices";

DROP POLICY "scoped_read" ON "clinic"."invoices";

DROP POLICY "scoped_update" ON "clinic"."invoices";

DROP POLICY "scoped_insert" ON "clinic"."journal_lines";

DROP POLICY "scoped_read" ON "clinic"."journal_lines";

DROP POLICY "scoped_update" ON "clinic"."journal_lines";

DROP POLICY "scoped_insert" ON "clinic"."journals";

DROP POLICY "scoped_read" ON "clinic"."journals";

DROP POLICY "scoped_update" ON "clinic"."journals";

DROP POLICY "scoped_insert" ON "clinic"."media";

DROP POLICY "scoped_read" ON "clinic"."media";

DROP POLICY "scoped_update" ON "clinic"."media";

DROP POLICY "membership_read" ON "clinic"."memberships";

DROP POLICY "membership_update" ON "clinic"."memberships";

DROP POLICY "organization_read" ON "clinic"."organizations";

DROP POLICY "organization_update" ON "clinic"."organizations";

DROP POLICY "scoped_insert" ON "clinic"."package_redemptions";

DROP POLICY "scoped_read" ON "clinic"."package_redemptions";

DROP POLICY "scoped_update" ON "clinic"."package_redemptions";

DROP POLICY "scoped_insert" ON "clinic"."packages";

DROP POLICY "scoped_read" ON "clinic"."packages";

DROP POLICY "scoped_update" ON "clinic"."packages";

DROP POLICY "insert_scope" ON "clinic"."patient_merges";

DROP POLICY "scope" ON "clinic"."patient_merges";

DROP POLICY "scoped_insert" ON "clinic"."patients";

DROP POLICY "scoped_read" ON "clinic"."patients";

DROP POLICY "scoped_update" ON "clinic"."patients";

DROP POLICY "scoped_insert" ON "clinic"."payments";

DROP POLICY "scoped_read" ON "clinic"."payments";

DROP POLICY "scoped_update" ON "clinic"."payments";

DROP POLICY "scoped_insert" ON "clinic"."procedures";

DROP POLICY "scoped_read" ON "clinic"."procedures";

DROP POLICY "scoped_update" ON "clinic"."procedures";

DROP POLICY "request_insert" ON "clinic"."requests";

DROP POLICY "request_read" ON "clinic"."requests";

DROP POLICY "scoped_insert" ON "clinic"."results";

DROP POLICY "scoped_read" ON "clinic"."results";

DROP POLICY "scoped_update" ON "clinic"."results";

DROP POLICY "scoped_insert" ON "clinic"."services";

DROP POLICY "scoped_read" ON "clinic"."services";

DROP POLICY "scoped_update" ON "clinic"."services";

DROP POLICY "scoped_insert" ON "clinic"."stock_lots";

DROP POLICY "scoped_read" ON "clinic"."stock_lots";

DROP POLICY "scoped_update" ON "clinic"."stock_lots";

DROP POLICY "scoped_insert" ON "clinic"."stock_movements";

DROP POLICY "scoped_read" ON "clinic"."stock_movements";

DROP POLICY "scoped_update" ON "clinic"."stock_movements";

DROP POLICY "scoped_insert" ON "clinic"."tasks";

DROP POLICY "scoped_read" ON "clinic"."tasks";

DROP POLICY "scoped_update" ON "clinic"."tasks";

DROP POLICY "scoped_insert" ON "clinic"."tills";

DROP POLICY "scoped_read" ON "clinic"."tills";

DROP POLICY "scoped_update" ON "clinic"."tills";

CREATE TABLE "clinic"."access_events" (
  "id"              uuid                     NOT NULL DEFAULT gen_random_uuid(),
  "organization_id" uuid                     NOT NULL,
  "action"          text                     NOT NULL,
  "target_id"       uuid,
  "reason"          text                     NOT NULL,
  "created_at"      timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT "access_events_organization_id_id_key" UNIQUE (organization_id, id),
  CONSTRAINT "access_events_pkey" PRIMARY KEY (id),
  "created_by"      uuid                     NOT NULL DEFAULT auth.uid()
);

ALTER TABLE "clinic"."access_events"
  ENABLE ROW LEVEL SECURITY;

CREATE TABLE "clinic"."account_mappings" (
  "id"              uuid                     NOT NULL DEFAULT gen_random_uuid(),
  "organization_id" uuid                     NOT NULL,
  "name"            text                     NOT NULL,
  "codes"           jsonb                    NOT NULL,
  "approved_at"     timestamp with time zone,
  "approved_by"     uuid,
  "created_at"      timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT "account_mappings_codes_check" CHECK ((jsonb_typeof(codes) = 'object'::text)),
  CONSTRAINT "account_mappings_organization_id_id_key" UNIQUE (organization_id, id),
  CONSTRAINT "account_mappings_organization_id_name_key" UNIQUE (organization_id, name),
  CONSTRAINT "account_mappings_pkey" PRIMARY KEY (id),
  "created_by"      uuid                     NOT NULL DEFAULT auth.uid()
);

ALTER TABLE "clinic"."account_mappings"
  ENABLE ROW LEVEL SECURITY;

CREATE TABLE "clinic"."accounting_acknowledgements" (
  "id"                 uuid                     NOT NULL DEFAULT gen_random_uuid(),
  "organization_id"    uuid                     NOT NULL,
  "batch_id"           uuid                     NOT NULL,
  "external_reference" text                     NOT NULL,
  "notes"              text                     NOT NULL,
  "created_at"         timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT "accounting_acknowledgements_batch_id_key" UNIQUE (batch_id),
  CONSTRAINT "accounting_acknowledgements_external_reference_check" CHECK ((length(TRIM(BOTH FROM external_reference)) >= 2)),
  CONSTRAINT "accounting_acknowledgements_organization_id_external_refere_key" UNIQUE (organization_id, external_reference),
  CONSTRAINT "accounting_acknowledgements_organization_id_id_key" UNIQUE (organization_id, id),
  CONSTRAINT "accounting_acknowledgements_pkey" PRIMARY KEY (id),
  "created_by"         uuid                     NOT NULL DEFAULT auth.uid()
);

ALTER TABLE "clinic"."accounting_acknowledgements"
  ENABLE ROW LEVEL SECURITY;

CREATE TABLE "clinic"."accounting_batch_items" (
  "id"              uuid                     NOT NULL DEFAULT gen_random_uuid(),
  "organization_id" uuid                     NOT NULL,
  "batch_id"        uuid                     NOT NULL,
  "line_id"         uuid                     NOT NULL,
  "account_code"    text                     NOT NULL,
  "created_at"      timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT "accounting_batch_items_line_id_key" UNIQUE (line_id),
  CONSTRAINT "accounting_batch_items_organization_id_id_key" UNIQUE (organization_id, id),
  CONSTRAINT "accounting_batch_items_pkey" PRIMARY KEY (id)
);

ALTER TABLE "clinic"."accounting_batch_items"
  ENABLE ROW LEVEL SECURITY;

CREATE TABLE "clinic"."accounting_batches" (
  "id"              uuid                     NOT NULL DEFAULT gen_random_uuid(),
  "organization_id" uuid                     NOT NULL,
  "mapping_id"      uuid                     NOT NULL,
  "from_day"        date                     NOT NULL,
  "to_day"          date                     NOT NULL,
  "created_at"      timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT "accounting_batches_check" CHECK ((to_day >= from_day)),
  CONSTRAINT "accounting_batches_organization_id_id_key" UNIQUE (organization_id, id),
  CONSTRAINT "accounting_batches_pkey" PRIMARY KEY (id),
  "created_by"      uuid                     NOT NULL DEFAULT auth.uid()
);

ALTER TABLE "clinic"."accounting_batches"
  ENABLE ROW LEVEL SECURITY;

CREATE TABLE "clinic"."accounting_periods" (
  "id"              uuid                     NOT NULL DEFAULT gen_random_uuid(),
  "organization_id" uuid                     NOT NULL,
  "from_day"        date                     NOT NULL,
  "to_day"          date                     NOT NULL,
  "reason"          text                     NOT NULL,
  "created_at"      timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT "accounting_periods_check" CHECK ((to_day >= from_day)),
  CONSTRAINT "accounting_periods_organization_id_id_key" UNIQUE (organization_id, id),
  CONSTRAINT "accounting_periods_pkey" PRIMARY KEY (id),
  CONSTRAINT "accounting_periods_reason_check" CHECK ((length(TRIM(BOTH FROM reason)) >= 5)),
  "created_by"      uuid                     NOT NULL DEFAULT auth.uid()
);

ALTER TABLE "clinic"."accounting_periods"
  ENABLE ROW LEVEL SECURITY;

CREATE TABLE "clinic"."additional_roles" (
  "id"              uuid                     NOT NULL DEFAULT gen_random_uuid(),
  "organization_id" uuid                     NOT NULL,
  "member_id"       uuid                     NOT NULL,
  "role"            text                     NOT NULL,
  "reason"          text                     NOT NULL,
  "created_at"      timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT "additional_roles_organization_id_id_key" UNIQUE (organization_id, id),
  CONSTRAINT "additional_roles_pkey" PRIMARY KEY (id),
  CONSTRAINT "additional_roles_reason_check" CHECK ((length(TRIM(BOTH FROM reason)) >= 5)),
  CONSTRAINT "additional_roles_role_check" CHECK ((role = ANY (ARRAY['doctor'::text, 'receptionist'::text, 'accountant'::text]))),
  "created_by"      uuid                     NOT NULL DEFAULT auth.uid()
);

ALTER TABLE "clinic"."additional_roles"
  ENABLE ROW LEVEL SECURITY;

CREATE TABLE "clinic"."approval_limits" (
  "id"              uuid                     NOT NULL DEFAULT gen_random_uuid(),
  "organization_id" uuid                     NOT NULL,
  "member_id"       uuid                     NOT NULL,
  "currency"        text                     NOT NULL,
  "max_amount"      numeric(18,3)            NOT NULL,
  "reason"          text                     NOT NULL,
  "created_at"      timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT "approval_limits_check"
    CHECK (((max_amount >= (0)::numeric) AND (max_amount <> 'NaN'::numeric) AND ((currency <> 'USD'::text) OR (max_amount = round(max_amount, 2))))),
  CONSTRAINT "approval_limits_currency_check" CHECK ((currency = ANY (ARRAY['IQD'::text, 'USD'::text]))),
  CONSTRAINT "approval_limits_organization_id_id_key" UNIQUE (organization_id, id),
  CONSTRAINT "approval_limits_pkey" PRIMARY KEY (id),
  CONSTRAINT "approval_limits_reason_check" CHECK ((length(TRIM(BOTH FROM reason)) >= 5)),
  "created_by"      uuid                     NOT NULL DEFAULT auth.uid()
);

ALTER TABLE "clinic"."approval_limits"
  ENABLE ROW LEVEL SECURITY;

CREATE TABLE "clinic"."availability_cancellations" (
  "id"              uuid                     NOT NULL DEFAULT gen_random_uuid(),
  "organization_id" uuid                     NOT NULL,
  "availability_id" uuid                     NOT NULL,
  "reason"          text                     NOT NULL,
  "created_at"      timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT "availability_cancellations_availability_id_key" UNIQUE (availability_id),
  CONSTRAINT "availability_cancellations_organization_id_id_key" UNIQUE (organization_id, id),
  CONSTRAINT "availability_cancellations_pkey" PRIMARY KEY (id),
  CONSTRAINT "availability_cancellations_reason_check" CHECK ((length(TRIM(BOTH FROM reason)) >= 5)),
  "created_by"      uuid                     NOT NULL DEFAULT auth.uid()
);

ALTER TABLE "clinic"."availability_cancellations"
  ENABLE ROW LEVEL SECURITY;

CREATE TABLE "clinic"."bank_match_reversals" (
  "id"              uuid                     NOT NULL DEFAULT gen_random_uuid(),
  "organization_id" uuid                     NOT NULL,
  "match_id"        uuid                     NOT NULL,
  "reason"          text                     NOT NULL,
  "created_at"      timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT "bank_match_reversals_match_id_key" UNIQUE (match_id),
  CONSTRAINT "bank_match_reversals_organization_id_id_key" UNIQUE (organization_id, id),
  CONSTRAINT "bank_match_reversals_pkey" PRIMARY KEY (id),
  CONSTRAINT "bank_match_reversals_reason_check" CHECK ((length(TRIM(BOTH FROM reason)) >= 5)),
  "created_by"      uuid                     NOT NULL DEFAULT auth.uid()
);

ALTER TABLE "clinic"."bank_match_reversals"
  ENABLE ROW LEVEL SECURITY;

CREATE TABLE "clinic"."bank_matches" (
  "id"              uuid                     NOT NULL DEFAULT gen_random_uuid(),
  "organization_id" uuid                     NOT NULL,
  "statement_id"    uuid                     NOT NULL,
  "journal_line_id" uuid                     NOT NULL,
  "reason"          text                     NOT NULL,
  "created_at"      timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT "bank_matches_organization_id_id_key" UNIQUE (organization_id, id),
  CONSTRAINT "bank_matches_pkey" PRIMARY KEY (id),
  CONSTRAINT "bank_matches_reason_check" CHECK ((length(TRIM(BOTH FROM reason)) >= 5)),
  "created_by"      uuid                     NOT NULL DEFAULT auth.uid()
);

ALTER TABLE "clinic"."bank_matches"
  ENABLE ROW LEVEL SECURITY;

CREATE TABLE "clinic"."bank_statement_lines" (
  "id"              uuid                     NOT NULL DEFAULT gen_random_uuid(),
  "organization_id" uuid                     NOT NULL,
  "account"         text                     NOT NULL,
  "currency"        text                     NOT NULL,
  "posted_on"       date                     NOT NULL,
  "amount"          numeric(18,3)            NOT NULL,
  "reference"       text                     NOT NULL,
  "external_id"     text                     NOT NULL,
  "created_at"      timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT "bank_statement_lines_account_check" CHECK ((account = ANY (ARRAY['bank'::text, 'card'::text]))),
  CONSTRAINT "bank_statement_lines_amount_finite" CHECK ((amount <> 'NaN'::numeric)),
  CONSTRAINT "bank_statement_lines_check" CHECK (((amount <> (0)::numeric) AND ((currency <> 'USD'::text) OR (amount = round(amount, 2))))),
  CONSTRAINT "bank_statement_lines_currency_check" CHECK ((currency = ANY (ARRAY['IQD'::text, 'USD'::text]))),
  CONSTRAINT "bank_statement_lines_organization_id_account_currency_exter_key" UNIQUE (organization_id, account, currency, external_id),
  CONSTRAINT "bank_statement_lines_organization_id_id_key" UNIQUE (organization_id, id),
  CONSTRAINT "bank_statement_lines_pkey" PRIMARY KEY (id),
  "created_by"      uuid                     NOT NULL DEFAULT auth.uid()
);

ALTER TABLE "clinic"."bank_statement_lines"
  ENABLE ROW LEVEL SECURITY;

CREATE TABLE "clinic"."care_assignments" (
  "id"              uuid                     NOT NULL DEFAULT gen_random_uuid(),
  "organization_id" uuid                     NOT NULL,
  "patient_id"      uuid                     NOT NULL,
  "doctor_id"       uuid                     NOT NULL,
  "reason"          text                     NOT NULL,
  "created_at"      timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT "care_assignments_organization_id_id_key" UNIQUE (organization_id, id),
  CONSTRAINT "care_assignments_pkey" PRIMARY KEY (id),
  CONSTRAINT "care_assignments_reason_check" CHECK ((length(TRIM(BOTH FROM reason)) >= 5)),
  "created_by"      uuid                     NOT NULL DEFAULT auth.uid()
);

ALTER TABLE "clinic"."care_assignments"
  ENABLE ROW LEVEL SECURITY;

CREATE TABLE "clinic"."care_revocations" (
  "id"              uuid                     NOT NULL DEFAULT gen_random_uuid(),
  "organization_id" uuid                     NOT NULL,
  "assignment_id"   uuid                     NOT NULL,
  "reason"          text                     NOT NULL,
  "created_at"      timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT "care_revocations_assignment_id_key" UNIQUE (assignment_id),
  CONSTRAINT "care_revocations_organization_id_id_key" UNIQUE (organization_id, id),
  CONSTRAINT "care_revocations_pkey" PRIMARY KEY (id),
  CONSTRAINT "care_revocations_reason_check" CHECK ((length(TRIM(BOTH FROM reason)) >= 5)),
  "created_by"      uuid                     NOT NULL DEFAULT auth.uid()
);

ALTER TABLE "clinic"."care_revocations"
  ENABLE ROW LEVEL SECURITY;

CREATE TABLE "clinic"."clinic_resources" (
  "id"              uuid                     NOT NULL DEFAULT gen_random_uuid(),
  "organization_id" uuid                     NOT NULL,
  "name"            text                     NOT NULL,
  "kind"            text                     NOT NULL,
  "active"          boolean                  NOT NULL DEFAULT true,
  "created_at"      timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT "clinic_resources_kind_check" CHECK ((kind = ANY (ARRAY['room'::text, 'device'::text]))),
  CONSTRAINT "clinic_resources_organization_id_id_key" UNIQUE (organization_id, id),
  CONSTRAINT "clinic_resources_organization_id_name_key" UNIQUE (organization_id, name),
  CONSTRAINT "clinic_resources_pkey" PRIMARY KEY (id)
);

ALTER TABLE "clinic"."clinic_resources"
  ENABLE ROW LEVEL SECURITY;

CREATE TABLE "clinic"."clinical_facts" (
  "id"              uuid                     NOT NULL DEFAULT gen_random_uuid(),
  "organization_id" uuid                     NOT NULL,
  "patient_id"      uuid                     NOT NULL,
  "kind"            text                     NOT NULL,
  "content"         text                     NOT NULL,
  "status"          text                     NOT NULL,
  "supersedes_id"   uuid,
  "created_at"      timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT "clinical_facts_content_check" CHECK (((length(TRIM(BOTH FROM content)) >= 2) AND (length(TRIM(BOTH FROM content)) <= 10000))),
  CONSTRAINT "clinical_facts_kind_check" CHECK ((kind = ANY (ARRAY['allergy'::text, 'problem'::text, 'medication'::text, 'history'::text]))),
  CONSTRAINT "clinical_facts_organization_id_id_key" UNIQUE (organization_id, id),
  CONSTRAINT "clinical_facts_pkey" PRIMARY KEY (id),
  CONSTRAINT "clinical_facts_status_check" CHECK ((status = ANY (ARRAY['active'::text, 'resolved'::text, 'entered_in_error'::text]))),
  CONSTRAINT "clinical_facts_supersedes_id_key" UNIQUE (supersedes_id),
  "created_by"      uuid                     NOT NULL DEFAULT auth.uid()
);

ALTER TABLE "clinic"."clinical_facts"
  ENABLE ROW LEVEL SECURITY;

CREATE TABLE "clinic"."clinician_availability" (
  "id"              uuid                     NOT NULL DEFAULT gen_random_uuid(),
  "organization_id" uuid                     NOT NULL,
  "doctor_id"       uuid                     NOT NULL,
  "starts_at"       timestamp with time zone NOT NULL,
  "ends_at"         timestamp with time zone NOT NULL,
  "kind"            text                     NOT NULL,
  "description"     text                     NOT NULL,
  "created_at"      timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT "clinician_availability_check" CHECK ((ends_at > starts_at)),
  CONSTRAINT "clinician_availability_kind_check" CHECK ((kind = ANY (ARRAY['available'::text, 'leave'::text]))),
  CONSTRAINT "clinician_availability_organization_id_id_key" UNIQUE (organization_id, id),
  CONSTRAINT "clinician_availability_pkey" PRIMARY KEY (id)
);

ALTER TABLE "clinic"."clinician_availability"
  ENABLE ROW LEVEL SECURITY;

CREATE TABLE "clinic"."contact_log" (
  "id"              uuid                     NOT NULL DEFAULT gen_random_uuid(),
  "organization_id" uuid                     NOT NULL,
  "patient_id"      uuid                     NOT NULL,
  "channel"         text                     NOT NULL,
  "purpose"         text                     NOT NULL,
  "outcome"         text                     NOT NULL,
  "notes"           text                     NOT NULL,
  "created_at"      timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT "contact_log_channel_check" CHECK ((channel = ANY (ARRAY['phone'::text, 'in_person'::text, 'sms'::text, 'whatsapp'::text, 'other'::text]))),
  CONSTRAINT "contact_log_notes_check" CHECK (((length(TRIM(BOTH FROM notes)) >= 1) AND (length(TRIM(BOTH FROM notes)) <= 10000))),
  CONSTRAINT "contact_log_organization_id_id_key" UNIQUE (organization_id, id),
  CONSTRAINT "contact_log_outcome_check" CHECK ((outcome = ANY (ARRAY['reached'::text, 'no_answer'::text, 'declined'::text, 'scheduled'::text, 'other'::text]))),
  CONSTRAINT "contact_log_pkey" PRIMARY KEY (id),
  CONSTRAINT "contact_log_purpose_check" CHECK ((length(TRIM(BOTH FROM purpose)) > 0)),
  "created_by"      uuid                     NOT NULL DEFAULT auth.uid()
);

ALTER TABLE "clinic"."contact_log"
  ENABLE ROW LEVEL SECURITY;

CREATE TABLE "clinic"."document_templates" (
  "id"              uuid                     NOT NULL DEFAULT gen_random_uuid(),
  "organization_id" uuid                     NOT NULL,
  "kind"            text                     NOT NULL,
  "name"            text                     NOT NULL,
  "language"        text                     NOT NULL,
  "version"         integer                  NOT NULL,
  "content"         text                     NOT NULL,
  "status"          text                     NOT NULL DEFAULT 'draft'::text,
  "approved_by"     uuid,
  "approved_at"     timestamp with time zone,
  "created_at"      timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT "document_templates_check" CHECK (((status = 'approved'::text) = ((approved_at IS NOT NULL) AND (approved_by IS NOT NULL)))),
  CONSTRAINT "document_templates_content_check" CHECK (((length(TRIM(BOTH FROM content)) >= 5) AND (length(TRIM(BOTH FROM content)) <= 30000))),
  CONSTRAINT "document_templates_kind_check" CHECK ((kind = ANY (ARRAY['procedure'::text, 'consent'::text, 'aftercare'::text, 'referral'::text, 'clinical'::text]))),
  CONSTRAINT "document_templates_language_check" CHECK ((language = ANY (ARRAY['en'::text, 'ckb'::text]))),
  CONSTRAINT "document_templates_name_check" CHECK (((length(TRIM(BOTH FROM name)) >= 2) AND (length(TRIM(BOTH FROM name)) <= 160))),
  CONSTRAINT "document_templates_organization_id_id_key" UNIQUE (organization_id, id),
  CONSTRAINT "document_templates_organization_id_kind_name_language_versi_key" UNIQUE (organization_id, kind, name, LANGUAGE, VERSION),
  CONSTRAINT "document_templates_pkey" PRIMARY KEY (id),
  CONSTRAINT "document_templates_status_check" CHECK ((status = ANY (ARRAY['draft'::text, 'approved'::text]))),
  CONSTRAINT "document_templates_version_check" CHECK ((version > 0)),
  "created_by"      uuid                     NOT NULL DEFAULT auth.uid()
);

ALTER TABLE "clinic"."document_templates"
  ENABLE ROW LEVEL SECURITY;

CREATE TABLE "clinic"."hold_releases" (
  "id"              uuid                     NOT NULL DEFAULT gen_random_uuid(),
  "organization_id" uuid                     NOT NULL,
  "hold_id"         uuid                     NOT NULL,
  "reason"          text                     NOT NULL,
  "created_at"      timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT "hold_releases_hold_id_key" UNIQUE (hold_id),
  CONSTRAINT "hold_releases_organization_id_id_key" UNIQUE (organization_id, id),
  CONSTRAINT "hold_releases_pkey" PRIMARY KEY (id),
  CONSTRAINT "hold_releases_reason_check" CHECK ((length(TRIM(BOTH FROM reason)) >= 5)),
  "created_by"      uuid                     NOT NULL DEFAULT auth.uid()
);

ALTER TABLE "clinic"."hold_releases"
  ENABLE ROW LEVEL SECURITY;

CREATE TABLE "clinic"."inventory_products" (
  "id"              uuid                     NOT NULL DEFAULT gen_random_uuid(),
  "organization_id" uuid                     NOT NULL,
  "name"            text                     NOT NULL,
  "unit"            text                     NOT NULL,
  "reorder_level"   numeric(18,3)            NOT NULL DEFAULT 0,
  "supplier_id"     uuid,
  "active"          boolean                  NOT NULL DEFAULT true,
  "created_at"      timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT "inventory_products_name_check" CHECK (((length(TRIM(BOTH FROM name)) >= 2) AND (length(TRIM(BOTH FROM name)) <= 160))),
  CONSTRAINT "inventory_products_organization_id_id_key" UNIQUE (organization_id, id),
  CONSTRAINT "inventory_products_organization_id_name_unit_key" UNIQUE (organization_id, name, unit),
  CONSTRAINT "inventory_products_pkey" PRIMARY KEY (id),
  CONSTRAINT "inventory_products_reorder_level_check" CHECK (((reorder_level >= (0)::numeric) AND (reorder_level <> 'NaN'::numeric))),
  CONSTRAINT "inventory_products_unit_check" CHECK ((length(TRIM(BOTH FROM unit)) > 0)),
  "created_by"      uuid                     NOT NULL DEFAULT auth.uid()
);

ALTER TABLE "clinic"."inventory_products"
  ENABLE ROW LEVEL SECURITY;

CREATE TABLE "clinic"."legal_holds" (
  "id"              uuid                     NOT NULL DEFAULT gen_random_uuid(),
  "organization_id" uuid                     NOT NULL,
  "patient_id"      uuid                     NOT NULL,
  "reason"          text                     NOT NULL,
  "created_at"      timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT "legal_holds_organization_id_id_key" UNIQUE (organization_id, id),
  CONSTRAINT "legal_holds_pkey" PRIMARY KEY (id),
  CONSTRAINT "legal_holds_reason_check" CHECK ((length(TRIM(BOTH FROM reason)) >= 5)),
  "created_by"      uuid                     NOT NULL DEFAULT auth.uid()
);

ALTER TABLE "clinic"."legal_holds"
  ENABLE ROW LEVEL SECURITY;

CREATE TABLE "clinic"."media_cleanup_events" (
  "id"              uuid                     NOT NULL DEFAULT gen_random_uuid(),
  "organization_id" uuid                     NOT NULL,
  "media_id"        uuid                     NOT NULL,
  "object_key"      text                     NOT NULL,
  "created_at"      timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT "media_cleanup_events_object_key_key" UNIQUE (object_key),
  CONSTRAINT "media_cleanup_events_pkey" PRIMARY KEY (id)
);

ALTER TABLE "clinic"."media_cleanup_events"
  ENABLE ROW LEVEL SECURITY;

CREATE TABLE "clinic"."package_corrections" (
  "id"              uuid                     NOT NULL DEFAULT gen_random_uuid(),
  "organization_id" uuid                     NOT NULL,
  "package_id"      uuid                     NOT NULL,
  "amount"          numeric(18,3)            NOT NULL,
  "currency"        text                     NOT NULL,
  "kind"            text                     NOT NULL,
  "reason"          text                     NOT NULL,
  "created_at"      timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT "package_corrections_amount_check" CHECK ((amount >= (0)::numeric)),
  CONSTRAINT "package_corrections_amount_finite" CHECK ((amount <> 'NaN'::numeric)),
  CONSTRAINT "package_corrections_currency_check" CHECK ((currency = ANY (ARRAY['IQD'::text, 'USD'::text]))),
  CONSTRAINT "package_corrections_kind_check" CHECK ((kind = ANY (ARRAY['refund'::text, 'expiry_extension'::text]))),
  CONSTRAINT "package_corrections_organization_id_id_key" UNIQUE (organization_id, id),
  CONSTRAINT "package_corrections_pkey" PRIMARY KEY (id),
  CONSTRAINT "package_corrections_reason_check" CHECK ((length(TRIM(BOTH FROM reason)) >= 5)),
  "created_by"      uuid                     NOT NULL DEFAULT auth.uid()
);

ALTER TABLE "clinic"."package_corrections"
  ENABLE ROW LEVEL SECURITY;

CREATE TABLE "clinic"."patient_documents" (
  "id"                uuid                     NOT NULL DEFAULT gen_random_uuid(),
  "organization_id"   uuid                     NOT NULL,
  "patient_id"        uuid                     NOT NULL,
  "kind"              text                     NOT NULL,
  "title"             text                     NOT NULL,
  "body"              text                     NOT NULL,
  "template_id"       uuid,
  "template_snapshot" jsonb,
  "supersedes_id"     uuid,
  "correction_reason" text,
  "signed_at"         timestamp with time zone NOT NULL DEFAULT now(),
  "created_at"        timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT "patient_documents_body_check" CHECK (((length(TRIM(BOTH FROM body)) >= 5) AND (length(TRIM(BOTH FROM body)) <= 30000))),
  CONSTRAINT "patient_documents_check" CHECK (((supersedes_id IS NULL) OR (length(TRIM(BOTH FROM correction_reason)) >= 5))),
  CONSTRAINT "patient_documents_kind_check" CHECK ((kind = ANY (ARRAY['referral'::text, 'aftercare'::text, 'care_letter'::text]))),
  CONSTRAINT "patient_documents_organization_id_id_key" UNIQUE (organization_id, id),
  CONSTRAINT "patient_documents_pkey" PRIMARY KEY (id),
  CONSTRAINT "patient_documents_title_check" CHECK ((length(TRIM(BOTH FROM title)) >= 2)),
  "signed_by"         uuid                     NOT NULL DEFAULT auth.uid()
);

ALTER TABLE "clinic"."patient_documents"
  ENABLE ROW LEVEL SECURITY;

CREATE TABLE "clinic"."patient_exports" (
  "id"              uuid                     NOT NULL DEFAULT gen_random_uuid(),
  "organization_id" uuid                     NOT NULL,
  "patient_id"      uuid                     NOT NULL,
  "purpose"         text                     NOT NULL,
  "created_at"      timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT "patient_exports_organization_id_id_key" UNIQUE (organization_id, id),
  CONSTRAINT "patient_exports_pkey" PRIMARY KEY (id),
  CONSTRAINT "patient_exports_purpose_check" CHECK ((length(TRIM(BOTH FROM purpose)) >= 10)),
  "created_by"      uuid                     NOT NULL DEFAULT auth.uid()
);

ALTER TABLE "clinic"."patient_exports"
  ENABLE ROW LEVEL SECURITY;

CREATE TABLE "clinic"."performed_services" (
  "id"              uuid                     NOT NULL DEFAULT gen_random_uuid(),
  "organization_id" uuid                     NOT NULL,
  "patient_id"      uuid                     NOT NULL,
  "encounter_id"    uuid                     NOT NULL,
  "service_id"      uuid                     NOT NULL,
  "quantity"        integer                  NOT NULL,
  "invoice_id"      uuid,
  "created_at"      timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT "performed_services_organization_id_id_key" UNIQUE (organization_id, id),
  CONSTRAINT "performed_services_pkey" PRIMARY KEY (id),
  CONSTRAINT "performed_services_quantity_check" CHECK (((quantity >= 1) AND (quantity <= 1000))),
  "created_by"      uuid                     NOT NULL DEFAULT auth.uid()
);

ALTER TABLE "clinic"."performed_services"
  ENABLE ROW LEVEL SECURITY;

CREATE TABLE "clinic"."prescription_items" (
  "id"              uuid                     NOT NULL DEFAULT gen_random_uuid(),
  "organization_id" uuid                     NOT NULL,
  "encounter_id"    uuid                     NOT NULL,
  "medicine"        text                     NOT NULL,
  "strength"        text                     NOT NULL DEFAULT ''::text,
  "dose"            text                     NOT NULL,
  "route"           text                     NOT NULL,
  "frequency"       text                     NOT NULL,
  "duration"        text                     NOT NULL,
  "quantity"        text                     NOT NULL DEFAULT ''::text,
  "instructions"    text                     NOT NULL DEFAULT ''::text,
  "created_at"      timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT "prescription_items_check" CHECK (((length(TRIM(BOTH FROM route)) > 0) AND (length(TRIM(BOTH FROM frequency)) > 0) AND (length(TRIM(BOTH FROM duration)) > 0))),
  CONSTRAINT "prescription_items_dose_check" CHECK ((length(TRIM(BOTH FROM dose)) > 0)),
  CONSTRAINT "prescription_items_medicine_check" CHECK (((length(TRIM(BOTH FROM medicine)) >= 1) AND (length(TRIM(BOTH FROM medicine)) <= 200))),
  CONSTRAINT "prescription_items_organization_id_id_key" UNIQUE (organization_id, id),
  CONSTRAINT "prescription_items_pkey" PRIMARY KEY (id),
  "created_by"      uuid                     NOT NULL DEFAULT auth.uid()
);

ALTER TABLE "clinic"."prescription_items"
  ENABLE ROW LEVEL SECURITY;

CREATE TABLE "clinic"."retention_rules" (
  "id"               uuid                     NOT NULL DEFAULT gen_random_uuid(),
  "organization_id"  uuid                     NOT NULL,
  "record_type"      text                     NOT NULL,
  "retain_days"      integer                  NOT NULL,
  "policy_reference" text                     NOT NULL,
  "approved_at"      timestamp with time zone,
  "approved_by"      uuid,
  "created_at"       timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT "retention_rules_organization_id_id_key" UNIQUE (organization_id, id),
  CONSTRAINT "retention_rules_pkey" PRIMARY KEY (id),
  CONSTRAINT "retention_rules_policy_reference_check" CHECK ((length(TRIM(BOTH FROM policy_reference)) >= 5)),
  CONSTRAINT "retention_rules_record_type_check" CHECK ((record_type = ANY (ARRAY['clinical'::text, 'media'::text, 'finance'::text, 'audit'::text, 'contact'::text]))),
  CONSTRAINT "retention_rules_retain_days_check" CHECK ((retain_days > 0)),
  "created_by"       uuid                     NOT NULL DEFAULT auth.uid()
);

ALTER TABLE "clinic"."retention_rules"
  ENABLE ROW LEVEL SECURITY;

CREATE TABLE "clinic"."role_revocations" (
  "id"              uuid                     NOT NULL DEFAULT gen_random_uuid(),
  "organization_id" uuid                     NOT NULL,
  "grant_id"        uuid                     NOT NULL,
  "reason"          text                     NOT NULL,
  "created_at"      timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT "role_revocations_grant_id_key" UNIQUE (grant_id),
  CONSTRAINT "role_revocations_organization_id_id_key" UNIQUE (organization_id, id),
  CONSTRAINT "role_revocations_pkey" PRIMARY KEY (id),
  CONSTRAINT "role_revocations_reason_check" CHECK ((length(TRIM(BOTH FROM reason)) >= 5)),
  "created_by"      uuid                     NOT NULL DEFAULT auth.uid()
);

ALTER TABLE "clinic"."role_revocations"
  ENABLE ROW LEVEL SECURITY;

CREATE TABLE "clinic"."suppliers" (
  "id"              uuid                     NOT NULL DEFAULT gen_random_uuid(),
  "organization_id" uuid                     NOT NULL,
  "name"            text                     NOT NULL,
  "contact_person"  text                     NOT NULL DEFAULT ''::text,
  "phone"           text,
  "address"         text                     NOT NULL DEFAULT ''::text,
  "active"          boolean                  NOT NULL DEFAULT true,
  "version"         integer                  NOT NULL DEFAULT 1,
  "created_at"      timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT "suppliers_name_check" CHECK (((length(TRIM(BOTH FROM name)) >= 2) AND (length(TRIM(BOTH FROM name)) <= 160))),
  CONSTRAINT "suppliers_organization_id_id_key" UNIQUE (organization_id, id),
  CONSTRAINT "suppliers_organization_id_name_key" UNIQUE (organization_id, name),
  CONSTRAINT "suppliers_pkey" PRIMARY KEY (id),
  "created_by"      uuid                     NOT NULL DEFAULT auth.uid()
);

ALTER TABLE "clinic"."suppliers"
  ENABLE ROW LEVEL SECURITY;

ALTER TABLE "clinic"."appointments"
  ADD COLUMN "resource_id" uuid;

ALTER TABLE "clinic"."consents"
  ADD COLUMN "template_id" uuid;

ALTER TABLE "clinic"."consents"
  ADD COLUMN "template_snapshot" jsonb;

ALTER TABLE "clinic"."contacts"
  ADD COLUMN "preferred" boolean NOT NULL DEFAULT false;

ALTER TABLE "clinic"."contacts"
  ADD COLUMN "verified_at" timestamp WITH time zone;

ALTER TABLE "clinic"."encounters"
  ADD COLUMN "template_id" uuid;

ALTER TABLE "clinic"."encounters"
  ADD COLUMN "template_snapshot" jsonb;

ALTER TABLE "clinic"."journals"
  ADD COLUMN "effective_date" date;

ALTER TABLE "clinic"."journals"
  ADD COLUMN "accounting_date" date GENERATED ALWAYS AS (COALESCE(effective_date, ((created_at AT TIME ZONE 'Asia/Baghdad'::text))::date)) STORED;

ALTER TABLE "clinic"."media"
  ADD COLUMN "preview_key" text;

ALTER TABLE "clinic"."media"
  ADD COLUMN "preview_sha256" text;

ALTER TABLE "clinic"."media"
  ADD COLUMN "processing_note" text;

ALTER TABLE "clinic"."media"
  ADD COLUMN "rejected_at" timestamp WITH time zone;

ALTER TABLE "clinic"."organizations"
  ADD COLUMN "clinical_access_scope" text NOT NULL DEFAULT 'organization'::text;

ALTER TABLE "clinic"."packages"
  ADD COLUMN "expires_on" date;

ALTER TABLE "clinic"."packages"
  ADD COLUMN "cancelled_at" timestamp WITH time zone;

ALTER TABLE "clinic"."packages"
  ADD COLUMN "sale_method" text;

ALTER TABLE "clinic"."packages"
  ADD COLUMN "patient_snapshot" jsonb NOT NULL DEFAULT '{}'::jsonb;

ALTER TABLE "clinic"."procedures"
  ADD COLUMN "template_id" uuid;

ALTER TABLE "clinic"."procedures"
  ADD COLUMN "template_snapshot" jsonb;

ALTER TABLE "clinic"."stock_lots"
  ADD COLUMN "created_at" timestamp WITH time zone NOT NULL DEFAULT now();

ALTER TABLE "clinic"."stock_lots"
  ADD COLUMN "product_id" uuid;

CREATE OR REPLACE FUNCTION clinic.allowed (
  perm text
)
  RETURNS boolean
  LANGUAGE sql
  STABLE
  SECURITY DEFINER
  SET search_path TO ''
  AS $function$
 select clinic.session_valid() and exists(select 1 from clinic.memberships m join clinic.organizations o on o.id=m.organization_id
 where m.user_id=auth.uid() and m.active and m.organization_id=clinic.org_id() and not m.password_change_required
 and perm=any(clinic.user_permissions()) and (not o.require_mfa or coalesce(auth.jwt()->>'aal','aal1')='aal2'))
$function$;

CREATE OR REPLACE FUNCTION clinic.canonical_patient_id (
  patient_id uuid
)
  RETURNS uuid
  LANGUAGE sql
  STABLE
  SECURITY DEFINER
  SET search_path TO ''
  AS $function$
 with recursive linked(id,merged_into) as (select p.id,p.merged_into from clinic.patients p where p.id=canonical_patient_id.patient_id and p.organization_id=clinic.org_id() and auth.uid() is not null
 union select p.id,p.merged_into from clinic.patients p join linked l on p.id=l.merged_into where p.organization_id=clinic.org_id()) select id from linked where merged_into is null limit 1
$function$;

CREATE OR REPLACE FUNCTION clinic.check_open_period()
  RETURNS TRIGGER
  LANGUAGE plpgsql
  SET search_path TO ''
  AS $function$declare posting_day date:=coalesce(new.effective_date,(new.created_at at time zone 'Asia/Baghdad')::date);begin
 perform pg_advisory_xact_lock(hashtextextended(new.organization_id::text,0));
 if not clinic.period_is_open(new.organization_id,posting_day) then raise exception 'Posting date is in a closed period or the future. Use an authorized adjustment in an open period.' using errcode='23514';end if;return new;end $function$;

CREATE OR REPLACE FUNCTION clinic.check_schedule()
  RETURNS TRIGGER
  LANGUAGE plpgsql
  SET search_path TO ''
  AS $function$begin
 perform pg_advisory_xact_lock(hashtextextended(new.organization_id::text,0));
 if new.status in ('cancelled','no_show','completed') then return new;end if;
 if exists(select 1 from clinic.appointments a where a.organization_id=new.organization_id and a.id<>new.id and a.status not in ('cancelled','no_show','completed') and a.starts_at<new.ends_at and a.ends_at>new.starts_at and (a.doctor_id=new.doctor_id or (new.resource_id is not null and a.resource_id=new.resource_id))) then raise exception 'The clinician or resource already has an appointment at this time' using errcode='23P01';end if;
 if new.resource_id is not null and not exists(select 1 from clinic.clinic_resources where id=new.resource_id and organization_id=new.organization_id and active) then raise exception 'Select an active clinic resource';end if;
 if exists(select 1 from clinic.clinician_availability a where a.organization_id=new.organization_id and a.doctor_id=new.doctor_id and a.kind='leave' and a.starts_at<new.ends_at and a.ends_at>new.starts_at and not exists(select 1 from clinic.availability_cancellations x where x.availability_id=a.id)) then raise exception 'The clinician is on leave during this time';end if;
 if exists(select 1 from clinic.clinician_availability a where a.organization_id=new.organization_id and a.doctor_id=new.doctor_id and a.kind='available' and not exists(select 1 from clinic.availability_cancellations x where x.availability_id=a.id)) and not exists(select 1 from clinic.clinician_availability where organization_id=new.organization_id and doctor_id=new.doctor_id and kind='available' and starts_at<=new.starts_at and ends_at>=new.ends_at and not exists(select 1 from clinic.availability_cancellations x where x.availability_id=clinic.clinician_availability.id)) then raise exception 'Appointment is outside the configured availability';end if;
 return new;
end $function$;

CREATE OR REPLACE FUNCTION clinic.encounter_care_access (
  encounter_id uuid
)
  RETURNS boolean
  LANGUAGE sql
  STABLE
  SECURITY DEFINER
  SET search_path TO ''
  AS $function$
 select exists(select 1 from clinic.encounters e where e.id=encounter_care_access.encounter_id and e.organization_id=clinic.org_id() and clinic.patient_care_access(e.patient_id))
$function$;

CREATE OR REPLACE FUNCTION clinic.encounter_lookup (
  patient_id    uuid,
  search_term   text,
  cursor_id     uuid,
  status_filter text,
  only_author   boolean
)
  RETURNS jsonb
  LANGUAGE plpgsql
  STABLE
  SECURITY DEFINER
  SET search_path TO ''
  AS $function$
declare items jsonb;more boolean;can_see_clinical boolean:=clinic.patient_care_access(patient_id);
begin
 if not (can_see_clinical or clinic.allowed('billing')) or not exists(select 1 from clinic.patients p where p.id=encounter_lookup.patient_id and p.organization_id=clinic.org_id()) then raise exception 'Patient encounter options unavailable' using errcode='42501';end if;
 select coalesce(jsonb_agg(to_jsonb(r) order by r.created_at desc,r.id desc),'[]') into items from (
 select e.id,e.created_at,e.status,case when can_see_clinical then e.chief_complaint else 'Signed encounter' end label
 from clinic.encounters e where e.organization_id=clinic.org_id() and e.patient_id in(select id from clinic.patient_ids(encounter_lookup.patient_id))
 and (can_see_clinical or e.status='signed') and (status_filter is null or e.status=status_filter) and (not only_author or e.doctor_id=auth.uid())
 and (cursor_id is null or (e.created_at,e.id)<(select c.created_at,c.id from clinic.encounters c where c.id=cursor_id and c.organization_id=clinic.org_id() and c.patient_id in(select id from clinic.patient_ids(encounter_lookup.patient_id))))
 and (coalesce(search_term,'')='' or (can_see_clinical and clinic.search_key(e.chief_complaint) like '%'||clinic.search_key(left(search_term,200))||'%') or e.created_at::text like '%'||left(search_term,50)||'%')
 order by e.created_at desc,e.id desc limit 26) r;
 more:=jsonb_array_length(items)>25;if more then items:=items-25;end if;
 return jsonb_build_object('items',items,'has_more',more);
end $function$;

CREATE OR REPLACE FUNCTION clinic.extra_roles (
  user_id uuid
)
  RETURNS text[]
  LANGUAGE sql
  STABLE
  SECURITY DEFINER
  SET search_path TO ''
  AS $function$
 select coalesce(array_agg(distinct g.role),array[]::text[]) from clinic.additional_roles g join clinic.memberships m on m.id=g.member_id
 where m.user_id=extra_roles.user_id and m.organization_id=clinic.org_id() and m.active and auth.uid() is not null
 and not exists(select 1 from clinic.role_revocations r where r.grant_id=g.id)
$function$;

CREATE OR REPLACE FUNCTION clinic.has_role (
  user_id   uuid,
  role_name text
)
  RETURNS boolean
  LANGUAGE sql
  STABLE
  SECURITY DEFINER
  SET search_path TO ''
  AS $function$
 select exists(select 1 from clinic.memberships m where m.user_id=has_role.user_id and m.organization_id=clinic.org_id() and m.active and auth.uid() is not null and (m.role=role_name or role_name=any(clinic.extra_roles(m.user_id))))
$function$;

CREATE OR REPLACE FUNCTION clinic.invoice_balance_at (
  invoice_id uuid,
  cutoff     timestamp with time zone
)
  RETURNS numeric
  LANGUAGE sql
  STABLE
  SET search_path TO ''
  AS $function$
 select i.total-coalesce((select sum(case when p.kind='refund' then -coalesce(p.invoice_amount,p.amount) else coalesce(p.invoice_amount,p.amount) end) from clinic.payments p where p.invoice_id=i.id and p.kind in ('payment','deposit_application','refund') and p.created_at<cutoff),0)-coalesce((select sum(c.amount) from clinic.credit_notes c where c.invoice_id=i.id and c.created_at<cutoff),0)
 from clinic.invoices i where i.id=invoice_balance_at.invoice_id and i.organization_id=clinic.org_id() and i.created_at<cutoff
$function$;

CREATE OR REPLACE FUNCTION clinic.media_rejection_time()
  RETURNS TRIGGER
  LANGUAGE plpgsql
  SET search_path TO ''
  AS $function$begin
 if new.status='rejected' and old.status<>'rejected' then new.rejected_at:=clock_timestamp();end if;
 return new;
end $function$;

CREATE OR REPLACE FUNCTION clinic.organization_care_access()
  RETURNS boolean
  LANGUAGE sql
  STABLE
  SECURITY DEFINER
  SET search_path TO ''
  AS $function$
 select clinic.allowed('clinical') and exists(select 1 from clinic.organizations where id=clinic.org_id() and clinical_access_scope='organization')
$function$;

CREATE OR REPLACE FUNCTION clinic.patient_care_access (
  patient_id uuid
)
  RETURNS boolean
  LANGUAGE sql
  STABLE
  SECURITY DEFINER
  SET search_path TO ''
  AS $function$
 select clinic.allowed('clinical') and exists(select 1 from clinic.organizations o where o.id=clinic.org_id() and clinic.canonical_patient_id(patient_care_access.patient_id) is not null
 and (o.clinical_access_scope='organization' or exists(select 1 from clinic.care_assignments a where a.organization_id=o.id and a.doctor_id=auth.uid() and a.patient_id in(select id from clinic.patient_ids(clinic.canonical_patient_id(patient_care_access.patient_id))) and not exists(select 1 from clinic.care_revocations r where r.assignment_id=a.id))))
$function$;

CREATE OR REPLACE FUNCTION clinic.period_is_open (
  org_id      uuid,
  posting_day date
)
  RETURNS boolean
  LANGUAGE sql
  STABLE
  SECURITY DEFINER
  SET search_path TO ''
  AS $function$
 select org_id=clinic.org_id() and clinic.session_valid() and posting_day<=(now() at time zone 'Asia/Baghdad')::date and not exists(select 1 from clinic.accounting_periods where organization_id=org_id and posting_day between from_day and to_day)
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
 when 'administrator' then array['patients','schedule','billing','finance','inventory','audit','staff']
 when 'doctor' then array['patients','schedule','clinical','media','results','inventory.read','clinical.export']
 when 'receptionist' then array['patients','schedule','billing']
 when 'accountant' then array['finance','approve','export','audit','payroll'] else array[]::text[] end
$function$;

CREATE OR REPLACE FUNCTION clinic.protect_approved_template()
  RETURNS TRIGGER
  LANGUAGE plpgsql
  SET search_path TO ''
  AS $function$begin
 if old.status='approved' then raise exception 'Approved templates are immutable. Create a new version.' using errcode='23514'; end if;return new;end $function$;

CREATE OR REPLACE FUNCTION clinic.protect_mapping()
  RETURNS TRIGGER
  LANGUAGE plpgsql
  SET search_path TO ''
  AS $function$begin if old.approved_at is not null then raise exception 'Approved account mappings are immutable' using errcode='23514';end if;return new;end $function$;

CREATE OR REPLACE FUNCTION clinic.protect_performed_service()
  RETURNS TRIGGER
  LANGUAGE plpgsql
  SET search_path TO ''
  AS $function$begin
 if row(new.id,new.organization_id,new.patient_id,new.encounter_id,new.service_id,new.quantity,new.created_by,new.created_at) is distinct from row(old.id,old.organization_id,old.patient_id,old.encounter_id,old.service_id,old.quantity,old.created_by,old.created_at) or old.invoice_id is not null then raise exception 'Performed services are immutable after invoicing' using errcode='23514';end if;return new;end $function$;

CREATE OR REPLACE FUNCTION clinic.protect_prescription()
  RETURNS TRIGGER
  LANGUAGE plpgsql
  SET search_path TO ''
  AS $function$begin
 if exists(select 1 from clinic.encounters where id=coalesce(new.encounter_id,old.encounter_id) and status='signed') then raise exception 'Signed prescriptions are immutable; use an addendum.' using errcode='23514'; end if;
 if tg_op='DELETE' then return old;end if;return new;end $function$;

CREATE OR REPLACE FUNCTION clinic.require_approval (
  amount   numeric,
  currency text
)
  RETURNS void
  LANGUAGE plpgsql
  STABLE
  SECURITY DEFINER
  SET search_path TO ''
  AS $function$
declare limit_amount numeric;
begin
 if not clinic.allowed('approve') or amount is null or amount<0 or amount='NaN'::numeric then raise exception 'Approval permission required' using errcode='42501';end if;
 select l.max_amount into limit_amount from clinic.approval_limits l join clinic.memberships m on m.id=l.member_id where m.user_id=auth.uid() and l.organization_id=clinic.org_id() and l.currency=require_approval.currency order by l.created_at desc,l.id desc limit 1;
 if found and amount>limit_amount then raise exception 'Amount exceeds your approval limit in this currency' using errcode='42501';end if;
end $function$;

CREATE OR REPLACE FUNCTION clinic.user_permissions()
  RETURNS text[]
  LANGUAGE sql
  STABLE
  SECURITY DEFINER
  SET search_path TO ''
  AS $function$
 select coalesce(array_agg(distinct p),array[]::text[]) from clinic.memberships m cross join lateral unnest(array[m.role]||clinic.extra_roles(m.user_id)) r(role) cross join lateral unnest(clinic.permissions(r.role)) p
 where m.organization_id=clinic.org_id() and m.user_id=auth.uid() and m.active
$function$;

CREATE OR REPLACE FUNCTION public.access_workflow (
  kind       text,
  payload    jsonb,
  request_id uuid
)
  RETURNS jsonb
  LANGUAGE plpgsql
  SET search_path TO ''
  AS $function$
declare o uuid:=clinic.org_id();actor uuid:=auth.uid();prior clinic.requests;fp text:=md5(kind||payload::text);rid uuid;v uuid;p uuid;member clinic.memberships;result jsonb;
begin
 perform clinic.require_permission('staff');
 if request_id is null or jsonb_typeof(payload)<>'object' or octet_length(payload::text)>20000 or length(trim(coalesce(payload->>'reason','')))<5 then raise exception 'A documented reason and valid request are required';end if;
 perform pg_advisory_xact_lock(hashtextextended(o::text,0));
 select * into prior from clinic.requests r where r.organization_id=o and r.actor_id=actor and r.request_id=access_workflow.request_id;
 if found then if prior.fingerprint<>fp then raise exception 'Request identifier reused with different content' using errcode='23505';end if;return prior.result;end if;
 v:=nullif(payload->>'user_id','')::uuid;p:=nullif(payload->>'patient_id','')::uuid;
 if v is not null then select * into member from clinic.memberships where user_id=v and organization_id=o and active;if not found then raise exception 'Active staff member unavailable';end if;end if;
 if p is not null and not exists(select 1 from clinic.patients where id=p and organization_id=o and merged_into is null) then raise exception 'Active patient unavailable';end if;
 if kind not in ('care.assign','care.revoke') and not clinic.has_role(actor,'owner') then raise exception 'Only the owner can change this policy' using errcode='42501';end if;
 case kind
 when 'access.role.grant' then
 if v=actor or member.role=payload->>'role' or exists(select 1 from clinic.additional_roles g where g.member_id=member.id and g.role=payload->>'role' and not exists(select 1 from clinic.role_revocations r where r.grant_id=g.id)) then raise exception 'Role is already assigned or targets your own account';end if;
 insert into clinic.additional_roles(organization_id,member_id,role,reason) values(o,member.id,payload->>'role',payload->>'reason') returning id into rid;
 when 'access.role.revoke' then
 select g.id into rid from clinic.additional_roles g where g.member_id=member.id and g.role=payload->>'role' and not exists(select 1 from clinic.role_revocations r where r.grant_id=g.id);
 if rid is null or v=actor then raise exception 'Additional role unavailable';end if;
 insert into clinic.role_revocations(organization_id,grant_id,reason) values(o,rid,payload->>'reason') returning id into rid;
 when 'access.limit.set' then
 if v=actor or member.role='owner' then raise exception 'Owner/self approval limits cannot be delegated';end if;
 insert into clinic.approval_limits(organization_id,member_id,currency,max_amount,reason) values(o,member.id,payload->>'currency',(payload->>'max_amount')::numeric,payload->>'reason') returning id into rid;
 when 'care.assign' then
 if not clinic.has_role(v,'doctor') or exists(select 1 from clinic.care_assignments a where a.patient_id=p and a.doctor_id=v and a.organization_id=o and not exists(select 1 from clinic.care_revocations r where r.assignment_id=a.id)) then raise exception 'Choose an active clinician without an existing assignment';end if;
 insert into clinic.care_assignments(organization_id,patient_id,doctor_id,reason) values(o,p,v,payload->>'reason') returning id into rid;
 when 'care.revoke' then
 insert into clinic.care_revocations(organization_id,assignment_id,reason) values(o,(payload->>'id')::uuid,payload->>'reason') returning id into rid;
 when 'care.scope.set' then
 update clinic.organizations set clinical_access_scope=payload->>'scope' where id=o returning id into rid;
 when 'retention.rule.create' then
 insert into clinic.retention_rules(organization_id,record_type,retain_days,policy_reference) values(o,payload->>'record_type',(payload->>'retain_days')::integer,payload->>'policy_reference') returning id into rid;
 when 'retention.rule.approve' then
 update clinic.retention_rules set approved_at=now(),approved_by=actor where id=(payload->>'id')::uuid and organization_id=o and approved_at is null returning id into rid;
 when 'retention.hold' then
 insert into clinic.legal_holds(organization_id,patient_id,reason) values(o,p,payload->>'reason') returning id into rid;
 when 'retention.release' then
 insert into clinic.hold_releases(organization_id,hold_id,reason) values(o,(payload->>'id')::uuid,payload->>'reason') returning id into rid;
 else raise exception 'Unknown access or retention operation';end case;
 if rid is null then raise exception 'No record changed';end if;
 insert into clinic.access_events(organization_id,action,target_id,reason) values(o,kind,rid,payload->>'reason');
 result:=jsonb_build_object('id',rid);insert into clinic.requests(organization_id,actor_id,request_id,fingerprint,result) values(o,actor,request_id,fp,result);return result;
end $function$;

REVOKE ALL ON FUNCTION "public"."access_workflow"(text, jsonb, uuid) FROM PUBLIC, "anon";

CREATE OR REPLACE FUNCTION public.accounting_batch_download (
  batch_id uuid
)
  RETURNS jsonb
  LANGUAGE plpgsql
  SET search_path TO ''
  AS $function$declare result jsonb;begin
 perform clinic.require_permission('export');
 if not exists(select 1 from clinic.accounting_batches where id=batch_id and organization_id=clinic.org_id()) then raise exception 'Batch unavailable';end if;
 select coalesce(jsonb_agg(to_jsonb(r) order by r.date,r.journal_id,r.line_id),'[]') into result from (select i.batch_id,j.id journal_id,l.id line_id,j.accounting_date date,j.currency,i.account_code,l.account,l.debit,l.credit,j.source_type,j.source_id,j.description from clinic.accounting_batch_items i join clinic.journal_lines l on l.id=i.line_id join clinic.journals j on j.id=l.journal_id where i.batch_id=accounting_batch_download.batch_id and i.organization_id=clinic.org_id()) r;
 perform clinic.log_access('ACCOUNTING_BATCH_DOWNLOAD',batch_id,'accounting_batch');return result;end $function$;

REVOKE ALL ON FUNCTION "public"."accounting_batch_download"(uuid) FROM PUBLIC, "anon";

CREATE OR REPLACE FUNCTION public.accounting_page (
  record_type text,
  search_term text DEFAULT ''::text,
  cursor_id   uuid DEFAULT NULL::uuid
)
  RETURNS jsonb
  LANGUAGE plpgsql
  STABLE
  SET search_path TO ''
  AS $function$
declare items jsonb;tbl text;more boolean;
begin perform clinic.require_permission('finance');
 select case record_type when 'statements' then 'bank_statement_lines' when 'matches' then 'bank_matches' when 'mappings' then 'account_mappings' when 'batches' then 'accounting_batches' when 'periods' then 'accounting_periods' end into tbl;
 if tbl is null then raise exception 'Invalid accounting list';end if;
 execute format($q$with records as (select r.id,r.created_at,to_jsonb(r) || case when $1='statements' then jsonb_build_object('matched',exists(select 1 from clinic.bank_matches m where m.statement_id=r.id and not exists(select 1 from clinic.bank_match_reversals x where x.match_id=m.id))) when $1='matches' then jsonb_build_object('reversed',exists(select 1 from clinic.bank_match_reversals x where x.match_id=r.id)) when $1='batches' then jsonb_build_object('acknowledged',exists(select 1 from clinic.accounting_acknowledgements a where a.batch_id=r.id)) else '{}'::jsonb end value from clinic.%I r where r.organization_id=$2),page as (select * from records r where ($3 is null or (r.created_at,r.id)<(select c.created_at,c.id from records c where c.id=$3)) and ($4='' or clinic.search_key(value::text) like '%%'||clinic.search_key(left($4,200))||'%%') order by created_at desc,id desc limit 51) select coalesce(jsonb_agg(value order by created_at desc,id desc),'[]') from page$q$,tbl) into items using record_type,clinic.org_id(),cursor_id,coalesce(search_term,'');
 more:=jsonb_array_length(items)>50;if more then items:=items-50;end if;return jsonb_build_object('items',items,'has_more',more);
end $function$;

REVOKE ALL ON FUNCTION "public"."accounting_page"(text, text, uuid) FROM PUBLIC, "anon";

CREATE OR REPLACE FUNCTION public.billing_patient_search (
  search_term text    DEFAULT ''::text,
  page_size   integer DEFAULT 50
)
  RETURNS jsonb
  LANGUAGE plpgsql
  STABLE
  SET search_path TO ''
  AS $function$
declare items jsonb;
begin
 if not (clinic.allowed('billing') or clinic.allowed('finance')) then raise exception 'Permission denied' using errcode='42501';end if;
 with identities as (
 select i.patient_id,i.patient_snapshot,i.created_at from clinic.invoices i where i.organization_id=clinic.org_id()
 union all select p.patient_id,p.patient_snapshot,p.created_at from clinic.payments p where p.organization_id=clinic.org_id()
 union all select p.patient_id,p.patient_snapshot,p.created_at from clinic.packages p where p.organization_id=clinic.org_id()
 ) select coalesce(jsonb_agg(to_jsonb(r)),'[]') into items from (
 select distinct on (i.patient_id) i.patient_id id,i.patient_snapshot->>'full_name' full_name,i.patient_snapshot->>'patient_number' patient_number
 from identities i where coalesce(search_term,'')='' or clinic.search_key(i.patient_snapshot::text) like '%'||clinic.search_key(left(search_term,200))||'%' order by i.patient_id,i.created_at desc limit least(greatest(page_size,1),100)) r;
 return jsonb_build_object('items',items);
end $function$;

CREATE OR REPLACE FUNCTION public.care_team (
  patient_id uuid
)
  RETURNS jsonb
  LANGUAGE plpgsql
  STABLE
  SET search_path TO ''
  AS $function$begin
 perform clinic.require_permission('staff');return coalesce((select jsonb_agg(to_jsonb(a)||jsonb_build_object('display_name',m.display_name)) from clinic.care_assignments a join clinic.memberships m on m.user_id=a.doctor_id and m.organization_id=a.organization_id where a.organization_id=clinic.org_id() and a.patient_id=care_team.patient_id and not exists(select 1 from clinic.care_revocations r where r.assignment_id=a.id)),'[]');end $function$;

REVOKE ALL ON FUNCTION "public"."care_team"(uuid) FROM PUBLIC, "anon";

CREATE OR REPLACE FUNCTION public.clinical_record (
  patient_id uuid
)
  RETURNS jsonb
  LANGUAGE plpgsql
  SET search_path TO ''
  AS $function$
begin
 perform clinic.require_permission('clinical');
 if not clinic.patient_care_access(patient_id) then raise exception 'Patient is outside your assigned care scope' using errcode='42501';end if;
 if not exists(select 1 from clinic.patients p where p.id=patient_id and organization_id=clinic.org_id()) then raise exception 'Patient not found'; end if;
 perform clinic.log_access('READ',patient_id,'clinical_record');
 return jsonb_build_object('encounters',coalesce((select jsonb_agg(x) from (select e.*, (select jsonb_agg(m order by m.created_at,m.id) from clinic.prescription_items m where m.encounter_id=e.id) prescription_items, (select jsonb_agg(a) from clinic.addenda a where a.encounter_id=e.id) addenda from clinic.encounters e where e.patient_id in (select id from clinic.patient_ids(clinical_record.patient_id)) order by created_at desc) x),'[]'),'facts',coalesce((select jsonb_agg(f order by f.created_at desc,f.id) from clinic.clinical_facts f where f.patient_id in (select id from clinic.patient_ids(clinical_record.patient_id)) and not exists(select 1 from clinic.clinical_facts n where n.supersedes_id=f.id)),'[]'),'procedures',coalesce((select jsonb_agg(p) from clinic.procedures p where p.patient_id in (select id from clinic.patient_ids(clinical_record.patient_id))),'[]'));
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
 line jsonb; lines jsonb:='[]'; total numeric:=0; num text; result jsonb; rate numeric; v_redemption_amount numeric; v_invoice_amount numeric; v_exchange_rate numeric; v_refundable numeric; v_allocatable numeric;
begin
 if o is null or actor is null or not clinic.session_valid() or exists(select 1 from clinic.memberships where user_id=actor and organization_id=o and password_change_required) then raise exception 'Not authenticated' using errcode='42501'; end if;
 if request_id is null or jsonb_typeof(payload)<>'object' or octet_length(payload::text)>200000 then raise exception 'Invalid request'; end if;
 perform pg_advisory_xact_lock(hashtextextended(o::text,0));
 select * into previous from clinic.requests r where r.organization_id=o and r.actor_id=actor and r.request_id=command.request_id;
 if found then if previous.fingerprint<>fingerprint then raise exception 'Request identifier was reused with different content' using errcode='23505'; end if; return previous.result; end if;
 p:=nullif(payload->>'patient_id','')::uuid; e:=nullif(payload->>'encounter_id','')::uuid;
 curr:=coalesce(payload->>'currency','IQD'); method:=coalesce(payload->>'method','cash');
 amt:=nullif(payload->>'amount','')::numeric;
 if method not in ('cash','bank','card') then raise exception 'Invalid payment method'; end if;
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
 if row_patient.version is distinct from (payload->>'version')::integer then raise exception 'This profile changed on another device. Refresh and compare your changes.' using errcode='40001'; end if;
 if row_patient.phone is distinct from nullif(payload->>'phone','') and row_patient.phone is not null then insert into clinic.contacts(organization_id,patient_id,phone,owner_name,valid_to) values(o,p,row_patient.phone,row_patient.contact_owner,now()); end if;
 update clinic.patients set full_name=trim(payload->>'full_name'),phone=nullif(payload->>'phone',''),contact_owner=payload->>'contact_owner',birth_date=nullif(payload->>'birth_date','')::date,birth_precision=coalesce(payload->>'birth_precision','unknown'),gender=coalesce(payload->>'gender','unknown'),language=coalesce(payload->>'language','ckb'),guardian_name=payload->>'guardian_name',guardian_relationship=payload->>'guardian_relationship',communication_consent=coalesce((payload->>'communication_consent')::boolean,false),version=version+1,updated_at=now() where id=p returning id into rid;
 when 'patient.merge' then
 perform clinic.require_approval(coalesce(amt,0),curr);
 if row_patient.version is distinct from (payload->>'version')::integer then raise exception 'Patient changed. Refresh and review identity before merging.' using errcode='40001'; end if;
 a:=(payload->>'target_id')::uuid;
 if p=a or length(trim(coalesce(payload->>'reason','')))<8 then raise exception 'A different target and documented identity review are required'; end if;
 if row_patient.merged_into is not null or not exists(select 1 from clinic.patients where id=a and organization_id=o and merged_into is null) then raise exception 'Invalid merge target'; end if;
 update clinic.patients set merged_into=a,version=version+1 where id=p returning id into rid;
 insert into clinic.patient_merges(organization_id,source_id,target_id,reason) values(o,p,a,payload->>'reason');
 perform clinic.log_access('PATIENT_MERGE',p,'patient');
 when 'appointment.create' then
 perform clinic.require_permission('schedule');
 a:=(payload->>'doctor_id')::uuid;
 if not exists(select 1 from clinic.memberships where user_id=a and organization_id=o and active and clinic.has_role(user_id,'doctor')) then raise exception 'Select an active clinician'; end if;
 if exists(select 1 from clinic.appointments where organization_id=o and doctor_id=a and status not in ('cancelled','no_show') and starts_at<(payload->>'ends_at')::timestamptz and ends_at>(payload->>'starts_at')::timestamptz) then raise exception 'The clinician already has an appointment at this time' using errcode='23P01'; end if;
 insert into clinic.appointments(organization_id,branch_id,patient_id,doctor_id,starts_at,ends_at,service_name,walk_in,status,checked_in_at,resource_id) values(o,clinic.branch_id(),p,a,(payload->>'starts_at')::timestamptz,(payload->>'ends_at')::timestamptz,payload->>'service_name',coalesce((payload->>'walk_in')::boolean,false),case when (payload->>'walk_in')::boolean then 'checked_in' else 'scheduled' end,case when (payload->>'walk_in')::boolean then now() end,nullif(payload->>'resource_id','')::uuid) returning id into rid;
 when 'appointment.status' then
 perform clinic.require_permission('schedule');
 select * into row_appointment from clinic.appointments where id=(payload->>'id')::uuid;
 if not found then raise exception 'Appointment not found'; end if;
 if row_appointment.version is distinct from (payload->>'version')::integer then raise exception 'Appointment changed. Refresh first.' using errcode='40001'; end if;
 if not ((row_appointment.status='scheduled' and payload->>'status' in ('checked_in','cancelled','no_show')) or (row_appointment.status='checked_in' and payload->>'status' in ('in_care','cancelled')) or (row_appointment.status='in_care' and payload->>'status'='completed')) then raise exception 'Invalid appointment status transition'; end if;
 if payload->>'status' in ('cancelled','no_show') and length(trim(coalesce(payload->>'reason','')))<3 then raise exception 'A reason is required'; end if;
 update clinic.appointments set status=payload->>'status',checked_in_at=case when payload->>'status'='checked_in' then now() else checked_in_at end,cancellation_reason=payload->>'reason',version=version+1 where id=row_appointment.id returning id into rid;
 when 'encounter.save' then
 perform clinic.require_permission('clinical');
 if nullif(payload->>'appointment_id','') is not null and not exists(select 1 from clinic.appointments where id=(payload->>'appointment_id')::uuid and patient_id=p and doctor_id=actor and organization_id=o) then raise exception 'Appointment does not belong to this patient and clinician'; end if;
 if nullif(payload->>'id','') is null then
 if nullif(payload->>'template_id','') is not null and not exists(select 1 from clinic.document_templates t where t.id=(payload->>'template_id')::uuid and t.organization_id=o and t.status='approved' and t.kind='clinical') then raise exception 'Select an approved clinical template';end if;
 insert into clinic.encounters(organization_id,patient_id,doctor_id,branch_id,appointment_id,chief_complaint,history,allergies,findings,diagnosis,plan,prescriptions,clinical_sex_notes,template_id,template_snapshot,birth_snapshot)
 values(o,p,actor,clinic.branch_id(),nullif(payload->>'appointment_id','')::uuid,payload->>'chief_complaint',coalesce(payload->>'history',''),coalesce(payload->>'allergies','Not reviewed'),coalesce(payload->>'findings',''),coalesce(payload->>'diagnosis',''),coalesce(payload->>'plan',''),coalesce(payload->>'prescriptions',''),coalesce(payload->>'clinical_sex_notes',''),nullif(payload->>'template_id','')::uuid,(select to_jsonb(t) from clinic.document_templates t where t.id=nullif(payload->>'template_id','')::uuid and t.organization_id=o),jsonb_build_object('birth_date',row_patient.birth_date,'precision',row_patient.birth_precision,'reported_age',row_patient.reported_age,'age_recorded_on',row_patient.age_recorded_on)) returning id into rid;
 else
 select * into row_enc from clinic.encounters where id=(payload->>'id')::uuid;
 if not found or row_enc.doctor_id<>actor then raise exception 'Only the author may edit this draft' using errcode='42501'; end if;
 if row_enc.version is distinct from (payload->>'version')::integer then raise exception 'Encounter changed. Refresh and compare your changes.' using errcode='40001'; end if;
 update clinic.encounters set chief_complaint=payload->>'chief_complaint',history=coalesce(payload->>'history',''),allergies=coalesce(payload->>'allergies','Not reviewed'),findings=coalesce(payload->>'findings',''),diagnosis=coalesce(payload->>'diagnosis',''),plan=coalesce(payload->>'plan',''),prescriptions=coalesce(payload->>'prescriptions',''),clinical_sex_notes=coalesce(payload->>'clinical_sex_notes',''),version=version+1 where id=row_enc.id returning id into rid;
 end if;
 when 'encounter.sign' then
 perform clinic.require_permission('clinical');
 select * into row_enc from clinic.encounters where id=(payload->>'id')::uuid;
 if not found or row_enc.doctor_id<>actor then raise exception 'Only the author may sign' using errcode='42501'; end if;
 if row_enc.version is distinct from (payload->>'version')::integer then raise exception 'Encounter changed. Refresh first.' using errcode='40001'; end if;
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
 if nullif(payload->>'template_id','') is not null and not exists(select 1 from clinic.document_templates t where t.id=(payload->>'template_id')::uuid and t.organization_id=o and t.status='approved' and t.kind in ('procedure','aftercare')) then raise exception 'Select an approved procedure or aftercare template';end if;
 insert into clinic.procedures(organization_id,patient_id,encounter_id,name,body_site,product,lot_number,settings,quantity,aftercare,adverse_event,template_id,template_snapshot) values(o,p,e,payload->>'name',payload->>'body_site',payload->>'product',payload->>'lot_number',payload->>'settings',nullif(payload->>'quantity','')::numeric,payload->>'aftercare',payload->>'adverse_event',nullif(payload->>'template_id','')::uuid,(select to_jsonb(t) from clinic.document_templates t where t.id=nullif(payload->>'template_id','')::uuid and t.organization_id=o)) returning id into rid;
 when 'consent.record' then
 perform clinic.require_permission('patients');
 if payload->>'purpose'<>'communication' then perform clinic.require_permission('clinical'); end if;
 if nullif(payload->>'template_id','') is not null and not exists(select 1 from clinic.document_templates t where t.id=(payload->>'template_id')::uuid and t.organization_id=o and t.status='approved' and t.kind='consent') then raise exception 'Select an approved consent template';end if;
 insert into clinic.consents(organization_id,patient_id,purpose,granted,template_version,evidence,template_id,template_snapshot) values(o,p,payload->>'purpose',(payload->>'granted')::boolean,case when nullif(payload->>'template_id','') is null then payload->>'template_version' else (select t.version::text from clinic.document_templates t where t.id=(payload->>'template_id')::uuid and t.organization_id=o) end,payload->>'evidence',nullif(payload->>'template_id','')::uuid,(select to_jsonb(t) from clinic.document_templates t where id=nullif(payload->>'template_id','')::uuid and organization_id=o and status='approved')) returning id into rid;
 when 'task.create' then
 perform clinic.require_permission('results');
 if not exists(select 1 from clinic.memberships where user_id=(payload->>'assigned_to')::uuid and organization_id=o and active and clinic.has_role(user_id,'doctor')) then raise exception 'Select an active clinician'; end if;
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
 if row_result.version is distinct from (payload->>'version')::integer then raise exception 'Result changed. Refresh first.' using errcode='40001'; end if;
 if not ((row_result.status='ordered' and payload->>'status'='received') or (row_result.status='received' and payload->>'status'='reviewed') or (row_result.status='reviewed' and payload->>'status'='notified') or (row_result.status='notified' and payload->>'status'='closed')) then raise exception 'Review and patient notification must happen in order'; end if;
 if length(trim(coalesce(payload->>'result_text','')))<3 then raise exception 'Document the result, review or communication evidence'; end if;
 update clinic.results set status=payload->>'status',result_text=coalesce(result_text||E'\n','')||'['||(payload->>'status')||'] '||(payload->>'result_text'),version=version+1 where id=row_result.id returning id into rid;
 when 'service.save' then
 perform clinic.require_permission('settings');
 if (payload->>'price')::numeric<0 or (payload->>'price')::numeric<>round((payload->>'price')::numeric,case when curr='USD' then 2 else 3 end) then raise exception 'Invalid service price precision'; end if;
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
 if nullif(payload->>'discount','') is not null and (payload->>'discount')::numeric<>0 then
 perform clinic.require_permission('approve');amt:=(payload->>'discount')::numeric;perform clinic.require_approval(amt,curr);
 if amt<0 or amt>=total or amt<>round(amt,case when curr='USD' then 2 else 3 end) then raise exception 'Discount must be positive, precise and smaller than invoice total'; end if;
 if length(trim(coalesce(payload->>'discount_reason','')))<5 then raise exception 'A discount reason is required'; end if;
 lines:=lines||jsonb_build_array(jsonb_build_object('description','Discount: '||(payload->>'discount_reason'),'quantity',1,'unit_price',-amt,'amount',-amt));total:=total-amt;
 end if;
 insert into clinic.invoices(organization_id,patient_id,invoice_number,patient_snapshot,currency,lines,total) values(o,p,num,jsonb_build_object('full_name',row_patient.full_name,'patient_number',row_patient.patient_number),curr,lines,total) returning id into rid;
 perform clinic.post_journal(curr,num,'invoice',rid,'receivable','revenue',total);
 when 'invoice.credit' then
 perform clinic.require_approval(coalesce(amt,0),curr);a:=(payload->>'invoice_id')::uuid;
 select * into row_invoice from clinic.invoices where id=a;
 if not found or curr<>row_invoice.currency then raise exception 'Invoice or currency mismatch'; end if;
 select clinic.invoice_balance(a) into due;
 if amt is null or amt>due or length(trim(coalesce(payload->>'reason','')))<5 then raise exception 'Credit cannot exceed outstanding balance and requires a reason'; end if;
 insert into clinic.credit_notes(organization_id,invoice_id,amount,reason) values(o,a,amt,payload->>'reason') returning id into rid;
 perform clinic.post_journal(curr,'Invoice correction','credit_note',rid,'revenue','receivable',amt);
 when 'payment.record' then
 perform clinic.require_permission('billing');
 a:=nullif(payload->>'invoice_id','')::uuid;
 if amt is null then raise exception 'Payment amount is required'; end if;
 v_invoice_amount:=amt;
 if a is not null then
 select * into row_invoice from clinic.invoices where id=a and patient_id=p;
 if not found then raise exception 'Invoice not found for this patient'; end if;
 if row_invoice.currency<>curr then
 if not exists(select 1 from clinic.organizations where id=o and allow_cross_currency) then raise exception 'Cross-currency settlement is disabled by clinic policy'; end if;
 v_exchange_rate:=nullif(payload->>'exchange_rate','')::numeric;
 if v_exchange_rate is null or v_exchange_rate<=0 or v_exchange_rate<>round(v_exchange_rate,6) then raise exception 'Enter an explicit IQD-per-USD exchange rate'; end if;
 v_invoice_amount:=round(case when row_invoice.currency='USD' then amt/v_exchange_rate else amt*v_exchange_rate end,case when row_invoice.currency='USD' then 2 else 3 end);
 if v_invoice_amount<=0 then raise exception 'Converted payment rounds to zero'; end if;
 end if;
 select clinic.invoice_balance(a) into due;
 if v_invoice_amount>due then raise exception 'Payment exceeds the outstanding invoice balance'; end if;
 end if;
 if method='deposit' then raise exception 'Use Apply deposit for existing patient credit'; end if;
 insert into clinic.payments(organization_id,patient_id,invoice_id,patient_snapshot,currency,amount,invoice_amount,exchange_rate,method,kind) values(o,p,a,jsonb_build_object('full_name',row_patient.full_name,'patient_number',row_patient.patient_number),curr,amt,case when a is not null then v_invoice_amount end,v_exchange_rate,method,case when a is null then 'deposit' else 'payment' end) returning id into rid;
 if a is not null and curr<>row_invoice.currency then
 perform clinic.post_journal(curr,'Patient receipt at recorded FX rate','payment',rid,method,'fx_clearing',amt);
 perform clinic.post_journal(row_invoice.currency,'Invoice settlement at recorded FX rate','payment',rid,'fx_clearing','receivable',v_invoice_amount);
 else perform clinic.post_journal(curr,'Patient receipt','payment',rid,method,case when a is null then 'deposits' else 'receivable' end,amt); end if;
 when 'deposit.apply' then
 perform clinic.require_permission('billing');
 a:=(payload->>'invoice_id')::uuid;
 select * into row_invoice from clinic.invoices where id=a and patient_id=p;
 if not found or row_invoice.currency<>curr then raise exception 'Invoice or currency mismatch'; end if;
 select coalesce(sum(case when pm.kind='deposit' then amount when pm.kind='deposit_application' then -amount when pm.kind='refund' and invoice_id is null then -amount else 0 end),0) into total from clinic.payments pm where patient_id=p and currency=curr;
 select clinic.invoice_balance(a) into due;
 if amt is null or amt>total or amt>due then raise exception 'Insufficient deposit or invoice balance'; end if;
 insert into clinic.payments(organization_id,patient_id,invoice_id,patient_snapshot,currency,amount,method,kind) values(o,p,a,jsonb_build_object('full_name',row_patient.full_name,'patient_number',row_patient.patient_number),curr,amt,'deposit','deposit_application') returning id into rid;
 perform clinic.post_journal(curr,'Apply patient deposit','deposit_application',rid,'deposits','receivable',amt);
 when 'refund.record' then
 perform clinic.require_approval(coalesce(amt,0),curr);
 select * into row_payment from clinic.payments pm where id=(payload->>'payment_id')::uuid and pm.kind in ('payment','deposit');
 if not found then raise exception 'Original payment not found'; end if;
 if length(trim(coalesce(payload->>'reason','')))<5 then raise exception 'A refund reason is required'; end if;
 if amt is null or curr<>row_payment.currency or amt>row_payment.amount-coalesce((select sum(amount) from clinic.payments pm where original_payment_id=row_payment.id and pm.kind='refund'),0) then raise exception 'Refund exceeds the unrefunded original payment'; end if;
 if row_payment.kind='deposit' then
 select coalesce(sum(case when pm.kind='deposit' then amount when pm.kind='deposit_application' then -amount when pm.kind='refund' and invoice_id is null then -amount else 0 end),0) into total from clinic.payments pm where patient_id=row_payment.patient_id and currency=curr;
 if amt>total then raise exception 'Deposit has already been used'; end if;
 else
 select * into row_invoice from clinic.invoices where id=row_payment.invoice_id;
 v_refundable:=row_payment.amount-coalesce((select sum(pm.amount) from clinic.payments pm where original_payment_id=row_payment.id and pm.kind='refund'),0);
 v_allocatable:=coalesce(row_payment.invoice_amount,row_payment.amount)-coalesce((select sum(coalesce(pm.invoice_amount,pm.amount)) from clinic.payments pm where original_payment_id=row_payment.id and pm.kind='refund'),0);
 v_invoice_amount:=case when amt=v_refundable then v_allocatable else round(amt/row_payment.amount*coalesce(row_payment.invoice_amount,row_payment.amount),case when row_invoice.currency='USD' then 2 else 3 end) end;
 if v_invoice_amount<=0 or v_invoice_amount>v_allocatable or (amt<v_refundable and v_invoice_amount>=v_allocatable) then raise exception 'Refund cannot be allocated at invoice currency precision; return the full remaining receipt or choose a larger representable split'; end if;
 insert into clinic.credit_notes(organization_id,invoice_id,amount,reason) values(o,row_payment.invoice_id,v_invoice_amount,payload->>'reason') returning id into a;
 perform clinic.post_journal(row_invoice.currency,'Service credit','credit_note',a,'revenue','receivable',v_invoice_amount);
 end if;
 insert into clinic.payments(organization_id,patient_id,invoice_id,patient_snapshot,currency,amount,invoice_amount,exchange_rate,method,kind,original_payment_id,reason) values(o,row_payment.patient_id,row_payment.invoice_id,row_payment.patient_snapshot,curr,amt,v_invoice_amount,row_payment.exchange_rate,row_payment.method,'refund',row_payment.id,payload->>'reason') returning id into rid;
 if row_payment.invoice_id is not null and curr<>row_invoice.currency then
 perform clinic.post_journal(row_invoice.currency,'Refund allocation at original FX rate','refund',rid,'receivable','fx_clearing',v_invoice_amount);
 perform clinic.post_journal(curr,'Refund in original tender currency','refund',rid,'fx_clearing',row_payment.method,amt);
 else perform clinic.post_journal(curr,'Patient refund','refund',rid,case when row_payment.kind='deposit' then 'deposits' else 'receivable' end,row_payment.method,amt); end if;
 when 'expense.record' then
 perform clinic.require_permission('finance');
 if payload->>'category'='salary' then perform clinic.require_permission('payroll'); end if;
 if amt is null then raise exception 'Amount is required'; end if;
 insert into clinic.expenses(organization_id,category,supplier,description,currency,amount,paid,method) values(o,payload->>'category',payload->>'supplier',payload->>'description',curr,amt,(payload->>'paid')::boolean,method) returning id into rid;
 perform clinic.post_journal(curr,payload->>'description','expense',rid,'expense',case when (payload->>'paid')::boolean then method else 'payable' end,amt);
 when 'cash.record' then
 perform clinic.require_approval(coalesce(amt,0),curr);
 if payload->>'kind' not in ('owner_contribution','owner_withdrawal','owner_loan','transfer','opening_balance') then raise exception 'Invalid cash movement type'; end if;
 if payload->>'kind'='transfer' and (payload->>'destination'=method or payload->>'destination' not in ('cash','bank','card') or payload->>'destination' is null) then raise exception 'Select a different destination account'; end if;
 if amt is null then raise exception 'Amount is required'; end if;
 insert into clinic.cash_movements(organization_id,kind,currency,amount,method,destination,description) values(o,payload->>'kind',curr,amt,method,nullif(payload->>'destination',''),payload->>'description') returning id into rid;
 perform clinic.post_journal(curr,payload->>'description','cash_movement',rid,
 case when payload->>'kind'='owner_withdrawal' then 'equity' when payload->>'kind'='transfer' then payload->>'destination' else method end,
 case when payload->>'kind'='owner_withdrawal' or payload->>'kind'='transfer' then method when payload->>'kind'='owner_loan' then 'owner_loan' else 'equity' end,amt);
 when 'fx.exchange' then
 perform clinic.require_approval(coalesce(amt,0),curr); rate:=(payload->>'rate')::numeric;
 if amt is null or rate<=0 or rate<>round(rate,6) or curr=payload->>'destination_currency' or payload->>'destination_currency' not in ('IQD','USD') then raise exception 'Provide two currencies and a positive explicit conversion rate'; end if;
 total:=round(amt*rate,case when payload->>'destination_currency'='USD' then 2 else 3 end);
 insert into clinic.cash_movements(organization_id,kind,currency,amount,method,description,fx_rate) values(o,'fx_exchange',curr,amt,method,'FX out: '||(payload->>'description'),rate) returning id into rid;
 insert into clinic.cash_movements(organization_id,kind,currency,amount,method,description,fx_rate,related_id) values(o,'fx_exchange',payload->>'destination_currency',total,method,'FX in: '||(payload->>'description'),rate,rid) returning id into a;
 perform clinic.post_journal(curr,'FX out','fx',rid,'fx_clearing',method,amt);
 perform clinic.post_journal(payload->>'destination_currency','FX in','fx',a,method,'fx_clearing',total);
 when 'stock.receive' then
 perform clinic.require_permission('inventory');
 if nullif(payload->>'product_id','') is not null then
 select to_jsonb(x) into result from clinic.inventory_products x where x.id=(payload->>'product_id')::uuid and x.organization_id=o and x.active;
 if result is null or (payload?'unit' and payload->>'unit' is distinct from result->>'unit') then raise exception 'Select an active product with the correct stock unit';end if;
 payload:=payload||jsonb_build_object('product',result->>'name','unit',result->>'unit');
 end if;
 if exists(select 1 from clinic.stock_lots where organization_id=o and product=payload->>'product' and lot_number=payload->>'lot_number' and (unit is distinct from payload->>'unit' or expires_on is distinct from (payload->>'expires_on')::date)) then raise exception 'Lot unit or expiry differs. Review the batch identity before receiving stock.';end if;
 if amt is null then raise exception 'Quantity required'; end if;
 insert into clinic.stock_lots(organization_id,product,lot_number,expires_on,unit,quantity,product_id) values(o,payload->>'product',payload->>'lot_number',(payload->>'expires_on')::date,payload->>'unit',amt,nullif(payload->>'product_id','')::uuid)
 on conflict(organization_id,product,lot_number) do update set quantity=clinic.stock_lots.quantity+excluded.quantity,version=clinic.stock_lots.version+1,product_id=coalesce(clinic.stock_lots.product_id,excluded.product_id) returning id into rid;
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
 update clinic.organizations set name=payload->>'name',require_mfa=coalesce((payload->>'require_mfa')::boolean,true),allow_cross_currency=coalesce((payload->>'allow_cross_currency')::boolean,allow_cross_currency) where id=o returning id into rid;
 when 'package.sell' then
 perform clinic.require_permission('billing');
 if amt is null or (payload->>'sessions')::integer not between 1 and 1000 then raise exception 'Package amount and valid session count are required'; end if;
 insert into clinic.packages(organization_id,patient_id,name,sessions,remaining,currency,total,sale_method,expires_on,patient_snapshot) values(o,p,payload->>'name',(payload->>'sessions')::integer,(payload->>'sessions')::integer,curr,amt,method,nullif(payload->>'expires_on','')::date,jsonb_build_object('full_name',row_patient.full_name,'patient_number',row_patient.patient_number)) returning id into rid;
 perform clinic.post_journal(curr,'Prepaid treatment package','package_sale',rid,method,'deposits',amt);
 when 'package.redeem' then
 perform clinic.require_permission('billing');
 select * into row_package from clinic.packages where id=(payload->>'package_id')::uuid and patient_id=p;
 e:=(payload->>'encounter_id')::uuid;
 if not found or row_package.remaining<=0 or row_package.cancelled_at is not null or row_package.expires_on<(now() at time zone 'Asia/Baghdad')::date then raise exception 'Package has no available sessions or is cancelled/expired'; end if;
 if clinic.billing_encounter_patient(e) is distinct from p then raise exception 'A signed encounter for this patient is required'; end if;
 total:=case when row_package.remaining=1 then row_package.total-row_package.redeemed_value else round(row_package.total/row_package.sessions,case when row_package.currency='USD' then 2 else 3 end) end;
 insert into clinic.package_redemptions(organization_id,package_id,encounter_id) values(o,row_package.id,e) returning id into rid;
 v_redemption_amount:=total;
 update clinic.packages set remaining=remaining-1,redeemed_value=redeemed_value+v_redemption_amount where id=row_package.id;
 if total>0 then perform clinic.post_journal(row_package.currency,'Treatment package session','package_redemption',rid,'deposits','revenue',total); end if;
 when 'expense.pay' then
 perform clinic.require_permission('finance');
 select amount,currency into total,curr from clinic.expenses where id=(payload->>'expense_id')::uuid and not paid;
 if not found or exists(select 1 from clinic.journals where source_type='expense_payment' and source_id=(payload->>'expense_id')::uuid) then raise exception 'Unpaid expense not found or already settled'; end if;
 rid:=clinic.post_journal(curr,'Supplier payable settlement','expense_payment',(payload->>'expense_id')::uuid,'payable',method,total);
 when 'member.update' then
 perform clinic.require_permission('staff');
 if not exists(select 1 from clinic.memberships where user_id=actor and organization_id=o and role='owner') and (payload->>'role' in ('owner','administrator','accountant') or exists(select 1 from clinic.memberships where user_id=(payload->>'user_id')::uuid and organization_id=o and role in ('owner','administrator','accountant'))) then raise exception 'Only the owner may manage privileged roles' using errcode='42501'; end if;
 a:=(payload->>'user_id')::uuid;
 if a=actor then raise exception 'You cannot change your own access'; end if;
 if payload->>'role' not in ('owner','administrator','doctor','receptionist','accountant') then raise exception 'Invalid role'; end if;
 update clinic.memberships set role=payload->>'role',active=(payload->>'active')::boolean where user_id=a and organization_id=o returning id into rid;
 when 'journal.post' then
 perform clinic.require_approval(coalesce(amt,0),curr);
 if amt is null or payload->>'debit_account'=payload->>'credit_account' or length(trim(coalesce(payload->>'description','')))<5 then raise exception 'Use different accounts and explain the adjustment'; end if;
 rid:=clinic.post_journal(curr,payload->>'description','manual',gen_random_uuid(),payload->>'debit_account',payload->>'credit_account',amt);
 else raise exception 'Unsupported operation: %',kind using errcode='22023';
 end case;
 if rid is null then raise exception 'No record was changed. Refresh and verify your access.' using errcode='P0002'; end if;
 result:=jsonb_build_object('id',rid);
 insert into clinic.requests(organization_id,actor_id,request_id,fingerprint,result) values(o,actor,command.request_id,fingerprint,result);
 return result;
end $function$;

CREATE OR REPLACE FUNCTION public.current_photography_consent (
  patient_id uuid
)
  RETURNS jsonb
  LANGUAGE plpgsql
  STABLE
  SET search_path TO ''
  AS $function$declare consent clinic.consents;begin
 perform clinic.require_permission('media');
 select * into consent from clinic.consents c where c.organization_id=clinic.org_id() and c.patient_id=current_photography_consent.patient_id and c.purpose='care_photography' order by created_at desc,id desc limit 1;
 if not found or not consent.granted then return '[]'::jsonb;end if;
 return jsonb_build_array(jsonb_build_object('id',consent.id,'template_version',consent.template_version,'created_at',consent.created_at));end $function$;

CREATE OR REPLACE FUNCTION public.encounter_search (
  patient_id    uuid,
  search_term   text    DEFAULT ''::text,
  cursor_id     uuid    DEFAULT NULL::uuid,
  status_filter text    DEFAULT NULL::text,
  only_author   boolean DEFAULT false
)
  RETURNS jsonb
  LANGUAGE plpgsql
  SET search_path TO ''
  AS $function$begin
 if clinic.allowed('clinical') then perform clinic.log_access('ENCOUNTER_OPTIONS',patient_id,'encounters');end if;
 return clinic.encounter_lookup(patient_id,search_term,cursor_id,status_filter,only_author);
end $function$;

REVOKE ALL ON FUNCTION "public"."encounter_search"(uuid, text, uuid, text, boolean) FROM PUBLIC, "anon";

CREATE OR REPLACE FUNCTION public.finance_workflow (
  kind       text,
  payload    jsonb,
  request_id uuid
)
  RETURNS jsonb
  LANGUAGE plpgsql
  SET search_path TO ''
  AS $function$
declare o uuid:=clinic.org_id();actor uuid:=auth.uid();prior clinic.requests;fp text:=md5(kind||payload::text);rid uuid;v uuid;item jsonb;mapping clinic.account_mappings;statement clinic.bank_statement_lines;posting record;amount numeric;lineid uuid;mapping_account text;codes jsonb;result jsonb;
begin
 perform clinic.require_permission('finance');
 if o is null or actor is null or request_id is null or jsonb_typeof(payload)<>'object' or octet_length(payload::text)>200000 then raise exception 'Invalid accounting request';end if;
 perform pg_advisory_xact_lock(hashtextextended(o::text,0));
 select * into prior from clinic.requests r where r.organization_id=o and r.actor_id=actor and r.request_id=finance_workflow.request_id;
 if found then if prior.fingerprint<>fp then raise exception 'Request identifier reused with different content' using errcode='23505';end if;return prior.result;end if;
 v:=nullif(payload->>'id','')::uuid;
 case kind
 when 'finance.mapping.create' then
 perform clinic.require_permission('approve');codes:=payload->'codes';
 if jsonb_typeof(codes)<>'object' or (select count(*) from jsonb_object_keys(codes))<>12 then raise exception 'Map all clinic ledger accounts';end if;
 foreach mapping_account in array array['cash','bank','card','receivable','deposits','revenue','expense','inventory','payable','equity','owner_loan','fx_clearing'] loop
 if length(trim(coalesce(codes->>mapping_account,''))) not between 1 and 100 then raise exception 'An external code is required for every account';end if;end loop;
 insert into clinic.account_mappings(organization_id,name,codes) values(o,payload->>'name',codes) returning id into rid;
 when 'finance.mapping.approve' then
 perform clinic.require_permission('approve');update clinic.account_mappings set approved_by=actor,approved_at=now() where id=v and organization_id=o and approved_at is null returning id into rid;
 when 'finance.batch.create' then
 perform clinic.require_permission('export');
 select * into mapping from clinic.account_mappings where id=(payload->>'mapping_id')::uuid and organization_id=o and approved_at is not null;
 if not found then raise exception 'Select an approved account mapping';end if;
 insert into clinic.accounting_batches(organization_id,mapping_id,from_day,to_day) values(o,mapping.id,(payload->>'from_day')::date,(payload->>'to_day')::date) returning id into rid;
 insert into clinic.accounting_batch_items(organization_id,batch_id,line_id,account_code)
 select o,rid,l.id,mapping.codes->>l.account from clinic.journal_lines l join clinic.journals j on j.id=l.journal_id where j.organization_id=o and j.accounting_date between (payload->>'from_day')::date and (payload->>'to_day')::date and not exists(select 1 from clinic.accounting_batch_items i where i.line_id=l.id);
 if not found then raise exception 'No unexported postings exist in this date range';end if;
 when 'finance.batch.acknowledge' then
 perform clinic.require_permission('export');
 insert into clinic.accounting_acknowledgements(organization_id,batch_id,external_reference,notes) values(o,v,payload->>'external_reference',payload->>'notes') returning id into rid;
 when 'finance.period.close' then
 perform clinic.require_permission('approve');
 if (payload->>'to_day')::date>(now() at time zone 'Asia/Baghdad')::date or exists(select 1 from clinic.accounting_periods where organization_id=o and from_day<=(payload->>'to_day')::date and to_day>=(payload->>'from_day')::date) then raise exception 'Period is in the future or overlaps an existing close';end if;
 insert into clinic.accounting_periods(organization_id,from_day,to_day,reason) values(o,(payload->>'from_day')::date,(payload->>'to_day')::date,payload->>'reason') returning id into rid;
 when 'finance.journal.adjust' then
 perform clinic.require_permission('approve');amount:=(payload->>'amount')::numeric;perform clinic.require_approval(amount,payload->>'currency');
 if amount<=0 or amount<>round(amount,case when payload->>'currency'='USD' then 2 else 3 end) or payload->>'debit_account'=payload->>'credit_account' or length(trim(coalesce(payload->>'description','')))<5 then raise exception 'A precise positive amount, different accounts and documented reason are required';end if;
 insert into clinic.journals(organization_id,currency,description,source_type,source_id,effective_date) values(o,payload->>'currency',payload->>'description','dated_adjustment',gen_random_uuid(),(payload->>'posting_day')::date) returning id into rid;
 insert into clinic.journal_lines(organization_id,journal_id,account,debit,credit) values(o,rid,payload->>'debit_account',amount,0),(o,rid,payload->>'credit_account',0,amount);
 when 'finance.bank.import' then
 if jsonb_typeof(payload->'lines')<>'array' or jsonb_array_length(payload->'lines') not between 1 and 1000 then raise exception 'Import 1–1000 statement lines at a time';end if;
 for item in select * from jsonb_array_elements(payload->'lines') loop
 if length(trim(coalesce(item->>'external_id','')))<1 or length(item->>'external_id')>200 then raise exception 'Each statement line requires a stable external identifier';end if;
 select * into statement from clinic.bank_statement_lines where organization_id=o and account=item->>'account' and currency=item->>'currency' and external_id=item->>'external_id';
 if found then
 if statement.amount is distinct from (item->>'amount')::numeric or statement.posted_on is distinct from (item->>'posted_on')::date or statement.reference is distinct from item->>'reference' then raise exception 'Imported identifier was reused with different statement content' using errcode='23505';end if;rid:=statement.id;
 else insert into clinic.bank_statement_lines(organization_id,account,currency,posted_on,amount,reference,external_id) values(o,item->>'account',item->>'currency',(item->>'posted_on')::date,(item->>'amount')::numeric,item->>'reference',item->>'external_id') returning id into rid;end if;
 end loop;
 when 'finance.bank.match' then
 select * into statement from clinic.bank_statement_lines where id=v and organization_id=o for update;
 select l.*,j.currency into posting from clinic.journal_lines l join clinic.journals j on j.id=l.journal_id where l.id=(payload->>'journal_line_id')::uuid and j.organization_id=o;
 if statement.id is null or posting.id is null or statement.account<>posting.account or statement.currency<>posting.currency or statement.amount<>posting.debit-posting.credit then raise exception 'Statement and posting must have the same account, currency and amount';end if;
 if exists(select 1 from clinic.bank_matches m where m.organization_id=o and (m.statement_id=v or m.journal_line_id=posting.id) and not exists(select 1 from clinic.bank_match_reversals r where r.match_id=m.id)) then raise exception 'Statement line or posting is already reconciled';end if;
 insert into clinic.bank_matches(organization_id,statement_id,journal_line_id,reason) values(o,v,posting.id,payload->>'reason') returning id into rid;
 when 'finance.bank.reverse_match' then
 perform clinic.require_permission('approve');
 insert into clinic.bank_match_reversals(organization_id,match_id,reason) values(o,v,payload->>'reason') returning id into rid;
 else raise exception 'Unknown accounting operation';end case;
 if rid is null then raise exception 'No record changed';end if;
 result:=jsonb_build_object('id',rid);insert into clinic.requests(organization_id,actor_id,request_id,fingerprint,result) values(o,actor,request_id,fp,result);return result;
end $function$;

REVOKE ALL ON FUNCTION "public"."finance_workflow"(text, jsonb, uuid) FROM PUBLIC, "anon";

CREATE OR REPLACE FUNCTION public.financial_report (
  report_type text,
  from_day    date,
  to_day      date,
  patient_id  uuid                     DEFAULT NULL::uuid,
  page_number integer                  DEFAULT 0,
  as_at       timestamp with time zone DEFAULT NULL::timestamp WITH time zone
)
  RETURNS jsonb
  LANGUAGE plpgsql
  SET search_path TO ''
  AS $function$
declare o uuid:=clinic.org_id();first_at timestamptz;last_at timestamptz;rows jsonb;totals jsonb;items jsonb;more boolean;count_records integer;opening jsonb:='[]';closing jsonb:='[]';prepayments jsonb:='[]';
begin
 if from_day is null or to_day is null or from_day>to_day or to_day>(now() at time zone 'Asia/Baghdad')::date or as_at>clock_timestamp() or page_number<0 or page_number>100000 then raise exception 'Select a valid report date range';end if;
 first_at:=from_day::timestamp at time zone 'Asia/Baghdad';last_at:=least((to_day+1)::timestamp at time zone 'Asia/Baghdad',coalesce(as_at,clock_timestamp()));
 if last_at<=first_at then raise exception 'Report snapshot must follow the start date';end if;
 if report_type in ('receivables','patient_statement','collections','liabilities') then
 if not (clinic.allowed('billing') or clinic.allowed('finance')) then raise exception 'Permission denied' using errcode='42501';end if;
 else perform clinic.require_permission('finance');end if;
 if patient_id is not null and not exists(select 1 from clinic.invoices where organization_id=o and clinic.invoices.patient_id=financial_report.patient_id) and not exists(select 1 from clinic.payments where organization_id=o and clinic.payments.patient_id=financial_report.patient_id) and not exists(select 1 from clinic.packages where organization_id=o and clinic.packages.patient_id=financial_report.patient_id) then raise exception 'Patient account unavailable' using errcode='42501';end if;
 case report_type
 when 'receivables' then
 select coalesce(jsonb_agg(to_jsonb(r) order by r.age_days desc,r.invoice_number),'[]') into rows from (
 select i.id,i.invoice_number,i.patient_snapshot->>'full_name' patient_name,i.patient_snapshot->>'patient_number' patient_number,i.currency,
 clinic.invoice_balance_at(i.id,last_at) amount,to_day-(i.created_at at time zone 'Asia/Baghdad')::date age_days,
 case when to_day-(i.created_at at time zone 'Asia/Baghdad')::date<=30 then '0–30' when to_day-(i.created_at at time zone 'Asia/Baghdad')::date<=60 then '31–60' when to_day-(i.created_at at time zone 'Asia/Baghdad')::date<=90 then '61–90' else '90+' end aging_band
 from clinic.invoices i where i.organization_id=o and i.created_at<last_at and (financial_report.patient_id is null or i.patient_id=financial_report.patient_id)
 and clinic.invoice_balance_at(i.id,last_at)>0) r;
 when 'patient_statement' then
 if patient_id is null then raise exception 'Choose a patient for the statement';end if;
 select coalesce(jsonb_agg(to_jsonb(r) order by r.date,r.id),'[]') into rows from (
 select i.id,i.created_at date,i.invoice_number reference,'invoice' category,i.currency,i.total amount from clinic.invoices i where i.organization_id=o and i.patient_id=financial_report.patient_id and i.created_at>=first_at and i.created_at<last_at
 union all select p.id,p.created_at,coalesce(i.invoice_number,p.id::text),p.kind,coalesce(i.currency,p.currency),case when p.kind='refund' then coalesce(p.invoice_amount,p.amount) else -coalesce(p.invoice_amount,p.amount) end from clinic.payments p left join clinic.invoices i on i.id=p.invoice_id where p.organization_id=o and p.patient_id=financial_report.patient_id and p.created_at>=first_at and p.created_at<last_at and p.invoice_id is not null
 union all select c.id,c.created_at,i.invoice_number,'credit',i.currency,-c.amount from clinic.credit_notes c join clinic.invoices i on i.id=c.invoice_id where c.organization_id=o and i.patient_id=financial_report.patient_id and c.created_at>=first_at and c.created_at<last_at) r;
 when 'collections' then
 select coalesce(jsonb_agg(to_jsonb(r) order by r.date,r.currency,r.method,r.category),'[]') into rows from (
 select (p.created_at at time zone 'Asia/Baghdad')::date date,p.currency,p.method,p.kind category,sum(case when p.kind='refund' then -p.amount else p.amount end) amount,count(*) transactions
 from clinic.payments p where p.organization_id=o and p.created_at>=first_at and p.created_at<last_at and p.kind<>'deposit_application' and (financial_report.patient_id is null or p.patient_id=financial_report.patient_id) group by 1,2,3,4
 union all select (j.created_at at time zone 'Asia/Baghdad')::date,j.currency,l.account,j.source_type,sum(l.debit-l.credit),count(*) from clinic.journals j join clinic.journal_lines l on l.journal_id=j.id where j.organization_id=o and j.created_at>=first_at and j.created_at<last_at and j.source_type in ('package_sale','package_refund') and l.account in ('cash','bank','card') and financial_report.patient_id is null group by 1,2,3,4) r;
 when 'liabilities' then
 select coalesce(jsonb_agg(to_jsonb(r) order by r.currency,r.category,r.id),'[]') into rows from (
 select min(p.id::text) id,p.patient_id,p.currency,'patient_deposit' category,sum(case when p.kind='deposit' then p.amount when p.kind='deposit_application' or (p.kind='refund' and p.invoice_id is null) then -p.amount else 0 end) amount
 from clinic.payments p where p.organization_id=o and p.created_at<last_at group by p.patient_id,p.currency
 having sum(case when p.kind='deposit' then p.amount when p.kind='deposit_application' or (p.kind='refund' and p.invoice_id is null) then -p.amount else 0 end)<>0
 union all select pkg.id::text,pkg.patient_id,j.currency,'treatment_package',sum(l.credit-l.debit) from clinic.packages pkg
 join (select id, id package_id from clinic.packages union all select id,package_id from clinic.package_redemptions union all select id,package_id from clinic.package_corrections where kind='refund') s on s.package_id=pkg.id
 join clinic.journals j on j.source_id=s.id and j.source_type in ('package_sale','package_redemption','package_refund') join clinic.journal_lines l on l.journal_id=j.id and l.account='deposits'
 where pkg.organization_id=o and j.created_at<last_at group by pkg.id,pkg.patient_id,j.currency having sum(l.credit-l.debit)<>0) r;
 when 'payables' then
 select coalesce(jsonb_agg(to_jsonb(r) order by r.date,r.id),'[]') into rows from (
 select e.id,e.created_at date,e.supplier,e.category,e.description,e.currency,e.amount from clinic.expenses e where e.organization_id=o and e.created_at<last_at and not e.paid
 and not exists(select 1 from clinic.journals j where j.organization_id=o and j.source_type='expense_payment' and j.source_id=e.id and j.created_at<last_at)) r;
 when 'cash_register' then
 select coalesce(jsonb_agg(to_jsonb(r) order by r.date,r.id),'[]') into rows from (
 select l.id,j.created_at date,l.account,j.currency,j.source_type category,j.source_id reference,j.description,l.debit-l.credit amount from clinic.journal_lines l join clinic.journals j on j.id=l.journal_id
 where j.organization_id=o and l.account in ('cash','bank','card') and j.created_at>=first_at and j.created_at<last_at) r;
 when 'till_variances' then
 select coalesce(jsonb_agg(to_jsonb(r) order by r.date,r.id),'[]') into rows from (
 select id,closed_at date,user_id,currency,opening,expected,counted,counted-expected amount,reason from clinic.tills where organization_id=o and closed_at>=first_at and closed_at<last_at) r;
 else raise exception 'Invalid financial report';end case;
 if report_type='liabilities' and patient_id is not null then select coalesce(jsonb_agg(value),'[]') into rows from jsonb_array_elements(rows) where value->>'patient_id'=patient_id::text;end if;
 if report_type='patient_statement' then
 select coalesce(jsonb_agg(to_jsonb(t) order by t.currency),'[]') into opening from (select i.currency,sum(clinic.invoice_balance_at(i.id,first_at)) amount from clinic.invoices i where i.organization_id=o and i.patient_id=financial_report.patient_id and i.created_at<first_at group by i.currency) t;
 select coalesce(jsonb_agg(to_jsonb(t) order by t.currency),'[]') into closing from (select i.currency,sum(clinic.invoice_balance_at(i.id,last_at)) amount from clinic.invoices i where i.organization_id=o and i.patient_id=financial_report.patient_id and i.created_at<last_at group by i.currency) t;
 prepayments:=public.financial_report('liabilities',from_day,to_day,patient_id,0,last_at)->'totals';
 end if;
 select coalesce(jsonb_agg(to_jsonb(t) order by t.currency),'[]') into totals from (select value->>'currency' currency,sum((value->>'amount')::numeric) amount from jsonb_array_elements(rows) group by 1) t;
 count_records:=jsonb_array_length(rows);
 select coalesce(jsonb_agg(value order by ord),'[]') into items from jsonb_array_elements(rows) with ordinality t(value,ord) where ord>page_number*100 and ord<=(page_number+1)*100;
 more:=count_records>(page_number+1)*100;
 perform clinic.log_access('FINANCIAL_REPORT',patient_id,report_type);
 return jsonb_build_object('items',items,'totals',totals,'has_more',more,'records',count_records,'from_day',from_day,'to_day',to_day,'as_at',last_at,'opening_balances',opening,'closing_balances',closing,'prepayment_totals',prepayments);
end $function$;

CREATE OR REPLACE FUNCTION public.history_page (
  record_type text,
  patient_id  uuid    DEFAULT NULL::uuid,
  search_term text    DEFAULT ''::text,
  cursor_id   uuid    DEFAULT NULL::uuid,
  page_size   integer DEFAULT 50
)
  RETURNS jsonb
  LANGUAGE plpgsql
  SET search_path TO ''
  AS $function$
declare o uuid:=clinic.org_id();tbl text;perm text;items jsonb;has_patient boolean;sz integer:=least(greatest(coalesce(page_size,50),1),100);more boolean;
begin
 select x.t,x.p,x.patient into tbl,perm,has_patient from (values
 ('encounters','clinical',true),('procedures','clinical',true),('patient_documents','clinical',true),('tasks','results',true),('results','results',true),('media','media',true),('consents','clinical',true),
 ('cash_movements','finance',false),('tills','billing',false),('stock_lots','inventory.read',false),('stock_movements','inventory.read',false),('packages','billing',true),
 ('services','schedule',false),('inventory_products','inventory.read',false),('suppliers','inventory',false),('document_templates','patients',false),('clinical_facts','clinical',true),('contact_log','patients',true),('performed_services','billing',true),
 ('clinician_availability','schedule',false),('clinic_resources','schedule',false)) x(t,p,patient) where x.t=record_type;
 if tbl is null then raise exception 'Invalid history type'; end if;
 if not clinic.allowed(perm) and not (tbl in ('stock_lots','stock_movements','inventory_products') and clinic.allowed('inventory')) and not (tbl='performed_services' and clinic.allowed('clinical')) and not (tbl in ('tills','suppliers') and clinic.allowed('finance')) then raise exception 'Permission denied' using errcode='42501'; end if;
 if patient_id is not null and (not has_patient or not exists(select 1 from clinic.patients p where p.id=history_page.patient_id and p.organization_id=o)) then raise exception 'Patient unavailable' using errcode='42501';end if;
 execute format($q$with records as (
 select r.id,coalesce((to_jsonb(r)->>'created_at')::timestamptz,(to_jsonb(r)->>'opened_at')::timestamptz,'-infinity'::timestamptz) sort_at,
 to_jsonb(r) || case when $7='clinician_availability' then jsonb_build_object('ended',exists(select 1 from clinic.availability_cancellations x where x.availability_id=r.id)) else '{}'::jsonb end || case when $5 then jsonb_build_object('patient_name',clinic.patient_label((to_jsonb(r)->>'patient_id')::uuid)) else '{}'::jsonb end value
 from clinic.%I r where r.organization_id=$1 and ($2 is null or (to_jsonb(r)->>'patient_id')::uuid in (select id from clinic.patient_ids($2)))
 ),page as (select * from records r where ($3 is null or (r.sort_at,r.id)<(select c.sort_at,c.id from records c where c.id=$3))
 and ($4='' or clinic.search_key(r.value::text) like '%%'||clinic.search_key(left($4,200))||'%%') order by sort_at desc,id desc limit $6)
 select coalesce(jsonb_agg(value order by sort_at desc,id desc),'[]') from page$q$,tbl)
 into items using o,patient_id,cursor_id,coalesce(search_term,''),has_patient,sz+1,record_type;
 more:=jsonb_array_length(items)>sz;if more then items:=items-sz;end if;
 if perm in ('clinical','media','results') then perform clinic.log_access('HISTORY_READ',patient_id,tbl);end if;
 return jsonb_build_object('items',items,'has_more',more);
end $function$;

REVOKE ALL ON FUNCTION "public"."history_page"(text, uuid, text, uuid, integer) FROM PUBLIC, "anon";

CREATE OR REPLACE FUNCTION public.inventory_alerts (
  expiry_days integer DEFAULT 30,
  page_number integer DEFAULT 0
)
  RETURNS jsonb
  LANGUAGE plpgsql
  STABLE
  SET search_path TO ''
  AS $function$
declare rows jsonb;items jsonb;today date:=(now() at time zone 'Asia/Baghdad')::date;
begin
 if not (clinic.allowed('inventory') or clinic.allowed('inventory.read')) then raise exception 'Permission denied' using errcode='42501';end if;
 if expiry_days not between 0 and 365 or page_number<0 then raise exception 'Invalid inventory report range';end if;
 select coalesce(jsonb_agg(to_jsonb(r) order by r.category,r.product,r.id),'[]') into rows from (
 select l.id,l.product,l.lot_number,l.expires_on,l.unit,l.quantity available,null::numeric threshold,case when l.expires_on<today then 'expired' when l.quantity=0 then 'out_of_stock' else 'expiring' end category
 from clinic.stock_lots l where l.organization_id=clinic.org_id() and ((l.quantity>0 and l.expires_on<=today+expiry_days) or l.quantity=0)
 union all select p.id,p.name,null::text,null::date,p.unit,coalesce(sum(l.quantity) filter(where l.expires_on>=today),0),p.reorder_level,'reorder'
 from clinic.inventory_products p left join clinic.stock_lots l on l.product_id=p.id where p.organization_id=clinic.org_id() and p.active group by p.id,p.name,p.unit,p.reorder_level having coalesce(sum(l.quantity) filter(where l.expires_on>=today),0)<=p.reorder_level) r;
 select coalesce(jsonb_agg(value order by ord),'[]') into items from jsonb_array_elements(rows) with ordinality x(value,ord) where ord>page_number*100 and ord<=(page_number+1)*100;
 return jsonb_build_object('items',items,'records',jsonb_array_length(rows),'has_more',jsonb_array_length(rows)>(page_number+1)*100);
end $function$;

REVOKE ALL ON FUNCTION "public"."inventory_alerts"(integer, integer) FROM PUBLIC, "anon";

CREATE OR REPLACE FUNCTION public.media_access_variant (
  media_id uuid,
  original boolean DEFAULT false
)
  RETURNS text
  LANGUAGE plpgsql
  SET search_path TO ''
  AS $function$
declare original_key text;m clinic.media;
begin
 original_key:=public.media_access(media_id);
 select * into m from clinic.media where id=media_id and organization_id=clinic.org_id();
 if original or m.mime_type='application/pdf' then return original_key;end if;
 if m.preview_key is null then raise exception 'Generate a preview or open the original image';end if;
 perform clinic.log_access('MEDIA_PREVIEW',media_id,'media');return m.preview_key;
end $function$;

REVOKE ALL ON FUNCTION "public"."media_access_variant"(uuid, boolean) FROM PUBLIC, "anon";

CREATE OR REPLACE FUNCTION public.media_cancel_upload (
  media_id uuid,
  reason   text
)
  RETURNS void
  LANGUAGE plpgsql
  SET search_path TO ''
  AS $function$begin
 perform clinic.require_permission('media');
 if length(trim(coalesce(reason,'')))<5 then raise exception 'Document why the pending upload is cancelled';end if;
 update clinic.media set status='rejected',processing_note=reason where id=media_id and organization_id=clinic.org_id() and uploaded_by=auth.uid() and status='pending';
 if not found then raise exception 'Your pending upload is unavailable';end if;
end $function$;

REVOKE ALL ON FUNCTION "public"."media_cancel_upload"(uuid, text) FROM PUBLIC, "anon";

CREATE OR REPLACE FUNCTION public.media_cleanup_record (
  media_id   uuid,
  object_key text
)
  RETURNS void
  LANGUAGE plpgsql
  SET search_path TO ''
  AS $function$declare m clinic.media;begin
 if current_user<>'service_role' then raise exception 'Server-only maintenance' using errcode='42501';end if;
 select * into m from clinic.media where id=media_id and status='rejected' and rejected_at<clock_timestamp()-interval '30 days';
 if not found or not (object_key=m.object_key or object_key like m.object_key||'.preview-%.png') then raise exception 'Cleanup is limited to expired rejected uploads';end if;
 if exists(select 1 from clinic.media where status='ready' and (clinic.media.object_key=media_cleanup_record.object_key or preview_key=media_cleanup_record.object_key)) then raise exception 'Ready media must be preserved';end if;
 insert into clinic.media_cleanup_events(organization_id,media_id,object_key) values(m.organization_id,m.id,media_cleanup_record.object_key) on conflict on constraint media_cleanup_events_object_key_key do nothing;
end $function$;

REVOKE ALL ON FUNCTION "public"."media_cleanup_record"(uuid, text) FROM PUBLIC, "anon", "authenticated";

CREATE OR REPLACE FUNCTION public.media_complete (
  media_id     uuid,
  preview_path text,
  preview_hash text,
  note         text
)
  RETURNS void
  LANGUAGE plpgsql
  SET search_path TO ''
  AS $function$
declare m clinic.media;
begin
 if current_user<>'service_role' then raise exception 'Server-only operation' using errcode='42501';end if;
 select * into m from clinic.media where id=media_id;
 if not found or m.status<>'pending' then raise exception 'Pending media unavailable';end if;
 if m.mime_type<>'application/pdf' and (preview_path is null or (preview_hash is null or preview_hash !~ '^[a-f0-9]{64}$') or preview_path is distinct from m.object_key||'.preview-'||preview_hash||'.png') then raise exception 'A verified image preview is required';end if;
 update clinic.media set status='ready',preview_key=preview_path,preview_sha256=preview_hash,processing_note=note where id=media_id and status='pending';
end $function$;

REVOKE ALL ON FUNCTION "public"."media_complete"(uuid, text, text, text) FROM PUBLIC, "anon", "authenticated";

CREATE OR REPLACE FUNCTION public.media_maintenance (
  expire_abandoned boolean DEFAULT false
)
  RETURNS jsonb
  LANGUAGE plpgsql
  SET search_path TO ''
  AS $function$
declare expired integer:=0;objects jsonb;
begin
 if current_user<>'service_role' then raise exception 'Server-only maintenance' using errcode='42501';end if;
 if expire_abandoned then
 update clinic.media set status='rejected',processing_note='Abandoned upload expired after seven days' where status='pending' and created_at<clock_timestamp()-interval '7 days';
 get diagnostics expired=row_count;
 end if;
 select coalesce(jsonb_agg(to_jsonb(r)),'[]') into objects from (
 select m.id media_id,m.organization_id,s.name object_key from clinic.media m join storage.objects s on s.bucket_id='clinical' and (s.name=m.object_key or s.name like m.object_key||'.preview-%.png')
 where m.status='rejected' and m.rejected_at<clock_timestamp()-interval '30 days'
 and not exists(select 1 from clinic.media ready where ready.status='ready' and (ready.object_key=s.name or ready.preview_key=s.name))
 and not exists(select 1 from clinic.media_cleanup_events c where c.object_key=s.name)
 order by m.rejected_at,s.name limit 100) r;
 return jsonb_build_object('expired',expired,'objects',objects);
end $function$;

REVOKE ALL ON FUNCTION "public"."media_maintenance"(boolean) FROM PUBLIC, "anon", "authenticated";

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
 if existing.patient_id<>patient_id or existing.consent_id<>consent_id or existing.mime_type<>mime_type or existing.title<>title or existing.body_site<>body_site or existing.object_key not like '%'||content_hash then raise exception 'Upload identifier already used for a different file'; end if;
 return jsonb_build_object('id',existing.id,'key',existing.object_key,'status',existing.status);
 end if;
 key:=clinic.org_id()::text||'/'||media_id::text||'/'||content_hash;
 insert into clinic.media(id,organization_id,patient_id,consent_id,title,body_site,mime_type,object_key) values(media_id,clinic.org_id(),patient_id,consent_id,title,body_site,mime_type,key);
 return jsonb_build_object('id',media_id,'key',key,'status','pending');
end $function$;

CREATE OR REPLACE FUNCTION public.media_preview_attach (
  media_id     uuid,
  preview_path text,
  preview_hash text,
  note         text
)
  RETURNS void
  LANGUAGE plpgsql
  SET search_path TO ''
  AS $function$
declare m clinic.media;begin
 if current_user<>'service_role' then raise exception 'Server-only operation' using errcode='42501';end if;
 select * into m from clinic.media where id=media_id and status='ready' and mime_type<>'application/pdf';
 if not found or (preview_hash is null or preview_hash !~ '^[a-f0-9]{64}$') or preview_path is distinct from m.object_key||'.preview-'||preview_hash||'.png' then raise exception 'Invalid preview attachment';end if;
 if m.preview_key is not null and m.preview_key<>preview_path then raise exception 'An approved preview already exists';end if;
 update clinic.media set preview_key=preview_path,preview_sha256=preview_hash,processing_note=note where id=media_id and preview_key is null;
end $function$;

REVOKE ALL ON FUNCTION "public"."media_preview_attach"(uuid, text, text, text) FROM PUBLIC, "anon", "authenticated";

CREATE OR REPLACE FUNCTION public.patient_contacts (
  patient_id uuid
)
  RETURNS jsonb
  LANGUAGE plpgsql
  STABLE
  SET search_path TO ''
  AS $function$begin
 perform clinic.require_permission('patients');
 if not exists(select 1 from clinic.patients p where p.id=patient_contacts.patient_id and p.organization_id=clinic.org_id()) then raise exception 'Patient unavailable' using errcode='42501';end if;
 return coalesce((select jsonb_agg(c order by c.valid_from desc,c.id) from clinic.contacts c where c.patient_id=patient_contacts.patient_id and c.organization_id=clinic.org_id()),'[]');end $function$;

REVOKE ALL ON FUNCTION "public"."patient_contacts"(uuid) FROM PUBLIC, "anon";

CREATE OR REPLACE FUNCTION public.patient_export (
  patient_id uuid,
  reason     text
)
  RETURNS jsonb
  LANGUAGE plpgsql
  SET search_path TO ''
  AS $function$declare record jsonb;export_id uuid;begin
 perform clinic.require_permission('clinical.export');
 if not clinic.patient_care_access(patient_id) or length(trim(coalesce(reason,'')))<10 then raise exception 'An authorized patient and documented export purpose are required' using errcode='42501';end if;
 record:=public.clinical_record(patient_id);insert into clinic.patient_exports(organization_id,patient_id,purpose) values(clinic.org_id(),patient_id,reason) returning id into export_id;
 perform clinic.log_access('PATIENT_EXPORT',patient_id,'care_packet');
 return record||jsonb_build_object('export_id',export_id,'documents',coalesce((select jsonb_agg(d) from clinic.patient_documents d where d.patient_id in(select id from clinic.patient_ids(patient_export.patient_id))),'[]'),'patient',public.patient_profile(patient_id),'exported_at',now(),'purpose',reason,
 'consents',coalesce((select jsonb_agg(c) from clinic.consents c where c.patient_id in(select id from clinic.patient_ids(patient_export.patient_id))),'[]'),
 'results',coalesce((select jsonb_agg(r) from clinic.results r where r.patient_id in(select id from clinic.patient_ids(patient_export.patient_id))),'[]'),
 'media',coalesce((select jsonb_agg(to_jsonb(m)-'object_key'-'preview_key'-'preview_sha256') from clinic.media m where m.patient_id in(select id from clinic.patient_ids(patient_export.patient_id))),'[]'));
end $function$;

REVOKE ALL ON FUNCTION "public"."patient_export"(uuid, text) FROM PUBLIC, "anon";

CREATE OR REPLACE FUNCTION public.reconciliation_options (
  statement_id uuid,
  search_term  text DEFAULT ''::text,
  cursor_id    uuid DEFAULT NULL::uuid
)
  RETURNS jsonb
  LANGUAGE plpgsql
  STABLE
  SET search_path TO ''
  AS $function$
declare s clinic.bank_statement_lines;items jsonb;more boolean;
begin perform clinic.require_permission('finance');select * into s from clinic.bank_statement_lines where id=statement_id and organization_id=clinic.org_id();if not found then raise exception 'Statement unavailable';end if;
 select coalesce(jsonb_agg(to_jsonb(r) order by r.created_at desc,r.id desc),'[]') into items from (select l.id,j.created_at,j.description,l.account,j.currency,l.debit-l.credit amount from clinic.journal_lines l join clinic.journals j on j.id=l.journal_id where j.organization_id=clinic.org_id() and l.account=s.account and j.currency=s.currency and l.debit-l.credit=s.amount and not exists(select 1 from clinic.bank_matches m where m.journal_line_id=l.id and not exists(select 1 from clinic.bank_match_reversals x where x.match_id=m.id)) and (cursor_id is null or (j.created_at,l.id)<(select cj.created_at,cl.id from clinic.journal_lines cl join clinic.journals cj on cj.id=cl.journal_id where cl.id=cursor_id and cj.organization_id=clinic.org_id())) and (coalesce(search_term,'')='' or clinic.search_key(j.description) like '%'||clinic.search_key(left(search_term,200))||'%') order by j.created_at desc,l.id desc limit 26) r;
 more:=jsonb_array_length(items)>25;if more then items:=items-25;end if;return jsonb_build_object('items',items,'has_more',more);
end $function$;

REVOKE ALL ON FUNCTION "public"."reconciliation_options"(uuid, text, uuid) FROM PUBLIC, "anon";

CREATE OR REPLACE FUNCTION public.retention_state()
  RETURNS jsonb
  LANGUAGE plpgsql
  STABLE
  SET search_path TO ''
  AS $function$begin
 perform clinic.require_permission('staff');
 return jsonb_build_object('rules',coalesce((select jsonb_agg(r order by created_at desc,id desc) from clinic.retention_rules r where r.organization_id=clinic.org_id()),'[]'),
 'holds',coalesce((select jsonb_agg(to_jsonb(h)||jsonb_build_object('released',exists(select 1 from clinic.hold_releases r where r.hold_id=h.id))) from clinic.legal_holds h where h.organization_id=clinic.org_id()),'[]'));
end $function$;

CREATE OR REPLACE FUNCTION public.staff_target (
  member_id uuid
)
  RETURNS jsonb
  LANGUAGE plpgsql
  STABLE
  SET search_path TO ''
  AS $function$
declare m clinic.memberships; actor_role text;
begin
 perform clinic.require_permission('staff');
 select role into actor_role from clinic.memberships where user_id=auth.uid() and organization_id=clinic.org_id();
 select * into m from clinic.memberships where user_id=member_id and organization_id=clinic.org_id();
 if not found or m.user_id=auth.uid() or m.role='owner' or (actor_role<>'owner' and m.role in ('administrator','accountant')) then
 raise exception 'This account cannot be reset by your role.' using errcode='42501'; end if;
 return jsonb_build_object('user_id',m.user_id,'username',m.username,'role',m.role);
end $function$;

CREATE OR REPLACE FUNCTION public.workflow (
  kind       text,
  payload    jsonb,
  request_id uuid
)
  RETURNS jsonb
  LANGUAGE plpgsql
  SET search_path TO ''
  AS $function$
declare o uuid:=clinic.org_id();actor uuid:=auth.uid();previous clinic.requests;fingerprint text:=md5(kind||payload::text);rid uuid;p uuid;e uuid;v uuid;rowdata record;amount numeric;result jsonb;counted numeric;curr text;
begin
 if o is null or actor is null or not clinic.session_valid() or exists(select 1 from clinic.memberships where user_id=actor and organization_id=o and password_change_required) or request_id is null or jsonb_typeof(payload)<>'object' or octet_length(payload::text)>200000 then raise exception 'Invalid authenticated request' using errcode='42501';end if;
 perform pg_advisory_xact_lock(hashtextextended(o::text,0));
 select * into previous from clinic.requests r where r.organization_id=o and r.actor_id=actor and r.request_id=workflow.request_id;
 if found then if previous.fingerprint<>fingerprint then raise exception 'Request identifier was reused with different content' using errcode='23505';end if;return previous.result;end if;
 p:=nullif(payload->>'patient_id','')::uuid;e:=nullif(payload->>'encounter_id','')::uuid;v:=nullif(payload->>'id','')::uuid;
 if p is not null and not exists(select 1 from clinic.patients where id=p and organization_id=o and merged_into is null) then raise exception 'Active patient unavailable' using errcode='42501';end if;
 case kind
 when 'service.propose' then
 perform clinic.require_permission('patients');
 insert into clinic.services(organization_id,name,name_ckb,category,currency,price,duration,active) values(o,payload->>'name',coalesce(payload->>'name_ckb',''),payload->>'category',coalesce(payload->>'currency','IQD'),0,(payload->>'duration')::integer,false) returning id into rid;
 when 'service.approve' then
 perform clinic.require_permission('settings');amount:=(payload->>'price')::numeric;curr:=payload->>'currency';
 if amount<0 or curr not in ('USD','IQD') or amount<>round(amount,case when curr='USD' then 2 else 3 end) then raise exception 'Invalid service price';end if;
 update clinic.services set active=true,price=amount,currency=curr where id=v and organization_id=o and not active returning id into rid;
 when 'document.create' then
 perform clinic.require_permission('clinical');
 if nullif(payload->>'template_id','') is not null and not exists(select 1 from clinic.document_templates t where t.id=(payload->>'template_id')::uuid and t.organization_id=o and t.kind=payload->>'kind' and t.status='approved') then raise exception 'Select an approved template for this document type';end if;
 if nullif(payload->>'supersedes_id','') is not null and not exists(select 1 from clinic.patient_documents d where d.id=(payload->>'supersedes_id')::uuid and d.organization_id=o and d.patient_id=p) then raise exception 'Corrected document must belong to this patient';end if;
 insert into clinic.patient_documents(organization_id,patient_id,kind,title,body,template_id,template_snapshot,supersedes_id,correction_reason) values(o,p,payload->>'kind',payload->>'title',payload->>'body',nullif(payload->>'template_id','')::uuid,(select to_jsonb(t) from clinic.document_templates t where t.id=nullif(payload->>'template_id','')::uuid and t.organization_id=o),nullif(payload->>'supersedes_id','')::uuid,payload->>'correction_reason') returning id into rid;
 when 'template.create' then
 perform clinic.require_permission('clinical');
 insert into clinic.document_templates(organization_id,kind,name,language,version,content) values(o,payload->>'kind',payload->>'name',payload->>'language',(payload->>'version')::integer,payload->>'content') returning id into rid;
 when 'template.approve' then
 perform clinic.require_permission('clinical');
 update clinic.document_templates set status='approved',approved_by=actor,approved_at=now() where id=v and organization_id=o and status='draft' returning id into rid;
 when 'fact.record' then
 perform clinic.require_permission('clinical');
 if nullif(payload->>'supersedes_id','') is not null and not exists(select 1 from clinic.clinical_facts f where f.id=(payload->>'supersedes_id')::uuid and f.patient_id=p and f.kind=payload->>'kind' and f.organization_id=o) then raise exception 'Clinical fact does not belong to this patient and category';end if;
 insert into clinic.clinical_facts(organization_id,patient_id,kind,content,status,supersedes_id) values(o,p,payload->>'kind',payload->>'content',coalesce(payload->>'status','active'),nullif(payload->>'supersedes_id','')::uuid) returning id into rid;
 when 'prescription.add' then
 perform clinic.require_permission('clinical');
 if not exists(select 1 from clinic.encounters where id=e and organization_id=o and patient_id=p and doctor_id=actor and status='draft') then raise exception 'Select your own draft encounter for this patient';end if;
 insert into clinic.prescription_items(organization_id,encounter_id,medicine,strength,dose,route,frequency,duration,quantity,instructions) values(o,e,payload->>'medicine',coalesce(payload->>'strength',''),payload->>'dose',payload->>'route',payload->>'frequency',payload->>'duration',coalesce(payload->>'quantity',''),coalesce(payload->>'instructions','')) returning id into rid;
 when 'contact.add' then
 perform clinic.require_permission('patients');
 insert into clinic.contacts(organization_id,patient_id,phone,owner_name,relationship,preferred,verified_at) values(o,p,payload->>'phone',payload->>'owner_name',payload->>'relationship',coalesce((payload->>'preferred')::boolean,false),case when (payload->>'verified')::boolean then now() end) returning id into rid;
 when 'contact.end' then
 perform clinic.require_permission('patients');
 update clinic.contacts set valid_to=now() where id=v and patient_id=p and organization_id=o and valid_to is null returning id into rid;
 when 'contact.log' then
 perform clinic.require_permission('patients');
 insert into clinic.contact_log(organization_id,patient_id,channel,purpose,outcome,notes) values(o,p,payload->>'channel',payload->>'purpose',payload->>'outcome',payload->>'notes') returning id into rid;
 when 'performed.record' then
 perform clinic.require_permission('clinical');
 if not exists(select 1 from clinic.encounters where id=e and patient_id=p and organization_id=o and status='signed') then raise exception 'A signed encounter for this patient is required';end if;
 if not exists(select 1 from clinic.services where id=(payload->>'service_id')::uuid and organization_id=o and active) then raise exception 'Select an approved active service';end if;
 insert into clinic.performed_services(organization_id,patient_id,encounter_id,service_id,quantity) values(o,p,e,(payload->>'service_id')::uuid,(payload->>'quantity')::integer) returning id into rid;
 when 'performed.invoice' then
 perform clinic.require_permission('billing');
 select ps.*,s.currency into rowdata from clinic.performed_services ps join clinic.services s on s.id=ps.service_id where ps.id=v and ps.organization_id=o and ps.invoice_id is null for update of ps;
 if not found then raise exception 'Performed service is unavailable or already invoiced';end if;
 result:=public.command('invoice.issue',jsonb_build_object('patient_id',rowdata.patient_id,'currency',rowdata.currency,'lines',jsonb_build_array(jsonb_build_object('service_id',rowdata.service_id,'quantity',rowdata.quantity))),gen_random_uuid());
 rid:=(result->>'id')::uuid;update clinic.performed_services set invoice_id=rid where id=v;
 when 'package.expiry' then
 perform clinic.require_permission('approve');
 if length(trim(coalesce(payload->>'reason','')))<5 or (payload->>'expires_on')::date<(now() at time zone 'Asia/Baghdad')::date then raise exception 'A future expiry and documented reason are required';end if;
 update clinic.packages set expires_on=(payload->>'expires_on')::date where id=v and organization_id=o and cancelled_at is null returning id into rid;
 insert into clinic.package_corrections(organization_id,package_id,amount,currency,kind,reason) select o,id,0,currency,'expiry_extension',payload->>'reason' from clinic.packages where id=rid;
 when 'package.cancel' then
 perform clinic.require_permission('approve');
 select * into rowdata from clinic.packages where id=v and organization_id=o and cancelled_at is null for update;
 if not found or rowdata.remaining=0 or rowdata.sale_method is null or length(trim(coalesce(payload->>'reason','')))<5 then raise exception 'Select a package with unused sessions, original tender and a documented reason';end if;
 amount:=rowdata.total-rowdata.redeemed_value;perform clinic.require_approval(amount,rowdata.currency);
 update clinic.packages set cancelled_at=now() where id=v;
 insert into clinic.package_corrections(organization_id,package_id,amount,currency,kind,reason) values(o,v,amount,rowdata.currency,'refund',payload->>'reason') returning id into rid;
 if amount>0 then perform clinic.post_journal(rowdata.currency,'Unused package refund','package_refund',rid,'deposits',rowdata.sale_method,amount);end if;
 when 'stock.adjust' then
 perform clinic.require_permission('inventory');
 select * into rowdata from clinic.stock_lots where id=v and organization_id=o for update;
 if not found or rowdata.version is distinct from (payload->>'version')::integer then raise exception 'Stock changed. Refresh before recording a count.' using errcode='40001';end if;
 counted:=(payload->>'counted')::numeric;amount:=counted-rowdata.quantity;
 if counted<0 or counted<>round(counted,3) or amount=0 or length(trim(coalesce(payload->>'reason','')))<5 then raise exception 'A different nonnegative count and documented reason are required';end if;
 update clinic.stock_lots set quantity=counted,version=version+1 where id=v;
 insert into clinic.stock_movements(organization_id,lot_id,quantity,reason) values(o,v,amount,payload->>'reason') returning id into rid;
 when 'supplier.create' then
 perform clinic.require_permission('inventory');
 insert into clinic.suppliers(organization_id,name,contact_person,phone,address) values(o,payload->>'name',coalesce(payload->>'contact_person',''),nullif(payload->>'phone',''),coalesce(payload->>'address','')) returning id into rid;
 when 'supplier.update' then
 perform clinic.require_permission('inventory');
 update clinic.suppliers set name=payload->>'name',contact_person=coalesce(payload->>'contact_person',''),phone=nullif(payload->>'phone',''),address=coalesce(payload->>'address',''),active=(payload->>'active')::boolean,version=version+1 where id=v and organization_id=o and version=(payload->>'version')::integer returning id into rid;
 if rid is null then raise exception 'Supplier changed. Refresh first.' using errcode='40001';end if;
 when 'product.create' then
 perform clinic.require_permission('inventory');
 if (payload->>'reorder_level')::numeric<>round((payload->>'reorder_level')::numeric,3) then raise exception 'Stock precision is at most three decimals';end if;
 insert into clinic.inventory_products(organization_id,name,unit,reorder_level,supplier_id) values(o,payload->>'name',payload->>'unit',(payload->>'reorder_level')::numeric,nullif(payload->>'supplier_id','')::uuid) returning id into rid;
 update clinic.stock_lots set product_id=rid,version=version+1 where organization_id=o and product=payload->>'name' and unit=payload->>'unit' and product_id is null;
 when 'availability.end' then
 perform clinic.require_permission('schedule');
 if length(trim(coalesce(payload->>'reason','')))<5 then raise exception 'Document why availability is ended';end if;
 insert into clinic.availability_cancellations(organization_id,availability_id,reason) values(o,v,payload->>'reason') returning id into rid;
 when 'availability.add' then
 perform clinic.require_permission('schedule');
 if not exists(select 1 from clinic.memberships where user_id=(payload->>'doctor_id')::uuid and organization_id=o and active and clinic.has_role(user_id,'doctor')) then raise exception 'Select an active clinician';end if;
 if payload->>'kind'='leave' and exists(select 1 from clinic.appointments where organization_id=o and doctor_id=(payload->>'doctor_id')::uuid and status not in ('cancelled','no_show','completed') and starts_at<(payload->>'ends_at')::timestamptz and ends_at>(payload->>'starts_at')::timestamptz) then raise exception 'Move or cancel conflicting appointments before recording leave';end if;
 insert into clinic.clinician_availability(organization_id,doctor_id,starts_at,ends_at,kind,description) values(o,(payload->>'doctor_id')::uuid,(payload->>'starts_at')::timestamptz,(payload->>'ends_at')::timestamptz,payload->>'kind',payload->>'description') returning id into rid;
 when 'resource.add' then
 perform clinic.require_permission('settings');
 insert into clinic.clinic_resources(organization_id,name,kind) values(o,payload->>'name',payload->>'kind') returning id into rid;
 when 'appointment.reschedule' then
 perform clinic.require_permission('schedule');
 select * into rowdata from clinic.appointments where id=v and organization_id=o and status in ('scheduled','checked_in') for update;
 if not found or rowdata.version is distinct from (payload->>'version')::integer then raise exception 'Appointment changed. Refresh before rescheduling.' using errcode='40001';end if;
 if length(trim(coalesce(payload->>'reason','')))<5 then raise exception 'Document the reason for rescheduling';end if;
 update clinic.appointments set starts_at=(payload->>'starts_at')::timestamptz,ends_at=(payload->>'ends_at')::timestamptz,resource_id=case when payload?'resource_id' then nullif(payload->>'resource_id','')::uuid else rowdata.resource_id end,version=version+1 where id=v returning id into rid;
 else raise exception 'Unsupported workflow operation';
 end case;
 if rid is null then raise exception 'No record changed. Refresh and review your access.' using errcode='P0002';end if;
 result:=jsonb_build_object('id',rid);insert into clinic.requests(organization_id,actor_id,request_id,fingerprint,result) values(o,actor,request_id,fingerprint,result);return result;
end $function$;

REVOKE ALL ON FUNCTION "public"."workflow"(text, jsonb, uuid) FROM PUBLIC, "anon";

CREATE OR REPLACE FUNCTION public.workspace()
  RETURNS jsonb
  LANGUAGE plpgsql
  SET search_path TO ''
  AS $function$
declare o uuid:=clinic.org_id(); m clinic.memberships; r jsonb;
begin
 if o is null then raise exception 'No active clinic membership. Ask the owner to invite your account.' using errcode='42501'; end if;
 select * into m from clinic.memberships where organization_id=o and user_id=auth.uid();
 r:=jsonb_build_object('organization',(select to_jsonb(x) from clinic.organizations x where id=o),'membership',to_jsonb(m),'account',public.account_status(),'permissions',to_jsonb(array(select perm from unnest(clinic.user_permissions()) perm where clinic.allowed(perm))));
 r:=r || jsonb_build_object(
 'patients',coalesce((select jsonb_agg(x) from (select * from clinic.patients where organization_id=o order by created_at desc limit 300) x),'[]'),
 'appointments',coalesce((select jsonb_agg(x) from (select a.*,clinic.patient_label(a.patient_id) patient_name from clinic.appointments a where organization_id=o and starts_at>=(now() at time zone 'Asia/Baghdad')::date::timestamp at time zone 'Asia/Baghdad' order by starts_at limit 500) x),'[]'),
 'encounters',coalesce((select jsonb_agg(x) from (select id,patient_id,doctor_id,status,chief_complaint,created_at,version from clinic.encounters where organization_id=o order by created_at desc limit 300) x),'[]'),
 'services',coalesce((select jsonb_agg(x) from clinic.services x where organization_id=o and active),'[]'),
 'invoices',coalesce((select jsonb_agg(x) from (select i.*,clinic.invoice_balance(i.id) balance from clinic.invoices i where organization_id=o order by created_at desc limit 300) x),'[]'),
 'payments',coalesce((select jsonb_agg(x) from (select pm.*,i.currency invoice_currency,i.invoice_number from clinic.payments pm left join clinic.invoices i on i.id=pm.invoice_id where pm.organization_id=o order by pm.created_at desc limit 500) x),'[]'),
 'expenses',coalesce((select jsonb_agg(x) from (select e.*, (e.paid or exists(select 1 from clinic.journals j where j.organization_id=o and j.source_type='expense_payment' and j.source_id=e.id)) is_paid from clinic.expenses e where organization_id=o order by created_at desc limit 300) x),'[]'),
 'tasks',coalesce((select jsonb_agg(x) from (select r.*,clinic.patient_label(r.patient_id) patient_name from clinic.tasks r where organization_id=o order by due_at limit 300) x),'[]'),
 'results',coalesce((select jsonb_agg(x) from (select r.*,clinic.patient_label(r.patient_id) patient_name from clinic.results r where organization_id=o order by created_at desc limit 300) x),'[]'),
 'consents',coalesce((select jsonb_agg(x) from (select * from clinic.consents where organization_id=o order by created_at desc limit 500) x),'[]'),
 'media',coalesce((select jsonb_agg(x) from (select * from clinic.media where organization_id=o order by created_at desc limit 300) x),'[]'),
 'stock',coalesce((select jsonb_agg(x) from clinic.stock_lots x where organization_id=o),'[]'),
 'movements',coalesce((select jsonb_agg(x) from (select * from clinic.cash_movements where organization_id=o order by created_at desc limit 300) x),'[]'),
 'journals',case when clinic.allowed('finance') then coalesce((select jsonb_agg(x) from (select j.*, (select jsonb_agg(l) from clinic.journal_lines l where l.journal_id=j.id) lines from clinic.journals j where organization_id=o order by created_at desc limit 500) x),'[]') else '[]'::jsonb end,
 'tills',coalesce((select jsonb_agg(x) from (select * from clinic.tills where organization_id=o order by opened_at desc limit 100) x),'[]'),
 'members',coalesce((select jsonb_agg(to_jsonb(x)||jsonb_build_object('additional_roles',clinic.extra_roles(x.user_id))) from clinic.memberships x where organization_id=o),'[]'),
 'audit',coalesce((select jsonb_agg(x) from (select * from clinic.audit_events where organization_id=o order by created_at desc limit 200) x),'[]'),
 'packages',coalesce((select jsonb_agg(x) from clinic.packages x where organization_id=o),'[]'),
 'billable_encounters',clinic.billable_encounters(),
 'metrics',jsonb_build_object('today_appointments',(select count(*) from clinic.appointments where organization_id=o and (starts_at at time zone 'Asia/Baghdad')::date=(now() at time zone 'Asia/Baghdad')::date),'waiting',(select count(*) from clinic.appointments where organization_id=o and status='checked_in'),'followups_due',(select count(*) from clinic.tasks where organization_id=o and completed_at is null and due_at<=now()),'open_invoices',(select count(*) from clinic.invoices i where organization_id=o and clinic.invoice_balance(i.id)>0)),
 'trial_balance',case when clinic.allowed('finance') then coalesce((select jsonb_agg(x) from (select j.currency,l.account,sum(l.debit) debit,sum(l.credit) credit from clinic.journal_lines l join clinic.journals j on j.id=l.journal_id where j.organization_id=o group by j.currency,l.account) x),'[]') else '[]'::jsonb end);
 if clinic.allowed('clinical') then perform clinic.log_access('WORKSPACE_READ',null,'clinical_summary'); end if;
 return r;
end $function$;

ALTER TABLE "clinic"."access_events"
  ADD CONSTRAINT "access_events_organization_id_fkey" FOREIGN KEY (organization_id) REFERENCES clinic.organizations(id);

ALTER TABLE "clinic"."account_mappings"
  ADD CONSTRAINT "account_mappings_approved_by_fkey" FOREIGN KEY (approved_by) REFERENCES auth.users(id);

ALTER TABLE "clinic"."account_mappings"
  ADD CONSTRAINT "account_mappings_organization_id_fkey" FOREIGN KEY (organization_id) REFERENCES clinic.organizations(id);

ALTER TABLE "clinic"."accounting_acknowledgements"
  ADD CONSTRAINT "accounting_acknowledgements_organization_id_batch_id_fkey" FOREIGN KEY (organization_id, batch_id) REFERENCES clinic.accounting_batches(organization_id, id);

ALTER TABLE "clinic"."accounting_batch_items"
  ADD CONSTRAINT "accounting_batch_items_organization_id_batch_id_fkey" FOREIGN KEY (organization_id, batch_id) REFERENCES clinic.accounting_batches(organization_id, id);

ALTER TABLE "clinic"."accounting_batches"
  ADD CONSTRAINT "accounting_batches_organization_id_mapping_id_fkey" FOREIGN KEY (organization_id, mapping_id) REFERENCES clinic.account_mappings(organization_id, id);

ALTER TABLE "clinic"."accounting_periods"
  ADD CONSTRAINT "accounting_periods_organization_id_fkey" FOREIGN KEY (organization_id) REFERENCES clinic.organizations(id);

ALTER TABLE "clinic"."additional_roles"
  ADD CONSTRAINT "additional_roles_organization_id_member_id_fkey" FOREIGN KEY (organization_id, member_id) REFERENCES clinic.memberships(organization_id, id);

ALTER TABLE "clinic"."approval_limits"
  ADD CONSTRAINT "approval_limits_organization_id_member_id_fkey" FOREIGN KEY (organization_id, member_id) REFERENCES clinic.memberships(organization_id, id);

ALTER TABLE "clinic"."bank_match_reversals"
  ADD CONSTRAINT "bank_match_reversals_organization_id_match_id_fkey" FOREIGN KEY (organization_id, match_id) REFERENCES clinic.bank_matches(organization_id, id);

ALTER TABLE "clinic"."bank_statement_lines"
  ADD CONSTRAINT "bank_statement_lines_organization_id_fkey" FOREIGN KEY (organization_id) REFERENCES clinic.organizations(id);

ALTER TABLE "clinic"."bank_matches"
  ADD CONSTRAINT "bank_matches_organization_id_statement_id_fkey" FOREIGN KEY (organization_id, statement_id) REFERENCES clinic.bank_statement_lines(organization_id, id);

ALTER TABLE "clinic"."care_assignments"
  ADD CONSTRAINT "care_assignments_doctor_id_fkey" FOREIGN KEY (doctor_id) REFERENCES auth.users(id);

ALTER TABLE "clinic"."care_assignments"
  ADD CONSTRAINT "care_assignments_organization_id_patient_id_fkey" FOREIGN KEY (organization_id, patient_id) REFERENCES clinic.patients(organization_id, id);

ALTER TABLE "clinic"."care_revocations"
  ADD CONSTRAINT "care_revocations_organization_id_assignment_id_fkey" FOREIGN KEY (organization_id, assignment_id) REFERENCES clinic.care_assignments(organization_id, id);

ALTER TABLE "clinic"."cash_movements"
  ADD CONSTRAINT "cash_movements_amount_finite" CHECK ((amount <> 'NaN'::numeric));

ALTER TABLE "clinic"."cash_movements"
  ADD CONSTRAINT "cash_movements_fx_rate_finite" CHECK ((fx_rate <> 'NaN'::numeric));

ALTER TABLE "clinic"."clinic_resources"
  ADD CONSTRAINT "clinic_resources_organization_id_fkey" FOREIGN KEY (organization_id) REFERENCES clinic.organizations(id);

ALTER TABLE "clinic"."appointments"
  ADD CONSTRAINT "appointments_organization_id_resource_id_fkey" FOREIGN KEY (organization_id, resource_id) REFERENCES clinic.clinic_resources(organization_id, id);

ALTER TABLE "clinic"."clinical_facts"
  ADD CONSTRAINT "clinical_facts_organization_id_patient_id_fkey" FOREIGN KEY (organization_id, patient_id) REFERENCES clinic.patients(organization_id, id);

ALTER TABLE "clinic"."clinical_facts"
  ADD CONSTRAINT "clinical_facts_organization_id_supersedes_id_fkey" FOREIGN KEY (organization_id, supersedes_id) REFERENCES clinic.clinical_facts(organization_id, id);

ALTER TABLE "clinic"."clinician_availability"
  ADD CONSTRAINT "clinician_availability_doctor_id_fkey" FOREIGN KEY (doctor_id) REFERENCES auth.users(id);

ALTER TABLE "clinic"."availability_cancellations"
  ADD CONSTRAINT "availability_cancellations_organization_id_availability_id_fkey" FOREIGN KEY (organization_id, availability_id)
    REFERENCES clinic.clinician_availability(organization_id, id);

ALTER TABLE "clinic"."contact_log"
  ADD CONSTRAINT "contact_log_organization_id_patient_id_fkey" FOREIGN KEY (organization_id, patient_id) REFERENCES clinic.patients(organization_id, id);

ALTER TABLE "clinic"."contacts"
  ADD CONSTRAINT "contact_phone_format" CHECK ((phone ~ '^\+[1-9][0-9]{7,14}$'::text));

ALTER TABLE "clinic"."credit_notes"
  ADD CONSTRAINT "credit_notes_amount_finite" CHECK ((amount <> 'NaN'::numeric));

ALTER TABLE "clinic"."document_templates"
  ADD CONSTRAINT "document_templates_approved_by_fkey" FOREIGN KEY (approved_by) REFERENCES auth.users(id);

ALTER TABLE "clinic"."document_templates"
  ADD CONSTRAINT "document_templates_organization_id_fkey" FOREIGN KEY (organization_id) REFERENCES clinic.organizations(id);

ALTER TABLE "clinic"."consents"
  ADD CONSTRAINT "consents_organization_id_template_id_fkey" FOREIGN KEY (organization_id, template_id) REFERENCES clinic.document_templates(organization_id, id);

ALTER TABLE "clinic"."encounters"
  ADD CONSTRAINT "encounters_organization_id_template_id_fkey" FOREIGN KEY (organization_id, template_id) REFERENCES clinic.document_templates(organization_id, id);

ALTER TABLE "clinic"."expenses"
  ADD CONSTRAINT "expenses_amount_finite" CHECK ((amount <> 'NaN'::numeric));

ALTER TABLE "clinic"."inventory_products"
  ADD CONSTRAINT "inventory_products_organization_id_fkey" FOREIGN KEY (organization_id) REFERENCES clinic.organizations(id);

ALTER TABLE "clinic"."invoices"
  ADD CONSTRAINT "invoices_total_finite" CHECK ((total <> 'NaN'::numeric));

ALTER TABLE "clinic"."journal_lines"
  ADD CONSTRAINT "journal_lines_credit_finite" CHECK ((credit <> 'NaN'::numeric));

ALTER TABLE "clinic"."journal_lines"
  ADD CONSTRAINT "journal_lines_debit_finite" CHECK ((debit <> 'NaN'::numeric));

ALTER TABLE "clinic"."journal_lines"
  ADD CONSTRAINT "journal_lines_organization_id_id_key" UNIQUE (organization_id, id);

ALTER TABLE "clinic"."accounting_batch_items"
  ADD CONSTRAINT "accounting_batch_items_organization_id_line_id_fkey" FOREIGN KEY (organization_id, line_id) REFERENCES clinic.journal_lines(organization_id, id);

ALTER TABLE "clinic"."bank_matches"
  ADD CONSTRAINT "bank_matches_organization_id_journal_line_id_fkey" FOREIGN KEY (organization_id, journal_line_id) REFERENCES clinic.journal_lines(organization_id, id);

ALTER TABLE "clinic"."hold_releases"
  ADD CONSTRAINT "hold_releases_organization_id_hold_id_fkey" FOREIGN KEY (organization_id, hold_id) REFERENCES clinic.legal_holds(organization_id, id);

ALTER TABLE "clinic"."legal_holds"
  ADD CONSTRAINT "legal_holds_organization_id_patient_id_fkey" FOREIGN KEY (organization_id, patient_id) REFERENCES clinic.patients(organization_id, id);

ALTER TABLE "clinic"."media"
  ADD CONSTRAINT "media_preview_sha256_check" CHECK ((preview_sha256 ~ '^[a-f0-9]{64}$'::text));

ALTER TABLE "clinic"."media"
  ADD CONSTRAINT "preview_pair" CHECK ((((preview_key IS NULL) AND (preview_sha256 IS NULL)) OR ((preview_key IS NOT NULL) AND (preview_sha256 IS
    NOT NULL) AND (mime_type <> 'application/pdf'::text) AND (preview_key = (((object_key || '.preview-'::text) || preview_sha256) || '.png'::text)))));

ALTER TABLE "clinic"."media_cleanup_events"
  ADD CONSTRAINT "media_cleanup_events_organization_id_media_id_fkey" FOREIGN KEY (organization_id, media_id) REFERENCES clinic.media(organization_id, id);

ALTER TABLE "clinic"."organizations"
  ADD CONSTRAINT "organizations_clinical_access_scope_check" CHECK ((clinical_access_scope = ANY (ARRAY['organization'::text, 'assigned'::text])));

ALTER TABLE "clinic"."package_corrections"
  ADD CONSTRAINT "package_corrections_organization_id_package_id_fkey" FOREIGN KEY (organization_id, package_id) REFERENCES clinic.packages(organization_id, id);

ALTER TABLE "clinic"."packages"
  ADD CONSTRAINT "packages_redeemed_value_finite" CHECK ((redeemed_value <> 'NaN'::numeric));

ALTER TABLE "clinic"."packages"
  ADD CONSTRAINT "packages_sale_method_check" CHECK ((sale_method = ANY (ARRAY['cash'::text, 'bank'::text, 'card'::text])));

ALTER TABLE "clinic"."packages"
  ADD CONSTRAINT "packages_total_finite" CHECK ((total <> 'NaN'::numeric));

ALTER TABLE "clinic"."patient_documents"
  ADD CONSTRAINT "patient_documents_organization_id_patient_id_fkey" FOREIGN KEY (organization_id, patient_id) REFERENCES clinic.patients(organization_id, id);

ALTER TABLE "clinic"."patient_documents"
  ADD CONSTRAINT "patient_documents_organization_id_supersedes_id_fkey" FOREIGN KEY (organization_id, supersedes_id) REFERENCES clinic.patient_documents(organization_id, id);

ALTER TABLE "clinic"."patient_documents"
  ADD CONSTRAINT "patient_documents_organization_id_template_id_fkey" FOREIGN KEY (organization_id, template_id) REFERENCES clinic.document_templates(organization_id, id);

ALTER TABLE "clinic"."patient_exports"
  ADD CONSTRAINT "patient_exports_organization_id_patient_id_fkey" FOREIGN KEY (organization_id, patient_id) REFERENCES clinic.patients(organization_id, id);

ALTER TABLE "clinic"."payments"
  ADD CONSTRAINT "payments_amount_finite" CHECK ((amount <> 'NaN'::numeric));

ALTER TABLE "clinic"."payments"
  ADD CONSTRAINT "payments_exchange_rate_finite" CHECK ((exchange_rate <> 'NaN'::numeric));

ALTER TABLE "clinic"."payments"
  ADD CONSTRAINT "payments_invoice_amount_finite" CHECK ((invoice_amount <> 'NaN'::numeric));

ALTER TABLE "clinic"."performed_services"
  ADD CONSTRAINT "performed_services_organization_id_encounter_id_fkey" FOREIGN KEY (organization_id, encounter_id) REFERENCES clinic.encounters(organization_id, id);

ALTER TABLE "clinic"."performed_services"
  ADD CONSTRAINT "performed_services_organization_id_invoice_id_fkey" FOREIGN KEY (organization_id, invoice_id) REFERENCES clinic.invoices(organization_id, id);

ALTER TABLE "clinic"."performed_services"
  ADD CONSTRAINT "performed_services_organization_id_patient_id_fkey" FOREIGN KEY (organization_id, patient_id) REFERENCES clinic.patients(organization_id, id);

ALTER TABLE "clinic"."performed_services"
  ADD CONSTRAINT "performed_services_organization_id_service_id_fkey" FOREIGN KEY (organization_id, service_id) REFERENCES clinic.services(organization_id, id);

ALTER TABLE "clinic"."prescription_items"
  ADD CONSTRAINT "prescription_items_organization_id_encounter_id_fkey" FOREIGN KEY (organization_id, encounter_id) REFERENCES clinic.encounters(organization_id, id);

ALTER TABLE "clinic"."procedures"
  ADD CONSTRAINT "procedures_organization_id_template_id_fkey" FOREIGN KEY (organization_id, template_id) REFERENCES clinic.document_templates(organization_id, id);

ALTER TABLE "clinic"."procedures"
  ADD CONSTRAINT "procedures_quantity_finite" CHECK ((quantity <> 'NaN'::numeric));

ALTER TABLE "clinic"."retention_rules"
  ADD CONSTRAINT "retention_rules_approved_by_fkey" FOREIGN KEY (approved_by) REFERENCES auth.users(id);

ALTER TABLE "clinic"."retention_rules"
  ADD CONSTRAINT "retention_rules_organization_id_fkey" FOREIGN KEY (organization_id) REFERENCES clinic.organizations(id);

ALTER TABLE "clinic"."role_revocations"
  ADD CONSTRAINT "role_revocations_organization_id_grant_id_fkey" FOREIGN KEY (organization_id, grant_id) REFERENCES clinic.additional_roles(organization_id, id);

ALTER TABLE "clinic"."services"
  ADD CONSTRAINT "services_price_finite" CHECK ((price <> 'NaN'::numeric));

ALTER TABLE "clinic"."stock_lots"
  ADD CONSTRAINT "stock_lots_organization_id_product_id_fkey" FOREIGN KEY (organization_id, product_id) REFERENCES clinic.inventory_products(organization_id, id);

ALTER TABLE "clinic"."stock_lots"
  ADD CONSTRAINT "stock_lots_quantity_finite" CHECK ((quantity <> 'NaN'::numeric));

ALTER TABLE "clinic"."stock_movements"
  ADD CONSTRAINT "stock_movements_quantity_finite" CHECK ((quantity <> 'NaN'::numeric));

ALTER TABLE "clinic"."suppliers"
  ADD CONSTRAINT "suppliers_organization_id_fkey" FOREIGN KEY (organization_id) REFERENCES clinic.organizations(id);

ALTER TABLE "clinic"."inventory_products"
  ADD CONSTRAINT "inventory_products_organization_id_supplier_id_fkey" FOREIGN KEY (organization_id, supplier_id) REFERENCES clinic.suppliers(organization_id, id);

ALTER TABLE "clinic"."tills"
  ADD CONSTRAINT "tills_counted_finite" CHECK ((counted <> 'NaN'::numeric));

ALTER TABLE "clinic"."tills"
  ADD CONSTRAINT "tills_expected_finite" CHECK ((expected <> 'NaN'::numeric));

ALTER TABLE "clinic"."tills"
  ADD CONSTRAINT "tills_opening_finite" CHECK ((opening <> 'NaN'::numeric));

CREATE INDEX account_mappings_approved_by_fkey_idx ON clinic.account_mappings USING btree (approved_by);

CREATE INDEX accounting_acknowledgements_organization_id_batch_id_fk_idx ON clinic.accounting_acknowledgements USING btree (organization_id, batch_id);

CREATE INDEX accounting_batch_items_organization_id_batch_id_fkey_idx ON clinic.accounting_batch_items USING btree (organization_id, batch_id);

CREATE INDEX accounting_batch_items_organization_id_line_id_fkey_idx ON clinic.accounting_batch_items USING btree (organization_id, line_id);

CREATE INDEX accounting_batches_organization_id_mapping_id_fkey_idx ON clinic.accounting_batches USING btree (organization_id, mapping_id);

CREATE INDEX additional_roles_organization_id_member_id_fkey_idx ON clinic.additional_roles USING btree (organization_id, member_id);

CREATE INDEX appointment_resource ON clinic.appointments USING btree (organization_id, resource_id, starts_at, ends_at)
  WHERE (resource_id IS NOT NULL);

CREATE INDEX approval_limits_organization_id_member_id_fkey_idx ON clinic.approval_limits USING btree (organization_id, member_id);

CREATE INDEX availability_cancellations_organization_id_availability_idx ON clinic.availability_cancellations USING btree (organization_id, availability_id);

CREATE INDEX availability_dates ON clinic.clinician_availability USING btree (organization_id, doctor_id, starts_at, ends_at);

CREATE INDEX bank_match_reversals_organization_id_match_id_fkey_idx ON clinic.bank_match_reversals USING btree (organization_id, match_id);

CREATE INDEX bank_matches_organization_id_journal_line_id_fkey_idx ON clinic.bank_matches USING btree (organization_id, journal_line_id);

CREATE INDEX bank_matches_organization_id_statement_id_fkey_idx ON clinic.bank_matches USING btree (organization_id, statement_id);

CREATE INDEX care_assignments_doctor_id_fkey_idx ON clinic.care_assignments USING btree (doctor_id);

CREATE INDEX care_assignments_organization_id_patient_id_fkey_idx ON clinic.care_assignments USING btree (organization_id, patient_id);

CREATE INDEX care_revocations_organization_id_assignment_id_fkey_idx ON clinic.care_revocations USING btree (organization_id, assignment_id);

CREATE INDEX clinical_contact_patient ON clinic.contact_log USING btree (organization_id, patient_id, created_at DESC, id DESC);

CREATE INDEX clinical_facts_organization_id_supersedes_id_fkey_idx ON clinic.clinical_facts USING btree (organization_id, supersedes_id);

CREATE INDEX clinical_facts_patient ON clinic.clinical_facts USING btree (organization_id, patient_id, created_at DESC, id DESC);

CREATE INDEX clinician_availability_doctor_id_fkey_idx ON clinic.clinician_availability USING btree (doctor_id);

CREATE INDEX consent_template_idx ON clinic.consents USING btree (organization_id, template_id);

CREATE UNIQUE INDEX contact_active_unique ON clinic.contacts USING btree (organization_id, patient_id, phone)
  WHERE (valid_to IS NULL);

CREATE INDEX document_patient_date ON clinic.patient_documents USING btree (organization_id, patient_id, created_at DESC, id DESC);

CREATE INDEX document_templates_approved_by_fkey_idx ON clinic.document_templates USING btree (approved_by);

CREATE INDEX encounters_organization_id_template_id_fkey_idx ON clinic.encounters USING btree (organization_id, template_id);

CREATE INDEX export_patient_date ON clinic.patient_exports USING btree (organization_id, patient_id, created_at DESC, id DESC);

CREATE INDEX hold_releases_organization_id_hold_id_fkey_idx ON clinic.hold_releases USING btree (organization_id, hold_id);

CREATE INDEX inventory_products_organization_id_supplier_id_fkey_idx ON clinic.inventory_products USING btree (organization_id, supplier_id);

CREATE INDEX journal_accounting_date ON clinic.journals USING btree (organization_id, accounting_date, id);

CREATE INDEX legal_holds_organization_id_patient_id_fkey_idx ON clinic.legal_holds USING btree (organization_id, patient_id);

CREATE INDEX media_cleanup_events_organization_id_media_id_fkey_idx ON clinic.media_cleanup_events USING btree (organization_id, media_id);

CREATE INDEX package_corrections_organization_id_package_id_fkey_idx ON clinic.package_corrections USING btree (organization_id, package_id);

CREATE INDEX patient_documents_organization_id_supersedes_id_fkey_idx ON clinic.patient_documents USING btree (organization_id, supersedes_id);

CREATE INDEX patient_documents_organization_id_template_id_fkey_idx ON clinic.patient_documents USING btree (organization_id, template_id);

CREATE INDEX performed_services_organization_id_encounter_id_fkey_idx ON clinic.performed_services USING btree (organization_id, encounter_id);

CREATE INDEX performed_services_organization_id_invoice_id_fkey_idx ON clinic.performed_services USING btree (organization_id, invoice_id);

CREATE INDEX performed_services_organization_id_patient_id_fkey_idx ON clinic.performed_services USING btree (organization_id, patient_id);

CREATE INDEX performed_services_organization_id_service_id_fkey_idx ON clinic.performed_services USING btree (organization_id, service_id);

CREATE INDEX performed_unbilled ON clinic.performed_services USING btree (organization_id, created_at DESC, id DESC)
  WHERE (invoice_id IS NULL);

CREATE INDEX prescription_items_organization_id_encounter_id_fkey_idx ON clinic.prescription_items USING btree (organization_id, encounter_id);

CREATE INDEX procedures_organization_id_template_id_fkey_idx ON clinic.procedures USING btree (organization_id, template_id);

CREATE INDEX retention_rules_approved_by_fkey_idx ON clinic.retention_rules USING btree (approved_by);

CREATE INDEX role_revocations_organization_id_grant_id_fkey_idx ON clinic.role_revocations USING btree (organization_id, grant_id);

CREATE INDEX stock_lots_organization_id_product_id_fkey_idx ON clinic.stock_lots USING btree (organization_id, product_id);

CREATE TRIGGER audit_write
  AFTER INSERT OR UPDATE ON clinic.access_events
  FOR EACH ROW
  EXECUTE FUNCTION clinic.audit_write();

CREATE TRIGGER immutable_record
  BEFORE DELETE OR UPDATE ON clinic.access_events
  FOR EACH ROW
  EXECUTE FUNCTION clinic.immutable_record();

CREATE TRIGGER approved_mapping
  BEFORE DELETE OR UPDATE ON clinic.account_mappings
  FOR EACH ROW
  EXECUTE FUNCTION clinic.protect_mapping();

CREATE TRIGGER audit_write
  AFTER INSERT OR UPDATE ON clinic.account_mappings
  FOR EACH ROW
  EXECUTE FUNCTION clinic.audit_write();

CREATE TRIGGER audit_write
  AFTER INSERT OR UPDATE ON clinic.accounting_acknowledgements
  FOR EACH ROW
  EXECUTE FUNCTION clinic.audit_write();

CREATE TRIGGER immutable_record
  BEFORE DELETE OR UPDATE ON clinic.accounting_acknowledgements
  FOR EACH ROW
  EXECUTE FUNCTION clinic.immutable_record();

CREATE TRIGGER audit_write
  AFTER INSERT OR UPDATE ON clinic.accounting_batch_items
  FOR EACH ROW
  EXECUTE FUNCTION clinic.audit_write();

CREATE TRIGGER immutable_record
  BEFORE DELETE OR UPDATE ON clinic.accounting_batch_items
  FOR EACH ROW
  EXECUTE FUNCTION clinic.immutable_record();

CREATE TRIGGER audit_write
  AFTER INSERT OR UPDATE ON clinic.accounting_batches
  FOR EACH ROW
  EXECUTE FUNCTION clinic.audit_write();

CREATE TRIGGER immutable_record
  BEFORE DELETE OR UPDATE ON clinic.accounting_batches
  FOR EACH ROW
  EXECUTE FUNCTION clinic.immutable_record();

CREATE TRIGGER audit_write
  AFTER INSERT OR UPDATE ON clinic.accounting_periods
  FOR EACH ROW
  EXECUTE FUNCTION clinic.audit_write();

CREATE TRIGGER immutable_record
  BEFORE DELETE OR UPDATE ON clinic.accounting_periods
  FOR EACH ROW
  EXECUTE FUNCTION clinic.immutable_record();

CREATE TRIGGER audit_write
  AFTER INSERT OR UPDATE ON clinic.additional_roles
  FOR EACH ROW
  EXECUTE FUNCTION clinic.audit_write();

CREATE TRIGGER immutable_record
  BEFORE DELETE OR UPDATE ON clinic.additional_roles
  FOR EACH ROW
  EXECUTE FUNCTION clinic.immutable_record();

CREATE TRIGGER schedule_guard
  BEFORE INSERT OR UPDATE OF starts_at, ends_at, status, resource_id, doctor_id ON clinic.appointments
  FOR EACH ROW
  EXECUTE FUNCTION clinic.check_schedule();

CREATE TRIGGER audit_write
  AFTER INSERT OR UPDATE ON clinic.approval_limits
  FOR EACH ROW
  EXECUTE FUNCTION clinic.audit_write();

CREATE TRIGGER immutable_record
  BEFORE DELETE OR UPDATE ON clinic.approval_limits
  FOR EACH ROW
  EXECUTE FUNCTION clinic.immutable_record();

CREATE TRIGGER audit_write
  AFTER INSERT ON clinic.availability_cancellations
  FOR EACH ROW
  EXECUTE FUNCTION clinic.audit_write();

CREATE TRIGGER immutable_record
  BEFORE DELETE OR UPDATE ON clinic.availability_cancellations
  FOR EACH ROW
  EXECUTE FUNCTION clinic.immutable_record();

CREATE TRIGGER audit_write
  AFTER INSERT OR UPDATE ON clinic.bank_match_reversals
  FOR EACH ROW
  EXECUTE FUNCTION clinic.audit_write();

CREATE TRIGGER immutable_record
  BEFORE DELETE OR UPDATE ON clinic.bank_match_reversals
  FOR EACH ROW
  EXECUTE FUNCTION clinic.immutable_record();

CREATE TRIGGER audit_write
  AFTER INSERT OR UPDATE ON clinic.bank_matches
  FOR EACH ROW
  EXECUTE FUNCTION clinic.audit_write();

CREATE TRIGGER immutable_record
  BEFORE DELETE OR UPDATE ON clinic.bank_matches
  FOR EACH ROW
  EXECUTE FUNCTION clinic.immutable_record();

CREATE TRIGGER audit_write
  AFTER INSERT OR UPDATE ON clinic.bank_statement_lines
  FOR EACH ROW
  EXECUTE FUNCTION clinic.audit_write();

CREATE TRIGGER immutable_record
  BEFORE DELETE OR UPDATE ON clinic.bank_statement_lines
  FOR EACH ROW
  EXECUTE FUNCTION clinic.immutable_record();

CREATE TRIGGER audit_write
  AFTER INSERT OR UPDATE ON clinic.care_assignments
  FOR EACH ROW
  EXECUTE FUNCTION clinic.audit_write();

CREATE TRIGGER immutable_record
  BEFORE DELETE OR UPDATE ON clinic.care_assignments
  FOR EACH ROW
  EXECUTE FUNCTION clinic.immutable_record();

CREATE TRIGGER audit_write
  AFTER INSERT OR UPDATE ON clinic.care_revocations
  FOR EACH ROW
  EXECUTE FUNCTION clinic.audit_write();

CREATE TRIGGER immutable_record
  BEFORE DELETE OR UPDATE ON clinic.care_revocations
  FOR EACH ROW
  EXECUTE FUNCTION clinic.immutable_record();

CREATE TRIGGER audit_write
  AFTER INSERT OR UPDATE ON clinic.clinic_resources
  FOR EACH ROW
  EXECUTE FUNCTION clinic.audit_write();

CREATE TRIGGER audit_write
  AFTER INSERT OR UPDATE ON clinic.clinical_facts
  FOR EACH ROW
  EXECUTE FUNCTION clinic.audit_write();

CREATE TRIGGER immutable_record
  BEFORE DELETE OR UPDATE ON clinic.clinical_facts
  FOR EACH ROW
  EXECUTE FUNCTION clinic.immutable_record();

CREATE TRIGGER audit_write
  AFTER INSERT OR UPDATE ON clinic.clinician_availability
  FOR EACH ROW
  EXECUTE FUNCTION clinic.audit_write();

CREATE TRIGGER audit_write
  AFTER INSERT OR UPDATE ON clinic.contact_log
  FOR EACH ROW
  EXECUTE FUNCTION clinic.audit_write();

CREATE TRIGGER immutable_record
  BEFORE DELETE OR UPDATE ON clinic.contact_log
  FOR EACH ROW
  EXECUTE FUNCTION clinic.immutable_record();

CREATE TRIGGER audit_write
  AFTER INSERT OR UPDATE ON clinic.document_templates
  FOR EACH ROW
  EXECUTE FUNCTION clinic.audit_write();

CREATE TRIGGER template_immutable
  BEFORE DELETE OR UPDATE ON clinic.document_templates
  FOR EACH ROW
  EXECUTE FUNCTION clinic.protect_approved_template();

CREATE TRIGGER audit_write
  AFTER INSERT OR UPDATE ON clinic.hold_releases
  FOR EACH ROW
  EXECUTE FUNCTION clinic.audit_write();

CREATE TRIGGER immutable_record
  BEFORE DELETE OR UPDATE ON clinic.hold_releases
  FOR EACH ROW
  EXECUTE FUNCTION clinic.immutable_record();

CREATE TRIGGER audit_write
  AFTER INSERT OR UPDATE ON clinic.inventory_products
  FOR EACH ROW
  EXECUTE FUNCTION clinic.audit_write();

CREATE TRIGGER open_accounting_period
  BEFORE INSERT ON clinic.journals
  FOR EACH ROW
  EXECUTE FUNCTION clinic.check_open_period();

CREATE TRIGGER audit_write
  AFTER INSERT OR UPDATE ON clinic.legal_holds
  FOR EACH ROW
  EXECUTE FUNCTION clinic.audit_write();

CREATE TRIGGER immutable_record
  BEFORE DELETE OR UPDATE ON clinic.legal_holds
  FOR EACH ROW
  EXECUTE FUNCTION clinic.immutable_record();

CREATE TRIGGER rejection_time
  BEFORE UPDATE OF status ON clinic.media
  FOR EACH ROW
  EXECUTE FUNCTION clinic.media_rejection_time();

CREATE TRIGGER immutable_record
  BEFORE DELETE OR UPDATE ON clinic.media_cleanup_events
  FOR EACH ROW
  EXECUTE FUNCTION clinic.immutable_record();

CREATE TRIGGER audit_write
  AFTER INSERT OR UPDATE ON clinic.package_corrections
  FOR EACH ROW
  EXECUTE FUNCTION clinic.audit_write();

CREATE TRIGGER immutable_record
  BEFORE DELETE OR UPDATE ON clinic.package_corrections
  FOR EACH ROW
  EXECUTE FUNCTION clinic.immutable_record();

CREATE TRIGGER audit_write
  AFTER INSERT ON clinic.patient_documents
  FOR EACH ROW
  EXECUTE FUNCTION clinic.audit_write();

CREATE TRIGGER immutable_record
  BEFORE DELETE OR UPDATE ON clinic.patient_documents
  FOR EACH ROW
  EXECUTE FUNCTION clinic.immutable_record();

CREATE TRIGGER audit_write
  AFTER INSERT ON clinic.patient_exports
  FOR EACH ROW
  EXECUTE FUNCTION clinic.audit_write();

CREATE TRIGGER immutable_record
  BEFORE DELETE OR UPDATE ON clinic.patient_exports
  FOR EACH ROW
  EXECUTE FUNCTION clinic.immutable_record();

CREATE TRIGGER audit_write
  AFTER INSERT OR UPDATE ON clinic.performed_services
  FOR EACH ROW
  EXECUTE FUNCTION clinic.audit_write();

CREATE TRIGGER performed_identity
  BEFORE UPDATE ON clinic.performed_services
  FOR EACH ROW
  EXECUTE FUNCTION clinic.protect_performed_service();

CREATE TRIGGER audit_write
  AFTER INSERT OR UPDATE ON clinic.prescription_items
  FOR EACH ROW
  EXECUTE FUNCTION clinic.audit_write();

CREATE TRIGGER signed_prescription
  BEFORE INSERT OR DELETE OR UPDATE ON clinic.prescription_items
  FOR EACH ROW
  EXECUTE FUNCTION clinic.protect_prescription();

CREATE TRIGGER procedure_immutable
  BEFORE DELETE OR UPDATE ON clinic.procedures
  FOR EACH ROW
  EXECUTE FUNCTION clinic.immutable_record();

CREATE TRIGGER audit_write
  AFTER INSERT OR UPDATE ON clinic.retention_rules
  FOR EACH ROW
  EXECUTE FUNCTION clinic.audit_write();

CREATE TRIGGER retention_approval_lock
  BEFORE DELETE OR UPDATE ON clinic.retention_rules
  FOR EACH ROW
  EXECUTE FUNCTION clinic.protect_mapping();

CREATE TRIGGER audit_write
  AFTER INSERT OR UPDATE ON clinic.role_revocations
  FOR EACH ROW
  EXECUTE FUNCTION clinic.audit_write();

CREATE TRIGGER immutable_record
  BEFORE DELETE OR UPDATE ON clinic.role_revocations
  FOR EACH ROW
  EXECUTE FUNCTION clinic.immutable_record();

CREATE TRIGGER audit_write
  AFTER INSERT OR UPDATE ON clinic.suppliers
  FOR EACH ROW
  EXECUTE FUNCTION clinic.audit_write();

CREATE POLICY "administrative_scope" ON "clinic"."access_events"
  FOR ALL
  TO "authenticated"
  USING (((organization_id = ( SELECT clinic.org_id() AS org_id)) AND ( SELECT clinic.allowed('staff'::text) AS allowed)))
  WITH CHECK (((organization_id = ( SELECT clinic.org_id() AS org_id)) AND ( SELECT clinic.allowed('staff'::text) AS allowed)));

CREATE POLICY "accounting_scope" ON "clinic"."account_mappings"
  FOR ALL
  TO "authenticated"
  USING (((organization_id = ( SELECT clinic.org_id() AS org_id)) AND ( SELECT clinic.allowed('finance'::text) AS allowed)))
  WITH CHECK (((organization_id = ( SELECT clinic.org_id() AS org_id)) AND ( SELECT clinic.allowed('finance'::text) AS allowed)));

CREATE POLICY "accounting_scope" ON "clinic"."accounting_acknowledgements"
  FOR ALL
  TO "authenticated"
  USING (((organization_id = ( SELECT clinic.org_id() AS org_id)) AND ( SELECT clinic.allowed('finance'::text) AS allowed)))
  WITH CHECK (((organization_id = ( SELECT clinic.org_id() AS org_id)) AND ( SELECT clinic.allowed('finance'::text) AS allowed)));

CREATE POLICY "accounting_scope" ON "clinic"."accounting_batch_items"
  FOR ALL
  TO "authenticated"
  USING (((organization_id = ( SELECT clinic.org_id() AS org_id)) AND ( SELECT clinic.allowed('finance'::text) AS allowed)))
  WITH CHECK (((organization_id = ( SELECT clinic.org_id() AS org_id)) AND ( SELECT clinic.allowed('finance'::text) AS allowed)));

CREATE POLICY "accounting_scope" ON "clinic"."accounting_batches"
  FOR ALL
  TO "authenticated"
  USING (((organization_id = ( SELECT clinic.org_id() AS org_id)) AND ( SELECT clinic.allowed('finance'::text) AS allowed)))
  WITH CHECK (((organization_id = ( SELECT clinic.org_id() AS org_id)) AND ( SELECT clinic.allowed('finance'::text) AS allowed)));

CREATE POLICY "accounting_scope" ON "clinic"."accounting_periods"
  FOR ALL
  TO "authenticated"
  USING (((organization_id = ( SELECT clinic.org_id() AS org_id)) AND ( SELECT clinic.allowed('finance'::text) AS allowed)))
  WITH CHECK (((organization_id = ( SELECT clinic.org_id() AS org_id)) AND ( SELECT clinic.allowed('finance'::text) AS allowed)));

CREATE POLICY "care_scope_guard" ON "clinic"."addenda"
  AS RESTRICTIVE
  FOR ALL
  TO "authenticated"
  USING ((( SELECT clinic.organization_care_access() AS organization_care_access) OR clinic.encounter_care_access(encounter_id)))
  WITH CHECK ((( SELECT clinic.organization_care_access() AS organization_care_access) OR clinic.encounter_care_access(encounter_id)));

CREATE POLICY "scoped_insert" ON "clinic"."addenda"
  FOR INSERT
  TO "authenticated"
  WITH CHECK (((organization_id = ( SELECT clinic.org_id() AS org_id)) AND ( SELECT clinic.allowed('clinical'::text) AS allowed)));

CREATE POLICY "scoped_read" ON "clinic"."addenda"
  FOR SELECT
  TO "authenticated"
  USING (((organization_id = ( SELECT clinic.org_id() AS org_id)) AND ( SELECT clinic.allowed('clinical'::text) AS allowed)));

CREATE POLICY "scoped_update" ON "clinic"."addenda"
  FOR UPDATE
  TO "authenticated"
  USING (((organization_id = ( SELECT clinic.org_id() AS org_id)) AND ( SELECT clinic.allowed('clinical'::text) AS allowed)))
  WITH CHECK (((organization_id = ( SELECT clinic.org_id() AS org_id)) AND ( SELECT clinic.allowed('clinical'::text) AS allowed)));

CREATE POLICY "administrative_scope" ON "clinic"."additional_roles"
  FOR ALL
  TO "authenticated"
  USING (((organization_id = ( SELECT clinic.org_id() AS org_id)) AND ( SELECT clinic.allowed('staff'::text) AS allowed)))
  WITH CHECK (((organization_id = ( SELECT clinic.org_id() AS org_id)) AND ( SELECT clinic.allowed('staff'::text) AS allowed)));

CREATE POLICY "scoped_insert" ON "clinic"."appointments"
  FOR INSERT
  TO "authenticated"
  WITH CHECK (((organization_id = ( SELECT clinic.org_id() AS org_id)) AND ( SELECT clinic.allowed('schedule'::text) AS allowed)));

CREATE POLICY "scoped_read" ON "clinic"."appointments"
  FOR SELECT
  TO "authenticated"
  USING (((organization_id = ( SELECT clinic.org_id() AS org_id)) AND ( SELECT clinic.allowed('schedule'::text) AS allowed)));

CREATE POLICY "scoped_update" ON "clinic"."appointments"
  FOR UPDATE
  TO "authenticated"
  USING (((organization_id = ( SELECT clinic.org_id() AS org_id)) AND ( SELECT clinic.allowed('schedule'::text) AS allowed)))
  WITH CHECK (((organization_id = ( SELECT clinic.org_id() AS org_id)) AND ( SELECT clinic.allowed('schedule'::text) AS allowed)));

CREATE POLICY "administrative_scope" ON "clinic"."approval_limits"
  FOR ALL
  TO "authenticated"
  USING (((organization_id = ( SELECT clinic.org_id() AS org_id)) AND ( SELECT clinic.allowed('staff'::text) AS allowed)))
  WITH CHECK (((organization_id = ( SELECT clinic.org_id() AS org_id)) AND ( SELECT clinic.allowed('staff'::text) AS allowed)));

CREATE POLICY "audit_read" ON "clinic"."audit_events"
  FOR SELECT
  TO "authenticated"
  USING (((organization_id = ( SELECT clinic.org_id() AS org_id)) AND ( SELECT clinic.allowed('audit'::text) AS allowed)));

CREATE POLICY "schedule_cancellation_insert" ON "clinic"."availability_cancellations"
  FOR INSERT
  TO "authenticated"
  WITH CHECK (((organization_id = ( SELECT clinic.org_id() AS org_id)) AND ( SELECT clinic.allowed('schedule'::text) AS allowed)));

CREATE POLICY "schedule_cancellation_read" ON "clinic"."availability_cancellations"
  FOR SELECT
  TO "authenticated"
  USING (((organization_id = ( SELECT clinic.org_id() AS org_id)) AND ( SELECT clinic.allowed('schedule'::text) AS allowed)));

CREATE POLICY "accounting_scope" ON "clinic"."bank_match_reversals"
  FOR ALL
  TO "authenticated"
  USING (((organization_id = ( SELECT clinic.org_id() AS org_id)) AND ( SELECT clinic.allowed('finance'::text) AS allowed)))
  WITH CHECK (((organization_id = ( SELECT clinic.org_id() AS org_id)) AND ( SELECT clinic.allowed('finance'::text) AS allowed)));

CREATE POLICY "accounting_scope" ON "clinic"."bank_matches"
  FOR ALL
  TO "authenticated"
  USING (((organization_id = ( SELECT clinic.org_id() AS org_id)) AND ( SELECT clinic.allowed('finance'::text) AS allowed)))
  WITH CHECK (((organization_id = ( SELECT clinic.org_id() AS org_id)) AND ( SELECT clinic.allowed('finance'::text) AS allowed)));

CREATE POLICY "accounting_scope" ON "clinic"."bank_statement_lines"
  FOR ALL
  TO "authenticated"
  USING (((organization_id = ( SELECT clinic.org_id() AS org_id)) AND ( SELECT clinic.allowed('finance'::text) AS allowed)))
  WITH CHECK (((organization_id = ( SELECT clinic.org_id() AS org_id)) AND ( SELECT clinic.allowed('finance'::text) AS allowed)));

CREATE POLICY "branch_read" ON "clinic"."branches"
  FOR SELECT
  TO "authenticated"
  USING ((organization_id = ( SELECT clinic.org_id() AS org_id)));

CREATE POLICY "administrative_scope" ON "clinic"."care_assignments"
  FOR ALL
  TO "authenticated"
  USING (((organization_id = ( SELECT clinic.org_id() AS org_id)) AND ( SELECT clinic.allowed('staff'::text) AS allowed)))
  WITH CHECK (((organization_id = ( SELECT clinic.org_id() AS org_id)) AND ( SELECT clinic.allowed('staff'::text) AS allowed)));

CREATE POLICY "administrative_scope" ON "clinic"."care_revocations"
  FOR ALL
  TO "authenticated"
  USING (((organization_id = ( SELECT clinic.org_id() AS org_id)) AND ( SELECT clinic.allowed('staff'::text) AS allowed)))
  WITH CHECK (((organization_id = ( SELECT clinic.org_id() AS org_id)) AND ( SELECT clinic.allowed('staff'::text) AS allowed)));

CREATE POLICY "scoped_insert" ON "clinic"."cash_movements"
  FOR INSERT
  TO "authenticated"
  WITH CHECK (((organization_id = ( SELECT clinic.org_id() AS org_id)) AND ( SELECT clinic.allowed('finance'::text) AS allowed)));

CREATE POLICY "scoped_read" ON "clinic"."cash_movements"
  FOR SELECT
  TO "authenticated"
  USING (((organization_id = ( SELECT clinic.org_id() AS org_id)) AND ( SELECT clinic.allowed('finance'::text) AS allowed)));

CREATE POLICY "scoped_update" ON "clinic"."cash_movements"
  FOR UPDATE
  TO "authenticated"
  USING (((organization_id = ( SELECT clinic.org_id() AS org_id)) AND ( SELECT clinic.allowed('finance'::text) AS allowed)))
  WITH CHECK (((organization_id = ( SELECT clinic.org_id() AS org_id)) AND ( SELECT clinic.allowed('finance'::text) AS allowed)));

CREATE POLICY "scoped_access" ON "clinic"."clinic_resources"
  FOR ALL
  TO "authenticated"
  USING (((organization_id = ( SELECT clinic.org_id() AS org_id)) AND ( SELECT clinic.allowed('schedule'::text) AS allowed)))
  WITH CHECK (((organization_id = ( SELECT clinic.org_id() AS org_id)) AND ( SELECT clinic.allowed('schedule'::text) AS allowed)));

CREATE POLICY "care_scope_guard" ON "clinic"."clinical_facts"
  AS RESTRICTIVE
  FOR ALL
  TO "authenticated"
  USING ((( SELECT clinic.organization_care_access() AS organization_care_access) OR clinic.patient_care_access(patient_id)))
  WITH CHECK ((( SELECT clinic.organization_care_access() AS organization_care_access) OR clinic.patient_care_access(patient_id)));

CREATE POLICY "scoped_access" ON "clinic"."clinical_facts"
  FOR ALL
  TO "authenticated"
  USING (((organization_id = ( SELECT clinic.org_id() AS org_id)) AND ( SELECT clinic.allowed('clinical'::text) AS allowed)))
  WITH CHECK (((organization_id = ( SELECT clinic.org_id() AS org_id)) AND ( SELECT clinic.allowed('clinical'::text) AS allowed)));

CREATE POLICY "scoped_access" ON "clinic"."clinician_availability"
  FOR ALL
  TO "authenticated"
  USING (((organization_id = ( SELECT clinic.org_id() AS org_id)) AND ( SELECT clinic.allowed('schedule'::text) AS allowed)))
  WITH CHECK (((organization_id = ( SELECT clinic.org_id() AS org_id)) AND ( SELECT clinic.allowed('schedule'::text) AS allowed)));

CREATE POLICY "consent_care_guard" ON "clinic"."consents"
  AS RESTRICTIVE
  FOR ALL
  TO "authenticated"
  USING (((purpose = 'communication'::text) OR ( SELECT clinic.organization_care_access() AS organization_care_access) OR clinic.patient_care_access(patient_id)))
  WITH CHECK (((purpose = 'communication'::text) OR ( SELECT clinic.organization_care_access() AS organization_care_access) OR clinic.patient_care_access(patient_id)));

CREATE POLICY "scoped_insert" ON "clinic"."consents"
  FOR INSERT
  TO "authenticated"
  WITH
    CHECK
    (((organization_id = ( SELECT clinic.org_id() AS org_id)) AND (( SELECT clinic.allowed('clinical'::text) AS allowed) OR ( SELECT clinic.allowed('patients'::text) AS allowed))));

CREATE POLICY "scoped_read" ON "clinic"."consents"
  FOR SELECT
  TO "authenticated"
  USING (((organization_id = ( SELECT clinic.org_id() AS org_id)) AND ( SELECT clinic.allowed('clinical'::text) AS allowed)));

CREATE POLICY "scoped_update" ON "clinic"."consents"
  FOR UPDATE
  TO "authenticated"
  USING (((organization_id = ( SELECT clinic.org_id() AS org_id)) AND ( SELECT clinic.allowed('clinical'::text) AS allowed)))
  WITH CHECK (((organization_id = ( SELECT clinic.org_id() AS org_id)) AND ( SELECT clinic.allowed('clinical'::text) AS allowed)));

CREATE POLICY "scoped_access" ON "clinic"."contact_log"
  FOR ALL
  TO "authenticated"
  USING (((organization_id = ( SELECT clinic.org_id() AS org_id)) AND ( SELECT clinic.allowed('patients'::text) AS allowed)))
  WITH CHECK (((organization_id = ( SELECT clinic.org_id() AS org_id)) AND ( SELECT clinic.allowed('patients'::text) AS allowed)));

CREATE POLICY "scoped_insert" ON "clinic"."contacts"
  FOR INSERT
  TO "authenticated"
  WITH CHECK (((organization_id = ( SELECT clinic.org_id() AS org_id)) AND ( SELECT clinic.allowed('patients'::text) AS allowed)));

CREATE POLICY "scoped_read" ON "clinic"."contacts"
  FOR SELECT
  TO "authenticated"
  USING (((organization_id = ( SELECT clinic.org_id() AS org_id)) AND ( SELECT clinic.allowed('patients'::text) AS allowed)));

CREATE POLICY "scoped_update" ON "clinic"."contacts"
  FOR UPDATE
  TO "authenticated"
  USING (((organization_id = ( SELECT clinic.org_id() AS org_id)) AND ( SELECT clinic.allowed('patients'::text) AS allowed)))
  WITH CHECK (((organization_id = ( SELECT clinic.org_id() AS org_id)) AND ( SELECT clinic.allowed('patients'::text) AS allowed)));

CREATE POLICY "scoped_insert" ON "clinic"."credit_notes"
  FOR INSERT
  TO "authenticated"
  WITH
    CHECK
    (((organization_id = ( SELECT clinic.org_id() AS org_id)) AND (( SELECT clinic.allowed('billing'::text) AS allowed) OR ( SELECT clinic.allowed('approve'::text) AS allowed))));

CREATE POLICY "scoped_read" ON "clinic"."credit_notes"
  FOR SELECT
  TO "authenticated"
  USING
    (((organization_id = ( SELECT clinic.org_id() AS org_id)) AND (( SELECT clinic.allowed('billing'::text) AS allowed) OR ( SELECT clinic.allowed('finance'::text) AS allowed) OR (
    SELECT clinic.allowed('billing'::text) AS allowed))));

CREATE POLICY "scoped_update" ON "clinic"."credit_notes"
  FOR UPDATE
  TO "authenticated"
  USING (((organization_id = ( SELECT clinic.org_id() AS org_id)) AND ( SELECT clinic.allowed('billing'::text) AS allowed)))
  WITH CHECK (((organization_id = ( SELECT clinic.org_id() AS org_id)) AND ( SELECT clinic.allowed('billing'::text) AS allowed)));

CREATE POLICY "template_insert" ON "clinic"."document_templates"
  FOR INSERT
  TO "authenticated"
  WITH CHECK (((organization_id = ( SELECT clinic.org_id() AS org_id)) AND ( SELECT clinic.allowed('clinical'::text) AS allowed)));

CREATE POLICY "template_read" ON "clinic"."document_templates"
  FOR SELECT
  TO "authenticated"
  USING
    (((organization_id = ( SELECT clinic.org_id() AS org_id)) AND (( SELECT clinic.allowed('clinical'::text) AS allowed) OR ((status = 'approved'::text) AND (kind = ANY
    (ARRAY['consent'::text, 'aftercare'::text, 'referral'::text])) AND ( SELECT clinic.allowed('patients'::text) AS allowed)))));

CREATE POLICY "template_update" ON "clinic"."document_templates"
  FOR UPDATE
  TO "authenticated"
  USING (((organization_id = ( SELECT clinic.org_id() AS org_id)) AND ( SELECT clinic.allowed('clinical'::text) AS allowed)))
  WITH CHECK (((organization_id = ( SELECT clinic.org_id() AS org_id)) AND ( SELECT clinic.allowed('clinical'::text) AS allowed)));

CREATE POLICY "care_scope_guard" ON "clinic"."encounters"
  AS RESTRICTIVE
  FOR ALL
  TO "authenticated"
  USING ((( SELECT clinic.organization_care_access() AS organization_care_access) OR clinic.patient_care_access(patient_id)))
  WITH CHECK ((( SELECT clinic.organization_care_access() AS organization_care_access) OR clinic.patient_care_access(patient_id)));

CREATE POLICY "scoped_insert" ON "clinic"."encounters"
  FOR INSERT
  TO "authenticated"
  WITH CHECK (((organization_id = ( SELECT clinic.org_id() AS org_id)) AND ( SELECT clinic.allowed('clinical'::text) AS allowed)));

CREATE POLICY "scoped_read" ON "clinic"."encounters"
  FOR SELECT
  TO "authenticated"
  USING (((organization_id = ( SELECT clinic.org_id() AS org_id)) AND ( SELECT clinic.allowed('clinical'::text) AS allowed)));

CREATE POLICY "scoped_update" ON "clinic"."encounters"
  FOR UPDATE
  TO "authenticated"
  USING (((organization_id = ( SELECT clinic.org_id() AS org_id)) AND ( SELECT clinic.allowed('clinical'::text) AS allowed)))
  WITH CHECK (((organization_id = ( SELECT clinic.org_id() AS org_id)) AND ( SELECT clinic.allowed('clinical'::text) AS allowed)));

CREATE POLICY "scoped_insert" ON "clinic"."expenses"
  FOR INSERT
  TO "authenticated"
  WITH CHECK (((organization_id = ( SELECT clinic.org_id() AS org_id)) AND ( SELECT clinic.allowed('finance'::text) AS allowed)));

CREATE POLICY "scoped_read" ON "clinic"."expenses"
  FOR SELECT
  TO "authenticated"
  USING
    (((organization_id = ( SELECT clinic.org_id() AS org_id)) AND ( SELECT clinic.allowed('finance'::text) AS allowed) AND ((category <> 'salary'::text) OR ( SELECT
    clinic.allowed('payroll'::text) AS allowed))));

CREATE POLICY "scoped_update" ON "clinic"."expenses"
  FOR UPDATE
  TO "authenticated"
  USING (((organization_id = ( SELECT clinic.org_id() AS org_id)) AND ( SELECT clinic.allowed('finance'::text) AS allowed)))
  WITH CHECK (((organization_id = ( SELECT clinic.org_id() AS org_id)) AND ( SELECT clinic.allowed('finance'::text) AS allowed)));

CREATE POLICY "administrative_scope" ON "clinic"."hold_releases"
  FOR ALL
  TO "authenticated"
  USING (((organization_id = ( SELECT clinic.org_id() AS org_id)) AND ( SELECT clinic.allowed('staff'::text) AS allowed)))
  WITH CHECK (((organization_id = ( SELECT clinic.org_id() AS org_id)) AND ( SELECT clinic.allowed('staff'::text) AS allowed)));

CREATE POLICY "product_insert" ON "clinic"."inventory_products"
  FOR INSERT
  TO "authenticated"
  WITH CHECK (((organization_id = ( SELECT clinic.org_id() AS org_id)) AND ( SELECT clinic.allowed('inventory'::text) AS allowed)));

CREATE POLICY "product_read" ON "clinic"."inventory_products"
  FOR SELECT
  TO "authenticated"
  USING
    (((organization_id = ( SELECT clinic.org_id() AS org_id)) AND (( SELECT clinic.allowed('inventory'::text) AS allowed) OR ( SELECT clinic.allowed('inventory.read'::text) AS
    allowed) OR ( SELECT clinic.allowed('finance'::text) AS allowed))));

CREATE POLICY "product_update" ON "clinic"."inventory_products"
  FOR UPDATE
  TO "authenticated"
  USING (((organization_id = ( SELECT clinic.org_id() AS org_id)) AND ( SELECT clinic.allowed('inventory'::text) AS allowed)))
  WITH CHECK (((organization_id = ( SELECT clinic.org_id() AS org_id)) AND ( SELECT clinic.allowed('inventory'::text) AS allowed)));

CREATE POLICY "scoped_insert" ON "clinic"."invoices"
  FOR INSERT
  TO "authenticated"
  WITH CHECK (((organization_id = ( SELECT clinic.org_id() AS org_id)) AND ( SELECT clinic.allowed('billing'::text) AS allowed)));

CREATE POLICY "scoped_read" ON "clinic"."invoices"
  FOR SELECT
  TO "authenticated"
  USING
    (((organization_id = ( SELECT clinic.org_id() AS org_id)) AND (( SELECT clinic.allowed('billing'::text) AS allowed) OR ( SELECT clinic.allowed('finance'::text) AS allowed) OR (
    SELECT clinic.allowed('billing'::text) AS allowed))));

CREATE POLICY "scoped_update" ON "clinic"."invoices"
  FOR UPDATE
  TO "authenticated"
  USING (((organization_id = ( SELECT clinic.org_id() AS org_id)) AND ( SELECT clinic.allowed('billing'::text) AS allowed)))
  WITH CHECK (((organization_id = ( SELECT clinic.org_id() AS org_id)) AND ( SELECT clinic.allowed('billing'::text) AS allowed)));

CREATE POLICY "scoped_insert" ON "clinic"."journal_lines"
  FOR INSERT
  TO "authenticated"
  WITH
    CHECK
    (((organization_id = ( SELECT clinic.org_id() AS org_id)) AND (( SELECT clinic.allowed('finance'::text) AS allowed) OR ( SELECT clinic.allowed('billing'::text) AS allowed) OR (
    SELECT clinic.allowed('clinical'::text) AS allowed))));

CREATE POLICY "scoped_read" ON "clinic"."journal_lines"
  FOR SELECT
  TO "authenticated"
  USING
    (((organization_id = ( SELECT clinic.org_id() AS org_id)) AND (( SELECT clinic.allowed('finance'::text) AS allowed) OR ( SELECT clinic.allowed('finance'::text) AS allowed) OR (
    SELECT clinic.allowed('billing'::text) AS allowed))));

CREATE POLICY "scoped_update" ON "clinic"."journal_lines"
  FOR UPDATE
  TO "authenticated"
  USING (((organization_id = ( SELECT clinic.org_id() AS org_id)) AND ( SELECT clinic.allowed('finance'::text) AS allowed)))
  WITH CHECK (((organization_id = ( SELECT clinic.org_id() AS org_id)) AND ( SELECT clinic.allowed('finance'::text) AS allowed)));

CREATE POLICY "scoped_insert" ON "clinic"."journals"
  FOR INSERT
  TO "authenticated"
  WITH
    CHECK
    (((organization_id = ( SELECT clinic.org_id() AS org_id)) AND (( SELECT clinic.allowed('finance'::text) AS allowed) OR ( SELECT clinic.allowed('billing'::text) AS allowed) OR (
    SELECT clinic.allowed('clinical'::text) AS allowed))));

CREATE POLICY "scoped_read" ON "clinic"."journals"
  FOR SELECT
  TO "authenticated"
  USING
    (((organization_id = ( SELECT clinic.org_id() AS org_id)) AND (( SELECT clinic.allowed('finance'::text) AS allowed) OR ( SELECT clinic.allowed('finance'::text) AS allowed) OR (
    SELECT clinic.allowed('billing'::text) AS allowed))));

CREATE POLICY "scoped_update" ON "clinic"."journals"
  FOR UPDATE
  TO "authenticated"
  USING (((organization_id = ( SELECT clinic.org_id() AS org_id)) AND ( SELECT clinic.allowed('finance'::text) AS allowed)))
  WITH CHECK (((organization_id = ( SELECT clinic.org_id() AS org_id)) AND ( SELECT clinic.allowed('finance'::text) AS allowed)));

CREATE POLICY "administrative_scope" ON "clinic"."legal_holds"
  FOR ALL
  TO "authenticated"
  USING (((organization_id = ( SELECT clinic.org_id() AS org_id)) AND ( SELECT clinic.allowed('staff'::text) AS allowed)))
  WITH CHECK (((organization_id = ( SELECT clinic.org_id() AS org_id)) AND ( SELECT clinic.allowed('staff'::text) AS allowed)));

CREATE POLICY "care_scope_guard" ON "clinic"."media"
  AS RESTRICTIVE
  FOR ALL
  TO "authenticated"
  USING ((( SELECT clinic.organization_care_access() AS organization_care_access) OR clinic.patient_care_access(patient_id)))
  WITH CHECK ((( SELECT clinic.organization_care_access() AS organization_care_access) OR clinic.patient_care_access(patient_id)));

CREATE POLICY "scoped_insert" ON "clinic"."media"
  FOR INSERT
  TO "authenticated"
  WITH CHECK (((organization_id = ( SELECT clinic.org_id() AS org_id)) AND ( SELECT clinic.allowed('media'::text) AS allowed)));

CREATE POLICY "scoped_read" ON "clinic"."media"
  FOR SELECT
  TO "authenticated"
  USING (((organization_id = ( SELECT clinic.org_id() AS org_id)) AND ( SELECT clinic.allowed('media'::text) AS allowed)));

CREATE POLICY "scoped_update" ON "clinic"."media"
  FOR UPDATE
  TO "authenticated"
  USING (((organization_id = ( SELECT clinic.org_id() AS org_id)) AND ( SELECT clinic.allowed('media'::text) AS allowed)))
  WITH CHECK (((organization_id = ( SELECT clinic.org_id() AS org_id)) AND ( SELECT clinic.allowed('media'::text) AS allowed)));

CREATE POLICY "membership_read" ON "clinic"."memberships"
  FOR SELECT
  TO "authenticated"
  USING ((organization_id = ( SELECT clinic.org_id() AS org_id)));

CREATE POLICY "membership_update" ON "clinic"."memberships"
  FOR UPDATE
  TO "authenticated"
  USING (((organization_id = ( SELECT clinic.org_id() AS org_id)) AND ( SELECT clinic.allowed('staff'::text) AS allowed) AND (user_id <> ( SELECT auth.uid() AS uid))))
  WITH CHECK (((organization_id = ( SELECT clinic.org_id() AS org_id)) AND ( SELECT clinic.allowed('staff'::text) AS allowed) AND (user_id <> ( SELECT auth.uid() AS uid))));

CREATE POLICY "organization_read" ON "clinic"."organizations"
  FOR SELECT
  TO "authenticated"
  USING ((id = ( SELECT clinic.org_id() AS org_id)));

CREATE POLICY "organization_update" ON "clinic"."organizations"
  FOR UPDATE
  TO "authenticated"
  USING (((id = ( SELECT clinic.org_id() AS org_id)) AND ( SELECT clinic.allowed('settings'::text) AS allowed)))
  WITH CHECK (((id = ( SELECT clinic.org_id() AS org_id)) AND ( SELECT clinic.allowed('settings'::text) AS allowed)));

CREATE POLICY "correction_insert" ON "clinic"."package_corrections"
  FOR INSERT
  TO "authenticated"
  WITH CHECK (((organization_id = ( SELECT clinic.org_id() AS org_id)) AND ( SELECT clinic.allowed('approve'::text) AS allowed)));

CREATE POLICY "correction_read" ON "clinic"."package_corrections"
  FOR SELECT
  TO "authenticated"
  USING
    (((organization_id = ( SELECT clinic.org_id() AS org_id)) AND (( SELECT clinic.allowed('billing'::text) AS allowed) OR ( SELECT clinic.allowed('finance'::text) AS allowed))));

CREATE POLICY "scoped_insert" ON "clinic"."package_redemptions"
  FOR INSERT
  TO "authenticated"
  WITH CHECK (((organization_id = ( SELECT clinic.org_id() AS org_id)) AND ( SELECT clinic.allowed('billing'::text) AS allowed)));

CREATE POLICY "scoped_read" ON "clinic"."package_redemptions"
  FOR SELECT
  TO "authenticated"
  USING (((organization_id = ( SELECT clinic.org_id() AS org_id)) AND ( SELECT clinic.allowed('billing'::text) AS allowed)));

CREATE POLICY "scoped_update" ON "clinic"."package_redemptions"
  FOR UPDATE
  TO "authenticated"
  USING (((organization_id = ( SELECT clinic.org_id() AS org_id)) AND ( SELECT clinic.allowed('clinical'::text) AS allowed)))
  WITH CHECK (((organization_id = ( SELECT clinic.org_id() AS org_id)) AND ( SELECT clinic.allowed('clinical'::text) AS allowed)));

CREATE POLICY "scoped_insert" ON "clinic"."packages"
  FOR INSERT
  TO "authenticated"
  WITH CHECK (((organization_id = ( SELECT clinic.org_id() AS org_id)) AND ( SELECT clinic.allowed('billing'::text) AS allowed)));

CREATE POLICY "scoped_read" ON "clinic"."packages"
  FOR SELECT
  TO "authenticated"
  USING
    (((organization_id = ( SELECT clinic.org_id() AS org_id)) AND (( SELECT clinic.allowed('billing'::text) AS allowed) OR ( SELECT clinic.allowed('clinical'::text) AS allowed) OR
    ( SELECT clinic.allowed('finance'::text) AS allowed))));

CREATE POLICY "scoped_update" ON "clinic"."packages"
  FOR UPDATE
  TO "authenticated"
  USING (((organization_id = ( SELECT clinic.org_id() AS org_id)) AND ( SELECT clinic.allowed('billing'::text) AS allowed)))
  WITH CHECK (((organization_id = ( SELECT clinic.org_id() AS org_id)) AND ( SELECT clinic.allowed('billing'::text) AS allowed)));

CREATE POLICY "clinical_document_scope" ON "clinic"."patient_documents"
  FOR ALL
  TO "authenticated"
  USING
    (((organization_id = ( SELECT clinic.org_id() AS org_id)) AND (( SELECT clinic.organization_care_access() AS organization_care_access) OR
    clinic.patient_care_access(patient_id))))
  WITH
    CHECK
    (((organization_id = ( SELECT clinic.org_id() AS org_id)) AND (( SELECT clinic.organization_care_access() AS organization_care_access) OR
    clinic.patient_care_access(patient_id))));

CREATE POLICY "insert_scope" ON "clinic"."patient_merges"
  FOR INSERT
  TO "authenticated"
  WITH CHECK (((organization_id = ( SELECT clinic.org_id() AS org_id)) AND ( SELECT clinic.allowed('approve'::text) AS allowed)));

CREATE POLICY "scope" ON "clinic"."patient_merges"
  FOR SELECT
  TO "authenticated"
  USING (((organization_id = ( SELECT clinic.org_id() AS org_id)) AND ( SELECT clinic.allowed('patients'::text) AS allowed)));

CREATE POLICY "scoped_insert" ON "clinic"."patients"
  FOR INSERT
  TO "authenticated"
  WITH CHECK (((organization_id = ( SELECT clinic.org_id() AS org_id)) AND ( SELECT clinic.allowed('patients'::text) AS allowed)));

CREATE POLICY "scoped_read" ON "clinic"."patients"
  FOR SELECT
  TO "authenticated"
  USING (((organization_id = ( SELECT clinic.org_id() AS org_id)) AND ( SELECT clinic.allowed('patients'::text) AS allowed)));

CREATE POLICY "scoped_update" ON "clinic"."patients"
  FOR UPDATE
  TO "authenticated"
  USING (((organization_id = ( SELECT clinic.org_id() AS org_id)) AND ( SELECT clinic.allowed('patients'::text) AS allowed)))
  WITH CHECK (((organization_id = ( SELECT clinic.org_id() AS org_id)) AND ( SELECT clinic.allowed('patients'::text) AS allowed)));

CREATE POLICY "scoped_insert" ON "clinic"."payments"
  FOR INSERT
  TO "authenticated"
  WITH
    CHECK
    (((organization_id = ( SELECT clinic.org_id() AS org_id)) AND (( SELECT clinic.allowed('billing'::text) AS allowed) OR ( SELECT clinic.allowed('approve'::text) AS allowed))));

CREATE POLICY "scoped_read" ON "clinic"."payments"
  FOR SELECT
  TO "authenticated"
  USING
    (((organization_id = ( SELECT clinic.org_id() AS org_id)) AND (( SELECT clinic.allowed('billing'::text) AS allowed) OR ( SELECT clinic.allowed('finance'::text) AS allowed) OR (
    SELECT clinic.allowed('billing'::text) AS allowed))));

CREATE POLICY "scoped_update" ON "clinic"."payments"
  FOR UPDATE
  TO "authenticated"
  USING (((organization_id = ( SELECT clinic.org_id() AS org_id)) AND ( SELECT clinic.allowed('billing'::text) AS allowed)))
  WITH CHECK (((organization_id = ( SELECT clinic.org_id() AS org_id)) AND ( SELECT clinic.allowed('billing'::text) AS allowed)));

CREATE POLICY "performed_care_guard" ON "clinic"."performed_services"
  AS RESTRICTIVE
  FOR ALL
  TO "authenticated"
  USING
    ((( SELECT clinic.allowed('billing'::text) AS allowed) OR ( SELECT clinic.organization_care_access() AS organization_care_access) OR clinic.patient_care_access(patient_id)))
  WITH
    CHECK
    ((( SELECT clinic.allowed('billing'::text) AS allowed) OR ( SELECT clinic.organization_care_access() AS organization_care_access) OR clinic.patient_care_access(patient_id)));

CREATE POLICY "performed_insert" ON "clinic"."performed_services"
  FOR INSERT
  TO "authenticated"
  WITH CHECK (((organization_id = ( SELECT clinic.org_id() AS org_id)) AND ( SELECT clinic.allowed('clinical'::text) AS allowed)));

CREATE POLICY "performed_invoice" ON "clinic"."performed_services"
  FOR UPDATE
  TO "authenticated"
  USING (((organization_id = ( SELECT clinic.org_id() AS org_id)) AND ( SELECT clinic.allowed('billing'::text) AS allowed)))
  WITH CHECK (((organization_id = ( SELECT clinic.org_id() AS org_id)) AND ( SELECT clinic.allowed('billing'::text) AS allowed)));

CREATE POLICY "performed_read" ON "clinic"."performed_services"
  FOR SELECT
  TO "authenticated"
  USING
    (((organization_id = ( SELECT clinic.org_id() AS org_id)) AND (( SELECT clinic.allowed('clinical'::text) AS allowed) OR ( SELECT clinic.allowed('billing'::text) AS allowed))));

CREATE POLICY "care_scope_guard" ON "clinic"."prescription_items"
  AS RESTRICTIVE
  FOR ALL
  TO "authenticated"
  USING ((( SELECT clinic.organization_care_access() AS organization_care_access) OR clinic.encounter_care_access(encounter_id)))
  WITH CHECK ((( SELECT clinic.organization_care_access() AS organization_care_access) OR clinic.encounter_care_access(encounter_id)));

CREATE POLICY "scoped_access" ON "clinic"."prescription_items"
  FOR ALL
  TO "authenticated"
  USING (((organization_id = ( SELECT clinic.org_id() AS org_id)) AND ( SELECT clinic.allowed('clinical'::text) AS allowed)))
  WITH CHECK (((organization_id = ( SELECT clinic.org_id() AS org_id)) AND ( SELECT clinic.allowed('clinical'::text) AS allowed)));

CREATE POLICY "care_scope_guard" ON "clinic"."procedures"
  AS RESTRICTIVE
  FOR ALL
  TO "authenticated"
  USING ((( SELECT clinic.organization_care_access() AS organization_care_access) OR clinic.patient_care_access(patient_id)))
  WITH CHECK ((( SELECT clinic.organization_care_access() AS organization_care_access) OR clinic.patient_care_access(patient_id)));

CREATE POLICY "scoped_insert" ON "clinic"."procedures"
  FOR INSERT
  TO "authenticated"
  WITH CHECK (((organization_id = ( SELECT clinic.org_id() AS org_id)) AND ( SELECT clinic.allowed('clinical'::text) AS allowed)));

CREATE POLICY "scoped_read" ON "clinic"."procedures"
  FOR SELECT
  TO "authenticated"
  USING (((organization_id = ( SELECT clinic.org_id() AS org_id)) AND ( SELECT clinic.allowed('clinical'::text) AS allowed)));

CREATE POLICY "scoped_update" ON "clinic"."procedures"
  FOR UPDATE
  TO "authenticated"
  USING (((organization_id = ( SELECT clinic.org_id() AS org_id)) AND ( SELECT clinic.allowed('clinical'::text) AS allowed)))
  WITH CHECK (((organization_id = ( SELECT clinic.org_id() AS org_id)) AND ( SELECT clinic.allowed('clinical'::text) AS allowed)));

CREATE POLICY "request_insert" ON "clinic"."requests"
  FOR INSERT
  TO "authenticated"
  WITH CHECK (((organization_id = ( SELECT clinic.org_id() AS org_id)) AND (actor_id = ( SELECT auth.uid() AS uid))));

CREATE POLICY "request_read" ON "clinic"."requests"
  FOR SELECT
  TO "authenticated"
  USING (((organization_id = ( SELECT clinic.org_id() AS org_id)) AND (actor_id = ( SELECT auth.uid() AS uid))));

CREATE POLICY "care_scope_guard" ON "clinic"."results"
  AS RESTRICTIVE
  FOR ALL
  TO "authenticated"
  USING ((( SELECT clinic.organization_care_access() AS organization_care_access) OR clinic.patient_care_access(patient_id)))
  WITH CHECK ((( SELECT clinic.organization_care_access() AS organization_care_access) OR clinic.patient_care_access(patient_id)));

CREATE POLICY "scoped_insert" ON "clinic"."results"
  FOR INSERT
  TO "authenticated"
  WITH CHECK (((organization_id = ( SELECT clinic.org_id() AS org_id)) AND ( SELECT clinic.allowed('results'::text) AS allowed)));

CREATE POLICY "scoped_read" ON "clinic"."results"
  FOR SELECT
  TO "authenticated"
  USING (((organization_id = ( SELECT clinic.org_id() AS org_id)) AND ( SELECT clinic.allowed('results'::text) AS allowed)));

CREATE POLICY "scoped_update" ON "clinic"."results"
  FOR UPDATE
  TO "authenticated"
  USING (((organization_id = ( SELECT clinic.org_id() AS org_id)) AND ( SELECT clinic.allowed('results'::text) AS allowed)))
  WITH CHECK (((organization_id = ( SELECT clinic.org_id() AS org_id)) AND ( SELECT clinic.allowed('results'::text) AS allowed)));

CREATE POLICY "administrative_scope" ON "clinic"."retention_rules"
  FOR ALL
  TO "authenticated"
  USING (((organization_id = ( SELECT clinic.org_id() AS org_id)) AND ( SELECT clinic.allowed('staff'::text) AS allowed)))
  WITH CHECK (((organization_id = ( SELECT clinic.org_id() AS org_id)) AND ( SELECT clinic.allowed('staff'::text) AS allowed)));

CREATE POLICY "administrative_scope" ON "clinic"."role_revocations"
  FOR ALL
  TO "authenticated"
  USING (((organization_id = ( SELECT clinic.org_id() AS org_id)) AND ( SELECT clinic.allowed('staff'::text) AS allowed)))
  WITH CHECK (((organization_id = ( SELECT clinic.org_id() AS org_id)) AND ( SELECT clinic.allowed('staff'::text) AS allowed)));

CREATE POLICY "scoped_insert" ON "clinic"."services"
  FOR INSERT
  TO "authenticated"
  WITH CHECK (((organization_id = ( SELECT clinic.org_id() AS org_id)) AND ( SELECT clinic.allowed('schedule'::text) AS allowed)));

CREATE POLICY "scoped_read" ON "clinic"."services"
  FOR SELECT
  TO "authenticated"
  USING
    (((organization_id = ( SELECT clinic.org_id() AS org_id)) AND (( SELECT clinic.allowed('schedule'::text) AS allowed) OR ( SELECT clinic.allowed('clinical'::text) AS allowed) OR
    ( SELECT clinic.allowed('billing'::text) AS allowed))));

CREATE POLICY "scoped_update" ON "clinic"."services"
  FOR UPDATE
  TO "authenticated"
  USING (((organization_id = ( SELECT clinic.org_id() AS org_id)) AND ( SELECT clinic.allowed('schedule'::text) AS allowed)))
  WITH CHECK (((organization_id = ( SELECT clinic.org_id() AS org_id)) AND ( SELECT clinic.allowed('schedule'::text) AS allowed)));

CREATE POLICY "scoped_insert" ON "clinic"."stock_lots"
  FOR INSERT
  TO "authenticated"
  WITH CHECK (((organization_id = ( SELECT clinic.org_id() AS org_id)) AND ( SELECT clinic.allowed('inventory'::text) AS allowed)));

CREATE POLICY "scoped_read" ON "clinic"."stock_lots"
  FOR SELECT
  TO "authenticated"
  USING
    (((organization_id = ( SELECT clinic.org_id() AS org_id)) AND (( SELECT clinic.allowed('inventory'::text) AS allowed) OR ( SELECT clinic.allowed('inventory.read'::text) AS
    allowed))));

CREATE POLICY "scoped_update" ON "clinic"."stock_lots"
  FOR UPDATE
  TO "authenticated"
  USING
    (((organization_id = ( SELECT clinic.org_id() AS org_id)) AND (( SELECT clinic.allowed('inventory'::text) AS allowed) OR ( SELECT clinic.allowed('clinical'::text) AS
    allowed))))
  WITH
    CHECK
    (((organization_id = ( SELECT clinic.org_id() AS org_id)) AND (( SELECT clinic.allowed('inventory'::text) AS allowed) OR ( SELECT clinic.allowed('clinical'::text) AS
    allowed))));

CREATE POLICY "scoped_insert" ON "clinic"."stock_movements"
  FOR INSERT
  TO "authenticated"
  WITH
    CHECK
    (((organization_id = ( SELECT clinic.org_id() AS org_id)) AND (( SELECT clinic.allowed('inventory'::text) AS allowed) OR ( SELECT clinic.allowed('clinical'::text) AS
    allowed))));

CREATE POLICY "scoped_read" ON "clinic"."stock_movements"
  FOR SELECT
  TO "authenticated"
  USING
    (((organization_id = ( SELECT clinic.org_id() AS org_id)) AND (( SELECT clinic.allowed('inventory'::text) AS allowed) OR ( SELECT clinic.allowed('inventory.read'::text) AS
    allowed))));

CREATE POLICY "scoped_update" ON "clinic"."stock_movements"
  FOR UPDATE
  TO "authenticated"
  USING (((organization_id = ( SELECT clinic.org_id() AS org_id)) AND ( SELECT clinic.allowed('inventory'::text) AS allowed)))
  WITH CHECK (((organization_id = ( SELECT clinic.org_id() AS org_id)) AND ( SELECT clinic.allowed('inventory'::text) AS allowed)));

CREATE POLICY "supplier_insert" ON "clinic"."suppliers"
  FOR INSERT
  TO "authenticated"
  WITH CHECK (((organization_id = ( SELECT clinic.org_id() AS org_id)) AND ( SELECT clinic.allowed('inventory'::text) AS allowed)));

CREATE POLICY "supplier_read" ON "clinic"."suppliers"
  FOR SELECT
  TO "authenticated"
  USING
    (((organization_id = ( SELECT clinic.org_id() AS org_id)) AND (( SELECT clinic.allowed('inventory'::text) AS allowed) OR ( SELECT clinic.allowed('finance'::text) AS allowed))));

CREATE POLICY "supplier_update" ON "clinic"."suppliers"
  FOR UPDATE
  TO "authenticated"
  USING (((organization_id = ( SELECT clinic.org_id() AS org_id)) AND ( SELECT clinic.allowed('inventory'::text) AS allowed)))
  WITH CHECK (((organization_id = ( SELECT clinic.org_id() AS org_id)) AND ( SELECT clinic.allowed('inventory'::text) AS allowed)));

CREATE POLICY "care_scope_guard" ON "clinic"."tasks"
  AS RESTRICTIVE
  FOR ALL
  TO "authenticated"
  USING ((( SELECT clinic.organization_care_access() AS organization_care_access) OR clinic.patient_care_access(patient_id)))
  WITH CHECK ((( SELECT clinic.organization_care_access() AS organization_care_access) OR clinic.patient_care_access(patient_id)));

CREATE POLICY "scoped_insert" ON "clinic"."tasks"
  FOR INSERT
  TO "authenticated"
  WITH CHECK (((organization_id = ( SELECT clinic.org_id() AS org_id)) AND ( SELECT clinic.allowed('results'::text) AS allowed)));

CREATE POLICY "scoped_read" ON "clinic"."tasks"
  FOR SELECT
  TO "authenticated"
  USING (((organization_id = ( SELECT clinic.org_id() AS org_id)) AND ( SELECT clinic.allowed('results'::text) AS allowed)));

CREATE POLICY "scoped_update" ON "clinic"."tasks"
  FOR UPDATE
  TO "authenticated"
  USING (((organization_id = ( SELECT clinic.org_id() AS org_id)) AND ( SELECT clinic.allowed('results'::text) AS allowed)))
  WITH CHECK (((organization_id = ( SELECT clinic.org_id() AS org_id)) AND ( SELECT clinic.allowed('results'::text) AS allowed)));

CREATE POLICY "scoped_insert" ON "clinic"."tills"
  FOR INSERT
  TO "authenticated"
  WITH CHECK (((organization_id = ( SELECT clinic.org_id() AS org_id)) AND ( SELECT clinic.allowed('billing'::text) AS allowed)));

CREATE POLICY "scoped_read" ON "clinic"."tills"
  FOR SELECT
  TO "authenticated"
  USING
    (((organization_id = ( SELECT clinic.org_id() AS org_id)) AND (( SELECT clinic.allowed('billing'::text) AS allowed) OR ( SELECT clinic.allowed('finance'::text) AS allowed))));

CREATE POLICY "scoped_update" ON "clinic"."tills"
  FOR UPDATE
  TO "authenticated"
  USING (((organization_id = ( SELECT clinic.org_id() AS org_id)) AND ( SELECT clinic.allowed('billing'::text) AS allowed)))
  WITH CHECK (((organization_id = ( SELECT clinic.org_id() AS org_id)) AND ( SELECT clinic.allowed('billing'::text) AS allowed)));

REVOKE ALL ON FUNCTION "clinic"."canonical_patient_id"(uuid) FROM PUBLIC;

GRANT EXECUTE ON FUNCTION "clinic"."canonical_patient_id"(uuid) TO "authenticated";

REVOKE ALL ON FUNCTION "clinic"."canonical_patient_id"(uuid) FROM "postgres";

GRANT EXECUTE ON FUNCTION "clinic"."canonical_patient_id"(uuid) TO "postgres";

REVOKE ALL ON FUNCTION "clinic"."check_open_period"() FROM PUBLIC;

REVOKE ALL ON FUNCTION "clinic"."check_open_period"() FROM "postgres";

GRANT EXECUTE ON FUNCTION "clinic"."check_open_period"() TO "postgres";

REVOKE ALL ON FUNCTION "clinic"."check_schedule"() FROM PUBLIC;

REVOKE ALL ON FUNCTION "clinic"."check_schedule"() FROM "postgres";

GRANT EXECUTE ON FUNCTION "clinic"."check_schedule"() TO "postgres";

REVOKE ALL ON FUNCTION "clinic"."encounter_care_access"(uuid) FROM PUBLIC;

GRANT EXECUTE ON FUNCTION "clinic"."encounter_care_access"(uuid) TO "authenticated";

REVOKE ALL ON FUNCTION "clinic"."encounter_care_access"(uuid) FROM "postgres";

GRANT EXECUTE ON FUNCTION "clinic"."encounter_care_access"(uuid) TO "postgres";

REVOKE ALL ON FUNCTION "clinic"."encounter_lookup"(uuid, text, uuid, text, boolean) FROM PUBLIC;

GRANT EXECUTE ON FUNCTION "clinic"."encounter_lookup"(uuid, text, uuid, text, boolean) TO "authenticated";

REVOKE ALL ON FUNCTION "clinic"."encounter_lookup"(uuid, text, uuid, text, boolean) FROM "postgres";

GRANT EXECUTE ON FUNCTION "clinic"."encounter_lookup"(uuid, text, uuid, text, boolean) TO "postgres";

REVOKE ALL ON FUNCTION "clinic"."extra_roles"(uuid) FROM PUBLIC;

GRANT EXECUTE ON FUNCTION "clinic"."extra_roles"(uuid) TO "authenticated";

REVOKE ALL ON FUNCTION "clinic"."extra_roles"(uuid) FROM "postgres";

GRANT EXECUTE ON FUNCTION "clinic"."extra_roles"(uuid) TO "postgres";

REVOKE ALL ON FUNCTION "clinic"."has_role"(uuid, text) FROM PUBLIC;

GRANT EXECUTE ON FUNCTION "clinic"."has_role"(uuid, text) TO "authenticated";

REVOKE ALL ON FUNCTION "clinic"."has_role"(uuid, text) FROM "postgres";

GRANT EXECUTE ON FUNCTION "clinic"."has_role"(uuid, text) TO "postgres";

REVOKE ALL ON FUNCTION "clinic"."invoice_balance_at"(uuid, timestamp WITH time zone) FROM PUBLIC;

GRANT EXECUTE ON FUNCTION "clinic"."invoice_balance_at"(uuid, timestamp WITH time zone) TO "authenticated";

REVOKE ALL ON FUNCTION "clinic"."invoice_balance_at"(uuid, timestamp WITH time zone) FROM "postgres";

GRANT EXECUTE ON FUNCTION "clinic"."invoice_balance_at"(uuid, timestamp WITH time zone) TO "postgres";

REVOKE ALL ON FUNCTION "clinic"."media_rejection_time"() FROM PUBLIC;

REVOKE ALL ON FUNCTION "clinic"."media_rejection_time"() FROM "postgres";

GRANT EXECUTE ON FUNCTION "clinic"."media_rejection_time"() TO "postgres";

REVOKE ALL ON FUNCTION "clinic"."organization_care_access"() FROM PUBLIC;

GRANT EXECUTE ON FUNCTION "clinic"."organization_care_access"() TO "authenticated";

REVOKE ALL ON FUNCTION "clinic"."organization_care_access"() FROM "postgres";

GRANT EXECUTE ON FUNCTION "clinic"."organization_care_access"() TO "postgres";

REVOKE ALL ON FUNCTION "clinic"."patient_care_access"(uuid) FROM PUBLIC;

GRANT EXECUTE ON FUNCTION "clinic"."patient_care_access"(uuid) TO "authenticated";

REVOKE ALL ON FUNCTION "clinic"."patient_care_access"(uuid) FROM "postgres";

GRANT EXECUTE ON FUNCTION "clinic"."patient_care_access"(uuid) TO "postgres";

REVOKE ALL ON FUNCTION "clinic"."period_is_open"(uuid, date) FROM PUBLIC;

GRANT EXECUTE ON FUNCTION "clinic"."period_is_open"(uuid, date) TO "authenticated";

REVOKE ALL ON FUNCTION "clinic"."period_is_open"(uuid, date) FROM "postgres";

GRANT EXECUTE ON FUNCTION "clinic"."period_is_open"(uuid, date) TO "postgres";

REVOKE ALL ON FUNCTION "clinic"."protect_approved_template"() FROM PUBLIC;

REVOKE ALL ON FUNCTION "clinic"."protect_approved_template"() FROM "postgres";

GRANT EXECUTE ON FUNCTION "clinic"."protect_approved_template"() TO "postgres";

REVOKE ALL ON FUNCTION "clinic"."protect_mapping"() FROM PUBLIC;

REVOKE ALL ON FUNCTION "clinic"."protect_mapping"() FROM "postgres";

GRANT EXECUTE ON FUNCTION "clinic"."protect_mapping"() TO "postgres";

REVOKE ALL ON FUNCTION "clinic"."protect_performed_service"() FROM PUBLIC;

REVOKE ALL ON FUNCTION "clinic"."protect_performed_service"() FROM "postgres";

GRANT EXECUTE ON FUNCTION "clinic"."protect_performed_service"() TO "postgres";

REVOKE ALL ON FUNCTION "clinic"."protect_prescription"() FROM PUBLIC;

REVOKE ALL ON FUNCTION "clinic"."protect_prescription"() FROM "postgres";

GRANT EXECUTE ON FUNCTION "clinic"."protect_prescription"() TO "postgres";

REVOKE ALL ON FUNCTION "clinic"."require_approval"(numeric, text) FROM PUBLIC;

GRANT EXECUTE ON FUNCTION "clinic"."require_approval"(numeric, text) TO "authenticated";

REVOKE ALL ON FUNCTION "clinic"."require_approval"(numeric, text) FROM "postgres";

GRANT EXECUTE ON FUNCTION "clinic"."require_approval"(numeric, text) TO "postgres";

REVOKE ALL ON FUNCTION "clinic"."user_permissions"() FROM PUBLIC;

GRANT EXECUTE ON FUNCTION "clinic"."user_permissions"() TO "authenticated";

REVOKE ALL ON FUNCTION "clinic"."user_permissions"() FROM "postgres";

GRANT EXECUTE ON FUNCTION "clinic"."user_permissions"() TO "postgres";

GRANT EXECUTE ON FUNCTION "public"."access_workflow"(text, jsonb, uuid) TO "authenticated";

REVOKE ALL ON FUNCTION "public"."access_workflow"(text, jsonb, uuid) FROM "postgres";

GRANT EXECUTE ON FUNCTION "public"."access_workflow"(text, jsonb, uuid) TO "postgres";

GRANT EXECUTE ON FUNCTION "public"."access_workflow"(text, jsonb, uuid) TO "service_role";

GRANT EXECUTE ON FUNCTION "public"."accounting_batch_download"(uuid) TO "authenticated";

REVOKE ALL ON FUNCTION "public"."accounting_batch_download"(uuid) FROM "postgres";

GRANT EXECUTE ON FUNCTION "public"."accounting_batch_download"(uuid) TO "postgres";

GRANT EXECUTE ON FUNCTION "public"."accounting_batch_download"(uuid) TO "service_role";

GRANT EXECUTE ON FUNCTION "public"."accounting_page"(text, text, uuid) TO "authenticated";

REVOKE ALL ON FUNCTION "public"."accounting_page"(text, text, uuid) FROM "postgres";

GRANT EXECUTE ON FUNCTION "public"."accounting_page"(text, text, uuid) TO "postgres";

GRANT EXECUTE ON FUNCTION "public"."accounting_page"(text, text, uuid) TO "service_role";

REVOKE ALL ON FUNCTION "public"."billing_patient_search"(text, integer) FROM PUBLIC;

GRANT EXECUTE ON FUNCTION "public"."billing_patient_search"(text, integer) TO "anon", "authenticated";

REVOKE ALL ON FUNCTION "public"."billing_patient_search"(text, integer) FROM "postgres";

GRANT EXECUTE ON FUNCTION "public"."billing_patient_search"(text, integer) TO "postgres";

GRANT EXECUTE ON FUNCTION "public"."billing_patient_search"(text, integer) TO "service_role";

GRANT EXECUTE ON FUNCTION "public"."care_team"(uuid) TO "authenticated";

REVOKE ALL ON FUNCTION "public"."care_team"(uuid) FROM "postgres";

GRANT EXECUTE ON FUNCTION "public"."care_team"(uuid) TO "postgres";

GRANT EXECUTE ON FUNCTION "public"."care_team"(uuid) TO "service_role";

REVOKE ALL ON FUNCTION "public"."current_photography_consent"(uuid) FROM PUBLIC;

GRANT EXECUTE ON FUNCTION "public"."current_photography_consent"(uuid) TO "anon", "authenticated";

REVOKE ALL ON FUNCTION "public"."current_photography_consent"(uuid) FROM "postgres";

GRANT EXECUTE ON FUNCTION "public"."current_photography_consent"(uuid) TO "postgres";

GRANT EXECUTE ON FUNCTION "public"."current_photography_consent"(uuid) TO "service_role";

GRANT EXECUTE ON FUNCTION "public"."encounter_search"(uuid, text, uuid, text, boolean) TO "authenticated";

REVOKE ALL ON FUNCTION "public"."encounter_search"(uuid, text, uuid, text, boolean) FROM "postgres";

GRANT EXECUTE ON FUNCTION "public"."encounter_search"(uuid, text, uuid, text, boolean) TO "postgres";

GRANT EXECUTE ON FUNCTION "public"."encounter_search"(uuid, text, uuid, text, boolean) TO "service_role";

GRANT EXECUTE ON FUNCTION "public"."finance_workflow"(text, jsonb, uuid) TO "authenticated";

REVOKE ALL ON FUNCTION "public"."finance_workflow"(text, jsonb, uuid) FROM "postgres";

GRANT EXECUTE ON FUNCTION "public"."finance_workflow"(text, jsonb, uuid) TO "postgres";

GRANT EXECUTE ON FUNCTION "public"."finance_workflow"(text, jsonb, uuid) TO "service_role";

REVOKE ALL ON FUNCTION "public"."financial_report"(text, date, date, uuid, integer, timestamp WITH time zone) FROM PUBLIC;

GRANT EXECUTE ON FUNCTION "public"."financial_report"(text, date, date, uuid, integer, timestamp WITH time zone) TO "anon", "authenticated";

REVOKE ALL ON FUNCTION "public"."financial_report"(text, date, date, uuid, integer, timestamp WITH time zone) FROM "postgres";

GRANT EXECUTE ON FUNCTION "public"."financial_report"(text, date, date, uuid, integer, timestamp WITH time zone) TO "postgres";

GRANT EXECUTE ON FUNCTION "public"."financial_report"(text, date, date, uuid, integer, timestamp WITH time zone) TO "service_role";

GRANT EXECUTE ON FUNCTION "public"."history_page"(text, uuid, text, uuid, integer) TO "authenticated";

REVOKE ALL ON FUNCTION "public"."history_page"(text, uuid, text, uuid, integer) FROM "postgres";

GRANT EXECUTE ON FUNCTION "public"."history_page"(text, uuid, text, uuid, integer) TO "postgres";

GRANT EXECUTE ON FUNCTION "public"."history_page"(text, uuid, text, uuid, integer) TO "service_role";

GRANT EXECUTE ON FUNCTION "public"."inventory_alerts"(integer, integer) TO "authenticated";

REVOKE ALL ON FUNCTION "public"."inventory_alerts"(integer, integer) FROM "postgres";

GRANT EXECUTE ON FUNCTION "public"."inventory_alerts"(integer, integer) TO "postgres";

GRANT EXECUTE ON FUNCTION "public"."inventory_alerts"(integer, integer) TO "service_role";

GRANT EXECUTE ON FUNCTION "public"."media_access_variant"(uuid, boolean) TO "authenticated";

REVOKE ALL ON FUNCTION "public"."media_access_variant"(uuid, boolean) FROM "postgres";

GRANT EXECUTE ON FUNCTION "public"."media_access_variant"(uuid, boolean) TO "postgres";

GRANT EXECUTE ON FUNCTION "public"."media_access_variant"(uuid, boolean) TO "service_role";

GRANT EXECUTE ON FUNCTION "public"."media_cancel_upload"(uuid, text) TO "authenticated";

REVOKE ALL ON FUNCTION "public"."media_cancel_upload"(uuid, text) FROM "postgres";

GRANT EXECUTE ON FUNCTION "public"."media_cancel_upload"(uuid, text) TO "postgres";

GRANT EXECUTE ON FUNCTION "public"."media_cancel_upload"(uuid, text) TO "service_role";

REVOKE ALL ON FUNCTION "public"."media_cleanup_record"(uuid, text) FROM "postgres";

GRANT EXECUTE ON FUNCTION "public"."media_cleanup_record"(uuid, text) TO "postgres";

GRANT EXECUTE ON FUNCTION "public"."media_cleanup_record"(uuid, text) TO "service_role";

REVOKE ALL ON FUNCTION "public"."media_complete"(uuid, text, text, text) FROM "postgres";

GRANT EXECUTE ON FUNCTION "public"."media_complete"(uuid, text, text, text) TO "postgres";

GRANT EXECUTE ON FUNCTION "public"."media_complete"(uuid, text, text, text) TO "service_role";

REVOKE ALL ON FUNCTION "public"."media_maintenance"(boolean) FROM "postgres";

GRANT EXECUTE ON FUNCTION "public"."media_maintenance"(boolean) TO "postgres";

GRANT EXECUTE ON FUNCTION "public"."media_maintenance"(boolean) TO "service_role";

REVOKE ALL ON FUNCTION "public"."media_preview_attach"(uuid, text, text, text) FROM "postgres";

GRANT EXECUTE ON FUNCTION "public"."media_preview_attach"(uuid, text, text, text) TO "postgres";

GRANT EXECUTE ON FUNCTION "public"."media_preview_attach"(uuid, text, text, text) TO "service_role";

GRANT EXECUTE ON FUNCTION "public"."patient_contacts"(uuid) TO "authenticated";

REVOKE ALL ON FUNCTION "public"."patient_contacts"(uuid) FROM "postgres";

GRANT EXECUTE ON FUNCTION "public"."patient_contacts"(uuid) TO "postgres";

GRANT EXECUTE ON FUNCTION "public"."patient_contacts"(uuid) TO "service_role";

GRANT EXECUTE ON FUNCTION "public"."patient_export"(uuid, text) TO "authenticated";

REVOKE ALL ON FUNCTION "public"."patient_export"(uuid, text) FROM "postgres";

GRANT EXECUTE ON FUNCTION "public"."patient_export"(uuid, text) TO "postgres";

GRANT EXECUTE ON FUNCTION "public"."patient_export"(uuid, text) TO "service_role";

GRANT EXECUTE ON FUNCTION "public"."reconciliation_options"(uuid, text, uuid) TO "authenticated";

REVOKE ALL ON FUNCTION "public"."reconciliation_options"(uuid, text, uuid) FROM "postgres";

GRANT EXECUTE ON FUNCTION "public"."reconciliation_options"(uuid, text, uuid) TO "postgres";

GRANT EXECUTE ON FUNCTION "public"."reconciliation_options"(uuid, text, uuid) TO "service_role";

REVOKE ALL ON FUNCTION "public"."retention_state"() FROM PUBLIC;

GRANT EXECUTE ON FUNCTION "public"."retention_state"() TO "anon", "authenticated";

REVOKE ALL ON FUNCTION "public"."retention_state"() FROM "postgres";

GRANT EXECUTE ON FUNCTION "public"."retention_state"() TO "postgres";

GRANT EXECUTE ON FUNCTION "public"."retention_state"() TO "service_role";

GRANT EXECUTE ON FUNCTION "public"."workflow"(text, jsonb, uuid) TO "authenticated";

REVOKE ALL ON FUNCTION "public"."workflow"(text, jsonb, uuid) FROM "postgres";

GRANT EXECUTE ON FUNCTION "public"."workflow"(text, jsonb, uuid) TO "postgres";

GRANT EXECUTE ON FUNCTION "public"."workflow"(text, jsonb, uuid) TO "service_role";

GRANT INSERT, SELECT, UPDATE ON TABLE "clinic"."access_events" TO "authenticated";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "clinic"."access_events" TO "service_role";

GRANT INSERT, SELECT, UPDATE ON TABLE "clinic"."account_mappings" TO "authenticated";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "clinic"."account_mappings" TO "service_role";

GRANT INSERT, SELECT, UPDATE ON TABLE "clinic"."accounting_acknowledgements" TO "authenticated";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "clinic"."accounting_acknowledgements" TO "service_role";

GRANT INSERT, SELECT, UPDATE ON TABLE "clinic"."accounting_batch_items" TO "authenticated";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "clinic"."accounting_batch_items" TO "service_role";

GRANT INSERT, SELECT, UPDATE ON TABLE "clinic"."accounting_batches" TO "authenticated";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "clinic"."accounting_batches" TO "service_role";

GRANT INSERT, SELECT, UPDATE ON TABLE "clinic"."accounting_periods" TO "authenticated";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "clinic"."accounting_periods" TO "service_role";

GRANT INSERT, SELECT, UPDATE ON TABLE "clinic"."additional_roles" TO "authenticated";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "clinic"."additional_roles" TO "service_role";

GRANT INSERT, SELECT, UPDATE ON TABLE "clinic"."approval_limits" TO "authenticated";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "clinic"."approval_limits" TO "service_role";

GRANT INSERT, SELECT ON TABLE "clinic"."availability_cancellations" TO "authenticated";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "clinic"."availability_cancellations" TO "service_role";

GRANT INSERT, SELECT, UPDATE ON TABLE "clinic"."bank_match_reversals" TO "authenticated";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "clinic"."bank_match_reversals" TO "service_role";

GRANT INSERT, SELECT, UPDATE ON TABLE "clinic"."bank_matches" TO "authenticated";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "clinic"."bank_matches" TO "service_role";

GRANT INSERT, SELECT, UPDATE ON TABLE "clinic"."bank_statement_lines" TO "authenticated";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "clinic"."bank_statement_lines" TO "service_role";

GRANT INSERT, SELECT, UPDATE ON TABLE "clinic"."care_assignments" TO "authenticated";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "clinic"."care_assignments" TO "service_role";

GRANT INSERT, SELECT, UPDATE ON TABLE "clinic"."care_revocations" TO "authenticated";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "clinic"."care_revocations" TO "service_role";

GRANT INSERT, SELECT, UPDATE ON TABLE "clinic"."clinic_resources" TO "authenticated";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "clinic"."clinic_resources" TO "service_role";

GRANT INSERT, SELECT, UPDATE ON TABLE "clinic"."clinical_facts" TO "authenticated";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "clinic"."clinical_facts" TO "service_role";

GRANT INSERT, SELECT, UPDATE ON TABLE "clinic"."clinician_availability" TO "authenticated";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "clinic"."clinician_availability" TO "service_role";

GRANT INSERT, SELECT, UPDATE ON TABLE "clinic"."contact_log" TO "authenticated";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "clinic"."contact_log" TO "service_role";

GRANT INSERT, SELECT, UPDATE ON TABLE "clinic"."document_templates" TO "authenticated";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "clinic"."document_templates" TO "service_role";

GRANT INSERT, SELECT, UPDATE ON TABLE "clinic"."hold_releases" TO "authenticated";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "clinic"."hold_releases" TO "service_role";

GRANT INSERT, SELECT, UPDATE ON TABLE "clinic"."inventory_products" TO "authenticated";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "clinic"."inventory_products" TO "service_role";

GRANT INSERT, SELECT, UPDATE ON TABLE "clinic"."legal_holds" TO "authenticated";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "clinic"."legal_holds" TO "service_role";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "clinic"."media_cleanup_events" TO "service_role";

GRANT INSERT, SELECT, UPDATE ON TABLE "clinic"."package_corrections" TO "authenticated";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "clinic"."package_corrections" TO "service_role";

GRANT INSERT, SELECT ON TABLE "clinic"."patient_documents" TO "authenticated";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "clinic"."patient_documents" TO "service_role";

GRANT INSERT, SELECT ON TABLE "clinic"."patient_exports" TO "authenticated";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "clinic"."patient_exports" TO "service_role";

GRANT INSERT, SELECT, UPDATE ON TABLE "clinic"."performed_services" TO "authenticated";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "clinic"."performed_services" TO "service_role";

GRANT INSERT, SELECT, UPDATE ON TABLE "clinic"."prescription_items" TO "authenticated";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "clinic"."prescription_items" TO "service_role";

GRANT INSERT, SELECT, UPDATE ON TABLE "clinic"."retention_rules" TO "authenticated";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "clinic"."retention_rules" TO "service_role";

GRANT INSERT, SELECT, UPDATE ON TABLE "clinic"."role_revocations" TO "authenticated";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "clinic"."role_revocations" TO "service_role";

GRANT INSERT, SELECT, UPDATE ON TABLE "clinic"."suppliers" TO "authenticated";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "clinic"."suppliers" TO "service_role";

CREATE POLICY "clinical_export_scope" ON "clinic"."patient_exports"
  FOR ALL
  TO "authenticated"
  USING
    (((organization_id = ( SELECT clinic.org_id() AS org_id)) AND (created_by = ( SELECT auth.uid() AS uid)) AND ( SELECT clinic.allowed('clinical.export'::text) AS allowed) AND ((
    SELECT clinic.organization_care_access() AS organization_care_access) OR clinic.patient_care_access(patient_id))))
  WITH
    CHECK
    (((organization_id = ( SELECT clinic.org_id() AS org_id)) AND (created_by = ( SELECT auth.uid() AS uid)) AND ( SELECT clinic.allowed('clinical.export'::text) AS allowed) AND ((
    SELECT clinic.organization_care_access() AS organization_care_access) OR clinic.patient_care_access(patient_id))));


-- Backfill original tender only where the immutable sale journal proves it.
-- Unknown legacy tender remains null and cannot be guessed for a refund.
UPDATE clinic.packages p SET sale_method=(
 SELECT l.account FROM clinic.journals j JOIN clinic.journal_lines l ON l.journal_id=j.id
 WHERE j.organization_id=p.organization_id AND j.source_id=p.id AND j.source_type='package_sale'
 AND l.account IN ('cash','bank','card') AND l.debit>0 ORDER BY l.id LIMIT 1
) WHERE p.sale_method IS NULL;
-- Give existing rejected uploads the full cleanup grace period from deployment.
UPDATE clinic.media SET rejected_at=clock_timestamp() WHERE status='rejected' AND rejected_at IS NULL;
