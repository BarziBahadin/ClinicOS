SET local check_function_bodies = off;

DROP POLICY "redemption_billing_insert" ON "clinic"."package_redemptions";

DROP POLICY "redemption_billing_read" ON "clinic"."package_redemptions";

DROP POLICY "scoped_insert" ON "clinic"."package_redemptions";

DROP POLICY "scoped_read" ON "clinic"."package_redemptions";

DROP INDEX "clinic"."payments_organization_id_invoice_id_fkey_idx";

CREATE OR REPLACE FUNCTION clinic.balanced_journal()
  RETURNS TRIGGER
  LANGUAGE plpgsql
  SET search_path TO ''
  AS $function$
declare j uuid; d numeric; c numeric; n integer; curr text;
begin if tg_table_name='journals' then j:=new.id; else j:=new.journal_id; end if;
 select sum(debit),sum(credit),count(*) into d,c,n from clinic.journal_lines where journal_id=j;
 select currency into curr from clinic.journals where id=j;
 if n<2 or d<>c or (curr='USD' and (d<>round(d,2) or exists(select 1 from clinic.journal_lines where journal_id=j and (debit<>round(debit,2) or credit<>round(credit,2))))) then raise exception 'Unbalanced or imprecise journal' using errcode='23514'; end if;
 return null;
end $function$;

CREATE OR REPLACE FUNCTION public.command (
  kind       text,
  payload    jsonb,
  request_id uuid
)
  RETURNS jsonb
  LANGUAGE plpgsql
  SET search_path TO ''
  AS $function$
declare
 o uuid:=clinic.org_id(); actor uuid:=auth.uid(); fingerprint text:=md5(kind||payload::text);
 previous clinic.requests; rid uuid; p uuid; e uuid; a uuid; amt numeric; due numeric; curr text; method text;
 row_patient clinic.patients; row_enc clinic.encounters; row_invoice clinic.invoices; row_payment clinic.payments;
 row_lot clinic.stock_lots; row_package clinic.packages; row_till clinic.tills; row_result clinic.results; row_appointment clinic.appointments;
 line jsonb; lines jsonb:='[]'; total numeric:=0; num text; result jsonb; rate numeric; v_redemption_amount numeric;
begin
 if o is null or actor is null then raise exception 'Not authenticated' using errcode='42501'; end if;
 if request_id is null or jsonb_typeof(payload)<>'object' or octet_length(payload::text)>200000 then raise exception 'Invalid request'; end if;
 perform pg_advisory_xact_lock(hashtextextended(o::text,0));
 select * into previous from clinic.requests r where r.organization_id=o and r.actor_id=actor and r.request_id=command.request_id;
 if found then if previous.fingerprint<>fingerprint then raise exception 'Request identifier was reused with different content' using errcode='23505'; end if; return previous.result; end if;
 p:=nullif(payload->>'patient_id','')::uuid; e:=nullif(payload->>'encounter_id','')::uuid;
 curr:=coalesce(payload->>'currency','IQD'); method:=coalesce(payload->>'method','cash');
 amt:=nullif(payload->>'amount','')::numeric;
 if method not in ('cash','bank','card') then raise exception 'Invalid payment method'; end if;
 if amt is not null and (amt<=0 or curr not in ('USD','IQD') or amt<>round(amt,case when curr='USD' then 2 else 3 end)) then raise exception 'Invalid amount or currency precision' using errcode='23514'; end if;
 if p is not null then
 select * into row_patient from clinic.patients where id=p and organization_id=o;
 if not found then raise exception 'Patient not found' using errcode='P0002'; end if;
 if row_patient.merged_into is not null and kind<>'patient.merge' then raise exception 'Patient was merged; use the active profile' using errcode='23514'; end if;
 end if;
 case kind
 when 'patient.create' then
 perform clinic.require_permission('patients');
 num:='P-'||lpad(((select count(*) from clinic.patients where organization_id=o)+1)::text,6,'0');
 insert into clinic.patients(organization_id,patient_number,full_name,phone,contact_owner,birth_date,birth_precision,gender,language,guardian_name,guardian_relationship,communication_consent,reported_age,age_recorded_on)
 values(o,num,trim(payload->>'full_name'),nullif(payload->>'phone',''),payload->>'contact_owner',nullif(payload->>'birth_date','')::date,coalesce(payload->>'birth_precision','unknown'),coalesce(payload->>'gender','unknown'),coalesce(payload->>'language','ckb'),payload->>'guardian_name',payload->>'guardian_relationship',coalesce((payload->>'communication_consent')::boolean,false),nullif(payload->>'reported_age','')::integer,case when nullif(payload->>'reported_age','') is not null then (now() at time zone 'Asia/Baghdad')::date end) returning id into rid;
 when 'patient.update' then
 perform clinic.require_permission('patients');
 if row_patient.version is distinct from (payload->>'version')::integer then raise exception 'This profile changed on another device. Refresh and compare your changes.' using errcode='40001'; end if;
 if row_patient.phone is distinct from nullif(payload->>'phone','') and row_patient.phone is not null then insert into clinic.contacts(organization_id,patient_id,phone,owner_name,valid_to) values(o,p,row_patient.phone,row_patient.contact_owner,now()); end if;
 update clinic.patients set full_name=trim(payload->>'full_name'),phone=nullif(payload->>'phone',''),contact_owner=payload->>'contact_owner',birth_date=nullif(payload->>'birth_date','')::date,birth_precision=coalesce(payload->>'birth_precision','unknown'),gender=coalesce(payload->>'gender','unknown'),language=coalesce(payload->>'language','ckb'),guardian_name=payload->>'guardian_name',guardian_relationship=payload->>'guardian_relationship',communication_consent=coalesce((payload->>'communication_consent')::boolean,false),version=version+1,updated_at=now() where id=p returning id into rid;
 when 'patient.merge' then
 perform clinic.require_permission('approve');
 a:=(payload->>'target_id')::uuid;
 if p=a or length(trim(coalesce(payload->>'reason','')))<8 then raise exception 'A different target and documented identity review are required'; end if;
 if row_patient.merged_into is not null or not exists(select 1 from clinic.patients where id=a and organization_id=o and merged_into is null) then raise exception 'Invalid merge target'; end if;
 update clinic.patients set merged_into=a,version=version+1 where id=p returning id into rid;
 insert into clinic.patient_merges(organization_id,source_id,target_id,reason) values(o,p,a,payload->>'reason');
 perform clinic.log_access('PATIENT_MERGE',p,'patient');
 when 'appointment.create' then
 perform clinic.require_permission('schedule');
 a:=(payload->>'doctor_id')::uuid;
 if not exists(select 1 from clinic.memberships where user_id=a and organization_id=o and active and role='doctor') then raise exception 'Select an active clinician'; end if;
 if exists(select 1 from clinic.appointments where organization_id=o and doctor_id=a and status not in ('cancelled','no_show') and starts_at<(payload->>'ends_at')::timestamptz and ends_at>(payload->>'starts_at')::timestamptz) then raise exception 'The clinician already has an appointment at this time' using errcode='23P01'; end if;
 insert into clinic.appointments(organization_id,branch_id,patient_id,doctor_id,starts_at,ends_at,service_name,walk_in,status,checked_in_at) values(o,clinic.branch_id(),p,a,(payload->>'starts_at')::timestamptz,(payload->>'ends_at')::timestamptz,payload->>'service_name',coalesce((payload->>'walk_in')::boolean,false),case when (payload->>'walk_in')::boolean then 'checked_in' else 'scheduled' end,case when (payload->>'walk_in')::boolean then now() end) returning id into rid;
 when 'appointment.status' then
 perform clinic.require_permission('schedule');
 select * into row_appointment from clinic.appointments where id=(payload->>'id')::uuid;
 if not found then raise exception 'Appointment not found'; end if;
 if row_appointment.version is distinct from (payload->>'version')::integer then raise exception 'Appointment changed. Refresh first.' using errcode='40001'; end if;
 if not ((row_appointment.status='scheduled' and payload->>'status' in ('checked_in','cancelled','no_show')) or (row_appointment.status='checked_in' and payload->>'status' in ('in_care','cancelled')) or (row_appointment.status='in_care' and payload->>'status'='completed')) then raise exception 'Invalid appointment status transition'; end if;
 if payload->>'status' in ('cancelled','no_show') and length(trim(coalesce(payload->>'reason','')))<3 then raise exception 'A reason is required'; end if;
 update clinic.appointments set status=payload->>'status',checked_in_at=case when payload->>'status'='checked_in' then now() else checked_in_at end,cancellation_reason=payload->>'reason',version=version+1 where id=row_appointment.id returning id into rid;
 when 'encounter.save' then
 perform clinic.require_permission('clinical');
 if nullif(payload->>'id','') is null then
 insert into clinic.encounters(organization_id,patient_id,doctor_id,branch_id,appointment_id,chief_complaint,history,allergies,findings,diagnosis,plan,prescriptions,clinical_sex_notes,birth_snapshot)
 values(o,p,actor,clinic.branch_id(),nullif(payload->>'appointment_id','')::uuid,payload->>'chief_complaint',coalesce(payload->>'history',''),coalesce(payload->>'allergies','Not reviewed'),coalesce(payload->>'findings',''),coalesce(payload->>'diagnosis',''),coalesce(payload->>'plan',''),coalesce(payload->>'prescriptions',''),coalesce(payload->>'clinical_sex_notes',''),jsonb_build_object('birth_date',row_patient.birth_date,'precision',row_patient.birth_precision,'reported_age',row_patient.reported_age,'age_recorded_on',row_patient.age_recorded_on)) returning id into rid;
 else
 select * into row_enc from clinic.encounters where id=(payload->>'id')::uuid;
 if not found or row_enc.doctor_id<>actor then raise exception 'Only the author may edit this draft' using errcode='42501'; end if;
 if row_enc.version is distinct from (payload->>'version')::integer then raise exception 'Encounter changed. Refresh and compare your changes.' using errcode='40001'; end if;
 update clinic.encounters set chief_complaint=payload->>'chief_complaint',history=coalesce(payload->>'history',''),allergies=coalesce(payload->>'allergies','Not reviewed'),findings=coalesce(payload->>'findings',''),diagnosis=coalesce(payload->>'diagnosis',''),plan=coalesce(payload->>'plan',''),prescriptions=coalesce(payload->>'prescriptions',''),clinical_sex_notes=coalesce(payload->>'clinical_sex_notes',''),version=version+1 where id=row_enc.id returning id into rid;
 end if;
 when 'encounter.sign' then
 perform clinic.require_permission('clinical');
 select * into row_enc from clinic.encounters where id=(payload->>'id')::uuid;
 if not found or row_enc.doctor_id<>actor then raise exception 'Only the author may sign' using errcode='42501'; end if;
 if row_enc.version is distinct from (payload->>'version')::integer then raise exception 'Encounter changed. Refresh first.' using errcode='40001'; end if;
 if length(trim(row_enc.diagnosis))=0 or length(trim(row_enc.plan))=0 or row_enc.allergies in ('','Not reviewed') then raise exception 'Review allergies, diagnosis and plan before signing'; end if;
 update clinic.encounters set status='signed',signed_at=now(),version=version+1 where id=row_enc.id returning id into rid;
 when 'encounter.addendum' then
 perform clinic.require_permission('clinical');
 if not exists(select 1 from clinic.encounters where id=e and status='signed') then raise exception 'Select a signed encounter'; end if;
 insert into clinic.addenda(organization_id,encounter_id,content) values(o,e,payload->>'content') returning id into rid;
 when 'procedure.create' then
 perform clinic.require_permission('clinical');
 if not exists(select 1 from clinic.encounters where id=e and patient_id=p) then raise exception 'Encounter does not belong to patient'; end if;
 if not exists(select 1 from clinic.consents c where patient_id=p and purpose='procedure' and granted and not exists(select 1 from clinic.consents n where n.patient_id=p and n.purpose=c.purpose and n.created_at>c.created_at)) then raise exception 'Current procedure consent is required'; end if;
 insert into clinic.procedures(organization_id,patient_id,encounter_id,name,body_site,product,lot_number,settings,quantity,aftercare,adverse_event) values(o,p,e,payload->>'name',payload->>'body_site',payload->>'product',payload->>'lot_number',payload->>'settings',nullif(payload->>'quantity','')::numeric,payload->>'aftercare',payload->>'adverse_event') returning id into rid;
 when 'consent.record' then
 perform clinic.require_permission('patients');
 if payload->>'purpose'<>'communication' then perform clinic.require_permission('clinical'); end if;
 insert into clinic.consents(organization_id,patient_id,purpose,granted,template_version,evidence) values(o,p,payload->>'purpose',(payload->>'granted')::boolean,payload->>'template_version',payload->>'evidence') returning id into rid;
 when 'task.create' then
 perform clinic.require_permission('results');
 if not exists(select 1 from clinic.memberships where user_id=(payload->>'assigned_to')::uuid and organization_id=o and active and role='doctor') then raise exception 'Select an active clinician'; end if;
 insert into clinic.tasks(organization_id,patient_id,title,due_at,assigned_to) values(o,p,payload->>'title',(payload->>'due_at')::timestamptz,(payload->>'assigned_to')::uuid) returning id into rid;
 when 'task.complete' then
 perform clinic.require_permission('results');
 update clinic.tasks set completed_at=now() where id=(payload->>'id')::uuid and completed_at is null returning id into rid;
 when 'result.create' then
 perform clinic.require_permission('results');
 insert into clinic.results(organization_id,patient_id,order_name,body_site,specimen_reference,due_at,assigned_to) values(o,p,payload->>'order_name',payload->>'body_site',payload->>'specimen_reference',(payload->>'due_at')::timestamptz,actor) returning id into rid;
 when 'result.update' then
 perform clinic.require_permission('results');
 select * into row_result from clinic.results where id=(payload->>'id')::uuid;
 if not found then raise exception 'Result not found'; end if;
 if row_result.version is distinct from (payload->>'version')::integer then raise exception 'Result changed. Refresh first.' using errcode='40001'; end if;
 if not ((row_result.status='ordered' and payload->>'status'='received') or (row_result.status='received' and payload->>'status'='reviewed') or (row_result.status='reviewed' and payload->>'status'='notified') or (row_result.status='notified' and payload->>'status'='closed')) then raise exception 'Review and patient notification must happen in order'; end if;
 if length(trim(coalesce(payload->>'result_text','')))<3 then raise exception 'Document the result, review or communication evidence'; end if;
 update clinic.results set status=payload->>'status',result_text=coalesce(result_text||E'\n','')||'['||(payload->>'status')||'] '||(payload->>'result_text'),version=version+1 where id=row_result.id returning id into rid;
 when 'service.save' then
 perform clinic.require_permission('settings');
 if (payload->>'price')::numeric<0 or (payload->>'price')::numeric<>round((payload->>'price')::numeric,case when curr='USD' then 2 else 3 end) then raise exception 'Invalid service price precision'; end if;
 insert into clinic.services(organization_id,name,name_ckb,category,currency,price,duration) values(o,payload->>'name',coalesce(payload->>'name_ckb',''),payload->>'category',curr,(payload->>'price')::numeric,(payload->>'duration')::integer) returning id into rid;
 when 'invoice.issue' then
 perform clinic.require_permission('billing');
 if jsonb_typeof(payload->'lines')<>'array' or jsonb_array_length(payload->'lines') not between 1 and 100 then raise exception 'Invoice must have 1–100 lines'; end if;
 for line in select * from jsonb_array_elements(payload->'lines') loop
 select to_jsonb(s) into result from clinic.services s where s.id=(line->>'service_id')::uuid and organization_id=o and active;
 if result is null or result->>'currency'<>curr then raise exception 'Invoice lines must use active services in the invoice currency'; end if;
 amt:=(result->>'price')::numeric * (line->>'quantity')::integer;
 if (line->>'quantity')::integer not between 1 and 1000 then raise exception 'Invalid quantity'; end if;
 total:=total+amt;
 lines:=lines||jsonb_build_array(jsonb_build_object('service_id',result->>'id','description',result->>'name','quantity',(line->>'quantity')::integer,'unit_price',result->>'price','amount',amt));
 end loop;
 num:='INV-'||lpad(((select count(*) from clinic.invoices where organization_id=o)+1)::text,6,'0');
 if nullif(payload->>'discount','') is not null and (payload->>'discount')::numeric<>0 then
 perform clinic.require_permission('approve');amt:=(payload->>'discount')::numeric;
 if amt<0 or amt>=total or amt<>round(amt,case when curr='USD' then 2 else 3 end) then raise exception 'Discount must be positive, precise and smaller than invoice total'; end if;
 if length(trim(coalesce(payload->>'discount_reason','')))<5 then raise exception 'A discount reason is required'; end if;
 lines:=lines||jsonb_build_array(jsonb_build_object('description','Discount: '||(payload->>'discount_reason'),'quantity',1,'unit_price',-amt,'amount',-amt));total:=total-amt;
 end if;
 insert into clinic.invoices(organization_id,patient_id,invoice_number,patient_snapshot,currency,lines,total) values(o,p,num,jsonb_build_object('full_name',row_patient.full_name,'patient_number',row_patient.patient_number),curr,lines,total) returning id into rid;
 perform clinic.post_journal(curr,num,'invoice',rid,'receivable','revenue',total);
 when 'invoice.credit' then
 perform clinic.require_permission('approve');a:=(payload->>'invoice_id')::uuid;
 select * into row_invoice from clinic.invoices where id=a;
 if not found or curr<>row_invoice.currency then raise exception 'Invoice or currency mismatch'; end if;
 select row_invoice.total-coalesce((select sum(pm.amount) from clinic.payments pm where invoice_id=a and pm.kind in ('payment','deposit_application')),0)-coalesce((select sum(amount) from clinic.credit_notes where invoice_id=a),0)+coalesce((select sum(pm.amount) from clinic.payments pm where invoice_id=a and pm.kind='refund'),0) into due;
 if amt is null or amt>due or length(trim(coalesce(payload->>'reason','')))<5 then raise exception 'Credit cannot exceed outstanding balance and requires a reason'; end if;
 insert into clinic.credit_notes(organization_id,invoice_id,amount,reason) values(o,a,amt,payload->>'reason') returning id into rid;
 perform clinic.post_journal(curr,'Invoice correction','credit_note',rid,'revenue','receivable',amt);
 when 'payment.record' then
 perform clinic.require_permission('billing');
 a:=nullif(payload->>'invoice_id','')::uuid;
 if amt is null then raise exception 'Payment amount is required'; end if;
 if a is not null then
 select * into row_invoice from clinic.invoices where id=a and patient_id=p;
 if not found or row_invoice.currency<>curr then raise exception 'Invoice or currency mismatch'; end if;
 select row_invoice.total-coalesce((select sum(amount) from clinic.payments pm where invoice_id=a and pm.kind in ('payment','deposit_application')),0)-coalesce((select sum(amount) from clinic.credit_notes where invoice_id=a),0)+coalesce((select sum(amount) from clinic.payments pm where invoice_id=a and pm.kind='refund'),0) into due;
 if amt>due then raise exception 'Payment exceeds the outstanding invoice balance'; end if;
 end if;
 if method='deposit' then raise exception 'Use Apply deposit for existing patient credit'; end if;
 insert into clinic.payments(organization_id,patient_id,invoice_id,currency,amount,method,kind) values(o,p,a,curr,amt,method,case when a is null then 'deposit' else 'payment' end) returning id into rid;
 perform clinic.post_journal(curr,'Patient receipt','payment',rid,method,case when a is null then 'deposits' else 'receivable' end,amt);
 when 'deposit.apply' then
 perform clinic.require_permission('billing');
 a:=(payload->>'invoice_id')::uuid;
 select * into row_invoice from clinic.invoices where id=a and patient_id=p;
 if not found or row_invoice.currency<>curr then raise exception 'Invoice or currency mismatch'; end if;
 select coalesce(sum(case when pm.kind='deposit' then amount when pm.kind='deposit_application' then -amount when pm.kind='refund' and invoice_id is null then -amount else 0 end),0) into total from clinic.payments pm where patient_id=p and currency=curr;
 select row_invoice.total-coalesce((select sum(amount) from clinic.payments pm where invoice_id=a and pm.kind in ('payment','deposit_application')),0)-coalesce((select sum(amount) from clinic.credit_notes where invoice_id=a),0)+coalesce((select sum(amount) from clinic.payments pm where invoice_id=a and pm.kind='refund'),0) into due;
 if amt is null or amt>total or amt>due then raise exception 'Insufficient deposit or invoice balance'; end if;
 insert into clinic.payments(organization_id,patient_id,invoice_id,currency,amount,method,kind) values(o,p,a,curr,amt,'deposit','deposit_application') returning id into rid;
 perform clinic.post_journal(curr,'Apply patient deposit','deposit_application',rid,'deposits','receivable',amt);
 when 'refund.record' then
 perform clinic.require_permission('approve');
 select * into row_payment from clinic.payments pm where id=(payload->>'payment_id')::uuid and pm.kind in ('payment','deposit');
 if not found then raise exception 'Original payment not found'; end if;
 if length(trim(coalesce(payload->>'reason','')))<5 then raise exception 'A refund reason is required'; end if;
 if amt is null or curr<>row_payment.currency or amt>row_payment.amount-coalesce((select sum(amount) from clinic.payments pm where original_payment_id=row_payment.id and pm.kind='refund'),0) then raise exception 'Refund exceeds the unrefunded original payment'; end if;
 if row_payment.kind='deposit' then
 select coalesce(sum(case when pm.kind='deposit' then amount when pm.kind='deposit_application' then -amount when pm.kind='refund' and invoice_id is null then -amount else 0 end),0) into total from clinic.payments pm where patient_id=row_payment.patient_id and currency=curr;
 if amt>total then raise exception 'Deposit has already been used'; end if;
 else
 insert into clinic.credit_notes(organization_id,invoice_id,amount,reason) values(o,row_payment.invoice_id,amt,payload->>'reason') returning id into a;
 perform clinic.post_journal(curr,'Service credit','credit_note',a,'revenue','receivable',amt);
 end if;
 insert into clinic.payments(organization_id,patient_id,invoice_id,currency,amount,method,kind,original_payment_id,reason) values(o,row_payment.patient_id,row_payment.invoice_id,curr,amt,row_payment.method,'refund',row_payment.id,payload->>'reason') returning id into rid;
 perform clinic.post_journal(curr,'Patient refund','refund',rid,case when row_payment.kind='deposit' then 'deposits' else 'receivable' end,row_payment.method,amt);
 when 'expense.record' then
 perform clinic.require_permission('finance');
 if payload->>'category'='salary' then perform clinic.require_permission('payroll'); end if;
 if amt is null then raise exception 'Amount is required'; end if;
 insert into clinic.expenses(organization_id,category,supplier,description,currency,amount,paid,method) values(o,payload->>'category',payload->>'supplier',payload->>'description',curr,amt,(payload->>'paid')::boolean,method) returning id into rid;
 perform clinic.post_journal(curr,payload->>'description','expense',rid,'expense',case when (payload->>'paid')::boolean then method else 'payable' end,amt);
 when 'cash.record' then
 perform clinic.require_permission('approve');
 if payload->>'kind' not in ('owner_contribution','owner_withdrawal','owner_loan','transfer','opening_balance') then raise exception 'Invalid cash movement type'; end if;
 if payload->>'kind'='transfer' and (payload->>'destination'=method or payload->>'destination' not in ('cash','bank','card') or payload->>'destination' is null) then raise exception 'Select a different destination account'; end if;
 if amt is null then raise exception 'Amount is required'; end if;
 insert into clinic.cash_movements(organization_id,kind,currency,amount,method,destination,description) values(o,payload->>'kind',curr,amt,method,nullif(payload->>'destination',''),payload->>'description') returning id into rid;
 perform clinic.post_journal(curr,payload->>'description','cash_movement',rid,
 case when payload->>'kind'='owner_withdrawal' then 'equity' when payload->>'kind'='transfer' then payload->>'destination' else method end,
 case when payload->>'kind'='owner_withdrawal' or payload->>'kind'='transfer' then method when payload->>'kind'='owner_loan' then 'owner_loan' else 'equity' end,amt);
 when 'fx.exchange' then
 perform clinic.require_permission('approve'); rate:=(payload->>'rate')::numeric;
 if amt is null or rate<=0 or rate<>round(rate,6) or curr=payload->>'destination_currency' or payload->>'destination_currency' not in ('IQD','USD') then raise exception 'Provide two currencies and a positive explicit conversion rate'; end if;
 total:=round(amt*rate,case when payload->>'destination_currency'='USD' then 2 else 3 end);
 insert into clinic.cash_movements(organization_id,kind,currency,amount,method,description,fx_rate) values(o,'fx_exchange',curr,amt,method,'FX out: '||(payload->>'description'),rate) returning id into rid;
 insert into clinic.cash_movements(organization_id,kind,currency,amount,method,description,fx_rate,related_id) values(o,'fx_exchange',payload->>'destination_currency',total,method,'FX in: '||(payload->>'description'),rate,rid) returning id into a;
 perform clinic.post_journal(curr,'FX out','fx',rid,'fx_clearing',method,amt);
 perform clinic.post_journal(payload->>'destination_currency','FX in','fx',a,method,'fx_clearing',total);
 when 'stock.receive' then
 perform clinic.require_permission('inventory');
 if amt is null then raise exception 'Quantity required'; end if;
 insert into clinic.stock_lots(organization_id,product,lot_number,expires_on,unit,quantity) values(o,payload->>'product',payload->>'lot_number',(payload->>'expires_on')::date,payload->>'unit',amt)
 on conflict(organization_id,product,lot_number) do update set quantity=clinic.stock_lots.quantity+excluded.quantity,version=clinic.stock_lots.version+1 returning id into rid;
 insert into clinic.stock_movements(organization_id,lot_id,quantity,reason) values(o,rid,amt,'Receipt');
 when 'stock.use' then
 perform clinic.require_permission('clinical');
 select * into row_lot from clinic.stock_lots where id=(payload->>'lot_id')::uuid;
 if not found or row_lot.expires_on<(now() at time zone 'Asia/Baghdad')::date or amt is null or amt>row_lot.quantity then raise exception 'Insufficient or expired stock'; end if;
 if not exists(select 1 from clinic.encounters where id=e) then raise exception 'A clinical encounter is required'; end if;
 update clinic.stock_lots set quantity=quantity-amt,version=version+1 where id=row_lot.id;
 insert into clinic.stock_movements(organization_id,lot_id,encounter_id,quantity,reason) values(o,row_lot.id,e,-amt,payload->>'reason') returning id into rid;
 when 'till.open' then
 perform clinic.require_permission('billing');
 if (payload->>'opening')::numeric<0 then raise exception 'Opening amount must not be negative'; end if;
 insert into clinic.tills(organization_id,currency,opening) values(o,curr,(payload->>'opening')::numeric) returning id into rid;
 when 'till.close' then
 perform clinic.require_permission('billing');
 select * into row_till from clinic.tills where id=(payload->>'id')::uuid and closed_at is null;
 if not found then raise exception 'Open till not found'; end if;
 select row_till.opening+coalesce(sum(l.debit-l.credit),0) into total from clinic.journal_lines l join clinic.journals j on j.id=l.journal_id where j.currency=row_till.currency and l.account='cash' and j.created_at>=row_till.opened_at;
 if (payload->>'counted')::numeric<0 or ((payload->>'counted')::numeric<>total and length(trim(coalesce(payload->>'reason','')))<5) then raise exception 'Document the reason for a cash discrepancy'; end if;
 update clinic.tills set closed_at=now(),expected=total,counted=(payload->>'counted')::numeric,reason=payload->>'reason' where id=row_till.id returning id into rid;
 when 'settings.update' then
 perform clinic.require_permission('settings');
 update clinic.organizations set name=payload->>'name',require_mfa=coalesce((payload->>'require_mfa')::boolean,true) where id=o returning id into rid;
 when 'package.sell' then
 perform clinic.require_permission('billing');
 if amt is null or (payload->>'sessions')::integer not between 1 and 1000 then raise exception 'Package amount and valid session count are required'; end if;
 insert into clinic.packages(organization_id,patient_id,name,sessions,remaining,currency,total) values(o,p,payload->>'name',(payload->>'sessions')::integer,(payload->>'sessions')::integer,curr,amt) returning id into rid;
 perform clinic.post_journal(curr,'Prepaid treatment package','package_sale',rid,method,'deposits',amt);
 when 'package.redeem' then
 perform clinic.require_permission('billing');
 select * into row_package from clinic.packages where id=(payload->>'package_id')::uuid and patient_id=p;
 e:=(payload->>'encounter_id')::uuid;
 if not found or row_package.remaining<=0 then raise exception 'Package has no available sessions'; end if;
 if clinic.billing_encounter_patient(e) is distinct from p then raise exception 'A signed encounter for this patient is required'; end if;
 total:=case when row_package.remaining=1 then row_package.total-row_package.redeemed_value else round(row_package.total/row_package.sessions,case when row_package.currency='USD' then 2 else 3 end) end;
 insert into clinic.package_redemptions(organization_id,package_id,encounter_id) values(o,row_package.id,e) returning id into rid;
 v_redemption_amount:=total;
 update clinic.packages set remaining=remaining-1,redeemed_value=redeemed_value+v_redemption_amount where id=row_package.id;
 if total>0 then perform clinic.post_journal(row_package.currency,'Treatment package session','package_redemption',rid,'deposits','revenue',total); end if;
 when 'expense.pay' then
 perform clinic.require_permission('finance');
 select amount,currency into total,curr from clinic.expenses where id=(payload->>'expense_id')::uuid and not paid;
 if not found or exists(select 1 from clinic.journals where source_type='expense_payment' and source_id=(payload->>'expense_id')::uuid) then raise exception 'Unpaid expense not found or already settled'; end if;
 rid:=clinic.post_journal(curr,'Supplier payable settlement','expense_payment',(payload->>'expense_id')::uuid,'payable',method,total);
 when 'member.update' then
 perform clinic.require_permission('staff');
 a:=(payload->>'user_id')::uuid;
 if a=actor then raise exception 'You cannot change your own access'; end if;
 if payload->>'role' not in ('owner','administrator','doctor','receptionist','accountant') then raise exception 'Invalid role'; end if;
 update clinic.memberships set role=payload->>'role',active=(payload->>'active')::boolean where user_id=a and organization_id=o returning id into rid;
 when 'journal.post' then
 perform clinic.require_permission('approve');
 if amt is null or payload->>'debit_account'=payload->>'credit_account' or length(trim(coalesce(payload->>'description','')))<5 then raise exception 'Use different accounts and explain the adjustment'; end if;
 rid:=clinic.post_journal(curr,payload->>'description','manual',gen_random_uuid(),payload->>'debit_account',payload->>'credit_account',amt);
 else raise exception 'Unsupported operation: %',kind using errcode='22023';
 end case;
 if rid is null then raise exception 'No record was changed. Refresh and verify your access.' using errcode='P0002'; end if;
 result:=jsonb_build_object('id',rid);
 insert into clinic.requests(organization_id,actor_id,request_id,fingerprint,result) values(o,actor,command.request_id,fingerprint,result);
 return result;
end $function$;

CREATE OR REPLACE FUNCTION public.workspace()
  RETURNS jsonb
  LANGUAGE plpgsql
  SET search_path TO ''
  AS $function$
declare o uuid:=clinic.org_id(); m clinic.memberships; r jsonb;
begin
 if o is null then raise exception 'No active clinic membership. Ask the owner to invite your account.' using errcode='42501'; end if;
 select * into m from clinic.memberships where organization_id=o and user_id=auth.uid();
 r:=jsonb_build_object('organization',(select to_jsonb(x) from clinic.organizations x where id=o),'membership',to_jsonb(m),'permissions',case when exists(select 1 from clinic.organizations where id=o and (not require_mfa or auth.jwt()->>'aal'='aal2')) then to_jsonb(clinic.permissions(m.role)) else '[]'::jsonb end);
 r:=r || jsonb_build_object(
 'patients',coalesce((select jsonb_agg(x) from (select * from clinic.patients where organization_id=o order by created_at desc limit 300) x),'[]'),
 'appointments',coalesce((select jsonb_agg(x) from (select * from clinic.appointments where organization_id=o and starts_at>now()-interval '30 days' order by starts_at limit 500) x),'[]'),
 'encounters',coalesce((select jsonb_agg(x) from (select id,patient_id,doctor_id,status,chief_complaint,created_at,version from clinic.encounters where organization_id=o order by created_at desc limit 300) x),'[]'),
 'services',coalesce((select jsonb_agg(x) from clinic.services x where organization_id=o and active),'[]'),
 'invoices',coalesce((select jsonb_agg(x) from (select i.*,i.total-coalesce((select sum(pm.amount) from clinic.payments pm where pm.invoice_id=i.id and pm.kind in ('payment','deposit_application')),0)-coalesce((select sum(c.amount) from clinic.credit_notes c where c.invoice_id=i.id),0)+coalesce((select sum(pm.amount) from clinic.payments pm where pm.invoice_id=i.id and pm.kind='refund'),0) balance from clinic.invoices i where organization_id=o order by created_at desc limit 300) x),'[]'),
 'payments',coalesce((select jsonb_agg(x) from (select * from clinic.payments pm where organization_id=o order by created_at desc limit 500) x),'[]'),
 'expenses',coalesce((select jsonb_agg(x) from (select e.*, (e.paid or exists(select 1 from clinic.journals j where j.organization_id=o and j.source_type='expense_payment' and j.source_id=e.id)) is_paid from clinic.expenses e where organization_id=o order by created_at desc limit 300) x),'[]'),
 'tasks',coalesce((select jsonb_agg(x) from (select * from clinic.tasks where organization_id=o order by due_at limit 300) x),'[]'),
 'results',coalesce((select jsonb_agg(x) from (select * from clinic.results where organization_id=o order by created_at desc limit 300) x),'[]'),
 'consents',coalesce((select jsonb_agg(x) from (select * from clinic.consents where organization_id=o order by created_at desc limit 500) x),'[]'),
 'media',coalesce((select jsonb_agg(x) from (select * from clinic.media where organization_id=o order by created_at desc limit 300) x),'[]'),
 'stock',coalesce((select jsonb_agg(x) from clinic.stock_lots x where organization_id=o),'[]'),
 'movements',coalesce((select jsonb_agg(x) from (select * from clinic.cash_movements where organization_id=o order by created_at desc limit 300) x),'[]'),
 'journals',case when clinic.allowed('finance') then coalesce((select jsonb_agg(x) from (select j.*, (select jsonb_agg(l) from clinic.journal_lines l where l.journal_id=j.id) lines from clinic.journals j where organization_id=o order by created_at desc limit 500) x),'[]') else '[]'::jsonb end,
 'tills',coalesce((select jsonb_agg(x) from (select * from clinic.tills where organization_id=o order by opened_at desc limit 100) x),'[]'),
 'members',coalesce((select jsonb_agg(x) from clinic.memberships x where organization_id=o),'[]'),
 'audit',coalesce((select jsonb_agg(x) from (select * from clinic.audit_events where organization_id=o order by created_at desc limit 200) x),'[]'),
 'packages',coalesce((select jsonb_agg(x) from clinic.packages x where organization_id=o),'[]'),
 'billable_encounters',clinic.billable_encounters(),
 'trial_balance',case when clinic.allowed('finance') then coalesce((select jsonb_agg(x) from (select j.currency,l.account,sum(l.debit) debit,sum(l.credit) credit from clinic.journal_lines l join clinic.journals j on j.id=l.journal_id where j.organization_id=o group by j.currency,l.account) x),'[]') else '[]'::jsonb end);
 if clinic.allowed('clinical') then perform clinic.log_access('WORKSPACE_READ',null,'clinical_summary'); end if;
 return r;
end $function$;

CREATE CONSTRAINT TRIGGER journal_header_must_balance
  AFTER INSERT ON clinic.journals DEFERRABLE INITIALLY DEFERRED
  FOR EACH ROW
  EXECUTE FUNCTION clinic.balanced_journal();

CREATE POLICY "scoped_insert" ON "clinic"."package_redemptions"
  FOR INSERT
  TO "authenticated"
  WITH CHECK (((organization_id = clinic.org_id()) AND clinic.allowed('billing'::text)));

CREATE POLICY "scoped_read" ON "clinic"."package_redemptions"
  FOR SELECT
  TO "authenticated"
  USING (((organization_id = clinic.org_id()) AND clinic.allowed('billing'::text)));

