-- Development reference. Generate and replay migrations before deployment.
create table clinic.document_templates (
 id uuid primary key default gen_random_uuid(), organization_id uuid not null references clinic.organizations,
 kind text not null check(kind in ('procedure','consent','aftercare','referral','clinical')),
 name text not null check(length(trim(name)) between 2 and 160), language text not null check(language in ('en','ckb')),
 version integer not null check(version>0), content text not null check(length(trim(content)) between 5 and 30000),
 status text not null default 'draft' check(status in ('draft','approved')), approved_by uuid references auth.users,
 approved_at timestamptz, created_by uuid not null default auth.uid(), created_at timestamptz not null default now(),
 unique(organization_id,kind,name,language,version), unique(organization_id,id),
 check((status='approved')=(approved_at is not null and approved_by is not null))
);
create table clinic.clinical_facts (
 id uuid primary key default gen_random_uuid(),organization_id uuid not null, patient_id uuid not null,
 kind text not null check(kind in ('allergy','problem','medication','history')), content text not null check(length(trim(content)) between 2 and 10000),
 status text not null check(status in ('active','resolved','entered_in_error')), supersedes_id uuid,
 created_by uuid not null default auth.uid(),created_at timestamptz not null default now(),
 unique(organization_id,id),foreign key(organization_id,patient_id) references clinic.patients(organization_id,id),
 foreign key(organization_id,supersedes_id) references clinic.clinical_facts(organization_id,id),unique(supersedes_id)
);
create table clinic.prescription_items (
 id uuid primary key default gen_random_uuid(),organization_id uuid not null, encounter_id uuid not null,
 medicine text not null check(length(trim(medicine)) between 1 and 200),strength text not null default '',dose text not null check(length(trim(dose))>0),
 route text not null,frequency text not null,duration text not null,quantity text not null default '',instructions text not null default '',
 created_at timestamptz not null default now(),created_by uuid not null default auth.uid(),
 foreign key(organization_id,encounter_id) references clinic.encounters(organization_id,id),unique(organization_id,id)
);
create table clinic.contact_log (
 id uuid primary key default gen_random_uuid(),organization_id uuid not null,patient_id uuid not null,
 channel text not null check(channel in ('phone','in_person','sms','whatsapp','other')),purpose text not null,
 outcome text not null check(outcome in ('reached','no_answer','declined','scheduled','other')),notes text not null check(length(trim(notes)) between 1 and 10000),
 created_by uuid not null default auth.uid(),created_at timestamptz not null default now(),
 foreign key(organization_id,patient_id) references clinic.patients(organization_id,id),unique(organization_id,id)
);
create table clinic.performed_services (
 id uuid primary key default gen_random_uuid(),organization_id uuid not null,patient_id uuid not null,encounter_id uuid not null,service_id uuid not null,
 quantity integer not null check(quantity between 1 and 1000),invoice_id uuid,created_by uuid not null default auth.uid(),created_at timestamptz not null default now(),
 foreign key(organization_id,patient_id) references clinic.patients(organization_id,id),foreign key(organization_id,encounter_id) references clinic.encounters(organization_id,id),
 foreign key(organization_id,service_id) references clinic.services(organization_id,id),foreign key(organization_id,invoice_id) references clinic.invoices(organization_id,id),unique(organization_id,id)
);
alter table clinic.contacts add column preferred boolean not null default false;
alter table clinic.contacts add column verified_at timestamptz;
create unique index contact_active_unique on clinic.contacts(organization_id,patient_id,phone) where valid_to is null;
alter table clinic.packages add column expires_on date;
alter table clinic.packages add column cancelled_at timestamptz;
alter table clinic.packages add column sale_method text check(sale_method in ('cash','bank','card'));
create table clinic.package_corrections (
 id uuid primary key default gen_random_uuid(),organization_id uuid not null,package_id uuid not null,amount numeric(18,3) not null check(amount>=0),
 currency text not null check(currency in ('IQD','USD')),kind text not null check(kind in ('refund','expiry_extension')),reason text not null check(length(trim(reason))>=5),
 created_by uuid not null default auth.uid(),created_at timestamptz not null default now(),
 foreign key(organization_id,package_id) references clinic.packages(organization_id,id),unique(organization_id,id)
);
create table clinic.clinician_availability (
 id uuid primary key default gen_random_uuid(),organization_id uuid not null,doctor_id uuid not null references auth.users,
 starts_at timestamptz not null,ends_at timestamptz not null,kind text not null check(kind in ('available','leave')),
 description text not null,created_at timestamptz not null default now(),check(ends_at>starts_at),unique(organization_id,id)
);
create table clinic.clinic_resources (
 id uuid primary key default gen_random_uuid(),organization_id uuid not null references clinic.organizations,name text not null,kind text not null check(kind in ('room','device')),
 active boolean not null default true,created_at timestamptz not null default now(),unique(organization_id,id),unique(organization_id,name)
);
alter table clinic.appointments add column resource_id uuid;
alter table clinic.appointments add foreign key(organization_id,resource_id) references clinic.clinic_resources(organization_id,id);

-- Private tables retain organization-scoped RLS in addition to narrow RPCs.
do $$declare t text; perm text; begin
 for t,perm in select * from (values ('document_templates','clinical'),('clinical_facts','clinical'),('prescription_items','clinical'),('contact_log','patients'),('performed_services','clinical'),('package_corrections','billing'),('clinician_availability','schedule'),('clinic_resources','schedule')) x(t,p) loop
 execute format('alter table clinic.%I enable row level security',t);
 execute format('grant select,insert,update on clinic.%I to authenticated',t);
 execute format('grant all on clinic.%I to service_role',t);
 execute format('create policy scoped_access on clinic.%I to authenticated using(organization_id=clinic.org_id() and clinic.allowed(%L)) with check(organization_id=clinic.org_id() and clinic.allowed(%L))',t,perm,perm);
 execute format('create trigger audit_write after insert or update on clinic.%I for each row execute function clinic.audit_write()',t);
 end loop;
end $$;
create policy performed_billing_read on clinic.performed_services for select to authenticated using(organization_id=clinic.org_id() and clinic.allowed('billing'));
create policy performed_billing_update on clinic.performed_services for update to authenticated using(organization_id=clinic.org_id() and clinic.allowed('billing')) with check(organization_id=clinic.org_id() and clinic.allowed('billing'));
create policy correction_approval on clinic.package_corrections for insert to authenticated with check(organization_id=clinic.org_id() and clinic.allowed('approve'));
create policy template_reception_read on clinic.document_templates for select to authenticated using(organization_id=clinic.org_id() and status='approved' and clinic.allowed('patients') and kind in ('consent','aftercare','referral'));

create function clinic.protect_approved_template() returns trigger language plpgsql set search_path='' as $$begin
 if old.status='approved' then raise exception 'Approved templates are immutable. Create a new version.' using errcode='23514'; end if;return new;end $$;
create trigger template_immutable before update or delete on clinic.document_templates for each row execute function clinic.protect_approved_template();
create function clinic.protect_prescription() returns trigger language plpgsql set search_path='' as $$begin
 if exists(select 1 from clinic.encounters where id=coalesce(new.encounter_id,old.encounter_id) and status='signed') then raise exception 'Signed prescriptions are immutable; use an addendum.' using errcode='23514'; end if;
 if tg_op='DELETE' then return old;end if;return new;end $$;
create trigger signed_prescription before insert or update or delete on clinic.prescription_items for each row execute function clinic.protect_prescription();
create function clinic.protect_performed_service() returns trigger language plpgsql set search_path='' as $$begin
 if row(new.id,new.organization_id,new.patient_id,new.encounter_id,new.service_id,new.quantity,new.created_by,new.created_at) is distinct from row(old.id,old.organization_id,old.patient_id,old.encounter_id,old.service_id,old.quantity,old.created_by,old.created_at) or old.invoice_id is not null then raise exception 'Performed services are immutable after invoicing' using errcode='23514';end if;return new;end $$;
create trigger performed_identity before update on clinic.performed_services for each row execute function clinic.protect_performed_service();
do $$declare t text;begin foreach t in array array['clinical_facts','contact_log','package_corrections'] loop execute format('create trigger immutable_record before update or delete on clinic.%I for each row execute function clinic.immutable_record()',t);end loop;end $$;

create function public.history_page(record_type text,patient_id uuid default null,search_term text default '',cursor_id uuid default null,page_size integer default 50) returns jsonb language plpgsql security invoker set search_path='' as $$
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
 execute format($q$with records as materialized (
 select r.id,coalesce((to_jsonb(r)->>'created_at')::timestamptz,(to_jsonb(r)->>'opened_at')::timestamptz,'-infinity'::timestamptz) sort_at,
 (to_jsonb(r)->>'patient_id')::uuid patient_id,to_jsonb(r) value
 from clinic.%I r where r.organization_id=$1 and ($2 is null or (to_jsonb(r)->>'patient_id')::uuid in (select id from clinic.patient_ids($2)))
 ),labels as materialized (
 select p.id,clinic.patient_label(p.id) name from (select distinct patient_id id from records where $5 and patient_id is not null) p
 ),page as (
 select r.*,l.name patient_name from records r left join labels l on l.id=r.patient_id
 where ($3 is null or (r.sort_at,r.id)<(select c.sort_at,c.id from records c where c.id=$3))
 and ($4='' or clinic.search_key(r.value::text||coalesce(l.name,'')) like '%%'||clinic.search_key(left($4,200))||'%%')
 order by r.sort_at desc,r.id desc limit $6
 ) select coalesce(jsonb_agg(value || case when $5 then jsonb_build_object('patient_name',patient_name) else '{}'::jsonb end || case when $7='clinician_availability' then jsonb_build_object('ended',exists(select 1 from clinic.availability_cancellations x where x.availability_id=page.id)) else '{}'::jsonb end order by sort_at desc,id desc),'[]') from page$q$,tbl)
 into items using o,patient_id,cursor_id,coalesce(search_term,''),has_patient,sz+1,record_type;
 more:=jsonb_array_length(items)>sz;if more then items:=items-sz;end if;
 if perm in ('clinical','media','results') then perform clinic.log_access('HISTORY_READ',patient_id,tbl);end if;
 return jsonb_build_object('items',items,'has_more',more);
end $$;
revoke all on function public.history_page(text,uuid,text,uuid,integer) from public,anon;
grant execute on function public.history_page(text,uuid,text,uuid,integer) to authenticated;

create function public.workflow(kind text,payload jsonb,request_id uuid) returns jsonb language plpgsql security invoker set search_path='' as $$
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
end $$;
revoke all on function public.workflow(text,jsonb,uuid) from public,anon;
grant execute on function public.workflow(text,jsonb,uuid) to authenticated;

create function clinic.check_schedule() returns trigger language plpgsql security invoker set search_path='' as $$begin
 perform pg_advisory_xact_lock(hashtextextended(new.organization_id::text,0));
 if new.status in ('cancelled','no_show','completed') then return new;end if;
 if exists(select 1 from clinic.appointments a where a.organization_id=new.organization_id and a.id<>new.id and a.status not in ('cancelled','no_show','completed') and a.starts_at<new.ends_at and a.ends_at>new.starts_at and (a.doctor_id=new.doctor_id or (new.resource_id is not null and a.resource_id=new.resource_id))) then raise exception 'The clinician or resource already has an appointment at this time' using errcode='23P01';end if;
 if new.resource_id is not null and not exists(select 1 from clinic.clinic_resources where id=new.resource_id and organization_id=new.organization_id and active) then raise exception 'Select an active clinic resource';end if;
 if exists(select 1 from clinic.clinician_availability a where a.organization_id=new.organization_id and a.doctor_id=new.doctor_id and a.kind='leave' and a.starts_at<new.ends_at and a.ends_at>new.starts_at and not exists(select 1 from clinic.availability_cancellations x where x.availability_id=a.id)) then raise exception 'The clinician is on leave during this time';end if;
 if exists(select 1 from clinic.clinician_availability a where a.organization_id=new.organization_id and a.doctor_id=new.doctor_id and a.kind='available' and not exists(select 1 from clinic.availability_cancellations x where x.availability_id=a.id)) and not exists(select 1 from clinic.clinician_availability where organization_id=new.organization_id and doctor_id=new.doctor_id and kind='available' and starts_at<=new.starts_at and ends_at>=new.ends_at and not exists(select 1 from clinic.availability_cancellations x where x.availability_id=clinic.clinician_availability.id)) then raise exception 'Appointment is outside the configured availability';end if;
 return new;
end $$;
create trigger schedule_guard before insert or update of starts_at,ends_at,status,resource_id,doctor_id on clinic.appointments for each row execute function clinic.check_schedule();
alter table clinic.contacts add constraint contact_phone_format check(phone ~ '^\+[1-9][0-9]{7,14}$');
create index clinical_facts_patient on clinic.clinical_facts(organization_id,patient_id,created_at desc,id desc);
create index clinical_contact_patient on clinic.contact_log(organization_id,patient_id,created_at desc,id desc);
create index performed_unbilled on clinic.performed_services(organization_id,created_at desc,id desc) where invoice_id is null;
create index availability_dates on clinic.clinician_availability(organization_id,doctor_id,starts_at,ends_at);
create index appointment_resource on clinic.appointments(organization_id,resource_id,starts_at,ends_at) where resource_id is not null;
-- Index every new foreign-key prefix, including approval/author references.
do $$declare r record;begin
 for r in select c.conrelid::regclass tbl,c.conname,(select string_agg(quote_ident(a.attname),',' order by u.ord) from unnest(c.conkey) with ordinality u(attnum,ord) join pg_attribute a on a.attrelid=c.conrelid and a.attnum=u.attnum) cols from pg_constraint c join pg_namespace n on n.oid=c.connamespace where c.contype='f' and n.nspname='clinic' and not exists(select 1 from pg_index i where i.indrelid=c.conrelid and i.indisvalid and (select array_agg(k order by ord) from unnest(i.indkey::smallint[]) with ordinality z(k,ord) where ord<=cardinality(c.conkey))=c.conkey) loop
 execute format('create index if not exists %I on %s(%s)',left(r.conname,55)||'_idx',r.tbl,r.cols);
 end loop;
end $$;
