insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types) values('clinical','clinical',false,10485760,array['image/jpeg','image/png','image/webp','application/pdf']) on conflict(id) do nothing;

create function public.media_prepare(media_id uuid,patient_id uuid,consent_id uuid,title text,body_site text,mime_type text,content_hash text) returns jsonb language plpgsql security invoker set search_path='' as $$
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
end $$;
grant execute on function public.media_prepare(uuid,uuid,uuid,text,text,text,text) to authenticated;

create function public.media_finalize(media_id uuid,approved boolean) returns void language plpgsql security invoker set search_path='' as $$
begin
 if current_user<>'service_role' then raise exception 'Server-only operation' using errcode='42501'; end if;
 update clinic.media set status=case when approved then 'ready' else 'rejected' end where id=media_id and status='pending';
end $$;
grant execute on function public.media_finalize(uuid,boolean) to service_role;

create function public.media_access(media_id uuid) returns text language plpgsql security invoker set search_path='' as $$
declare m clinic.media;
begin
 perform clinic.require_permission('media');
 select * into m from clinic.media where id=media_id and organization_id=clinic.org_id() and status='ready';
 if not found then raise exception 'Media not found or not ready' using errcode='42501'; end if;
 if not coalesce((select granted from clinic.consents where patient_id=m.patient_id and purpose=m.purpose order by created_at desc limit 1),false) then raise exception 'Current consent does not permit access' using errcode='42501'; end if;
 perform clinic.log_access('MEDIA_ACCESS',m.id,'media'); return m.object_key;
end $$;
grant execute on function public.media_access(uuid) to authenticated;
