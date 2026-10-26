alter table clinic.organizations add column clinical_access_scope text not null default 'organization' check(clinical_access_scope in ('organization','assigned'));
create table clinic.additional_roles (
 id uuid primary key default gen_random_uuid(),organization_id uuid not null,member_id uuid not null,role text not null check(role in ('doctor','receptionist','accountant')),
 reason text not null check(length(trim(reason))>=5),created_by uuid not null default auth.uid(),created_at timestamptz not null default now(),
 foreign key(organization_id,member_id) references clinic.memberships(organization_id,id),unique(organization_id,id)
);
create table clinic.role_revocations (
 id uuid primary key default gen_random_uuid(),organization_id uuid not null,grant_id uuid not null,reason text not null check(length(trim(reason))>=5),
 created_by uuid not null default auth.uid(),created_at timestamptz not null default now(),foreign key(organization_id,grant_id) references clinic.additional_roles(organization_id,id),unique(grant_id),unique(organization_id,id)
);
create table clinic.approval_limits (
 id uuid primary key default gen_random_uuid(),organization_id uuid not null,member_id uuid not null,currency text not null check(currency in ('IQD','USD')),
 max_amount numeric(18,3) not null check(max_amount>=0 and max_amount<>'NaN'::numeric and (currency<>'USD' or max_amount=round(max_amount,2))),
 reason text not null check(length(trim(reason))>=5),created_by uuid not null default auth.uid(),created_at timestamptz not null default now(),
 foreign key(organization_id,member_id) references clinic.memberships(organization_id,id),unique(organization_id,id)
);
create table clinic.care_assignments (
 id uuid primary key default gen_random_uuid(),organization_id uuid not null,patient_id uuid not null,doctor_id uuid not null references auth.users,
 reason text not null check(length(trim(reason))>=5),created_by uuid not null default auth.uid(),created_at timestamptz not null default now(),
 foreign key(organization_id,patient_id) references clinic.patients(organization_id,id),unique(organization_id,id)
);
create table clinic.care_revocations (
 id uuid primary key default gen_random_uuid(),organization_id uuid not null,assignment_id uuid not null,reason text not null check(length(trim(reason))>=5),
 created_by uuid not null default auth.uid(),created_at timestamptz not null default now(),foreign key(organization_id,assignment_id) references clinic.care_assignments(organization_id,id),unique(assignment_id),unique(organization_id,id)
);
create table clinic.retention_rules (
 id uuid primary key default gen_random_uuid(),organization_id uuid not null references clinic.organizations,
 record_type text not null check(record_type in ('clinical','media','finance','audit','contact')),
 retain_days integer not null check(retain_days>0),policy_reference text not null check(length(trim(policy_reference))>=5),
 approved_at timestamptz,approved_by uuid references auth.users,created_by uuid not null default auth.uid(),created_at timestamptz not null default now(),unique(organization_id,id)
);
create table clinic.legal_holds (
 id uuid primary key default gen_random_uuid(),organization_id uuid not null,patient_id uuid not null,reason text not null check(length(trim(reason))>=5),
 created_by uuid not null default auth.uid(),created_at timestamptz not null default now(),foreign key(organization_id,patient_id) references clinic.patients(organization_id,id),unique(organization_id,id)
);
create table clinic.hold_releases (
 id uuid primary key default gen_random_uuid(),organization_id uuid not null,hold_id uuid not null,reason text not null check(length(trim(reason))>=5),
 created_by uuid not null default auth.uid(),created_at timestamptz not null default now(),foreign key(organization_id,hold_id) references clinic.legal_holds(organization_id,id),unique(hold_id),unique(organization_id,id)
);
create table clinic.access_events (
 id uuid primary key default gen_random_uuid(),organization_id uuid not null references clinic.organizations,action text not null,target_id uuid,
 reason text not null,created_by uuid not null default auth.uid(),created_at timestamptz not null default now(),unique(organization_id,id)
);
do $$declare t text;begin foreach t in array array['additional_roles','role_revocations','approval_limits','care_assignments','care_revocations','retention_rules','legal_holds','hold_releases','access_events'] loop
 execute format('alter table clinic.%I enable row level security',t);execute format('grant select,insert,update on clinic.%I to authenticated',t);execute format('grant all on clinic.%I to service_role',t);
 execute format('create policy administrative_scope on clinic.%I to authenticated using(organization_id=(select clinic.org_id()) and (select clinic.allowed(''staff''))) with check(organization_id=(select clinic.org_id()) and (select clinic.allowed(''staff'')))',t);
 execute format('create trigger audit_write after insert or update on clinic.%I for each row execute function clinic.audit_write()',t);
 if t<>'retention_rules' then execute format('create trigger immutable_record before update or delete on clinic.%I for each row execute function clinic.immutable_record()',t);end if;
 end loop;end $$;
create trigger retention_approval_lock before update or delete on clinic.retention_rules for each row execute function clinic.protect_mapping();

create function clinic.extra_roles(user_id uuid) returns text[] language sql stable security definer set search_path='' as $$
 select coalesce(array_agg(distinct g.role),array[]::text[]) from clinic.additional_roles g join clinic.memberships m on m.id=g.member_id
 where m.user_id=extra_roles.user_id and m.organization_id=clinic.org_id() and m.active and auth.uid() is not null
 and not exists(select 1 from clinic.role_revocations r where r.grant_id=g.id)
$$;
revoke all on function clinic.extra_roles(uuid) from public,anon;
grant execute on function clinic.extra_roles(uuid) to authenticated;
create function clinic.has_role(user_id uuid,role_name text) returns boolean language sql stable security definer set search_path='' as $$
 select exists(select 1 from clinic.memberships m where m.user_id=has_role.user_id and m.organization_id=clinic.org_id() and m.active and auth.uid() is not null and (m.role=role_name or role_name=any(clinic.extra_roles(m.user_id))))
$$;
revoke all on function clinic.has_role(uuid,text) from public,anon;
grant execute on function clinic.has_role(uuid,text) to authenticated;
create function clinic.user_permissions() returns text[] language sql stable security definer set search_path='' as $$
 select coalesce(array_agg(distinct p),array[]::text[]) from clinic.memberships m cross join lateral unnest(array[m.role]||clinic.extra_roles(m.user_id)) r(role) cross join lateral unnest(clinic.permissions(r.role)) p
 where m.organization_id=clinic.org_id() and m.user_id=auth.uid() and m.active
$$;
revoke all on function clinic.user_permissions() from public,anon;
grant execute on function clinic.user_permissions() to authenticated;
create or replace function clinic.allowed(perm text) returns boolean language sql stable security definer set search_path='' as $$
 select clinic.session_valid() and exists(select 1 from clinic.memberships m join clinic.organizations o on o.id=m.organization_id
 where m.user_id=auth.uid() and m.active and m.organization_id=clinic.org_id() and not m.password_change_required
 and perm=any(clinic.user_permissions()) and (not o.require_mfa or coalesce(auth.jwt()->>'aal','aal1')='aal2'))
$$;
create function clinic.canonical_patient_id(patient_id uuid) returns uuid language sql stable security definer set search_path='' as $$
 with recursive linked(id,merged_into) as (select p.id,p.merged_into from clinic.patients p where p.id=canonical_patient_id.patient_id and p.organization_id=clinic.org_id() and auth.uid() is not null
 union select p.id,p.merged_into from clinic.patients p join linked l on p.id=l.merged_into where p.organization_id=clinic.org_id()) select id from linked where merged_into is null limit 1
$$;
revoke all on function clinic.canonical_patient_id(uuid) from public,anon;
grant execute on function clinic.canonical_patient_id(uuid) to authenticated;
create function clinic.patient_care_access(patient_id uuid) returns boolean language sql stable security definer set search_path='' as $$
 select clinic.allowed('clinical') and exists(select 1 from clinic.organizations o where o.id=clinic.org_id() and clinic.canonical_patient_id(patient_care_access.patient_id) is not null
 and (o.clinical_access_scope='organization' or exists(select 1 from clinic.care_assignments a where a.organization_id=o.id and a.doctor_id=auth.uid() and a.patient_id in(select id from clinic.patient_ids(clinic.canonical_patient_id(patient_care_access.patient_id))) and not exists(select 1 from clinic.care_revocations r where r.assignment_id=a.id))))
$$;
revoke all on function clinic.patient_care_access(uuid) from public,anon;
grant execute on function clinic.patient_care_access(uuid) to authenticated;
create function clinic.encounter_care_access(encounter_id uuid) returns boolean language sql stable security definer set search_path='' as $$
 select exists(select 1 from clinic.encounters e where e.id=encounter_care_access.encounter_id and e.organization_id=clinic.org_id() and clinic.patient_care_access(e.patient_id))
$$;
revoke all on function clinic.encounter_care_access(uuid) from public,anon;
grant execute on function clinic.encounter_care_access(uuid) to authenticated;
create function clinic.require_approval(amount numeric,currency text) returns void language plpgsql stable security definer set search_path='' as $$
declare limit_amount numeric;
begin
 if not clinic.allowed('approve') or amount is null or amount<0 or amount='NaN'::numeric then raise exception 'Approval permission required' using errcode='42501';end if;
 select l.max_amount into limit_amount from clinic.approval_limits l join clinic.memberships m on m.id=l.member_id where m.user_id=auth.uid() and l.organization_id=clinic.org_id() and l.currency=require_approval.currency order by l.created_at desc,l.id desc limit 1;
 if found and amount>limit_amount then raise exception 'Amount exceeds your approval limit in this currency' using errcode='42501';end if;
end $$;
revoke all on function clinic.require_approval(numeric,text) from public,anon;
grant execute on function clinic.require_approval(numeric,text) to authenticated;

-- Care scope is checked at the protected table boundary as well as in RPCs.
do $$declare t text;col text;expr text;begin
 for t,col in select * from(values ('encounters','patient_id'),('procedures','patient_id'),('media','patient_id'),('tasks','patient_id'),('results','patient_id'),('clinical_facts','patient_id'),('addenda','encounter_id'),('prescription_items','encounter_id')) x(t,c) loop
 expr:=case when col='patient_id' then 'clinic.patient_care_access(patient_id)' else 'clinic.encounter_care_access(encounter_id)' end;
 execute format('create policy care_scope_guard on clinic.%I as restrictive to authenticated using(%s) with check(%s)',t,expr,expr);
 end loop;
end $$;
create policy consent_care_guard on clinic.consents as restrictive to authenticated using(purpose='communication' or clinic.patient_care_access(patient_id)) with check(purpose='communication' or clinic.patient_care_access(patient_id));
create policy performed_care_guard on clinic.performed_services as restrictive to authenticated using((select clinic.allowed('billing')) or clinic.patient_care_access(patient_id)) with check((select clinic.allowed('billing')) or clinic.patient_care_access(patient_id));

create function public.access_workflow(kind text,payload jsonb,request_id uuid) returns jsonb language plpgsql security invoker set search_path='' as $$
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
end $$;
revoke all on function public.access_workflow(text,jsonb,uuid) from public,anon;
grant execute on function public.access_workflow(text,jsonb,uuid) to authenticated;
create function public.care_team(patient_id uuid) returns jsonb language plpgsql stable security invoker set search_path='' as $$begin
 perform clinic.require_permission('staff');return coalesce((select jsonb_agg(to_jsonb(a)||jsonb_build_object('display_name',m.display_name)) from clinic.care_assignments a join clinic.memberships m on m.user_id=a.doctor_id and m.organization_id=a.organization_id where a.organization_id=clinic.org_id() and a.patient_id=care_team.patient_id and not exists(select 1 from clinic.care_revocations r where r.assignment_id=a.id)),'[]');end $$;
revoke all on function public.care_team(uuid) from public,anon;
grant execute on function public.care_team(uuid) to authenticated;
create function public.patient_export(patient_id uuid,reason text) returns jsonb language plpgsql security invoker set search_path='' as $$declare record jsonb;export_id uuid;begin
 perform clinic.require_permission('clinical.export');
 if not clinic.patient_care_access(patient_id) or length(trim(coalesce(reason,'')))<10 then raise exception 'An authorized patient and documented export purpose are required' using errcode='42501';end if;
 record:=public.clinical_record(patient_id);insert into clinic.patient_exports(organization_id,patient_id,purpose) values(clinic.org_id(),patient_id,reason) returning id into export_id;
 perform clinic.log_access('PATIENT_EXPORT',patient_id,'care_packet');
 return record||jsonb_build_object('export_id',export_id,'documents',coalesce((select jsonb_agg(d) from clinic.patient_documents d where d.patient_id in(select id from clinic.patient_ids(patient_export.patient_id))),'[]'),'patient',public.patient_profile(patient_id),'exported_at',now(),'purpose',reason,
 'consents',coalesce((select jsonb_agg(c) from clinic.consents c where c.patient_id in(select id from clinic.patient_ids(patient_export.patient_id))),'[]'),
 'results',coalesce((select jsonb_agg(r) from clinic.results r where r.patient_id in(select id from clinic.patient_ids(patient_export.patient_id))),'[]'),
 'media',coalesce((select jsonb_agg(to_jsonb(m)-'object_key'-'preview_key'-'preview_sha256') from clinic.media m where m.patient_id in(select id from clinic.patient_ids(patient_export.patient_id))),'[]'));
end $$;
revoke all on function public.patient_export(uuid,text) from public,anon;
grant execute on function public.patient_export(uuid,text) to authenticated;

create function clinic.organization_care_access() returns boolean language sql stable security definer set search_path='' as $$
 select clinic.allowed('clinical') and exists(select 1 from clinic.organizations where id=clinic.org_id() and clinical_access_scope='organization')
$$;
revoke all on function clinic.organization_care_access() from public,anon;
grant execute on function clinic.organization_care_access() to authenticated;
do $$declare t text;col text;expr text;begin
 for t,col in select * from(values ('encounters','patient_id'),('procedures','patient_id'),('media','patient_id'),('tasks','patient_id'),('results','patient_id'),('clinical_facts','patient_id'),('addenda','encounter_id'),('prescription_items','encounter_id')) x(t,c) loop
 expr:='(select clinic.organization_care_access()) or '||case when col='patient_id' then 'clinic.patient_care_access(patient_id)' else 'clinic.encounter_care_access(encounter_id)' end;
 execute format('alter policy care_scope_guard on clinic.%I using(%s) with check(%s)',t,expr,expr);end loop;end $$;
alter policy consent_care_guard on clinic.consents using(purpose='communication' or (select clinic.organization_care_access()) or clinic.patient_care_access(patient_id)) with check(purpose='communication' or (select clinic.organization_care_access()) or clinic.patient_care_access(patient_id));
alter policy performed_care_guard on clinic.performed_services using((select clinic.allowed('billing')) or (select clinic.organization_care_access()) or clinic.patient_care_access(patient_id)) with check((select clinic.allowed('billing')) or (select clinic.organization_care_access()) or clinic.patient_care_access(patient_id));

create function public.retention_state() returns jsonb language plpgsql stable security invoker set search_path='' as $$begin
 perform clinic.require_permission('staff');
 return jsonb_build_object('rules',coalesce((select jsonb_agg(r order by created_at desc,id desc) from clinic.retention_rules r where r.organization_id=clinic.org_id()),'[]'),
 'holds',coalesce((select jsonb_agg(to_jsonb(h)||jsonb_build_object('released',exists(select 1 from clinic.hold_releases r where r.hold_id=h.id))) from clinic.legal_holds h where h.organization_id=clinic.org_id()),'[]'));
end $$;
revoke all on function public.retention_state() from public,anon;
grant execute on function public.retention_state() to authenticated;
