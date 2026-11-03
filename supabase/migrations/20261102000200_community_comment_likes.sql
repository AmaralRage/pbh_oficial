begin;
create table public.community_comment_likes(
  comment_id uuid not null references public.community_comments(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  primary key(comment_id,user_id)
);
create table public.community_sample_comment_likes(
  comment_id uuid not null references public.community_sample_comments(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  primary key(comment_id,user_id)
);
alter table public.community_comment_likes enable row level security;
alter table public.community_sample_comment_likes enable row level security;
revoke all on public.community_comment_likes,public.community_sample_comment_likes from anon,authenticated;
create function public.set_community_comment_like(p_id uuid,p_liked boolean,p_sample boolean default false)
returns void language plpgsql security definer set search_path='' as $$
begin
  if auth.uid() is null then raise exception 'Entre na sua conta.' using errcode='42501'; end if;
  if p_liked is null or p_sample is null then raise exception 'Invalid decision'; end if;
  if p_sample then
    if not exists(select 1 from public.community_sample_comment_feed where id=p_id) then raise exception 'Comment unavailable' using errcode='42501'; end if;
    if p_liked then insert into public.community_sample_comment_likes values(p_id,auth.uid()) on conflict do nothing;
    else delete from public.community_sample_comment_likes where comment_id=p_id and user_id=auth.uid(); end if;
  else
    if not exists(select 1 from public.community_comment_feed c join public.community_feed p on p.id=c.post_id where c.id=p_id) then raise exception 'Comment unavailable' using errcode='42501'; end if;
    if p_liked then insert into public.community_comment_likes values(p_id,auth.uid()) on conflict do nothing;
    else delete from public.community_comment_likes where comment_id=p_id and user_id=auth.uid(); end if;
  end if;
end $$;
revoke all on function public.set_community_comment_like(uuid,boolean,boolean) from public,anon;
grant execute on function public.set_community_comment_like(uuid,boolean,boolean) to authenticated;
create or replace view public.community_sample_comment_feed with(security_invoker=false) as
select c.id,c.sample_post_key,c.user_id,
  case when coalesce(pr.is_public,true) then coalesce(nullif(pr.display_name,''),'Membro') else 'Membro' end as author_name,
  case when coalesce(pr.is_public,true) then pr.avatar_url else null end as author_avatar_url,
  c.content,c.created_at,c.edited_at,c.reply_to_id,
  (select count(*)::integer from public.community_sample_comment_likes l where l.comment_id=c.id) as likes_count,
  exists(select 1 from public.community_sample_comment_likes l where l.comment_id=c.id and l.user_id=(select auth.uid())) as liked_by_me
from public.community_sample_comments c left join public.profiles pr on pr.id=c.user_id
where not exists(select 1 from public.community_blocks b where
  (b.blocker_id=(select auth.uid()) and b.blocked_id=c.user_id) or
  (b.blocker_id=c.user_id and b.blocked_id=(select auth.uid())));
create or replace view public.community_comment_feed with(security_invoker=false) as
select c.id,c.post_id,c.user_id,
  case when coalesce(pr.is_public,true) then coalesce(nullif(pr.display_name,''),'Membro') else 'Membro' end as author_name,
  c.content,c.created_at,
  case when coalesce(pr.is_public,true) then pr.avatar_url else null end as author_avatar_url,
  c.edited_at,c.reply_to_id,
  (select count(*)::integer from public.community_comment_likes l where l.comment_id=c.id) as likes_count,
  exists(select 1 from public.community_comment_likes l where l.comment_id=c.id and l.user_id=(select auth.uid())) as liked_by_me
from public.community_comments c left join public.profiles pr on pr.id=c.user_id
where not exists(select 1 from public.community_blocks b where
  (b.blocker_id=(select auth.uid()) and b.blocked_id=c.user_id) or
  (b.blocker_id=c.user_id and b.blocked_id=(select auth.uid())));
grant select on public.community_comment_feed,public.community_sample_comment_feed to anon,authenticated;

commit;
