create policy finance_till_read on clinic.tills for select to authenticated using(organization_id=clinic.org_id() and clinic.allowed('finance'));
grant execute on function public.billing_patient_search(text,integer) to authenticated;
create function clinic.encounter_lookup(patient_id uuid,search_term text,cursor_id uuid,status_filter text,only_author boolean) returns jsonb language plpgsql stable security definer set search_path='' as $$
declare items jsonb;more boolean;can_see_clinical boolean:=clinic.patient_care_access(patient_id);
begin
 if not (can_see_clinical or clinic.allowed('billing')) or not exists(select 1 from clinic.patients p where p.id=encounter_lookup.patient_id and p.organization_id=clinic.org_id()) then raise exception 'Patient encounter options unavailable' using errcode='42501';end if;
 select coalesce(jsonb_agg(to_jsonb(r) order by r.created_at desc,r.id desc),'[]') into items from (
 select e.id,e.created_at,e.status,case when can_see_clinical then e.chief_complaint else 'Signed encounter' end label
 from clinic.encounters e where e.organization_id=clinic.org_id() and e.patient_id in(select id from clinic.patient_ids(encounter_lookup.patient_id))
 and (can_see_clinical or e.status='signed') and (status_filter is null or e.status=status_filter) and (not only_author or e.doctor_id=auth.uid())
 and (cursor_id is null or (e.created_at,e.id)<(select c.created_at,c.id from clinic.encounters c where c.id=cursor_id and c.organization_id=clinic.org_id() and c.patient_id in(select id from clinic.patient_ids(encounter_lookup.patient_id))))
 and (coalesce(search_term,'')='' or (can_see_clinical and clinic.search_key(e.chief_complaint) like '%'||clinic.search_key(left(search_term,200))||'%') or e.created_at::text like '%'||left(search_term,50)||'%')
 order by e.created_at desc,e.id desc limit 26) r;
 more:=jsonb_array_length(items)>25;if more then items:=items-25;end if;
 return jsonb_build_object('items',items,'has_more',more);
end $$;
revoke all on function clinic.encounter_lookup(uuid,text,uuid,text,boolean) from public,anon;
grant execute on function clinic.encounter_lookup(uuid,text,uuid,text,boolean) to authenticated;
create function public.encounter_search(patient_id uuid,search_term text default '',cursor_id uuid default null,status_filter text default null,only_author boolean default false) returns jsonb language plpgsql security invoker set search_path='' as $$begin
 if clinic.allowed('clinical') then perform clinic.log_access('ENCOUNTER_OPTIONS',patient_id,'encounters');end if;
 return clinic.encounter_lookup(patient_id,search_term,cursor_id,status_filter,only_author);
end $$;
revoke all on function public.encounter_search(uuid,text,uuid,text,boolean) from public,anon;
grant execute on function public.encounter_search(uuid,text,uuid,text,boolean) to authenticated;
