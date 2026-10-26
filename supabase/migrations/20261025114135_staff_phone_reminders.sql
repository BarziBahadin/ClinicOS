-- Manual staff call reminders only: current consent, scoped contacts and appointment versions.
-- Earlier outcomes remain immutable and rescheduled appointments need a fresh reminder.
SET local check_function_bodies = off;

DROP POLICY "scoped_insert" ON "clinic"."consents";

DROP POLICY "scoped_read" ON "clinic"."consents";

ALTER TABLE "clinic"."contact_log"
  ADD COLUMN "appointment_id" uuid;

ALTER TABLE "clinic"."contact_log"
  ADD COLUMN "contact_id" uuid;

ALTER TABLE "clinic"."contact_log"
  ADD COLUMN "appointment_version" integer;

CREATE OR REPLACE FUNCTION public.phone_reminders (
  from_day          date,
  to_day            date,
  include_contacted boolean DEFAULT false,
  page_number       integer DEFAULT 0
)
  RETURNS jsonb
  LANGUAGE plpgsql
  STABLE
  SET search_path TO ''
  AS $function$
declare first_at timestamptz;last_at timestamptz;items jsonb;records integer;
begin
 perform clinic.require_permission('patients');perform clinic.require_permission('schedule');
 if from_day is null or to_day is null or to_day<from_day or to_day-from_day>31 or page_number is null or page_number not between 0 and 100000 then raise exception 'Choose a reminder range of at most 32 days';end if;
 first_at:=from_day::timestamp at time zone 'Asia/Baghdad';last_at:=(to_day+1)::timestamp at time zone 'Asia/Baghdad';
 with eligible as materialized (
 select a.id,a.version,a.starts_at,a.ends_at,a.service_name,p.id patient_id,p.full_name patient_name,p.patient_number,m.display_name clinician_name,
 coalesce(consent.granted,false) communication_allowed,c.id contact_id,case when coalesce(consent.granted,false) then coalesce(c.phone,p.phone) else null end phone,
 case when c.id is not null then c.owner_name else p.contact_owner end contact_owner,
 last_call.outcome last_outcome,last_call.created_at last_call_at,coalesce(last_call.outcome in ('reached','declined'),false) contacted
 from clinic.appointments a join clinic.patients p on p.id=clinic.canonical_patient_id(a.patient_id) and p.organization_id=a.organization_id
 left join clinic.memberships m on m.organization_id=a.organization_id and m.user_id=a.doctor_id
 left join lateral(select co.granted from clinic.consents co where co.organization_id=a.organization_id and co.patient_id=p.id and co.purpose='communication' order by co.created_at desc,co.id desc limit 1) consent on true
 left join lateral(select con.id,con.phone,con.owner_name from clinic.contacts con where con.organization_id=a.organization_id and con.patient_id=p.id and con.valid_to is null order by con.preferred desc,con.valid_from desc,con.id desc limit 1) c on true
 left join lateral(select l.outcome,l.created_at from clinic.contact_log l where l.organization_id=a.organization_id and l.appointment_id=a.id and l.appointment_version=a.version and l.purpose='appointment_reminder' and l.channel='phone' order by l.created_at desc,l.id desc limit 1) last_call on true
 where a.organization_id=(select clinic.org_id()) and a.status='scheduled' and a.starts_at>=first_at and a.starts_at<last_at
 ),filtered as materialized(select * from eligible where coalesce(include_contacted,false) or not contacted),page as(select * from filtered order by starts_at,id limit 100 offset page_number*100)
 select coalesce((select jsonb_agg(to_jsonb(r) order by r.starts_at,r.id) from page r),'[]'),(select count(*) from filtered) into items,records;
 return jsonb_build_object('items',items,'records',records,'has_more',records>(page_number+1)*100);
end $function$;

REVOKE ALL ON FUNCTION "public"."phone_reminders"(date, date, boolean, integer) FROM PUBLIC, "anon";

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
 if nullif(payload->>'appointment_id','') is not null then
 perform clinic.require_permission('schedule');
 if payload->>'purpose' is distinct from 'appointment_reminder' or payload->>'channel' is distinct from 'phone' then raise exception 'Appointment reminders use the staff phone-call workflow';end if;
 if not exists(select 1 from clinic.appointments a where a.organization_id=o and a.id=(payload->>'appointment_id')::uuid and clinic.canonical_patient_id(a.patient_id)=p and a.status='scheduled' and a.version=(payload->>'appointment_version')::integer) then raise exception 'Appointment changed. Refresh before recording the call.' using errcode='40001';end if;
 if not coalesce((select c.granted from clinic.consents c where c.organization_id=o and c.patient_id=p and c.purpose='communication' order by c.created_at desc,c.id desc limit 1),false) then raise exception 'Review current communication consent before calling';end if;
 end if;
 if nullif(payload->>'contact_id','') is not null and not exists(select 1 from clinic.contacts c where c.id=(payload->>'contact_id')::uuid and c.organization_id=o and c.patient_id=p and c.valid_to is null) then raise exception 'Contact changed. Refresh first.' using errcode='40001';end if;
 insert into clinic.contact_log(organization_id,patient_id,channel,purpose,outcome,notes,appointment_id,contact_id,appointment_version) values(o,p,payload->>'channel',payload->>'purpose',payload->>'outcome',payload->>'notes',nullif(payload->>'appointment_id','')::uuid,nullif(payload->>'contact_id','')::uuid,nullif(payload->>'appointment_version','')::integer) returning id into rid;
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

ALTER TABLE "clinic"."contact_log"
  ADD CONSTRAINT "contact_log_appointment_version_check" CHECK ((appointment_version > 0));

ALTER TABLE "clinic"."contact_log"
  ADD CONSTRAINT "contact_log_check" CHECK (((appointment_id IS NULL) = (appointment_version IS NULL)));

ALTER TABLE "clinic"."contact_log"
  ADD CONSTRAINT "contact_log_organization_id_appointment_id_fkey" FOREIGN KEY (organization_id, appointment_id) REFERENCES clinic.appointments(organization_id, id);

ALTER TABLE "clinic"."contacts"
  ADD CONSTRAINT "contacts_organization_id_id_key" UNIQUE (organization_id, id);

ALTER TABLE "clinic"."contact_log"
  ADD CONSTRAINT "contact_log_organization_id_contact_id_fkey" FOREIGN KEY (organization_id, contact_id) REFERENCES clinic.contacts(organization_id, id);

CREATE INDEX contact_log_contact_idx ON clinic.contact_log USING btree (organization_id, contact_id);

CREATE INDEX contact_reminder_latest ON clinic.contact_log USING btree (organization_id, appointment_id, created_at DESC, id DESC);

CREATE POLICY "scoped_insert" ON "clinic"."consents"
  FOR INSERT
  TO "authenticated"
  WITH
    CHECK
    (((organization_id = ( SELECT clinic.org_id() AS org_id)) AND (( SELECT clinic.allowed('clinical'::text) AS allowed) OR ((purpose = 'communication'::text) AND ( SELECT
    clinic.allowed('patients'::text) AS allowed)))));

CREATE POLICY "scoped_read" ON "clinic"."consents"
  FOR SELECT
  TO "authenticated"
  USING
    (((organization_id = ( SELECT clinic.org_id() AS org_id)) AND (( SELECT clinic.allowed('clinical'::text) AS allowed) OR ((purpose = 'communication'::text) AND ( SELECT
    clinic.allowed('patients'::text) AS allowed)))));

GRANT EXECUTE ON FUNCTION "public"."phone_reminders"(date, date, boolean, integer) TO "authenticated";

REVOKE ALL ON FUNCTION "public"."phone_reminders"(date, date, boolean, integer) FROM "postgres";

GRANT EXECUTE ON FUNCTION "public"."phone_reminders"(date, date, boolean, integer) TO "postgres";

GRANT EXECUTE ON FUNCTION "public"."phone_reminders"(date, date, boolean, integer) TO "service_role";

