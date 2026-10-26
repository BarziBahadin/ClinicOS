-- Accountant-controlled mappings, immutable export batches, period locks and reconciliation.
alter table clinic.journals add column effective_date date;
alter table clinic.journals add column accounting_date date generated always as (coalesce(effective_date,(created_at at time zone 'Asia/Baghdad')::date)) stored;
create index journal_accounting_date on clinic.journals(organization_id,accounting_date,id);
create table clinic.accounting_periods (
 id uuid primary key default gen_random_uuid(),organization_id uuid not null references clinic.organizations,
 from_day date not null,to_day date not null,reason text not null check(length(trim(reason))>=5),created_by uuid not null default auth.uid(),created_at timestamptz not null default now(),check(to_day>=from_day),unique(organization_id,id)
);
create table clinic.account_mappings (
 id uuid primary key default gen_random_uuid(),organization_id uuid not null references clinic.organizations,name text not null,
 codes jsonb not null check(jsonb_typeof(codes)='object'),approved_at timestamptz,approved_by uuid references auth.users,
 created_by uuid not null default auth.uid(),created_at timestamptz not null default now(),unique(organization_id,name),unique(organization_id,id)
);
create table clinic.accounting_batches (
 id uuid primary key default gen_random_uuid(),organization_id uuid not null,mapping_id uuid not null,from_day date not null,to_day date not null,
 created_by uuid not null default auth.uid(),created_at timestamptz not null default now(),check(to_day>=from_day),
 foreign key(organization_id,mapping_id) references clinic.account_mappings(organization_id,id),unique(organization_id,id)
);
create table clinic.accounting_batch_items (
 id uuid primary key default gen_random_uuid(),organization_id uuid not null,batch_id uuid not null,line_id uuid not null,account_code text not null,
 created_at timestamptz not null default now(),foreign key(organization_id,batch_id) references clinic.accounting_batches(organization_id,id),
 foreign key(line_id) references clinic.journal_lines(id),unique(line_id),unique(organization_id,id)
);
create table clinic.accounting_acknowledgements (
 id uuid primary key default gen_random_uuid(),organization_id uuid not null,batch_id uuid not null,external_reference text not null check(length(trim(external_reference))>=2),
 notes text not null,created_by uuid not null default auth.uid(),created_at timestamptz not null default now(),
 foreign key(organization_id,batch_id) references clinic.accounting_batches(organization_id,id),unique(batch_id),unique(organization_id,external_reference),unique(organization_id,id)
);
create table clinic.bank_statement_lines (
 id uuid primary key default gen_random_uuid(),organization_id uuid not null references clinic.organizations,
 account text not null check(account in ('bank','card')),currency text not null check(currency in ('IQD','USD')),posted_on date not null,
 amount numeric(18,3) not null check(amount<>0 and (currency<>'USD' or amount=round(amount,2))),reference text not null,external_id text not null,
 created_by uuid not null default auth.uid(),created_at timestamptz not null default now(),unique(organization_id,account,currency,external_id),unique(organization_id,id)
);
create table clinic.bank_matches (
 id uuid primary key default gen_random_uuid(),organization_id uuid not null,statement_id uuid not null,journal_line_id uuid not null,reason text not null check(length(trim(reason))>=5),
 created_by uuid not null default auth.uid(),created_at timestamptz not null default now(),
 foreign key(organization_id,statement_id) references clinic.bank_statement_lines(organization_id,id),foreign key(journal_line_id) references clinic.journal_lines(id),unique(organization_id,id)
);
create table clinic.bank_match_reversals (
 id uuid primary key default gen_random_uuid(),organization_id uuid not null,match_id uuid not null,reason text not null check(length(trim(reason))>=5),
 created_by uuid not null default auth.uid(),created_at timestamptz not null default now(),foreign key(organization_id,match_id) references clinic.bank_matches(organization_id,id),unique(match_id),unique(organization_id,id)
);
do $$declare t text;begin
 foreach t in array array['accounting_periods','account_mappings','accounting_batches','accounting_batch_items','accounting_acknowledgements','bank_statement_lines','bank_matches','bank_match_reversals'] loop
 execute format('alter table clinic.%I enable row level security',t);
 execute format('grant select,insert,update on clinic.%I to authenticated',t);
 execute format('grant all on clinic.%I to service_role',t);
 execute format('create policy accounting_scope on clinic.%I to authenticated using(organization_id=clinic.org_id() and clinic.allowed(''finance'')) with check(organization_id=clinic.org_id() and clinic.allowed(''finance''))',t);
 execute format('create trigger audit_write after insert or update on clinic.%I for each row execute function clinic.audit_write()',t);
 if t<>'account_mappings' then execute format('create trigger immutable_record before update or delete on clinic.%I for each row execute function clinic.immutable_record()',t);end if;
 end loop;
end $$;
create function clinic.protect_mapping() returns trigger language plpgsql set search_path='' as $$begin if old.approved_at is not null then raise exception 'Approved account mappings are immutable' using errcode='23514';end if;return new;end $$;
create trigger approved_mapping before update or delete on clinic.account_mappings for each row execute function clinic.protect_mapping();
create function clinic.check_open_period() returns trigger language plpgsql security invoker set search_path='' as $$declare day date:=coalesce(new.effective_date,(new.created_at at time zone 'Asia/Baghdad')::date);begin
 perform pg_advisory_xact_lock(hashtextextended(new.organization_id::text,0));
 if day>(now() at time zone 'Asia/Baghdad')::date or exists(select 1 from clinic.accounting_periods where organization_id=new.organization_id and day between from_day and to_day) then raise exception 'Posting date is in a closed period or the future. Use an authorized adjustment in an open period.' using errcode='23514';end if;return new;end $$;
create trigger open_accounting_period before insert on clinic.journals for each row execute function clinic.check_open_period();
-- Period validation must run for billing/clinical posting roles without exposing finance tables.
create function clinic.period_is_open(org_id uuid,posting_day date) returns boolean language sql stable security definer set search_path='' as $$
 select org_id=clinic.org_id() and clinic.session_valid() and posting_day<=(now() at time zone 'Asia/Baghdad')::date and not exists(select 1 from clinic.accounting_periods where organization_id=org_id and posting_day between from_day and to_day)
$$;
revoke all on function clinic.period_is_open(uuid,date) from public,anon;
grant execute on function clinic.period_is_open(uuid,date) to authenticated;
create or replace function clinic.check_open_period() returns trigger language plpgsql security invoker set search_path='' as $$declare posting_day date:=coalesce(new.effective_date,(new.created_at at time zone 'Asia/Baghdad')::date);begin
 perform pg_advisory_xact_lock(hashtextextended(new.organization_id::text,0));
 if not clinic.period_is_open(new.organization_id,posting_day) then raise exception 'Posting date is in a closed period or the future. Use an authorized adjustment in an open period.' using errcode='23514';end if;return new;end $$;
create function public.finance_workflow(kind text,payload jsonb,request_id uuid) returns jsonb language plpgsql security invoker set search_path='' as $$
declare o uuid:=clinic.org_id();actor uuid:=auth.uid();prior clinic.requests;fp text:=md5(kind||payload::text);rid uuid;v uuid;item jsonb;mapping clinic.account_mappings;statement clinic.bank_statement_lines;posting record;amount numeric;lineid uuid;mapping_account text;codes jsonb;result jsonb;
begin
 perform clinic.require_permission('finance');
 if o is null or actor is null or request_id is null or jsonb_typeof(payload)<>'object' or octet_length(payload::text)>200000 then raise exception 'Invalid accounting request';end if;
 perform pg_advisory_xact_lock(hashtextextended(o::text,0));
 select * into prior from clinic.requests r where r.organization_id=o and r.actor_id=actor and r.request_id=finance_workflow.request_id;
 if found then if prior.fingerprint<>fp then raise exception 'Request identifier reused with different content' using errcode='23505';end if;return prior.result;end if;
 v:=nullif(payload->>'id','')::uuid;
 case kind
 when 'finance.mapping.create' then
 perform clinic.require_permission('approve');codes:=payload->'codes';
 if jsonb_typeof(codes)<>'object' or (select count(*) from jsonb_object_keys(codes))<>12 then raise exception 'Map all clinic ledger accounts';end if;
 foreach mapping_account in array array['cash','bank','card','receivable','deposits','revenue','expense','inventory','payable','equity','owner_loan','fx_clearing'] loop
 if length(trim(coalesce(codes->>mapping_account,''))) not between 1 and 100 then raise exception 'An external code is required for every account';end if;end loop;
 insert into clinic.account_mappings(organization_id,name,codes) values(o,payload->>'name',codes) returning id into rid;
 when 'finance.mapping.approve' then
 perform clinic.require_permission('approve');update clinic.account_mappings set approved_by=actor,approved_at=now() where id=v and organization_id=o and approved_at is null returning id into rid;
 when 'finance.batch.create' then
 perform clinic.require_permission('export');
 select * into mapping from clinic.account_mappings where id=(payload->>'mapping_id')::uuid and organization_id=o and approved_at is not null;
 if not found then raise exception 'Select an approved account mapping';end if;
 insert into clinic.accounting_batches(organization_id,mapping_id,from_day,to_day) values(o,mapping.id,(payload->>'from_day')::date,(payload->>'to_day')::date) returning id into rid;
 insert into clinic.accounting_batch_items(organization_id,batch_id,line_id,account_code)
 select o,rid,l.id,mapping.codes->>l.account from clinic.journal_lines l join clinic.journals j on j.id=l.journal_id where j.organization_id=o and j.accounting_date between (payload->>'from_day')::date and (payload->>'to_day')::date and not exists(select 1 from clinic.accounting_batch_items i where i.line_id=l.id);
 if not found then raise exception 'No unexported postings exist in this date range';end if;
 when 'finance.batch.acknowledge' then
 perform clinic.require_permission('export');
 insert into clinic.accounting_acknowledgements(organization_id,batch_id,external_reference,notes) values(o,v,payload->>'external_reference',payload->>'notes') returning id into rid;
 when 'finance.period.close' then
 perform clinic.require_permission('approve');
 if (payload->>'to_day')::date>(now() at time zone 'Asia/Baghdad')::date or exists(select 1 from clinic.accounting_periods where organization_id=o and from_day<=(payload->>'to_day')::date and to_day>=(payload->>'from_day')::date) then raise exception 'Period is in the future or overlaps an existing close';end if;
 insert into clinic.accounting_periods(organization_id,from_day,to_day,reason) values(o,(payload->>'from_day')::date,(payload->>'to_day')::date,payload->>'reason') returning id into rid;
 when 'finance.journal.adjust' then
 perform clinic.require_permission('approve');amount:=(payload->>'amount')::numeric;perform clinic.require_approval(amount,payload->>'currency');
 if amount<=0 or amount<>round(amount,case when payload->>'currency'='USD' then 2 else 3 end) or payload->>'debit_account'=payload->>'credit_account' or length(trim(coalesce(payload->>'description','')))<5 then raise exception 'A precise positive amount, different accounts and documented reason are required';end if;
 insert into clinic.journals(organization_id,currency,description,source_type,source_id,effective_date) values(o,payload->>'currency',payload->>'description','dated_adjustment',gen_random_uuid(),(payload->>'posting_day')::date) returning id into rid;
 insert into clinic.journal_lines(organization_id,journal_id,account,debit,credit) values(o,rid,payload->>'debit_account',amount,0),(o,rid,payload->>'credit_account',0,amount);
 when 'finance.bank.import' then
 if jsonb_typeof(payload->'lines')<>'array' or jsonb_array_length(payload->'lines') not between 1 and 1000 then raise exception 'Import 1–1000 statement lines at a time';end if;
 for item in select * from jsonb_array_elements(payload->'lines') loop
 if length(trim(coalesce(item->>'external_id','')))<1 or length(item->>'external_id')>200 then raise exception 'Each statement line requires a stable external identifier';end if;
 select * into statement from clinic.bank_statement_lines where organization_id=o and account=item->>'account' and currency=item->>'currency' and external_id=item->>'external_id';
 if found then
 if statement.amount is distinct from (item->>'amount')::numeric or statement.posted_on is distinct from (item->>'posted_on')::date or statement.reference is distinct from item->>'reference' then raise exception 'Imported identifier was reused with different statement content' using errcode='23505';end if;rid:=statement.id;
 else insert into clinic.bank_statement_lines(organization_id,account,currency,posted_on,amount,reference,external_id) values(o,item->>'account',item->>'currency',(item->>'posted_on')::date,(item->>'amount')::numeric,item->>'reference',item->>'external_id') returning id into rid;end if;
 end loop;
 when 'finance.bank.match' then
 select * into statement from clinic.bank_statement_lines where id=v and organization_id=o for update;
 select l.*,j.currency into posting from clinic.journal_lines l join clinic.journals j on j.id=l.journal_id where l.id=(payload->>'journal_line_id')::uuid and j.organization_id=o;
 if statement.id is null or posting.id is null or statement.account<>posting.account or statement.currency<>posting.currency or statement.amount<>posting.debit-posting.credit then raise exception 'Statement and posting must have the same account, currency and amount';end if;
 if exists(select 1 from clinic.bank_matches m where m.organization_id=o and (m.statement_id=v or m.journal_line_id=posting.id) and not exists(select 1 from clinic.bank_match_reversals r where r.match_id=m.id)) then raise exception 'Statement line or posting is already reconciled';end if;
 insert into clinic.bank_matches(organization_id,statement_id,journal_line_id,reason) values(o,v,posting.id,payload->>'reason') returning id into rid;
 when 'finance.bank.reverse_match' then
 perform clinic.require_permission('approve');
 insert into clinic.bank_match_reversals(organization_id,match_id,reason) values(o,v,payload->>'reason') returning id into rid;
 else raise exception 'Unknown accounting operation';end case;
 if rid is null then raise exception 'No record changed';end if;
 result:=jsonb_build_object('id',rid);insert into clinic.requests(organization_id,actor_id,request_id,fingerprint,result) values(o,actor,request_id,fp,result);return result;
end $$;
revoke all on function public.finance_workflow(text,jsonb,uuid) from public,anon;
grant execute on function public.finance_workflow(text,jsonb,uuid) to authenticated;

create function public.accounting_page(record_type text,search_term text default '',cursor_id uuid default null) returns jsonb language plpgsql stable security invoker set search_path='' as $$
declare items jsonb;tbl text;more boolean;
begin perform clinic.require_permission('finance');
 select case record_type when 'statements' then 'bank_statement_lines' when 'matches' then 'bank_matches' when 'mappings' then 'account_mappings' when 'batches' then 'accounting_batches' when 'periods' then 'accounting_periods' end into tbl;
 if tbl is null then raise exception 'Invalid accounting list';end if;
 execute format($q$with records as (select r.id,r.created_at,to_jsonb(r) || case when $1='statements' then jsonb_build_object('matched',exists(select 1 from clinic.bank_matches m where m.statement_id=r.id and not exists(select 1 from clinic.bank_match_reversals x where x.match_id=m.id))) when $1='matches' then jsonb_build_object('reversed',exists(select 1 from clinic.bank_match_reversals x where x.match_id=r.id)) when $1='batches' then jsonb_build_object('acknowledged',exists(select 1 from clinic.accounting_acknowledgements a where a.batch_id=r.id)) else '{}'::jsonb end value from clinic.%I r where r.organization_id=$2),page as (select * from records r where ($3 is null or (r.created_at,r.id)<(select c.created_at,c.id from records c where c.id=$3)) and ($4='' or clinic.search_key(value::text) like '%%'||clinic.search_key(left($4,200))||'%%') order by created_at desc,id desc limit 51) select coalesce(jsonb_agg(value order by created_at desc,id desc),'[]') from page$q$,tbl) into items using record_type,clinic.org_id(),cursor_id,coalesce(search_term,'');
 more:=jsonb_array_length(items)>50;if more then items:=items-50;end if;return jsonb_build_object('items',items,'has_more',more);
end $$;
revoke all on function public.accounting_page(text,text,uuid) from public,anon;
grant execute on function public.accounting_page(text,text,uuid) to authenticated;
create function public.reconciliation_options(statement_id uuid,search_term text default '',cursor_id uuid default null) returns jsonb language plpgsql stable security invoker set search_path='' as $$
declare s clinic.bank_statement_lines;items jsonb;more boolean;
begin perform clinic.require_permission('finance');select * into s from clinic.bank_statement_lines where id=statement_id and organization_id=clinic.org_id();if not found then raise exception 'Statement unavailable';end if;
 select coalesce(jsonb_agg(to_jsonb(r) order by r.created_at desc,r.id desc),'[]') into items from (select l.id,j.created_at,j.description,l.account,j.currency,l.debit-l.credit amount from clinic.journal_lines l join clinic.journals j on j.id=l.journal_id where j.organization_id=clinic.org_id() and l.account=s.account and j.currency=s.currency and l.debit-l.credit=s.amount and not exists(select 1 from clinic.bank_matches m where m.journal_line_id=l.id and not exists(select 1 from clinic.bank_match_reversals x where x.match_id=m.id)) and (cursor_id is null or (j.created_at,l.id)<(select cj.created_at,cl.id from clinic.journal_lines cl join clinic.journals cj on cj.id=cl.journal_id where cl.id=cursor_id and cj.organization_id=clinic.org_id())) and (coalesce(search_term,'')='' or clinic.search_key(j.description) like '%'||clinic.search_key(left(search_term,200))||'%') order by j.created_at desc,l.id desc limit 26) r;
 more:=jsonb_array_length(items)>25;if more then items:=items-25;end if;return jsonb_build_object('items',items,'has_more',more);
end $$;
revoke all on function public.reconciliation_options(uuid,text,uuid) from public,anon;
grant execute on function public.reconciliation_options(uuid,text,uuid) to authenticated;
create function public.accounting_batch_download(batch_id uuid) returns jsonb language plpgsql security invoker set search_path='' as $$declare result jsonb;begin
 perform clinic.require_permission('export');
 if not exists(select 1 from clinic.accounting_batches where id=batch_id and organization_id=clinic.org_id()) then raise exception 'Batch unavailable';end if;
 select coalesce(jsonb_agg(to_jsonb(r) order by r.date,r.journal_id,r.line_id),'[]') into result from (select i.batch_id,j.id journal_id,l.id line_id,j.accounting_date date,j.currency,i.account_code,l.account,l.debit,l.credit,j.source_type,j.source_id,j.description from clinic.accounting_batch_items i join clinic.journal_lines l on l.id=i.line_id join clinic.journals j on j.id=l.journal_id where i.batch_id=accounting_batch_download.batch_id and i.organization_id=clinic.org_id()) r;
 perform clinic.log_access('ACCOUNTING_BATCH_DOWNLOAD',batch_id,'accounting_batch');return result;end $$;
revoke all on function public.accounting_batch_download(uuid) from public,anon;
grant execute on function public.accounting_batch_download(uuid) to authenticated;
