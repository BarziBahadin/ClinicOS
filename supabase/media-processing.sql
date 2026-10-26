alter table clinic.media add column preview_key text;
alter table clinic.media add column preview_sha256 text check(preview_sha256 ~ '^[a-f0-9]{64}$');
alter table clinic.media add column processing_note text;
create function public.media_complete(media_id uuid,preview_path text,preview_hash text,note text) returns void language plpgsql security invoker set search_path='' as $$
declare m clinic.media;
begin
 if current_user<>'service_role' then raise exception 'Server-only operation' using errcode='42501';end if;
 select * into m from clinic.media where id=media_id;
 if not found or m.status<>'pending' then raise exception 'Pending media unavailable';end if;
 if m.mime_type<>'application/pdf' and (preview_path is null or (preview_hash is null or preview_hash !~ '^[a-f0-9]{64}$') or preview_path is distinct from m.object_key||'.preview-'||preview_hash||'.png') then raise exception 'A verified image preview is required';end if;
 update clinic.media set status='ready',preview_key=preview_path,preview_sha256=preview_hash,processing_note=note where id=media_id and status='pending';
end $$;
revoke all on function public.media_complete(uuid,text,text,text) from public,anon,authenticated;
grant execute on function public.media_complete(uuid,text,text,text) to service_role;
create function public.media_access_variant(media_id uuid,original boolean default false) returns text language plpgsql security invoker set search_path='' as $$
declare original_key text;m clinic.media;
begin
 original_key:=public.media_access(media_id);
 select * into m from clinic.media where id=media_id and organization_id=clinic.org_id();
 if original or m.mime_type='application/pdf' then return original_key;end if;
 if m.preview_key is null then raise exception 'Generate a preview or open the original image';end if;
 perform clinic.log_access('MEDIA_PREVIEW',media_id,'media');return m.preview_key;
end $$;
revoke all on function public.media_access_variant(uuid,boolean) from public,anon;
grant execute on function public.media_access_variant(uuid,boolean) to authenticated;
create function public.media_preview_attach(media_id uuid,preview_path text,preview_hash text,note text) returns void language plpgsql security invoker set search_path='' as $$
declare m clinic.media;begin
 if current_user<>'service_role' then raise exception 'Server-only operation' using errcode='42501';end if;
 select * into m from clinic.media where id=media_id and status='ready' and mime_type<>'application/pdf';
 if not found or (preview_hash is null or preview_hash !~ '^[a-f0-9]{64}$') or preview_path is distinct from m.object_key||'.preview-'||preview_hash||'.png' then raise exception 'Invalid preview attachment';end if;
 if m.preview_key is not null and m.preview_key<>preview_path then raise exception 'An approved preview already exists';end if;
 update clinic.media set preview_key=preview_path,preview_sha256=preview_hash,processing_note=note where id=media_id and preview_key is null;
end $$;
revoke all on function public.media_preview_attach(uuid,text,text,text) from public,anon,authenticated;
grant execute on function public.media_preview_attach(uuid,text,text,text) to service_role;
create function public.media_cancel_upload(media_id uuid,reason text) returns void language plpgsql security invoker set search_path='' as $$begin
 perform clinic.require_permission('media');
 if length(trim(coalesce(reason,'')))<5 then raise exception 'Document why the pending upload is cancelled';end if;
 update clinic.media set status='rejected',processing_note=reason where id=media_id and organization_id=clinic.org_id() and uploaded_by=auth.uid() and status='pending';
 if not found then raise exception 'Your pending upload is unavailable';end if;
end $$;
revoke all on function public.media_cancel_upload(uuid,text) from public,anon;
grant execute on function public.media_cancel_upload(uuid,text) to authenticated;

create function public.current_photography_consent(patient_id uuid) returns jsonb language plpgsql stable security invoker set search_path='' as $$declare consent clinic.consents;begin
 perform clinic.require_permission('media');
 select * into consent from clinic.consents c where c.organization_id=clinic.org_id() and c.patient_id=current_photography_consent.patient_id and c.purpose='care_photography' order by created_at desc,id desc limit 1;
 if not found or not consent.granted then return '[]'::jsonb;end if;
 return jsonb_build_array(jsonb_build_object('id',consent.id,'template_version',consent.template_version,'created_at',consent.created_at));end $$;
revoke all on function public.current_photography_consent(uuid) from public,anon;
grant execute on function public.current_photography_consent(uuid) to authenticated;
