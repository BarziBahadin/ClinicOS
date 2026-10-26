alter table clinic.encounters add column template_id uuid;
alter table clinic.encounters add column template_snapshot jsonb;
alter table clinic.encounters add foreign key(organization_id,template_id) references clinic.document_templates(organization_id,id);
alter table clinic.procedures add column template_id uuid;
alter table clinic.procedures add column template_snapshot jsonb;
alter table clinic.procedures add foreign key(organization_id,template_id) references clinic.document_templates(organization_id,id);
create trigger procedure_immutable before update or delete on clinic.procedures for each row execute function clinic.immutable_record();
create table clinic.patient_documents (
 id uuid primary key default gen_random_uuid(),organization_id uuid not null,patient_id uuid not null,
 kind text not null check(kind in ('referral','aftercare','care_letter')),title text not null check(length(trim(title))>=2),body text not null check(length(trim(body)) between 5 and 30000),
 template_id uuid,template_snapshot jsonb,supersedes_id uuid,correction_reason text,
 signed_by uuid not null default auth.uid(),signed_at timestamptz not null default now(),created_at timestamptz not null default now(),
 foreign key(organization_id,patient_id) references clinic.patients(organization_id,id),foreign key(organization_id,template_id) references clinic.document_templates(organization_id,id),
 unique(organization_id,id),foreign key(organization_id,supersedes_id) references clinic.patient_documents(organization_id,id),check(supersedes_id is null or length(trim(correction_reason))>=5)
);
create table clinic.patient_exports (
 id uuid primary key default gen_random_uuid(),organization_id uuid not null,patient_id uuid not null,purpose text not null check(length(trim(purpose))>=10),
 created_by uuid not null default auth.uid(),created_at timestamptz not null default now(),foreign key(organization_id,patient_id) references clinic.patients(organization_id,id),unique(organization_id,id)
);
alter table clinic.patient_documents enable row level security;
alter table clinic.patient_exports enable row level security;
grant select,insert on clinic.patient_documents,clinic.patient_exports to authenticated;
grant all on clinic.patient_documents,clinic.patient_exports to service_role;
create policy clinical_document_scope on clinic.patient_documents to authenticated using(organization_id=(select clinic.org_id()) and ((select clinic.organization_care_access()) or clinic.patient_care_access(patient_id))) with check(organization_id=(select clinic.org_id()) and ((select clinic.organization_care_access()) or clinic.patient_care_access(patient_id)));
create policy clinical_export_scope on clinic.patient_exports to authenticated using(organization_id=(select clinic.org_id()) and created_by=auth.uid() and (select clinic.allowed('clinical.export')) and ((select clinic.organization_care_access()) or clinic.patient_care_access(patient_id))) with check(organization_id=(select clinic.org_id()) and created_by=auth.uid() and (select clinic.allowed('clinical.export')) and ((select clinic.organization_care_access()) or clinic.patient_care_access(patient_id)));
create trigger immutable_record before update or delete on clinic.patient_documents for each row execute function clinic.immutable_record();
create trigger immutable_record before update or delete on clinic.patient_exports for each row execute function clinic.immutable_record();
create trigger audit_write after insert on clinic.patient_documents for each row execute function clinic.audit_write();
create trigger audit_write after insert on clinic.patient_exports for each row execute function clinic.audit_write();
create index document_patient_date on clinic.patient_documents(organization_id,patient_id,created_at desc,id desc);
create index export_patient_date on clinic.patient_exports(organization_id,patient_id,created_at desc,id desc);
alter table clinic.media add constraint preview_pair check((preview_key is null and preview_sha256 is null) or (preview_key is not null and preview_sha256 is not null and mime_type<>'application/pdf' and preview_key=object_key||'.preview-'||preview_sha256||'.png'));
alter table clinic.prescription_items add check(length(trim(route))>0 and length(trim(frequency))>0 and length(trim(duration))>0);
alter table clinic.contact_log add check(length(trim(purpose))>0);
