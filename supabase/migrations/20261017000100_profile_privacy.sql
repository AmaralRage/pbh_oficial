-- Let each member choose whether their display name appears in public community feeds.
alter table public.profiles
  add column if not exists is_public boolean not null default true;

revoke select (display_name) on public.profiles from anon, authenticated;
grant select (is_public) on public.profiles to anon, authenticated;
grant update (is_public) on public.profiles to authenticated;

drop policy if exists "Members manage their own profile visibility" on public.profiles;
create policy "Members manage their own profile visibility"
  on public.profiles
  for update
  to authenticated
  using (id = (select auth.uid()))
  with check (id = (select auth.uid()));

create or replace view public.community_feed with (security_invoker = false) as
select p.id, p.user_id,
       case when coalesce(pr.is_public, true)
         then coalesce(nullif(pr.display_name, ''), 'Membro')
         else 'Membro'
       end as author_name,
       p.content, p.achievement_tag, p.created_at,
       (select count(*)::integer from public.community_post_likes l where l.post_id = p.id) as likes_count,
       (select count(*)::integer from public.community_comments c where c.post_id = p.id) as comments_count,
       exists(select 1 from public.community_post_likes l where l.post_id = p.id and l.user_id = (select auth.uid())) as liked_by_me
from public.community_posts p
left join public.profiles pr on pr.id = p.user_id;
grant select on public.community_feed to anon, authenticated;

create or replace view public.community_comment_feed with (security_invoker = false) as
select c.id, c.post_id, c.user_id,
       case when coalesce(pr.is_public, true)
         then coalesce(nullif(pr.display_name, ''), 'Membro')
         else 'Membro'
       end as author_name,
       c.content, c.created_at
from public.community_comments c
left join public.profiles pr on pr.id = c.user_id;
grant select on public.community_comment_feed to anon, authenticated;
