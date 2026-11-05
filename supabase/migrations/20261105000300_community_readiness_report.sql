begin;
create or replace function public.admin_community_health() returns jsonb
language plpgsql security definer set search_path='' as $$
declare result jsonb; job jsonb;
begin
 if not coalesce(public.is_admin(),false) then raise exception 'Admin access required' using errcode='42501'; end if;
 select jsonb_build_object('expired_posts',count(*)) into result from public.community_posts p
 where p.created_at<=now()-interval '7 days' and not exists(select 1 from auth.users u where u.id=p.user_id and lower(coalesce(u.email,''))='amaralaragao31@gmail.com' and u.email_confirmed_at is not null);
 result:=result||jsonb_build_object('pending_media',(select count(*) from public.community_photo_cleanup));
 result:=result||jsonb_build_object('restrictions',coalesce((select jsonb_agg(to_jsonb(r)) from (
 select c.user_id,c.until_at,left(coalesce(nullif(u.raw_user_meta_data->>'display_name',''),p.display_name,'Membro'),40) as name
 from public.community_restrictions c join auth.users u on u.id=c.user_id left join public.profiles p on p.id=c.user_id
 where c.until_at>now() order by c.until_at limit 50) r),'[]'::jsonb));
 result:=result||jsonb_build_object('features',(select jsonb_agg(jsonb_build_object('label',label,'available',to_regprocedure(signature) is not null)) from (values
 ('Busca de membros','public.search_community_members(text,integer)'),
 ('Publicações do perfil','public.member_publications(uuid,integer)'),
 ('Editor de anexos','public.edit_community_publication(uuid,jsonb,text,text[],jsonb)'),
 ('Preferências de atividade','public.get_community_activity_preferences()'),
 ('Atividade detalhada','public.community_activity_page(integer)'),
 ('Marcar atividades lidas','public.mark_community_activity_read(timestamp with time zone)'),
 ('Menções','public.resolve_community_handles(text[])')
 ) f(label,signature)));
 result:=result||jsonb_build_object('due_media_objects',(
 select count(*) from storage.objects o join public.community_photo_cleanup q on o.name=any(q.paths)
 where o.bucket_id='community-photos' and q.not_before<=now()
 and not exists(select 1 from public.community_posts p where o.name=any(p.image_paths))),
 'oldest_cleanup_due',(select min(not_before) from public.community_photo_cleanup where not_before<=now()));
 if to_regclass('cron.job') is not null then
 execute $q$select jsonb_build_object('scheduled',j.active,'schedule',j.schedule,'last_status',r.status,'last_run',r.end_time)
 from cron.job j left join lateral(select status,end_time from cron.job_run_details where jobid=j.jobid order by runid desc limit 1) r on true
 where j.jobname='pbh-expire-community-member-posts' limit 1$q$ into job;
 end if;
 return result||coalesce(job,'{"scheduled":false}'::jsonb);
end $$;
revoke all on function public.admin_community_health() from public,anon;
grant execute on function public.admin_community_health() to authenticated;
commit;
