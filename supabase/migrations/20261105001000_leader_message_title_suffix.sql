begin;
-- Use the PBH leader message title for future community broadcasts.
create or replace function public.queue_community_post_broadcast(p_post uuid) returns uuid
language plpgsql security definer set search_path='' as $$
declare item public.community_posts; notice uuid; job uuid; author text; preview text;
begin
  if not exists(select 1 from auth.users u where u.id=(select auth.uid())
      and u.email_confirmed_at is not null and u.raw_app_meta_data->'pbh_project_leader'='true'::jsonb) then
    raise exception 'Somente o líder pode avisar todos os membros.' using errcode='42501';
  end if;
  select * into item from public.community_posts where id=p_post and user_id=(select auth.uid()) for update;
  if not found then raise exception 'Publicação indisponível.' using errcode='22023'; end if;
  select announcement_id into notice from public.community_post_broadcasts where post_id=p_post;
  if found then return notice; end if;
  select left(coalesce(nullif(btrim(u.raw_user_meta_data->>'display_name'),''),nullif(btrim(p.display_name),''),'Líder do PBH'),40)
    into author from auth.users u left join public.profiles p on p.id=u.id where u.id=(select auth.uid());
  preview:=regexp_replace(author||': '||btrim(item.content),'[[:space:]]+',' ','g');
  if length(preview)>240 then preview:=left(preview,239)||'…'; end if;
  insert into public.announcements(title,message,audience,destination_url,sound_enabled,created_by)
    values('Mensagem do Líder 👑',preview,'all',
      'https://pbh-oficial.vercel.app/?community_post='||item.id::text,true,(select auth.uid())) returning id into notice;
  insert into public.announcement_schedules(title,message,audience,destination_url,sound_enabled,
      scheduled_at,created_by,status,announcement_id,published_at)
    values('Mensagem do Líder 👑',preview,'all',
      'https://pbh-oficial.vercel.app/?community_post='||item.id::text,true,
      now(),(select auth.uid()),'published',notice,now()) returning id into job;
  insert into public.community_post_broadcasts values(p_post,notice,job);
  -- Reuse the durable scheduler. Missing delivery configuration leaves the job
  -- queued for cron; a client never receives any service credentials.
  perform public.run_announcement_scheduler();
  return notice;
end $$;
commit;
