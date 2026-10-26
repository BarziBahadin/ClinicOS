-- Anonymous requests must not execute application operations, even when their
-- bodies also reject missing identity. Service-only operations stay server-only.
do $$declare f record;begin
 for f in select p.oid::regprocedure signature from pg_proc p join pg_namespace n on n.oid=p.pronamespace
 where n.nspname in ('clinic','public') and p.prokind='f'
 and not exists(select 1 from pg_depend d where d.classid='pg_proc'::regclass and d.objid=p.oid and d.deptype='e') loop
 execute format('revoke all on function %s from public,anon',f.signature);
 end loop;
end $$;
alter default privileges for role postgres in schema public revoke execute on functions from public,anon;
alter default privileges for role postgres in schema clinic revoke execute on functions from public,anon;
revoke all on function public.media_finalize(uuid,boolean),public.provision_member(uuid,uuid,text,text) from authenticated;
