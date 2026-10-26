-- Preserve the patient and author identity shown on newly created clinical documents.
-- Existing signed records remain unchanged; absent historical identity is explicit.
alter table clinic.encounters add column identity_snapshot jsonb not null default '{}';
alter table clinic.procedures add column identity_snapshot jsonb not null default '{}';
alter table clinic.consents add column identity_snapshot jsonb not null default '{}';
alter table clinic.patient_documents add column identity_snapshot jsonb not null default '{}';
create function clinic.capture_document_identity() returns trigger language plpgsql security invoker set search_path='' as $$
declare patient clinic.patients;author uuid;author_name text;
begin
 if tg_op='UPDATE' then
 if not (old.status='draft' and new.status='signed' and new.identity_snapshot='{}') then return new;end if;
 end if;
 select * into patient from clinic.patients p where p.id=new.patient_id and p.organization_id=new.organization_id;
 if not found then raise exception 'Patient identity unavailable' using errcode='42501';end if;
 if tg_table_name='encounters' then author:=new.doctor_id;
 elsif tg_table_name='patient_documents' then author:=new.signed_by;
 elsif tg_table_name='procedures' then author:=new.performed_by;
 else author:=new.recorded_by;end if;
 select display_name into author_name from clinic.memberships where user_id=author and organization_id=new.organization_id;
 new.identity_snapshot:=jsonb_build_object('full_name',patient.full_name,'patient_number',patient.patient_number,'birth_date',patient.birth_date,'birth_precision',patient.birth_precision,'reported_age',patient.reported_age,'age_recorded_on',patient.age_recorded_on,'clinician_name',author_name,'captured_at',clock_timestamp());
 return new;
end $$;
revoke all on function clinic.capture_document_identity() from public,anon;
create trigger capture_identity before insert or update of status on clinic.encounters for each row execute function clinic.capture_document_identity();
create trigger capture_identity before insert on clinic.procedures for each row execute function clinic.capture_document_identity();
create trigger capture_identity before insert on clinic.consents for each row execute function clinic.capture_document_identity();
create trigger capture_identity before insert on clinic.patient_documents for each row execute function clinic.capture_document_identity();
