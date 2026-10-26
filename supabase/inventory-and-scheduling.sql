create table clinic.suppliers (
 id uuid primary key default gen_random_uuid(),organization_id uuid not null references clinic.organizations,name text not null check(length(trim(name)) between 2 and 160),
 contact_person text not null default '',phone text,address text not null default '',active boolean not null default true,version integer not null default 1,
 created_by uuid not null default auth.uid(),created_at timestamptz not null default now(),unique(organization_id,id),unique(organization_id,name)
);
create table clinic.inventory_products (
 id uuid primary key default gen_random_uuid(),organization_id uuid not null references clinic.organizations,name text not null check(length(trim(name)) between 2 and 160),unit text not null check(length(trim(unit))>0),
 reorder_level numeric(18,3) not null default 0 check(reorder_level>=0 and reorder_level<>'NaN'::numeric),supplier_id uuid,active boolean not null default true,
 created_by uuid not null default auth.uid(),created_at timestamptz not null default now(),foreign key(organization_id,supplier_id) references clinic.suppliers(organization_id,id),unique(organization_id,id),unique(organization_id,name,unit)
);
alter table clinic.stock_lots add column product_id uuid;
alter table clinic.stock_lots add foreign key(organization_id,product_id) references clinic.inventory_products(organization_id,id);
create table clinic.availability_cancellations (
 id uuid primary key default gen_random_uuid(),organization_id uuid not null,availability_id uuid not null,reason text not null check(length(trim(reason))>=5),
 created_by uuid not null default auth.uid(),created_at timestamptz not null default now(),foreign key(organization_id,availability_id) references clinic.clinician_availability(organization_id,id),unique(availability_id),unique(organization_id,id)
);
alter table clinic.suppliers enable row level security;
alter table clinic.inventory_products enable row level security;
alter table clinic.availability_cancellations enable row level security;
grant select,insert,update on clinic.suppliers,clinic.inventory_products to authenticated;
grant select,insert on clinic.availability_cancellations to authenticated;
grant all on clinic.suppliers,clinic.inventory_products,clinic.availability_cancellations to service_role;
create policy supplier_read on clinic.suppliers for select to authenticated using(organization_id=(select clinic.org_id()) and ((select clinic.allowed('inventory')) or (select clinic.allowed('finance'))));
create policy supplier_insert on clinic.suppliers for insert to authenticated with check(organization_id=(select clinic.org_id()) and (select clinic.allowed('inventory')));
create policy supplier_update on clinic.suppliers for update to authenticated using(organization_id=(select clinic.org_id()) and (select clinic.allowed('inventory'))) with check(organization_id=(select clinic.org_id()) and (select clinic.allowed('inventory')));
create policy product_read on clinic.inventory_products for select to authenticated using(organization_id=(select clinic.org_id()) and ((select clinic.allowed('inventory')) or (select clinic.allowed('inventory.read')) or (select clinic.allowed('finance'))));
create policy product_insert on clinic.inventory_products for insert to authenticated with check(organization_id=(select clinic.org_id()) and (select clinic.allowed('inventory')));
create policy product_update on clinic.inventory_products for update to authenticated using(organization_id=(select clinic.org_id()) and (select clinic.allowed('inventory'))) with check(organization_id=(select clinic.org_id()) and (select clinic.allowed('inventory')));
create policy schedule_cancellation_read on clinic.availability_cancellations for select to authenticated using(organization_id=(select clinic.org_id()) and (select clinic.allowed('schedule')));
create policy schedule_cancellation_insert on clinic.availability_cancellations for insert to authenticated with check(organization_id=(select clinic.org_id()) and (select clinic.allowed('schedule')));
create trigger immutable_record before update or delete on clinic.availability_cancellations for each row execute function clinic.immutable_record();
create trigger audit_write after insert or update on clinic.suppliers for each row execute function clinic.audit_write();
create trigger audit_write after insert or update on clinic.inventory_products for each row execute function clinic.audit_write();
create trigger audit_write after insert on clinic.availability_cancellations for each row execute function clinic.audit_write();
create function public.inventory_alerts(expiry_days integer default 30,page_number integer default 0) returns jsonb language plpgsql stable security invoker set search_path='' as $$
declare rows jsonb;items jsonb;today date:=(now() at time zone 'Asia/Baghdad')::date;
begin
 if not (clinic.allowed('inventory') or clinic.allowed('inventory.read')) then raise exception 'Permission denied' using errcode='42501';end if;
 if expiry_days not between 0 and 365 or page_number<0 then raise exception 'Invalid inventory report range';end if;
 select coalesce(jsonb_agg(to_jsonb(r) order by r.category,r.product,r.id),'[]') into rows from (
 select l.id,l.product,l.lot_number,l.expires_on,l.unit,l.quantity available,null::numeric threshold,case when l.expires_on<today then 'expired' when l.quantity=0 then 'out_of_stock' else 'expiring' end category
 from clinic.stock_lots l where l.organization_id=clinic.org_id() and ((l.quantity>0 and l.expires_on<=today+expiry_days) or l.quantity=0)
 union all select p.id,p.name,null::text,null::date,p.unit,coalesce(sum(l.quantity) filter(where l.expires_on>=today),0),p.reorder_level,'reorder'
 from clinic.inventory_products p left join clinic.stock_lots l on l.product_id=p.id where p.organization_id=clinic.org_id() and p.active group by p.id,p.name,p.unit,p.reorder_level having coalesce(sum(l.quantity) filter(where l.expires_on>=today),0)<=p.reorder_level) r;
 select coalesce(jsonb_agg(value order by ord),'[]') into items from jsonb_array_elements(rows) with ordinality x(value,ord) where ord>page_number*100 and ord<=(page_number+1)*100;
 return jsonb_build_object('items',items,'records',jsonb_array_length(rows),'has_more',jsonb_array_length(rows)>(page_number+1)*100);
end $$;
revoke all on function public.inventory_alerts(integer,integer) from public,anon;
grant execute on function public.inventory_alerts(integer,integer) to authenticated;
