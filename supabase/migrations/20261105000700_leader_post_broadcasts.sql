begin;
create table public.community_post_broadcasts(
  post_id uuid primary key references public.community_posts(id) on delete cascade,
  announcement_id uuid not null unique references public.announcements(id) on delete cascade,
  schedule_id uuid not null unique references public.announcement_schedules(id) on delete cascade
);
alter table public.community_post_broadcasts enable row level security;
revoke all on public.community_post_broadcasts from public,anon,authenticated;
grant all on public.community_post_broadcasts to service_role;

create function public.queue_community_post_broadcast(p_post uuid) returns uuid
language plpgsql security definer set search_path='' as $$
declare item public.community_posts; notice uuid; job uuid;
begin
  if not exists(select 1 from auth.users u where u.id=(select auth.uid())
      and u.email_confirmed_at is not null and u.raw_app_meta_data->'pbh_project_leader'='true'::jsonb) then
    raise exception 'Somente o líder pode avisar todos os membros.' using errcode='42501';
  end if;
  select * into item from public.community_posts where id=p_post and user_id=(select auth.uid()) for update;
  if not found then raise exception 'Publicação indisponível.' using errcode='22023'; end if;
  select announcement_id into notice from public.community_post_broadcasts where post_id=p_post;
  if found then return notice; end if;
  insert into public.announcements(title,message,audience,destination_url,sound_enabled,created_by)
    values('Nova publicação do líder',left(btrim(item.content),500),'all',
      'https://pbh-oficial.vercel.app/?community_post='||item.id::text,true,(select auth.uid())) returning id into notice;
  insert into public.announcement_schedules(title,message,audience,destination_url,sound_enabled,
      scheduled_at,created_by,status,announcement_id,published_at)
    values('Nova publicação do líder',left(btrim(item.content),500),'all',
      'https://pbh-oficial.vercel.app/?community_post='||item.id::text,true,
      now(),(select auth.uid()),'published',notice,now()) returning id into job;
  insert into public.community_post_broadcasts values(p_post,notice,job);
  -- Reuse the durable scheduler. Missing delivery configuration leaves the job
  -- queued for cron; a client never receives any service credentials.
  perform public.run_announcement_scheduler();
  return notice;
end $$;
revoke all on function public.queue_community_post_broadcast(uuid) from public,anon;
grant execute on function public.queue_community_post_broadcast(uuid) to authenticated;

create function public.remove_community_post_broadcast() returns trigger
language plpgsql security definer set search_path='' as $$
declare item public.community_post_broadcasts;
begin
  select * into item from public.community_post_broadcasts where post_id=old.id;
  if found then
    delete from public.announcement_schedules where id=item.schedule_id;
    delete from public.announcements where id=item.announcement_id;
  end if;
  return old;
end $$;
revoke all on function public.remove_community_post_broadcast() from public,anon,authenticated;
create trigger remove_community_post_broadcast before delete on public.community_posts
  for each row execute function public.remove_community_post_broadcast();
commit;
