-- Development reference. Deployment uses generated migrations.
alter table clinic.memberships add column username text unique check(username ~ '^[a-z][a-z0-9._-]{2,31}$');
alter table clinic.memberships add column password_change_required boolean not null default false;
alter table clinic.memberships add column credential_valid_after timestamptz;
update clinic.memberships m set username=split_part(u.email,'@',1) from auth.users u
 where u.id=m.user_id and u.email like '%@clinicos.test' and split_part(u.email,'@',1) ~ '^[a-z][a-z0-9._-]{2,31}$';
revoke update on clinic.memberships from authenticated;
grant update(role,active) on clinic.memberships to authenticated;

create function clinic.session_valid() returns boolean language sql stable security definer set search_path='' as $$
 select exists(select 1 from auth.sessions s join clinic.memberships m on m.user_id=s.user_id
 where s.id=nullif(auth.jwt()->>'session_id','')::uuid and s.user_id=auth.uid() and m.active
 and m.organization_id=clinic.org_id() and (m.credential_valid_after is null or s.created_at>m.credential_valid_after))
$$;
revoke all on function clinic.session_valid() from public,anon;
grant execute on function clinic.session_valid() to authenticated;

create or replace function clinic.allowed(perm text) returns boolean language sql stable security definer set search_path='' as $$
 select clinic.session_valid() and exists(select 1 from clinic.memberships m join clinic.organizations o on o.id=m.organization_id
 where m.user_id=auth.uid() and m.active and m.organization_id=clinic.org_id() and not m.password_change_required
 and perm=any(clinic.permissions(m.role)) and (not o.require_mfa or coalesce(auth.jwt()->>'aal','aal1')='aal2'))
$$;

create function public.account_status() returns jsonb language plpgsql stable security invoker set search_path='' as $$
declare m clinic.memberships;
begin
 if not clinic.session_valid() then raise exception 'Your session is no longer valid. Sign in again.' using errcode='42501'; end if;
 select * into m from clinic.memberships where user_id=auth.uid() and organization_id=clinic.org_id() and active;
 return jsonb_build_object('username',m.username,'password_change_required',m.password_change_required);
end $$;
revoke all on function public.account_status() from public,anon;
grant execute on function public.account_status() to authenticated;

create function public.staff_target(member_id uuid) returns jsonb language plpgsql stable security invoker set search_path='' as $$
declare m clinic.memberships; actor_role text;
begin
 perform clinic.require_permission('staff');
 select role into actor_role from clinic.memberships where user_id=auth.uid() and organization_id=clinic.org_id();
 select * into m from clinic.memberships where user_id=member_id and organization_id=clinic.org_id();
 if not found or m.user_id=auth.uid() or m.role='owner' or (actor_role<>'owner' and m.role in ('administrator','accountant')) then
 raise exception 'This account cannot be reset by your role.' using errcode='42501'; end if;
 return jsonb_build_object('user_id',m.user_id,'username',m.username,'role',m.role);
end $$;
revoke all on function public.staff_target(uuid) from public,anon;
grant execute on function public.staff_target(uuid) to authenticated;

create function public.staff_provision(org_id uuid,member_id uuid,member_name text,member_role text,member_username text) returns uuid language plpgsql security invoker set search_path='' as $$
declare r uuid;
begin
 if current_user<>'service_role' then raise exception 'Server-only operation' using errcode='42501'; end if;
 if member_role not in ('doctor','receptionist','administrator','accountant') or length(trim(member_name)) not between 2 and 160 then raise exception 'Invalid account'; end if;
 insert into clinic.memberships(organization_id,user_id,display_name,role,username,password_change_required)
 values(org_id,member_id,trim(member_name),member_role,member_username,true)
 on conflict(organization_id,user_id) do nothing returning id into r;
 if r is null then select id into r from clinic.memberships where organization_id=org_id and user_id=member_id and username=member_username and role=member_role and display_name=trim(member_name); end if;
 if r is null then raise exception 'Account creation does not match its earlier request'; end if;
 return r;
end $$;
revoke all on function public.staff_provision(uuid,uuid,text,text,text) from public,anon,authenticated;
grant execute on function public.staff_provision(uuid,uuid,text,text,text) to service_role;

create function clinic.staff_creation_identity(login_name text,operation_id uuid,actor_id uuid,content_fingerprint text) returns uuid language sql stable security definer set search_path='' as $$
 select id from auth.users where auth.jwt()->>'role'='service_role' and email=login_name||'@clinicos.test'
 and raw_app_meta_data->>'creation_request_id'=operation_id::text and raw_app_meta_data->>'creation_actor_id'=actor_id::text
 and raw_app_meta_data->>'creation_fingerprint'=content_fingerprint
$$;
revoke all on function clinic.staff_creation_identity(text,uuid,uuid,text) from public,anon,authenticated;
grant execute on function clinic.staff_creation_identity(text,uuid,uuid,text) to service_role;
create function public.staff_creation_lookup(login_name text,operation_id uuid,actor_id uuid,content_fingerprint text) returns uuid language sql stable security invoker set search_path='' as $$
 select clinic.staff_creation_identity(login_name,operation_id,actor_id,content_fingerprint)
$$;
revoke all on function public.staff_creation_lookup(text,uuid,uuid,text) from public,anon,authenticated;
grant execute on function public.staff_creation_lookup(text,uuid,uuid,text) to service_role;

create function public.staff_password_state(org_id uuid,member_id uuid,action text) returns void language plpgsql security invoker set search_path='' as $$
begin
 if current_user<>'service_role' then raise exception 'Server-only operation' using errcode='42501'; end if;
 if action='reset' then
 update clinic.memberships set password_change_required=true,credential_valid_after=clock_timestamp() where organization_id=org_id and user_id=member_id;
 elsif action='complete' then
 update clinic.memberships set password_change_required=false where organization_id=org_id and user_id=member_id;
 else raise exception 'Invalid credential operation'; end if;
 if not found then raise exception 'Account not found'; end if;
end $$;
revoke all on function public.staff_password_state(uuid,uuid,text) from public,anon,authenticated;
grant execute on function public.staff_password_state(uuid,uuid,text) to service_role;
