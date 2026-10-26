-- Financial reports aggregate complete source sets before paginating detail rows.
create function clinic.invoice_balance_at(invoice_id uuid,cutoff timestamptz) returns numeric language sql stable security invoker set search_path='' as $$
 select i.total-coalesce((select sum(case when p.kind='refund' then -coalesce(p.invoice_amount,p.amount) else coalesce(p.invoice_amount,p.amount) end) from clinic.payments p where p.invoice_id=i.id and p.kind in ('payment','deposit_application','refund') and p.created_at<cutoff),0)-coalesce((select sum(c.amount) from clinic.credit_notes c where c.invoice_id=i.id and c.created_at<cutoff),0)
 from clinic.invoices i where i.id=invoice_balance_at.invoice_id and i.organization_id=clinic.org_id() and i.created_at<cutoff
$$;
revoke all on function clinic.invoice_balance_at(uuid,timestamptz) from public,anon;
grant execute on function clinic.invoice_balance_at(uuid,timestamptz) to authenticated;
-- One set-based balance projection per cutoff; avoid repeated RLS/identity work for each invoice.
create function clinic.invoice_balances(cutoff timestamptz) returns table(id uuid,currency text,patient_id uuid,created_at timestamptz,invoice_number text,patient_snapshot jsonb,balance numeric)
language sql stable security invoker set search_path='' as $$
 with allocations as materialized (
 select p.invoice_id,sum(case when p.kind='refund' then -coalesce(p.invoice_amount,p.amount) else coalesce(p.invoice_amount,p.amount) end) amount
 from clinic.payments p where p.organization_id=(select clinic.org_id()) and p.invoice_id is not null and p.kind in ('payment','deposit_application','refund') and p.created_at<cutoff group by p.invoice_id
 ),credits as materialized (
 select c.invoice_id,sum(c.amount) amount from clinic.credit_notes c where c.organization_id=(select clinic.org_id()) and c.created_at<cutoff group by c.invoice_id
 ) select i.id,i.currency,i.patient_id,i.created_at,i.invoice_number,i.patient_snapshot,i.total-coalesce(a.amount,0)-coalesce(c.amount,0)
 from clinic.invoices i left join allocations a on a.invoice_id=i.id left join credits c on c.invoice_id=i.id
 where i.organization_id=(select clinic.org_id()) and i.created_at<cutoff
$$;
revoke all on function clinic.invoice_balances(timestamptz) from public,anon;
grant execute on function clinic.invoice_balances(timestamptz) to authenticated;
create function public.financial_report(report_type text,from_day date,to_day date,patient_id uuid default null,page_number integer default 0,as_at timestamptz default null) returns jsonb language plpgsql security invoker set search_path='' as $$
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
end $$;
revoke all on function public.financial_report(text,date,date,uuid,integer,timestamptz) from public,anon;
grant execute on function public.financial_report(text,date,date,uuid,integer,timestamptz) to authenticated;

create function public.billing_patient_search(search_term text default '',page_size integer default 50) returns jsonb language plpgsql stable security invoker set search_path='' as $$
declare items jsonb;
begin
 if not (clinic.allowed('billing') or clinic.allowed('finance')) then raise exception 'Permission denied' using errcode='42501';end if;
 with identities as (
 select i.patient_id,i.patient_snapshot,i.created_at from clinic.invoices i where i.organization_id=clinic.org_id()
 union all select p.patient_id,p.patient_snapshot,p.created_at from clinic.payments p where p.organization_id=clinic.org_id()
 union all select p.patient_id,p.patient_snapshot,p.created_at from clinic.packages p where p.organization_id=clinic.org_id()
 ) select coalesce(jsonb_agg(to_jsonb(r)),'[]') into items from (
 select distinct on (i.patient_id) i.patient_id id,i.patient_snapshot->>'full_name' full_name,i.patient_snapshot->>'patient_number' patient_number
 from identities i where coalesce(search_term,'')='' or clinic.search_key(i.patient_snapshot::text) like '%'||clinic.search_key(left(search_term,200))||'%' order by i.patient_id,i.created_at desc limit least(greatest(page_size,1),100)) r;
 return jsonb_build_object('items',items);
end $$;
revoke all on function public.billing_patient_search(text,integer) from public,anon;
grant execute on function public.billing_patient_search(text,integer) to authenticated;
