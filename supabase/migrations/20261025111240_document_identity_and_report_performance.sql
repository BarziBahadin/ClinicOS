-- Preserve new clinical-document identities and aggregate report balances/history labels in sets.
-- Existing signed identities are not reconstructed or overwritten.
SET local check_function_bodies = off;

ALTER TABLE "clinic"."consents"
  ADD COLUMN "identity_snapshot" jsonb NOT NULL DEFAULT '{}'::jsonb;

ALTER TABLE "clinic"."encounters"
  ADD COLUMN "identity_snapshot" jsonb NOT NULL DEFAULT '{}'::jsonb;

ALTER TABLE "clinic"."patient_documents"
  ADD COLUMN "identity_snapshot" jsonb NOT NULL DEFAULT '{}'::jsonb;

ALTER TABLE "clinic"."procedures"
  ADD COLUMN "identity_snapshot" jsonb NOT NULL DEFAULT '{}'::jsonb;

CREATE OR REPLACE FUNCTION clinic.capture_document_identity()
  RETURNS TRIGGER
  LANGUAGE plpgsql
  SET search_path TO ''
  AS $function$
declare patient clinic.patients;author uuid;author_name text;
begin
 if tg_op='UPDATE' then
 if not (old.status='draft' and new.status='signed' and new.identity_snapshot='{}') then return new;end if;
 end if;
 select * into patient from clinic.patients p where p.id=new.patient_id and p.organization_id=new.organization_id;
 if not found then raise exception 'Patient identity unavailable' using errcode='42501';end if;
 if tg_table_name='encounters' then author:=new.doctor_id;
 elsif tg_table_name='patient_documents' then author:=new.signed_by;
 elsif tg_table_name='procedures' then author:=new.performed_by;
 else author:=new.recorded_by;end if;
 select display_name into author_name from clinic.memberships where user_id=author and organization_id=new.organization_id;
 new.identity_snapshot:=jsonb_build_object('full_name',patient.full_name,'patient_number',patient.patient_number,'birth_date',patient.birth_date,'birth_precision',patient.birth_precision,'reported_age',patient.reported_age,'age_recorded_on',patient.age_recorded_on,'clinician_name',author_name,'captured_at',clock_timestamp());
 return new;
end $function$;

CREATE OR REPLACE FUNCTION clinic.invoice_balances (
  cutoff timestamp with time zone
)
  RETURNS TABLE (
    id               uuid,
    currency         text,
    patient_id       uuid,
    created_at       timestamp with time zone,
    invoice_number   text,
    patient_snapshot jsonb,
    balance          numeric
  )
  LANGUAGE sql
  STABLE
  SET search_path TO ''
  AS $function$
 with allocations as materialized (
 select p.invoice_id,sum(case when p.kind='refund' then -coalesce(p.invoice_amount,p.amount) else coalesce(p.invoice_amount,p.amount) end) amount
 from clinic.payments p where p.organization_id=(select clinic.org_id()) and p.invoice_id is not null and p.kind in ('payment','deposit_application','refund') and p.created_at<cutoff group by p.invoice_id
 ),credits as materialized (
 select c.invoice_id,sum(c.amount) amount from clinic.credit_notes c where c.organization_id=(select clinic.org_id()) and c.created_at<cutoff group by c.invoice_id
 ) select i.id,i.currency,i.patient_id,i.created_at,i.invoice_number,i.patient_snapshot,i.total-coalesce(a.amount,0)-coalesce(c.amount,0)
 from clinic.invoices i left join allocations a on a.invoice_id=i.id left join credits c on c.invoice_id=i.id
 where i.organization_id=(select clinic.org_id()) and i.created_at<cutoff
$function$;

CREATE OR REPLACE FUNCTION public.financial_report (
  report_type text,
  from_day    date,
  to_day      date,
  patient_id  uuid                     DEFAULT NULL::uuid,
  page_number integer                  DEFAULT 0,
  as_at       timestamp with time zone DEFAULT NULL::timestamp WITH time zone
)
  RETURNS jsonb
  LANGUAGE plpgsql
  SET search_path TO ''
  AS $function$
declare o uuid:=clinic.org_id();first_at timestamptz;last_at timestamptz;rows jsonb;totals jsonb;items jsonb;more boolean;count_records integer;opening jsonb:='[]';closing jsonb:='[]';prepayments jsonb:='[]';
begin
 if from_day is null or to_day is null or from_day>to_day or to_day>(now() at time zone 'Asia/Baghdad')::date or as_at>clock_timestamp() or page_number<0 or page_number>100000 then raise exception 'Select a valid report date range';end if;
 first_at:=from_day::timestamp at time zone 'Asia/Baghdad';last_at:=least((to_day+1)::timestamp at time zone 'Asia/Baghdad',coalesce(as_at,clock_timestamp()));
 if last_at<=first_at then raise exception 'Report snapshot must follow the start date';end if;
 if report_type in ('receivables','patient_statement','collections','liabilities') then
 if not (clinic.allowed('billing') or clinic.allowed('finance')) then raise exception 'Permission denied' using errcode='42501';end if;
 else perform clinic.require_permission('finance');end if;
 if patient_id is not null and not exists(select 1 from clinic.invoices where organization_id=o and clinic.invoices.patient_id=financial_report.patient_id) and not exists(select 1 from clinic.payments where organization_id=o and clinic.payments.patient_id=financial_report.patient_id) and not exists(select 1 from clinic.packages where organization_id=o and clinic.packages.patient_id=financial_report.patient_id) then raise exception 'Patient account unavailable' using errcode='42501';end if;
 case report_type
 when 'receivables' then
 select coalesce(jsonb_agg(to_jsonb(r) order by r.age_days desc,r.invoice_number),'[]') into rows from (
 select i.id,i.invoice_number,i.patient_snapshot->>'full_name' patient_name,i.patient_snapshot->>'patient_number' patient_number,i.currency,
 i.balance amount,to_day-(i.created_at at time zone 'Asia/Baghdad')::date age_days,
 case when to_day-(i.created_at at time zone 'Asia/Baghdad')::date<=30 then '0–30' when to_day-(i.created_at at time zone 'Asia/Baghdad')::date<=60 then '31–60' when to_day-(i.created_at at time zone 'Asia/Baghdad')::date<=90 then '61–90' else '90+' end aging_band
 from clinic.invoice_balances(last_at) i where (financial_report.patient_id is null or i.patient_id=financial_report.patient_id)
 and i.balance>0) r;
 when 'patient_statement' then
 if patient_id is null then raise exception 'Choose a patient for the statement';end if;
 select coalesce(jsonb_agg(to_jsonb(r) order by r.date,r.id),'[]') into rows from (
 select i.id,i.created_at date,i.invoice_number reference,'invoice' category,i.currency,i.total amount from clinic.invoices i where i.organization_id=o and i.patient_id=financial_report.patient_id and i.created_at>=first_at and i.created_at<last_at
 union all select p.id,p.created_at,coalesce(i.invoice_number,p.id::text),p.kind,coalesce(i.currency,p.currency),case when p.kind='refund' then coalesce(p.invoice_amount,p.amount) else -coalesce(p.invoice_amount,p.amount) end from clinic.payments p left join clinic.invoices i on i.id=p.invoice_id where p.organization_id=o and p.patient_id=financial_report.patient_id and p.created_at>=first_at and p.created_at<last_at and p.invoice_id is not null
 union all select c.id,c.created_at,i.invoice_number,'credit',i.currency,-c.amount from clinic.credit_notes c join clinic.invoices i on i.id=c.invoice_id where c.organization_id=o and i.patient_id=financial_report.patient_id and c.created_at>=first_at and c.created_at<last_at) r;
 when 'collections' then
 select coalesce(jsonb_agg(to_jsonb(r) order by r.date,r.currency,r.method,r.category),'[]') into rows from (
 select (p.created_at at time zone 'Asia/Baghdad')::date date,p.currency,p.method,p.kind category,sum(case when p.kind='refund' then -p.amount else p.amount end) amount,count(*) transactions
 from clinic.payments p where p.organization_id=o and p.created_at>=first_at and p.created_at<last_at and p.kind<>'deposit_application' and (financial_report.patient_id is null or p.patient_id=financial_report.patient_id) group by 1,2,3,4
 union all select (j.created_at at time zone 'Asia/Baghdad')::date,j.currency,l.account,j.source_type,sum(l.debit-l.credit),count(*) from clinic.journals j join clinic.journal_lines l on l.journal_id=j.id where j.organization_id=o and j.created_at>=first_at and j.created_at<last_at and j.source_type in ('package_sale','package_refund') and l.account in ('cash','bank','card') and financial_report.patient_id is null group by 1,2,3,4) r;
 when 'liabilities' then
 select coalesce(jsonb_agg(to_jsonb(r) order by r.currency,r.category,r.id),'[]') into rows from (
 select min(p.id::text) id,p.patient_id,p.currency,'patient_deposit' category,sum(case when p.kind='deposit' then p.amount when p.kind='deposit_application' or (p.kind='refund' and p.invoice_id is null) then -p.amount else 0 end) amount
 from clinic.payments p where p.organization_id=o and p.created_at<last_at group by p.patient_id,p.currency
 having sum(case when p.kind='deposit' then p.amount when p.kind='deposit_application' or (p.kind='refund' and p.invoice_id is null) then -p.amount else 0 end)<>0
 union all select pkg.id::text,pkg.patient_id,j.currency,'treatment_package',sum(l.credit-l.debit) from clinic.packages pkg
 join (select id, id package_id from clinic.packages union all select id,package_id from clinic.package_redemptions union all select id,package_id from clinic.package_corrections where kind='refund') s on s.package_id=pkg.id
 join clinic.journals j on j.source_id=s.id and j.source_type in ('package_sale','package_redemption','package_refund') join clinic.journal_lines l on l.journal_id=j.id and l.account='deposits'
 where pkg.organization_id=o and j.created_at<last_at group by pkg.id,pkg.patient_id,j.currency having sum(l.credit-l.debit)<>0) r;
 when 'payables' then
 select coalesce(jsonb_agg(to_jsonb(r) order by r.date,r.id),'[]') into rows from (
 select e.id,e.created_at date,e.supplier,e.category,e.description,e.currency,e.amount from clinic.expenses e where e.organization_id=o and e.created_at<last_at and not e.paid
 and not exists(select 1 from clinic.journals j where j.organization_id=o and j.source_type='expense_payment' and j.source_id=e.id and j.created_at<last_at)) r;
 when 'cash_register' then
 select coalesce(jsonb_agg(to_jsonb(r) order by r.date,r.id),'[]') into rows from (
 select l.id,j.created_at date,l.account,j.currency,j.source_type category,j.source_id reference,j.description,l.debit-l.credit amount from clinic.journal_lines l join clinic.journals j on j.id=l.journal_id
 where j.organization_id=o and l.account in ('cash','bank','card') and j.created_at>=first_at and j.created_at<last_at) r;
 when 'till_variances' then
 select coalesce(jsonb_agg(to_jsonb(r) order by r.date,r.id),'[]') into rows from (
 select id,closed_at date,user_id,currency,opening,expected,counted,counted-expected amount,reason from clinic.tills where organization_id=o and closed_at>=first_at and closed_at<last_at) r;
 else raise exception 'Invalid financial report';end case;
 if report_type='liabilities' and patient_id is not null then select coalesce(jsonb_agg(value),'[]') into rows from jsonb_array_elements(rows) where value->>'patient_id'=patient_id::text;end if;
 if report_type='patient_statement' then
 select coalesce(jsonb_agg(to_jsonb(t) order by t.currency),'[]') into opening from (select i.currency,sum(i.balance) amount from clinic.invoice_balances(first_at) i where i.patient_id=financial_report.patient_id group by i.currency) t;
 select coalesce(jsonb_agg(to_jsonb(t) order by t.currency),'[]') into closing from (select i.currency,sum(i.balance) amount from clinic.invoice_balances(last_at) i where i.patient_id=financial_report.patient_id group by i.currency) t;
 prepayments:=public.financial_report('liabilities',from_day,to_day,patient_id,0,last_at)->'totals';
 end if;
 select coalesce(jsonb_agg(to_jsonb(t) order by t.currency),'[]') into totals from (select value->>'currency' currency,sum((value->>'amount')::numeric) amount from jsonb_array_elements(rows) group by 1) t;
 count_records:=jsonb_array_length(rows);
 select coalesce(jsonb_agg(value order by ord),'[]') into items from jsonb_array_elements(rows) with ordinality t(value,ord) where ord>page_number*100 and ord<=(page_number+1)*100;
 more:=count_records>(page_number+1)*100;
 perform clinic.log_access('FINANCIAL_REPORT',patient_id,report_type);
 return jsonb_build_object('items',items,'totals',totals,'has_more',more,'records',count_records,'from_day',from_day,'to_day',to_day,'as_at',last_at,'opening_balances',opening,'closing_balances',closing,'prepayment_totals',prepayments);
end $function$;

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
 ('clinician_availability','schedule',false),('clinic_resources','schedule',false)) x(t,p,patient) where x.t=record_type;
 if tbl is null then raise exception 'Invalid history type'; end if;
 if not clinic.allowed(perm) and not (tbl in ('stock_lots','stock_movements','inventory_products') and clinic.allowed('inventory')) and not (tbl='performed_services' and clinic.allowed('clinical')) and not (tbl in ('tills','suppliers') and clinic.allowed('finance')) then raise exception 'Permission denied' using errcode='42501'; end if;
 if patient_id is not null and (not has_patient or not exists(select 1 from clinic.patients p where p.id=history_page.patient_id and p.organization_id=o)) then raise exception 'Patient unavailable' using errcode='42501';end if;
 execute format($q$with records as materialized (
 select r.id,coalesce((to_jsonb(r)->>'created_at')::timestamptz,(to_jsonb(r)->>'opened_at')::timestamptz,'-infinity'::timestamptz) sort_at,
 (to_jsonb(r)->>'patient_id')::uuid patient_id,to_jsonb(r) value
 from clinic.%I r where r.organization_id=$1 and ($2 is null or (to_jsonb(r)->>'patient_id')::uuid in (select id from clinic.patient_ids($2)))
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

CREATE TRIGGER capture_identity
  BEFORE INSERT ON clinic.consents
  FOR EACH ROW
  EXECUTE FUNCTION clinic.capture_document_identity();

CREATE TRIGGER capture_identity
  BEFORE INSERT OR UPDATE OF status ON clinic.encounters
  FOR EACH ROW
  EXECUTE FUNCTION clinic.capture_document_identity();

CREATE TRIGGER capture_identity
  BEFORE INSERT ON clinic.patient_documents
  FOR EACH ROW
  EXECUTE FUNCTION clinic.capture_document_identity();

CREATE TRIGGER capture_identity
  BEFORE INSERT ON clinic.procedures
  FOR EACH ROW
  EXECUTE FUNCTION clinic.capture_document_identity();

REVOKE ALL ON FUNCTION "clinic"."capture_document_identity"() FROM PUBLIC;

REVOKE ALL ON FUNCTION "clinic"."capture_document_identity"() FROM "postgres";

GRANT EXECUTE ON FUNCTION "clinic"."capture_document_identity"() TO "postgres";

REVOKE ALL ON FUNCTION "clinic"."invoice_balances"(timestamp WITH time zone) FROM PUBLIC;

GRANT EXECUTE ON FUNCTION "clinic"."invoice_balances"(timestamp WITH time zone) TO "authenticated";

REVOKE ALL ON FUNCTION "clinic"."invoice_balances"(timestamp WITH time zone) FROM "postgres";

GRANT EXECUTE ON FUNCTION "clinic"."invoice_balances"(timestamp WITH time zone) TO "postgres";

