-- Permit safe, idempotent like writes while keeping individual reactions private.
grant select on public.community_post_likes to authenticated;
drop policy if exists "Like totals are public" on public.community_post_likes;
drop policy if exists "Members read their own likes" on public.community_post_likes;
create policy "Members read their own likes"
  on public.community_post_likes for select to authenticated
  using (user_id = (select auth.uid()));

grant select on public.community_sample_post_likes to authenticated;
drop policy if exists "Members read their own example likes" on public.community_sample_post_likes;
create policy "Members read their own example likes"
  on public.community_sample_post_likes for select to authenticated
  using (user_id = (select auth.uid()));

-- Deletes through PostgREST also need SELECT on the target table. Keep direct
-- reads limited to the member's own rows; the public comment views stay intact.
grant select on public.community_comments to authenticated;
drop policy if exists "Comments are public" on public.community_comments;
drop policy if exists "Members read their own comments" on public.community_comments;
create policy "Members read their own comments"
  on public.community_comments for select to authenticated
  using (user_id = (select auth.uid()));

grant select on public.community_sample_comments to authenticated;
drop policy if exists "Members read their own example comments" on public.community_sample_comments;
create policy "Members read their own example comments"
  on public.community_sample_comments for select to authenticated
  using (user_id = (select auth.uid()));

-- Comment views filter blocked members on the server, avoiding a second request
-- every time the comments panel opens.
create or replace view public.community_sample_comment_feed
with (security_invoker = false) as
select c.id, c.sample_post_key, c.user_id,
       case when coalesce(pr.is_public, true)
         then coalesce(nullif(pr.display_name, ''), 'Membro')
         else 'Membro'
       end as author_name,
       case when coalesce(pr.is_public, true) then pr.avatar_url else null end as author_avatar_url,
       c.content, c.created_at
from public.community_sample_comments c
left join public.profiles pr on pr.id = c.user_id
where not exists (
  select 1 from public.community_blocks b
  where b.blocker_id = (select auth.uid()) and b.blocked_id = c.user_id
);
grant select on public.community_sample_comment_feed to anon, authenticated;

create or replace view public.community_comment_feed
with (security_invoker = false) as
select c.id, c.post_id, c.user_id,
       case when coalesce(pr.is_public, true)
         then coalesce(nullif(pr.display_name, ''), 'Membro')
         else 'Membro'
       end as author_name,
       c.content, c.created_at,
       case when coalesce(pr.is_public, true) then pr.avatar_url else null end as author_avatar_url
from public.community_comments c
left join public.profiles pr on pr.id = c.user_id
where not exists (
  select 1 from public.community_blocks b
  where b.blocker_id = (select auth.uid()) and b.blocked_id = c.user_id
);
grant select on public.community_comment_feed to anon, authenticated;

-- The feed itself applies member blocks so clients no longer need to fetch the
-- block list before every page of posts.
create or replace view public.community_feed with (security_invoker = false) as
select p.id, p.user_id,
       case when coalesce(pr.is_public, true)
         then coalesce(nullif(pr.display_name, ''), 'Membro')
         else 'Membro'
       end as author_name,
       p.content, p.achievement_tag, p.created_at,
       (select count(*)::integer from public.community_post_likes l where l.post_id = p.id) as likes_count,
       (select count(*)::integer from public.community_comments c where c.post_id = p.id) as comments_count,
       exists(select 1 from public.community_post_likes l
         where l.post_id = p.id and l.user_id = (select auth.uid())) as liked_by_me,
       p.topic,
       case when coalesce(pr.is_public, true) then pr.avatar_url else null end as author_avatar_url
from public.community_posts p
left join public.profiles pr on pr.id = p.user_id
where not exists (
  select 1 from public.community_blocks b
  where b.blocker_id = (select auth.uid()) and b.blocked_id = p.user_id
);
grant select on public.community_feed to anon, authenticated;
