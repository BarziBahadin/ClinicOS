-- Staff call reminders only. This operation never sends an external message.
alter table clinic.contacts add unique(organization_id,id);
alter table clinic.contact_log add column appointment_id uuid;
alter table clinic.contact_log add column appointment_version integer check(appointment_version>0);
alter table clinic.contact_log add check((appointment_id is null)=(appointment_version is null));
alter table clinic.contact_log add column contact_id uuid;
alter table clinic.contact_log add foreign key(organization_id,appointment_id) references clinic.appointments(organization_id,id);
alter table clinic.contact_log add foreign key(organization_id,contact_id) references clinic.contacts(organization_id,id);
create index contact_reminder_latest on clinic.contact_log(organization_id,appointment_id,created_at desc,id desc);
create index contact_log_contact_idx on clinic.contact_log(organization_id,contact_id);
create function public.phone_reminders(from_day date,to_day date,include_contacted boolean default false,page_number integer default 0) returns jsonb language plpgsql stable security invoker set search_path='' as $$
declare first_at timestamptz;last_at timestamptz;items jsonb;records integer;
begin
 perform clinic.require_permission('patients');perform clinic.require_permission('schedule');
 if from_day is null or to_day is null or to_day<from_day or to_day-from_day>31 or page_number is null or page_number not between 0 and 100000 then raise exception 'Choose a reminder range of at most 32 days';end if;
 first_at:=from_day::timestamp at time zone 'Asia/Baghdad';last_at:=(to_day+1)::timestamp at time zone 'Asia/Baghdad';
 with eligible as materialized (
 select a.id,a.version,a.starts_at,a.ends_at,a.service_name,p.id patient_id,p.full_name patient_name,p.patient_number,m.display_name clinician_name,
 coalesce(consent.granted,false) communication_allowed,c.id contact_id,case when coalesce(consent.granted,false) then coalesce(c.phone,p.phone) else null end phone,
 case when c.id is not null then c.owner_name else p.contact_owner end contact_owner,
 last_call.outcome last_outcome,last_call.created_at last_call_at,coalesce(last_call.outcome in ('reached','declined'),false) contacted
 from clinic.appointments a join clinic.patients p on p.id=clinic.canonical_patient_id(a.patient_id) and p.organization_id=a.organization_id
 left join clinic.memberships m on m.organization_id=a.organization_id and m.user_id=a.doctor_id
 left join lateral(select co.granted from clinic.consents co where co.organization_id=a.organization_id and co.patient_id=p.id and co.purpose='communication' order by co.created_at desc,co.id desc limit 1) consent on true
 left join lateral(select con.id,con.phone,con.owner_name from clinic.contacts con where con.organization_id=a.organization_id and con.patient_id=p.id and con.valid_to is null order by con.preferred desc,con.valid_from desc,con.id desc limit 1) c on true
 left join lateral(select l.outcome,l.created_at from clinic.contact_log l where l.organization_id=a.organization_id and l.appointment_id=a.id and l.appointment_version=a.version and l.purpose='appointment_reminder' and l.channel='phone' order by l.created_at desc,l.id desc limit 1) last_call on true
 where a.organization_id=(select clinic.org_id()) and a.status='scheduled' and a.starts_at>=first_at and a.starts_at<last_at
 ),filtered as materialized(select * from eligible where coalesce(include_contacted,false) or not contacted),page as(select * from filtered order by starts_at,id limit 100 offset page_number*100)
 select coalesce((select jsonb_agg(to_jsonb(r) order by r.starts_at,r.id) from page r),'[]'),(select count(*) from filtered) into items,records;
 return jsonb_build_object('items',items,'records',records,'has_more',records>(page_number+1)*100);
end $$;
revoke all on function public.phone_reminders(date,date,boolean,integer) from public,anon;
grant execute on function public.phone_reminders(date,date,boolean,integer) to authenticated;
alter policy scoped_read on clinic.consents using(organization_id=(select clinic.org_id()) and ((select clinic.allowed('clinical')) or (purpose='communication' and (select clinic.allowed('patients')))));
alter policy scoped_insert on clinic.consents with check(organization_id=(select clinic.org_id()) and ((select clinic.allowed('clinical')) or (purpose='communication' and (select clinic.allowed('patients')))));
