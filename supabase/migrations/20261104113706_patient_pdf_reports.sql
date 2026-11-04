-- PDF reports use the existing media permissions, patient scope and audit trail.
SET local check_function_bodies = off;

CREATE OR REPLACE FUNCTION public.history_page (
  record_type text,
  patient_id  uuid    DEFAULT NULL::uuid,
  search_term text    DEFAULT ''::text,
  cursor_id   uuid    DEFAULT NULL::uuid,
  page_size   integer DEFAULT 50
)
  RETURNS jsonb
  LANGUAGE plpgsql
  SET search_path TO ''
  AS $function$
declare o uuid:=clinic.org_id();tbl text;perm text;items jsonb;has_patient boolean;sz integer:=least(greatest(coalesce(page_size,50),1),100);more boolean;
begin
 select x.t,x.p,x.patient into tbl,perm,has_patient from (values
 ('encounters','clinical',true),('procedures','clinical',true),('patient_documents','clinical',true),('tasks','results',true),('results','results',true),('media','media',true),('consents','clinical',true),
 ('cash_movements','finance',false),('tills','billing',false),('stock_lots','inventory.read',false),('stock_movements','inventory.read',false),('packages','billing',true),
 ('services','schedule',false),('inventory_products','inventory.read',false),('suppliers','inventory',false),('document_templates','patients',false),('clinical_facts','clinical',true),('contact_log','patients',true),('performed_services','billing',true),
 ('clinician_availability','schedule',false),('clinic_resources','schedule',false)) x(t,p,patient) where x.t=case when record_type='media_documents' then 'media' else record_type end;
 if tbl is null then raise exception 'Invalid history type'; end if;
 if not clinic.allowed(perm) and not (tbl in ('stock_lots','stock_movements','inventory_products') and clinic.allowed('inventory')) and not (tbl='performed_services' and clinic.allowed('clinical')) and not (tbl in ('tills','suppliers') and clinic.allowed('finance')) then raise exception 'Permission denied' using errcode='42501'; end if;
 if patient_id is not null and (not has_patient or not exists(select 1 from clinic.patients p where p.id=history_page.patient_id and p.organization_id=o)) then raise exception 'Patient unavailable' using errcode='42501';end if;
 execute format($q$with records as materialized (
 select r.id,coalesce((to_jsonb(r)->>'created_at')::timestamptz,(to_jsonb(r)->>'opened_at')::timestamptz,'-infinity'::timestamptz) sort_at,
 (to_jsonb(r)->>'patient_id')::uuid patient_id,to_jsonb(r) value
 from clinic.%I r where r.organization_id=$1 and ($7<>'media_documents' or to_jsonb(r)->>'mime_type'='application/pdf') and ($2 is null or (to_jsonb(r)->>'patient_id')::uuid in (select id from clinic.patient_ids($2)))
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
end $function$;

revoke all on function public.history_page(text,uuid,text,uuid,integer) from public,anon;
grant execute on function public.history_page(text,uuid,text,uuid,integer) to authenticated;
