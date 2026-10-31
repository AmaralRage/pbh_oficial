begin;
alter table public.community_posts add column edited_at timestamptz, add column pinned_at timestamptz;
create index community_posts_pin_time on public.community_posts(pinned_at desc nulls last,created_at desc,id desc);
revoke update on public.community_posts from authenticated;
revoke insert(edited_at,pinned_at),update(content,edited_at,pinned_at) on public.community_posts from authenticated;
create function public.edit_community_post(p_id uuid,p_content text,p_expected text) returns void
language plpgsql security definer set search_path='' as $$
begin
  if auth.uid() is null then raise exception 'Entre na sua conta.' using errcode='42501'; end if;
  if p_content is null or length(btrim(p_content)) not between 1 and 2000 then raise exception 'Escreva até 2000 caracteres.'; end if;
  update public.community_posts set content=btrim(p_content),edited_at=case when content<>btrim(p_content) then now() else edited_at end
    where id=p_id and user_id=auth.uid() and content=p_expected;
  if not found then raise exception 'A publicação mudou ou não pertence a você. Atualize antes de editar.' using errcode='40001'; end if;
end $$;
create function public.pin_community_post(p_id uuid,p_pin boolean) returns void
language plpgsql security definer set search_path='' as $$
begin
  if not exists(select 1 from auth.users where id=auth.uid() and lower(email)='amaralaragao31@gmail.com' and email_confirmed_at is not null) then
    raise exception 'Somente o fundador pode fixar avisos.' using errcode='42501'; end if;
  if p_pin is null then raise exception 'Escolha uma ação.'; end if;
  perform pg_catalog.pg_advisory_xact_lock(310001);
  if p_pin and (select count(*) from public.community_posts where pinned_at is not null and id<>p_id)>=3 then
    raise exception 'Você pode manter até três publicações fixadas.'; end if;
  update public.community_posts set pinned_at=case when p_pin then now() else null end where id=p_id and user_id=auth.uid();
  if not found then raise exception 'Fixe somente suas próprias publicações.' using errcode='42501'; end if;
end $$;
revoke all on function public.edit_community_post(uuid,text,text),public.pin_community_post(uuid,boolean) from public,anon;
grant execute on function public.edit_community_post(uuid,text,text),public.pin_community_post(uuid,boolean) to authenticated;

create table public.community_reply_notifications(
  id uuid primary key default gen_random_uuid(),recipient_id uuid not null references auth.users(id) on delete cascade,
  actor_id uuid not null references auth.users(id) on delete cascade,
  post_id uuid not null references public.community_posts(id) on delete cascade,
  comment_id uuid not null unique references public.community_comments(id) on delete cascade,
  parent_comment_id uuid not null references public.community_comments(id) on delete cascade,
  created_at timestamptz not null default now(),read_at timestamptz
);
create index community_reply_notifications_recipient_time on public.community_reply_notifications(recipient_id,created_at desc);
create index community_reply_notifications_parent on public.community_reply_notifications(parent_comment_id);
alter table public.community_reply_notifications enable row level security;
revoke all on public.community_reply_notifications from public,anon,authenticated;
grant select,update(read_at) on public.community_reply_notifications to authenticated;
create function public.can_view_community_reply(p_post uuid,p_actor uuid) returns boolean
language sql stable security definer set search_path='' as $$
  select not exists(select 1 from public.community_blocks b where
    (b.blocker_id=(select auth.uid()) and b.blocked_id=p_actor) or (b.blocked_id=(select auth.uid()) and b.blocker_id=p_actor))
    and exists(select 1 from public.community_feed f where f.id=p_post);
$$;
revoke all on function public.can_view_community_reply(uuid,uuid) from public,anon;
grant execute on function public.can_view_community_reply(uuid,uuid) to authenticated;
create policy "Recipients read available replies" on public.community_reply_notifications for select to authenticated using(
  recipient_id=(select auth.uid()) and public.can_view_community_reply(post_id,actor_id));
create policy "Recipients mark replies read" on public.community_reply_notifications for update to authenticated
  using(recipient_id=(select auth.uid())) with check(recipient_id=(select auth.uid()));
create function public.notify_community_reply() returns trigger
language plpgsql security definer set search_path='' as $$
declare recipient uuid;
begin
  select user_id into recipient from public.community_comments where id=new.reply_to_id and post_id=new.post_id;
  if recipient is not null and recipient<>new.user_id and not exists(select 1 from public.community_blocks b where
    (b.blocker_id=recipient and b.blocked_id=new.user_id) or (b.blocker_id=new.user_id and b.blocked_id=recipient)) then
    insert into public.community_reply_notifications(recipient_id,actor_id,post_id,comment_id,parent_comment_id) values(recipient,new.user_id,new.post_id,new.id,new.reply_to_id);
  end if;
  return new;
end $$;
revoke all on function public.notify_community_reply() from public,anon,authenticated;
create trigger notify_community_reply after insert on public.community_comments for each row execute function public.notify_community_reply();

create or replace view public.community_feed with(security_invoker=false) as
select p.id,p.user_id,
  case when coalesce(pr.is_public,true) then coalesce(nullif(pr.display_name,''),'Membro') else 'Membro' end as author_name,
  p.content,p.achievement_tag,p.created_at,
  (select count(*)::integer from public.community_post_likes l where l.post_id=p.id) as likes_count,
  (select count(*)::integer from public.community_comments c where c.post_id=p.id) as comments_count,
  exists(select 1 from public.community_post_likes l where l.post_id=p.id and l.user_id=(select auth.uid())) as liked_by_me,
  p.topic,case when coalesce(pr.is_public,true) then pr.avatar_url else null end as author_avatar_url,
  p.image_paths,p.edited_at,p.pinned_at
from public.community_posts p left join public.profiles pr on pr.id=p.user_id
where not exists(select 1 from public.community_blocks b where
  (b.blocker_id=(select auth.uid()) and b.blocked_id=p.user_id) or
  (b.blocker_id=p.user_id and b.blocked_id=(select auth.uid())));
grant select on public.community_feed to anon,authenticated;
commit;
