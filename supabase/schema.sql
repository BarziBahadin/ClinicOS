-- Canonical schema. Apply to local Postgres for development, then generate migrations.
create schema clinic;
revoke all on schema clinic from public, anon;
grant usage on schema clinic to authenticated, service_role;
alter default privileges in schema clinic revoke all on tables from public, anon;
alter default privileges revoke execute on functions from public;

create table clinic.organizations (
 id uuid primary key default gen_random_uuid(), name text not null check(length(name) between 2 and 160),
 country text not null default 'IQ' check(country='IQ'), timezone text not null default 'Asia/Baghdad',
 base_currency text not null default 'IQD' check(base_currency in ('IQD','USD')),
 require_mfa boolean not null default true, allow_cross_currency boolean not null default true, created_at timestamptz not null default now()
);
create table clinic.branches (id uuid primary key default gen_random_uuid(), organization_id uuid not null references clinic.organizations, name text not null, unique(organization_id,id));
create table clinic.memberships (
 id uuid primary key default gen_random_uuid(), organization_id uuid not null references clinic.organizations,
 user_id uuid not null references auth.users, display_name text not null,
 role text not null check(role in ('owner','administrator','doctor','receptionist','accountant')),
 active boolean not null default true, unique(organization_id,user_id), unique(organization_id,id)
);
create index membership_identity on clinic.memberships(user_id,organization_id) where active;

create function clinic.org_id() returns uuid language sql stable security definer set search_path='' as $$
 select m.organization_id from clinic.memberships m where m.user_id=(select auth.uid()) and m.active order by m.organization_id limit 1
$$;
create function clinic.permissions(p_role text) returns text[] language sql immutable set search_path='' as $$
 select case p_role
 when 'owner' then array['patients','schedule','billing','finance','approve','inventory','staff','settings','audit','export','payroll']
 when 'administrator' then array['patients','schedule','billing','finance','inventory','audit']
 when 'doctor' then array['patients','schedule','clinical','media','results','inventory.read']
 when 'receptionist' then array['patients','schedule','billing']
 when 'accountant' then array['finance','approve','export','audit','payroll'] else array[]::text[] end
$$;
create function clinic.allowed(perm text) returns boolean language sql stable security definer set search_path='' as $$
 select exists(select 1 from clinic.memberships m join clinic.organizations o on o.id=m.organization_id
 where m.user_id=(select auth.uid()) and m.active and m.organization_id=clinic.org_id()
 and perm=any(clinic.permissions(m.role)) and (not o.require_mfa or coalesce(auth.jwt()->>'aal','aal1')='aal2'))
$$;
create function clinic.require_permission(perm text) returns void language plpgsql stable security invoker set search_path='' as $$
begin if not clinic.allowed(perm) then raise exception 'Permission denied or multi-factor verification required' using errcode='42501'; end if; end $$;
create function clinic.branch_id() returns uuid language sql stable security invoker set search_path='' as $$ select id from clinic.branches where organization_id=clinic.org_id() order by id limit 1 $$;
grant execute on function clinic.org_id(),clinic.permissions(text),clinic.allowed(text),clinic.require_permission(text),clinic.branch_id() to authenticated;

create table clinic.patients (
 id uuid primary key default gen_random_uuid(), organization_id uuid not null references clinic.organizations,
 patient_number text not null, full_name text not null check(length(trim(full_name)) between 2 and 200),
 phone text check(phone is null or phone ~ '^\+[1-9][0-9]{7,14}$'), contact_owner text,
 birth_date date, birth_precision text not null default 'unknown' check(birth_precision in ('day','month','year','unknown')),
 reported_age integer check(reported_age between 0 and 130), age_recorded_on date,
 gender text not null default 'unknown' check(gender in ('female','male','other','unknown','not_disclosed')),
 language text not null default 'ckb' check(language in ('en','ckb')), guardian_name text, guardian_relationship text,
 communication_consent boolean not null default false, merged_into uuid, version integer not null default 1,
 created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
 unique(organization_id,id), unique(organization_id,patient_number),
 foreign key(organization_id,merged_into) references clinic.patients(organization_id,id),
 check((birth_precision='unknown' and birth_date is null) or (birth_precision<>'unknown' and birth_date is not null)),
 check(birth_precision<>'year' or extract(doy from birth_date)=1),
 check(birth_precision<>'month' or extract(day from birth_date)=1),
 check(reported_age is null or age_recorded_on is not null), check(merged_into is null or merged_into<>id)
);
create index patient_search on clinic.patients(organization_id,lower(full_name));
create index patient_phone on clinic.patients(organization_id,phone);
create table clinic.patient_merges (id uuid primary key default gen_random_uuid(), organization_id uuid not null, source_id uuid not null, target_id uuid not null, reason text not null, reviewed_by uuid not null default auth.uid(), created_at timestamptz not null default now(), foreign key(organization_id,source_id) references clinic.patients(organization_id,id), foreign key(organization_id,target_id) references clinic.patients(organization_id,id));
create table clinic.contacts (
 id uuid primary key default gen_random_uuid(), organization_id uuid not null, patient_id uuid not null,
 phone text not null, owner_name text, relationship text, valid_from timestamptz not null default now(), valid_to timestamptz,
 foreign key(organization_id,patient_id) references clinic.patients(organization_id,id)
);
create table clinic.appointments (
 id uuid primary key default gen_random_uuid(), organization_id uuid not null references clinic.organizations,
 branch_id uuid not null, patient_id uuid not null, doctor_id uuid not null references auth.users,
 starts_at timestamptz not null, ends_at timestamptz not null, service_name text not null,
 status text not null default 'scheduled' check(status in ('scheduled','checked_in','in_care','completed','cancelled','no_show')),
 walk_in boolean not null default false, cancellation_reason text, checked_in_at timestamptz,
 version integer not null default 1, created_at timestamptz not null default now(),
 foreign key(organization_id,patient_id) references clinic.patients(organization_id,id),
 foreign key(organization_id,branch_id) references clinic.branches(organization_id,id), unique(organization_id,id), check(ends_at>starts_at)
);
create index appointment_day on clinic.appointments(organization_id,starts_at);
create index appointment_clinician on clinic.appointments(organization_id,doctor_id,starts_at,ends_at) where status not in ('cancelled','no_show');
create table clinic.encounters (
 id uuid primary key default gen_random_uuid(), organization_id uuid not null references clinic.organizations,
 patient_id uuid not null, doctor_id uuid not null references auth.users, branch_id uuid not null,
 appointment_id uuid, status text not null default 'draft' check(status in ('draft','signed')),
 chief_complaint text not null, history text not null default '', allergies text not null default 'Not reviewed',
 findings text not null default '', diagnosis text not null default '', plan text not null default '', prescriptions text not null default '',
 clinical_sex_notes text not null default '', birth_snapshot jsonb not null default '{}',
 signed_at timestamptz, version integer not null default 1, created_at timestamptz not null default now(),
 foreign key(organization_id,patient_id) references clinic.patients(organization_id,id),
 foreign key(organization_id,appointment_id) references clinic.appointments(organization_id,id),
 foreign key(organization_id,branch_id) references clinic.branches(organization_id,id), unique(organization_id,id)
);
create index encounter_history on clinic.encounters(organization_id,patient_id,created_at desc);
create table clinic.addenda (id uuid primary key default gen_random_uuid(), organization_id uuid not null, encounter_id uuid not null, author_id uuid not null default auth.uid(), content text not null check(length(trim(content))>0), created_at timestamptz not null default now(), foreign key(organization_id,encounter_id) references clinic.encounters(organization_id,id));
create table clinic.procedures (
 id uuid primary key default gen_random_uuid(), organization_id uuid not null, patient_id uuid not null, encounter_id uuid not null,
 name text not null, body_site text not null, product text, lot_number text, settings text, quantity numeric(18,3),
 aftercare text not null, adverse_event text, performed_by uuid not null default auth.uid(), created_at timestamptz not null default now(),
 foreign key(organization_id,patient_id) references clinic.patients(organization_id,id), foreign key(organization_id,encounter_id) references clinic.encounters(organization_id,id)
);
create table clinic.consents (
 id uuid primary key default gen_random_uuid(), organization_id uuid not null, patient_id uuid not null,
 purpose text not null check(purpose in ('care_photography','procedure','teaching','publication','marketing','communication')),
 granted boolean not null, template_version text not null, evidence text not null check(length(trim(evidence))>0),
 recorded_by uuid not null default auth.uid(), created_at timestamptz not null default now(),
 foreign key(organization_id,patient_id) references clinic.patients(organization_id,id), unique(organization_id,id)
);
create table clinic.media (
 id uuid primary key default gen_random_uuid(), organization_id uuid not null, patient_id uuid not null, encounter_id uuid,
 object_key text not null unique, title text not null, body_site text not null, purpose text not null default 'care_photography',
 mime_type text not null check(mime_type in ('image/jpeg','image/png','image/webp','application/pdf')),
 status text not null default 'pending' check(status in ('pending','ready','rejected')),
 consent_id uuid not null, created_at timestamptz not null default now(), uploaded_by uuid not null default auth.uid(),
 foreign key(organization_id,patient_id) references clinic.patients(organization_id,id),
 foreign key(organization_id,encounter_id) references clinic.encounters(organization_id,id),
 foreign key(organization_id,consent_id) references clinic.consents(organization_id,id), unique(organization_id,id)
);
create table clinic.tasks (id uuid primary key default gen_random_uuid(), organization_id uuid not null, patient_id uuid not null, title text not null, due_at timestamptz not null, assigned_to uuid not null references auth.users, completed_at timestamptz, created_at timestamptz not null default now(), foreign key(organization_id,patient_id) references clinic.patients(organization_id,id));
create index task_due on clinic.tasks(organization_id,due_at) where completed_at is null;
create table clinic.results (id uuid primary key default gen_random_uuid(), organization_id uuid not null, patient_id uuid not null, order_name text not null, body_site text not null, specimen_reference text not null, status text not null default 'ordered' check(status in ('ordered','received','reviewed','notified','closed')), result_text text, due_at timestamptz not null, assigned_to uuid not null references auth.users, version integer not null default 1, created_at timestamptz not null default now(), foreign key(organization_id,patient_id) references clinic.patients(organization_id,id));
create table clinic.services (id uuid primary key default gen_random_uuid(), organization_id uuid not null, name text not null, name_ckb text not null default '', category text not null check(category in ('medical','cosmetic')), currency text not null check(currency in ('IQD','USD')), price numeric(18,3) not null check(price>=0), duration integer not null default 30 check(duration between 5 and 480), active boolean not null default true, foreign key(organization_id) references clinic.organizations, unique(organization_id,id), check(currency<>'USD' or price=round(price,2)));
create table clinic.invoices (
 id uuid primary key default gen_random_uuid(), organization_id uuid not null, patient_id uuid not null,
 invoice_number text not null, patient_snapshot jsonb not null, currency text not null check(currency in ('IQD','USD')),
 lines jsonb not null check(jsonb_typeof(lines)='array'), total numeric(18,3) not null check(total>0),
 created_at timestamptz not null default now(), created_by uuid not null default auth.uid(),
 foreign key(organization_id,patient_id) references clinic.patients(organization_id,id), unique(organization_id,invoice_number), unique(organization_id,id), check(currency<>'USD' or total=round(total,2))
);
create table clinic.payments (
 id uuid primary key default gen_random_uuid(), organization_id uuid not null, patient_id uuid not null, invoice_id uuid,
 currency text not null check(currency in ('IQD','USD')), amount numeric(18,3) not null check(amount>0),
 method text not null check(method in ('cash','bank','card','deposit')), kind text not null default 'payment' check(kind in ('payment','deposit','deposit_application','refund')),
 original_payment_id uuid, patient_snapshot jsonb not null default '{}', invoice_amount numeric(18,3) check(invoice_amount is null or invoice_amount>0), exchange_rate numeric(18,6) check(exchange_rate is null or exchange_rate>0), reason text, created_at timestamptz not null default now(), created_by uuid not null default auth.uid(),
 foreign key(organization_id,patient_id) references clinic.patients(organization_id,id), foreign key(organization_id,invoice_id) references clinic.invoices(organization_id,id),
 foreign key(organization_id,original_payment_id) references clinic.payments(organization_id,id), unique(organization_id,id), check(currency<>'USD' or amount=round(amount,2))
);
create index payment_invoice on clinic.payments(organization_id,invoice_id);
create table clinic.credit_notes (id uuid primary key default gen_random_uuid(), organization_id uuid not null, invoice_id uuid not null, amount numeric(18,3) not null check(amount>0), reason text not null, created_at timestamptz not null default now(), foreign key(organization_id,invoice_id) references clinic.invoices(organization_id,id));
create table clinic.expenses (id uuid primary key default gen_random_uuid(), organization_id uuid not null, category text not null, supplier text not null, description text not null, currency text not null check(currency in ('IQD','USD')), amount numeric(18,3) not null check(amount>0), paid boolean not null, method text not null check(method in ('cash','bank','card')), created_at timestamptz not null default now(), unique(organization_id,id), check(currency<>'USD' or amount=round(amount,2)));
create table clinic.cash_movements (id uuid primary key default gen_random_uuid(), organization_id uuid not null, kind text not null check(kind in ('owner_contribution','owner_withdrawal','owner_loan','transfer','opening_balance','fx_exchange')), currency text not null check(currency in ('IQD','USD')), amount numeric(18,3) not null check(amount>0), method text not null check(method in ('cash','bank','card')), destination text check(destination in ('cash','bank','card')), description text not null, fx_rate numeric(18,6), related_id uuid, created_at timestamptz not null default now(), check(currency<>'USD' or amount=round(amount,2)));
create table clinic.journals (id uuid primary key default gen_random_uuid(), organization_id uuid not null, currency text not null check(currency in ('IQD','USD')), description text not null, source_type text not null, source_id uuid not null, created_at timestamptz not null default now(), unique(organization_id,source_type,source_id,currency), unique(organization_id,id));
create table clinic.journal_lines (id uuid primary key default gen_random_uuid(), organization_id uuid not null, journal_id uuid not null, account text not null check(account in ('cash','bank','card','receivable','deposits','revenue','expense','inventory','payable','equity','owner_loan','fx_clearing')), debit numeric(18,3) not null default 0, credit numeric(18,3) not null default 0, foreign key(organization_id,journal_id) references clinic.journals(organization_id,id), check(debit>=0 and credit>=0 and ((debit>0 and credit=0) or (credit>0 and debit=0))));
create index journal_account on clinic.journal_lines(organization_id,account,journal_id);
create table clinic.stock_lots (id uuid primary key default gen_random_uuid(), organization_id uuid not null, product text not null, lot_number text not null, expires_on date not null, unit text not null, quantity numeric(18,3) not null check(quantity>=0), version integer not null default 1, unique(organization_id,product,lot_number), unique(organization_id,id));
create table clinic.stock_movements (id uuid primary key default gen_random_uuid(), organization_id uuid not null, lot_id uuid not null, encounter_id uuid, quantity numeric(18,3) not null check(quantity<>0), reason text not null, created_at timestamptz not null default now(), foreign key(organization_id,lot_id) references clinic.stock_lots(organization_id,id), foreign key(organization_id,encounter_id) references clinic.encounters(organization_id,id));
create table clinic.tills (id uuid primary key default gen_random_uuid(), organization_id uuid not null, user_id uuid not null default auth.uid(), currency text not null check(currency in ('USD','IQD')), opening numeric(18,3) not null check(opening>=0), opened_at timestamptz not null default now(), closed_at timestamptz, expected numeric(18,3), counted numeric(18,3), reason text, unique(organization_id,id));
create unique index till_open on clinic.tills(organization_id,currency) where closed_at is null;
create table clinic.packages (id uuid primary key default gen_random_uuid(), organization_id uuid not null, patient_id uuid not null, name text not null, sessions integer not null check(sessions>0), remaining integer not null check(remaining>=0 and remaining<=sessions), currency text not null check(currency in ('IQD','USD')), total numeric(18,3) not null check(total>0), redeemed_value numeric(18,3) not null default 0, created_at timestamptz not null default now(), foreign key(organization_id,patient_id) references clinic.patients(organization_id,id), unique(organization_id,id));
create table clinic.package_redemptions (id uuid primary key default gen_random_uuid(), organization_id uuid not null, package_id uuid not null, encounter_id uuid not null, created_at timestamptz not null default now(), foreign key(organization_id,package_id) references clinic.packages(organization_id,id), foreign key(organization_id,encounter_id) references clinic.encounters(organization_id,id), unique(package_id,encounter_id));
create table clinic.audit_events (id uuid primary key default gen_random_uuid(), organization_id uuid not null, actor_id uuid, action text not null, entity_id uuid, entity_type text not null, created_at timestamptz not null default now());
create index audit_time on clinic.audit_events(organization_id,created_at desc);
create table clinic.requests (organization_id uuid not null, actor_id uuid not null, request_id uuid not null, fingerprint text not null, result jsonb not null, created_at timestamptz not null default now(), primary key(organization_id,actor_id,request_id));

-- Audit only identifiers and action, never clinical content or credentials.
create function clinic.audit_write() returns trigger language plpgsql security definer set search_path='' as $$
begin
 insert into clinic.audit_events(organization_id,actor_id,action,entity_id,entity_type)
 values(new.organization_id,auth.uid(),tg_op,new.id,tg_table_name);
 return new;
end $$;
create function clinic.immutable_record() returns trigger language plpgsql set search_path='' as $$ begin raise exception 'Posted records are immutable; use an amendment or reversal' using errcode='23514'; end $$;
create function clinic.protect_encounter() returns trigger language plpgsql set search_path='' as $$
begin
 if old.status='signed' then raise exception 'Signed encounter is immutable; add an addendum' using errcode='23514'; end if;
 if new.patient_id<>old.patient_id or new.doctor_id<>old.doctor_id or new.organization_id<>old.organization_id then raise exception 'Encounter identity is immutable' using errcode='23514'; end if;
 return new;
end $$;
create trigger protect_signed before update or delete on clinic.encounters for each row execute function clinic.protect_encounter();
create function clinic.valid_birth() returns trigger language plpgsql set search_path='' as $$ begin if new.birth_date>(now() at time zone 'Asia/Baghdad')::date then raise exception 'Birth date cannot be in the future' using errcode='23514'; end if; return new; end $$;
create trigger validate_birth before insert or update on clinic.patients for each row execute function clinic.valid_birth();
create function clinic.balanced_journal() returns trigger language plpgsql set search_path='' as $$
declare j uuid; d numeric; c numeric; n integer; curr text;
begin if tg_table_name='journals' then j:=new.id; else j:=new.journal_id; end if;
 select sum(debit),sum(credit),count(*) into d,c,n from clinic.journal_lines where journal_id=j;
 select currency into curr from clinic.journals where id=j;
 if n<2 or d<>c or (curr='USD' and (d<>round(d,2) or exists(select 1 from clinic.journal_lines where journal_id=j and (debit<>round(debit,2) or credit<>round(credit,2))))) then raise exception 'Unbalanced or imprecise journal' using errcode='23514'; end if;
 return null;
end $$;
create constraint trigger journal_must_balance after insert on clinic.journal_lines deferrable initially deferred for each row execute function clinic.balanced_journal();
create constraint trigger journal_header_must_balance after insert on clinic.journals deferrable initially deferred for each row execute function clinic.balanced_journal();

do $$ declare t text; begin
 foreach t in array array['patients','patient_merges','contacts','appointments','encounters','addenda','procedures','consents','media','tasks','results','services','invoices','payments','credit_notes','expenses','cash_movements','journals','journal_lines','stock_lots','stock_movements','tills','packages','package_redemptions','memberships'] loop
 execute format('create trigger audit_write after insert or update on clinic.%I for each row execute function clinic.audit_write()',t);
 end loop;
 foreach t in array array['invoices','payments','credit_notes','expenses','cash_movements','journals','journal_lines','patient_merges','addenda','consents','stock_movements','package_redemptions','audit_events'] loop
 execute format('create trigger immutable_record before update or delete on clinic.%I for each row execute function clinic.immutable_record()',t);
 end loop;
end $$;

-- All base tables are non-exposed. API functions run as the authenticated user.
do $$ declare t text; p text; begin
 for t,p in select * from (values
 ('patients','patients'),('patient_merges','patients'),('contacts','patients'),('appointments','schedule'),('encounters','clinical'),('addenda','clinical'),('procedures','clinical'),('consents','clinical'),('media','media'),('tasks','results'),('results','results'),('services','schedule'),('invoices','billing'),('payments','billing'),('credit_notes','billing'),('expenses','finance'),('cash_movements','finance'),('journals','finance'),('journal_lines','finance'),('stock_lots','inventory'),('stock_movements','inventory'),('tills','billing'),('packages','billing'),('package_redemptions','billing')) as x(t,p) loop
 execute format('alter table clinic.%I enable row level security',t);
 execute format('grant select,insert,update on clinic.%I to authenticated',t);
 execute format('create policy scoped_read on clinic.%I for select to authenticated using (organization_id=clinic.org_id() and (clinic.allowed(%L)%s))',t,p,
 case when t in ('invoices','payments','credit_notes','journals','journal_lines') then ' or clinic.allowed(''finance'') or clinic.allowed(''billing'')'
 when t='expenses' then ' and (category<>''salary'' or clinic.allowed(''payroll''))'
 when t in ('stock_lots','stock_movements') then ' or clinic.allowed(''inventory.read'')'
 when t in ('services','packages') then ' or clinic.allowed(''clinical'') or clinic.allowed(''billing'')'
 else '' end);
 execute format('create policy scoped_insert on clinic.%I for insert to authenticated with check (organization_id=clinic.org_id() and (clinic.allowed(%L)%s))',t,p,
 case when t in ('journals','journal_lines') then ' or clinic.allowed(''billing'') or clinic.allowed(''clinical'')'
 when t='stock_movements' then ' or clinic.allowed(''clinical'')'
 when t in ('payments','credit_notes') then ' or clinic.allowed(''approve'')'
 when t='consents' then ' or clinic.allowed(''patients'')'
 else '' end);
 execute format('create policy scoped_update on clinic.%I for update to authenticated using (organization_id=clinic.org_id() and (clinic.allowed(%L)%s)) with check (organization_id=clinic.org_id() and (clinic.allowed(%L)%s))',t,p,case when t='stock_lots' then ' or clinic.allowed(''clinical'')' else '' end,p,case when t='stock_lots' then ' or clinic.allowed(''clinical'')' else '' end);
 end loop;
end $$;
alter table clinic.organizations enable row level security;
alter table clinic.branches enable row level security;
alter table clinic.memberships enable row level security;
alter table clinic.audit_events enable row level security;
alter table clinic.requests enable row level security;
grant select,update on clinic.organizations to authenticated;
grant select on clinic.branches,clinic.memberships,clinic.audit_events to authenticated;
grant select,insert on clinic.requests to authenticated;
create policy organization_read on clinic.organizations for select to authenticated using(id=clinic.org_id());
create policy organization_update on clinic.organizations for update to authenticated using(id=clinic.org_id() and clinic.allowed('settings')) with check(id=clinic.org_id() and clinic.allowed('settings'));
create policy branch_read on clinic.branches for select to authenticated using(organization_id=clinic.org_id());
create policy membership_read on clinic.memberships for select to authenticated using(organization_id=clinic.org_id());
create policy audit_read on clinic.audit_events for select to authenticated using(organization_id=clinic.org_id() and clinic.allowed('audit'));
create policy request_read on clinic.requests for select to authenticated using(organization_id=clinic.org_id() and actor_id=(select auth.uid()));
create policy request_insert on clinic.requests for insert to authenticated with check(organization_id=clinic.org_id() and actor_id=(select auth.uid()));
grant all on all tables in schema clinic to service_role;

create function clinic.log_access(action text,entity uuid,entity_type text) returns void language plpgsql security definer set search_path='' as $$
begin if auth.uid() is null or clinic.org_id() is null then raise exception 'Not authenticated' using errcode='42501'; end if;
 insert into clinic.audit_events(organization_id,actor_id,action,entity_id,entity_type) values(clinic.org_id(),auth.uid(),action,entity,entity_type); end $$;
grant execute on function clinic.log_access(text,uuid,text) to authenticated;
create function clinic.post_journal(curr text,description text,source_type text,source_id uuid,debit_account text,credit_account text,value numeric) returns uuid language plpgsql security invoker set search_path='' as $$
declare j uuid;
begin
 if value<=0 or (curr='USD' and value<>round(value,2)) or (curr='IQD' and value<>round(value,3)) then raise exception 'Invalid currency precision or amount' using errcode='23514'; end if;
 insert into clinic.journals(organization_id,currency,description,source_type,source_id) values(clinic.org_id(),curr,description,source_type,source_id) returning id into j;
 insert into clinic.journal_lines(organization_id,journal_id,account,debit,credit) values(clinic.org_id(),j,debit_account,value,0),(clinic.org_id(),j,credit_account,0,value);
 return j;
end $$;
grant execute on function clinic.post_journal(text,text,text,uuid,text,text,numeric) to authenticated;

create function clinic.billing_encounter_patient(encounter_id uuid) returns uuid language sql stable security definer set search_path='' as $$
 select patient_id from clinic.encounters where id=encounter_id and organization_id=clinic.org_id() and status='signed' and clinic.allowed('billing')
$$;
grant execute on function clinic.billing_encounter_patient(uuid) to authenticated;
grant update on clinic.memberships to authenticated;
create policy membership_update on clinic.memberships for update to authenticated using(organization_id=clinic.org_id() and clinic.allowed('staff') and user_id<>(select auth.uid())) with check(organization_id=clinic.org_id() and clinic.allowed('staff') and user_id<>(select auth.uid()));
create function public.authorize(permission text) returns boolean language sql stable security invoker set search_path='' as $$select clinic.allowed(permission)$$;
grant execute on function public.authorize(text) to authenticated;
create function public.provision_member(org_id uuid,member_id uuid,member_name text,member_role text) returns uuid language plpgsql security invoker set search_path='' as $$
declare r uuid;
begin
 if current_user<>'service_role' then raise exception 'Server-only operation' using errcode='42501'; end if;
 insert into clinic.memberships(organization_id,user_id,display_name,role) values(org_id,member_id,member_name,member_role) returning id into r; return r;
end $$;
grant execute on function public.provision_member(uuid,uuid,text,text) to service_role;

create function public.workspace() returns jsonb language plpgsql security invoker set search_path='' as $$
declare o uuid:=clinic.org_id(); m clinic.memberships; r jsonb;
begin
 if o is null then raise exception 'No active clinic membership. Ask the owner to invite your account.' using errcode='42501'; end if;
 select * into m from clinic.memberships where organization_id=o and user_id=auth.uid();
 r:=jsonb_build_object('organization',(select to_jsonb(x) from clinic.organizations x where id=o),'membership',to_jsonb(m),'permissions',case when exists(select 1 from clinic.organizations where id=o and (not require_mfa or auth.jwt()->>'aal'='aal2')) then to_jsonb(clinic.permissions(m.role)) else '[]'::jsonb end);
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
 'members',coalesce((select jsonb_agg(x) from clinic.memberships x where organization_id=o),'[]'),
 'audit',coalesce((select jsonb_agg(x) from (select * from clinic.audit_events where organization_id=o order by created_at desc limit 200) x),'[]'),
 'packages',coalesce((select jsonb_agg(x) from clinic.packages x where organization_id=o),'[]'),
 'billable_encounters',clinic.billable_encounters(),
 'metrics',jsonb_build_object('today_appointments',(select count(*) from clinic.appointments where organization_id=o and (starts_at at time zone 'Asia/Baghdad')::date=(now() at time zone 'Asia/Baghdad')::date),'waiting',(select count(*) from clinic.appointments where organization_id=o and status='checked_in'),'followups_due',(select count(*) from clinic.tasks where organization_id=o and completed_at is null and due_at<=now()),'open_invoices',(select count(*) from clinic.invoices i where organization_id=o and clinic.invoice_balance(i.id)>0)),
 'trial_balance',case when clinic.allowed('finance') then coalesce((select jsonb_agg(x) from (select j.currency,l.account,sum(l.debit) debit,sum(l.credit) credit from clinic.journal_lines l join clinic.journals j on j.id=l.journal_id where j.organization_id=o group by j.currency,l.account) x),'[]') else '[]'::jsonb end);
 if clinic.allowed('clinical') then perform clinic.log_access('WORKSPACE_READ',null,'clinical_summary'); end if;
 return r;
end $$;
grant execute on function public.workspace() to authenticated;

create function public.clinical_record(patient_id uuid) returns jsonb language plpgsql security invoker set search_path='' as $$
begin
 perform clinic.require_permission('clinical');
 if not exists(select 1 from clinic.patients p where p.id=patient_id and organization_id=clinic.org_id()) then raise exception 'Patient not found'; end if;
 perform clinic.log_access('READ',patient_id,'clinical_record');
 return jsonb_build_object('encounters',coalesce((select jsonb_agg(x) from (select e.*, (select jsonb_agg(a) from clinic.addenda a where a.encounter_id=e.id) addenda from clinic.encounters e where e.patient_id in (select id from clinic.patient_ids(clinical_record.patient_id)) order by created_at desc) x),'[]'),'procedures',coalesce((select jsonb_agg(p) from clinic.procedures p where p.patient_id in (select id from clinic.patient_ids(clinical_record.patient_id))),'[]'));
end $$;
grant execute on function public.clinical_record(uuid) to authenticated;

create function public.command(kind text,payload jsonb,request_id uuid) returns jsonb language plpgsql security invoker set search_path='' as $$
declare
 o uuid:=clinic.org_id(); actor uuid:=auth.uid(); fingerprint text:=md5(kind||payload::text);
 previous clinic.requests; rid uuid; p uuid; e uuid; a uuid; amt numeric; due numeric; curr text; method text;
 row_patient clinic.patients; row_enc clinic.encounters; row_invoice clinic.invoices; row_payment clinic.payments;
 row_lot clinic.stock_lots; row_package clinic.packages; row_till clinic.tills; row_result clinic.results; row_appointment clinic.appointments;
 line jsonb; lines jsonb:='[]'; total numeric:=0; num text; result jsonb; rate numeric; v_redemption_amount numeric; v_invoice_amount numeric; v_exchange_rate numeric; v_refundable numeric; v_allocatable numeric;
begin
 if o is null or actor is null then raise exception 'Not authenticated' using errcode='42501'; end if;
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
 perform clinic.require_permission('approve');
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
 if not exists(select 1 from clinic.memberships where user_id=a and organization_id=o and active and role='doctor') then raise exception 'Select an active clinician'; end if;
 if exists(select 1 from clinic.appointments where organization_id=o and doctor_id=a and status not in ('cancelled','no_show') and starts_at<(payload->>'ends_at')::timestamptz and ends_at>(payload->>'starts_at')::timestamptz) then raise exception 'The clinician already has an appointment at this time' using errcode='23P01'; end if;
 insert into clinic.appointments(organization_id,branch_id,patient_id,doctor_id,starts_at,ends_at,service_name,walk_in,status,checked_in_at) values(o,clinic.branch_id(),p,a,(payload->>'starts_at')::timestamptz,(payload->>'ends_at')::timestamptz,payload->>'service_name',coalesce((payload->>'walk_in')::boolean,false),case when (payload->>'walk_in')::boolean then 'checked_in' else 'scheduled' end,case when (payload->>'walk_in')::boolean then now() end) returning id into rid;
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
 insert into clinic.encounters(organization_id,patient_id,doctor_id,branch_id,appointment_id,chief_complaint,history,allergies,findings,diagnosis,plan,prescriptions,clinical_sex_notes,birth_snapshot)
 values(o,p,actor,clinic.branch_id(),nullif(payload->>'appointment_id','')::uuid,payload->>'chief_complaint',coalesce(payload->>'history',''),coalesce(payload->>'allergies','Not reviewed'),coalesce(payload->>'findings',''),coalesce(payload->>'diagnosis',''),coalesce(payload->>'plan',''),coalesce(payload->>'prescriptions',''),coalesce(payload->>'clinical_sex_notes',''),jsonb_build_object('birth_date',row_patient.birth_date,'precision',row_patient.birth_precision,'reported_age',row_patient.reported_age,'age_recorded_on',row_patient.age_recorded_on)) returning id into rid;
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
 perform clinic.require_permission('approve');amt:=(payload->>'discount')::numeric;
 if amt<0 or amt>=total or amt<>round(amt,case when curr='USD' then 2 else 3 end) then raise exception 'Discount must be positive, precise and smaller than invoice total'; end if;
 if length(trim(coalesce(payload->>'discount_reason','')))<5 then raise exception 'A discount reason is required'; end if;
 lines:=lines||jsonb_build_array(jsonb_build_object('description','Discount: '||(payload->>'discount_reason'),'quantity',1,'unit_price',-amt,'amount',-amt));total:=total-amt;
 end if;
 insert into clinic.invoices(organization_id,patient_id,invoice_number,patient_snapshot,currency,lines,total) values(o,p,num,jsonb_build_object('full_name',row_patient.full_name,'patient_number',row_patient.patient_number),curr,lines,total) returning id into rid;
 perform clinic.post_journal(curr,num,'invoice',rid,'receivable','revenue',total);
 when 'invoice.credit' then
 perform clinic.require_permission('approve');a:=(payload->>'invoice_id')::uuid;
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
 perform clinic.require_permission('approve');
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
 perform clinic.require_permission('approve');
 if payload->>'kind' not in ('owner_contribution','owner_withdrawal','owner_loan','transfer','opening_balance') then raise exception 'Invalid cash movement type'; end if;
 if payload->>'kind'='transfer' and (payload->>'destination'=method or payload->>'destination' not in ('cash','bank','card') or payload->>'destination' is null) then raise exception 'Select a different destination account'; end if;
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
 update clinic.organizations set name=payload->>'name',require_mfa=coalesce((payload->>'require_mfa')::boolean,true),allow_cross_currency=coalesce((payload->>'allow_cross_currency')::boolean,allow_cross_currency) where id=o returning id into rid;
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
 a:=(payload->>'user_id')::uuid;
 if a=actor then raise exception 'You cannot change your own access'; end if;
 if payload->>'role' not in ('owner','administrator','doctor','receptionist','accountant') then raise exception 'Invalid role'; end if;
 update clinic.memberships set role=payload->>'role',active=(payload->>'active')::boolean where user_id=a and organization_id=o returning id into rid;
 when 'journal.post' then
 perform clinic.require_permission('approve');
 if amt is null or payload->>'debit_account'=payload->>'credit_account' or length(trim(coalesce(payload->>'description','')))<5 then raise exception 'Use different accounts and explain the adjustment'; end if;
 rid:=clinic.post_journal(curr,payload->>'description','manual',gen_random_uuid(),payload->>'debit_account',payload->>'credit_account',amt);
 else raise exception 'Unsupported operation: %',kind using errcode='22023';
 end case;
 if rid is null then raise exception 'No record was changed. Refresh and verify your access.' using errcode='P0002'; end if;
 result:=jsonb_build_object('id',rid);
 insert into clinic.requests(organization_id,actor_id,request_id,fingerprint,result) values(o,actor,command.request_id,fingerprint,result);
 return result;
end $$;
grant execute on function public.command(text,jsonb,uuid) to authenticated;

create function public.accounting_export() returns jsonb language plpgsql security invoker set search_path='' as $$
begin perform clinic.require_permission('export'); perform clinic.log_access('EXPORT',null,'accounting');
 return coalesce((select jsonb_agg(x) from (select j.id,j.currency,j.description,j.source_type,j.source_id,j.created_at,l.account,l.debit,l.credit from clinic.journals j join clinic.journal_lines l on l.journal_id=j.id where j.organization_id=clinic.org_id() order by j.created_at,j.id,l.id) x),'[]'); end $$;
grant execute on function public.accounting_export() to authenticated;
