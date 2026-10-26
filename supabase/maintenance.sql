-- Maintenance preserves records and ready originals. Only failed temporary bytes expire.
alter table clinic.media add column rejected_at timestamptz;
update clinic.media set rejected_at=clock_timestamp() where status='rejected';
create function clinic.media_rejection_time() returns trigger language plpgsql security invoker set search_path='' as $$begin
 if new.status='rejected' and old.status<>'rejected' then new.rejected_at:=clock_timestamp();end if;
 return new;
end $$;
revoke all on function clinic.media_rejection_time() from public,anon;
create trigger rejection_time before update of status on clinic.media for each row execute function clinic.media_rejection_time();
create table clinic.media_cleanup_events (
 id uuid primary key default gen_random_uuid(),organization_id uuid not null,media_id uuid not null,object_key text not null unique,
 created_at timestamptz not null default now(),foreign key(organization_id,media_id) references clinic.media(organization_id,id)
);
alter table clinic.media_cleanup_events enable row level security;
grant all on clinic.media_cleanup_events to service_role;
create trigger immutable_record before update or delete on clinic.media_cleanup_events for each row execute function clinic.immutable_record();
create function public.media_maintenance(expire_abandoned boolean default false) returns jsonb language plpgsql security invoker set search_path='' as $$
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
end $$;
revoke all on function public.media_maintenance(boolean) from public,anon,authenticated;
grant execute on function public.media_maintenance(boolean) to service_role;
create function public.media_cleanup_record(media_id uuid,object_key text) returns void language plpgsql security invoker set search_path='' as $$declare m clinic.media;begin
 if current_user<>'service_role' then raise exception 'Server-only maintenance' using errcode='42501';end if;
 select * into m from clinic.media where id=media_id and status='rejected' and rejected_at<clock_timestamp()-interval '30 days';
 if not found or not (object_key=m.object_key or object_key like m.object_key||'.preview-%.png') then raise exception 'Cleanup is limited to expired rejected uploads';end if;
 if exists(select 1 from clinic.media where status='ready' and (clinic.media.object_key=media_cleanup_record.object_key or preview_key=media_cleanup_record.object_key)) then raise exception 'Ready media must be preserved';end if;
 insert into clinic.media_cleanup_events(organization_id,media_id,object_key) values(m.organization_id,m.id,media_cleanup_record.object_key) on conflict on constraint media_cleanup_events_object_key_key do nothing;
end $$;
revoke all on function public.media_cleanup_record(uuid,text) from public,anon,authenticated;
grant execute on function public.media_cleanup_record(uuid,text) to service_role;
