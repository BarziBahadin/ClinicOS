create extension if not exists pg_trgm with schema extensions;
create function clinic.search_key(value text) returns text language sql immutable set search_path='' as $$ select lower(normalize(translate(coalesce(value,''),'كيى٠١٢٣٤٥٦٧٨٩۰۱۲۳۴۵۶۷۸۹','کیی01234567890123456789'),NFKC)) $$;
grant execute on function clinic.search_key(text) to authenticated;
create index patient_name_trigram on clinic.patients using gin(clinic.search_key(full_name) extensions.gin_trgm_ops);
create function clinic.patient_ids(root uuid) returns table(id uuid) language sql stable security invoker set search_path='' as $$
 with recursive linked(id) as (select id from clinic.patients where id=root and organization_id=clinic.org_id() union select p.id from clinic.patients p join linked l on p.merged_into=l.id where p.organization_id=clinic.org_id()) select id from linked
$$;
grant execute on function clinic.patient_ids(uuid) to authenticated;
create function clinic.billable_encounters() returns jsonb language sql stable security definer set search_path='' as $$
 select coalesce(jsonb_agg(x),'[]') from (select id,patient_id,status,created_at from clinic.encounters where organization_id=clinic.org_id() and clinic.allowed('billing') and status='signed' order by created_at desc limit 500) x
$$;
grant execute on function clinic.billable_encounters() to authenticated;
create function public.patient_search(search_term text default '',cursor_id uuid default null,page_size integer default 50) returns jsonb language plpgsql stable security invoker set search_path='' as $$
declare items jsonb; more boolean; sz integer:=least(greatest(page_size,1),100);
begin
 perform clinic.require_permission('patients');
 select coalesce(jsonb_agg(x),'[]') into items from (select * from clinic.patients where organization_id=clinic.org_id() and merged_into is null and (cursor_id is null or id>cursor_id) and (clinic.search_key(full_name) like '%'||clinic.search_key(left(search_term,200))||'%' or phone like '%'||clinic.search_key(left(search_term,200))||'%' or patient_number ilike '%'||left(search_term,200)||'%') order by id limit sz+1) x;
 more:=jsonb_array_length(items)>sz;
 if more then items:=items-sz; end if;
 return jsonb_build_object('items',items,'has_more',more);
end $$;
grant execute on function public.patient_search(text,uuid,integer) to authenticated;
create function public.patient_profile(patient_id uuid) returns jsonb language sql stable security invoker set search_path='' as $$ select to_jsonb(p) from clinic.patients p where id=patient_id and organization_id=clinic.org_id() $$;
grant execute on function public.patient_profile(uuid) to authenticated;

create function clinic.patient_label(patient_id uuid) returns text language sql stable security definer set search_path='' as $$
 select full_name from clinic.patients where id=patient_id and organization_id=clinic.org_id() and (clinic.allowed('patients') or clinic.allowed('finance'))
$$;
grant execute on function clinic.patient_label(uuid) to authenticated;
create function public.appointments_for_day(service_day date) returns jsonb language plpgsql stable security invoker set search_path='' as $$
begin perform clinic.require_permission('schedule');
 return coalesce((select jsonb_agg(x) from (select a.*,clinic.patient_label(a.patient_id) patient_name from clinic.appointments a where a.organization_id=clinic.org_id() and a.starts_at>=service_day::timestamp at time zone 'Asia/Baghdad' and a.starts_at<(service_day+1)::timestamp at time zone 'Asia/Baghdad' order by a.starts_at) x),'[]');
end $$;
grant execute on function public.appointments_for_day(date) to authenticated;

-- Every foreign key's referencing columns receive an index for joins and integrity checks.
do $$declare r record; begin
 for r in select c.conrelid::regclass tbl,c.conname,(select string_agg(quote_ident(a.attname),',' order by u.ord) from unnest(c.conkey) with ordinality u(attnum,ord) join pg_attribute a on a.attrelid=c.conrelid and a.attnum=u.attnum) cols from pg_constraint c join pg_namespace n on n.oid=c.connamespace where c.contype='f' and n.nspname='clinic' and not exists (select 1 from pg_index i where i.indrelid=c.conrelid and i.indisvalid and (select array_agg(k order by ord) from unnest(i.indkey::smallint[]) with ordinality z(k,ord) where ord<=cardinality(c.conkey))=c.conkey) loop
 execute format('create index if not exists %I on %s(%s)',left(r.conname,55)||'_idx',r.tbl,r.cols);
 end loop;
end $$;

-- Stable invoice allocation policy shared by screens, posting and reporting.
create function clinic.invoice_balance(invoice_id uuid) returns numeric language sql stable security invoker set search_path='' as $$
 select i.total-coalesce((select sum(coalesce(p.invoice_amount,p.amount)) from clinic.payments p where p.invoice_id=i.id and p.kind in ('payment','deposit_application')),0)-coalesce((select sum(c.amount) from clinic.credit_notes c where c.invoice_id=i.id),0)+coalesce((select sum(coalesce(p.invoice_amount,p.amount)) from clinic.payments p where p.invoice_id=i.id and p.kind='refund'),0) from clinic.invoices i where i.id=invoice_balance.invoice_id and i.organization_id=clinic.org_id()
$$;
grant execute on function clinic.invoice_balance(uuid) to authenticated;
create function public.record_page(record_type text,search_term text default '',cursor_id uuid default null,page_size integer default 50) returns jsonb language plpgsql stable security invoker set search_path='' as $$
declare o uuid:=clinic.org_id(); items jsonb; sz integer:=least(greatest(page_size,1),100); more boolean;
begin
 if record_type not in ('invoices','payments','expenses','audit') then raise exception 'Invalid record type'; end if;
 if record_type='audit' then perform clinic.require_permission('audit');
 elsif record_type='expenses' then perform clinic.require_permission('finance');
 elsif not (clinic.allowed('billing') or clinic.allowed('finance')) then raise exception 'Permission denied' using errcode='42501'; end if;
 with records as (
 select i.id,i.created_at,to_jsonb(i)||jsonb_build_object('balance',clinic.invoice_balance(i.id)) value from clinic.invoices i where record_type='invoices' and i.organization_id=o
 union all select p.id,p.created_at,to_jsonb(p)||jsonb_build_object('invoice_currency',i.currency,'invoice_number',i.invoice_number) from clinic.payments p left join clinic.invoices i on i.id=p.invoice_id where record_type='payments' and p.organization_id=o
 union all select e.id,e.created_at,to_jsonb(e)||jsonb_build_object('is_paid',e.paid or exists(select 1 from clinic.journals j where j.organization_id=o and j.source_type='expense_payment' and j.source_id=e.id)) from clinic.expenses e where record_type='expenses' and e.organization_id=o
 union all select a.id,a.created_at,to_jsonb(a) from clinic.audit_events a where record_type='audit' and a.organization_id=o
 ), page as (
 select * from records r where (cursor_id is null or (r.created_at,r.id)<(select c.created_at,c.id from records c where c.id=cursor_id)) and (coalesce(search_term,'')='' or clinic.search_key(concat_ws(' ',r.value->>'invoice_number',r.value#>>'{patient_snapshot,full_name}',r.value#>>'{patient_snapshot,patient_number}',r.value->>'supplier',r.value->>'description',r.value->>'action',r.value->>'entity_type',r.id::text)) like '%'||clinic.search_key(left(search_term,200))||'%') order by r.created_at desc,r.id desc limit sz+1
 ) select coalesce(jsonb_agg(value order by created_at desc,id desc),'[]') into items from page;
 more:=jsonb_array_length(items)>sz;if more then items:=items-sz;end if;
 return jsonb_build_object('items',items,'has_more',more);
end $$;
revoke all on function public.record_page(text,text,uuid,integer) from public,anon;
grant execute on function public.record_page(text,text,uuid,integer) to authenticated;
