-- Community discovery, member blocking and admin report review.
alter table public.community_posts
  add column if not exists topic text;

alter table public.community_posts
  drop constraint if exists community_posts_topic_check;
alter table public.community_posts
  add constraint community_posts_topic_check
  check (topic is null or topic in ('disciplina', 'treino', 'leitura', 'proposito', 'reflexao'));

alter table public.community_reports
  add column if not exists reason text not null default 'other',
  add column if not exists status text not null default 'open';
alter table public.community_reports
  drop constraint if exists community_reports_reason_check;
alter table public.community_reports
  add constraint community_reports_reason_check
  check (reason in ('spam', 'harassment', 'inappropriate', 'other'));
alter table public.community_reports
  drop constraint if exists community_reports_status_check;
alter table public.community_reports
  add constraint community_reports_status_check
  check (status in ('open', 'reviewed', 'removed', 'dismissed'));

create index if not exists community_posts_topic_created_idx on public.community_posts(topic, created_at desc);
create index if not exists community_reports_status_created_idx on public.community_reports(status, created_at desc);

create table if not exists public.community_blocks (
  blocker_id uuid not null references auth.users(id) on delete cascade,
  blocked_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (blocker_id, blocked_id),
  check (blocker_id <> blocked_id)
);

alter table public.community_blocks enable row level security;
revoke all on public.community_blocks from anon, authenticated;
grant select, insert (blocker_id, blocked_id), delete on public.community_blocks to authenticated;
drop policy if exists "Members read their blocks" on public.community_blocks;
create policy "Members read their blocks" on public.community_blocks for select to authenticated using (blocker_id = (select auth.uid()));
drop policy if exists "Members block accounts for themselves" on public.community_blocks;
create policy "Members block accounts for themselves" on public.community_blocks for insert to authenticated with check (blocker_id = (select auth.uid()));
drop policy if exists "Members remove their own blocks" on public.community_blocks;
create policy "Members remove their own blocks" on public.community_blocks for delete to authenticated using (blocker_id = (select auth.uid()));

grant insert (user_id, content, achievement_tag, topic) on public.community_posts to authenticated;
grant insert (reporter_id, post_id, reason) on public.community_reports to authenticated;

create or replace view public.community_feed with (security_invoker = false) as
select p.id, p.user_id,
       case when coalesce(pr.is_public, true)
         then coalesce(nullif(pr.display_name, ''), 'Membro')
         else 'Membro'
       end as author_name,
       p.content, p.achievement_tag, p.created_at,
       (select count(*)::integer from public.community_post_likes l where l.post_id = p.id) as likes_count,
       (select count(*)::integer from public.community_comments c where c.post_id = p.id) as comments_count,
       exists(select 1 from public.community_post_likes l where l.post_id = p.id and l.user_id = (select auth.uid())) as liked_by_me,
       p.topic
from public.community_posts p
left join public.profiles pr on pr.id = p.user_id;
grant select on public.community_feed to anon, authenticated;

create or replace view public.community_admin_report_feed with (security_invoker = false) as
select r.id, r.post_id, r.reason, r.status, r.created_at,
       p.content as post_content,
       case when coalesce(pr.is_public, true) then coalesce(nullif(pr.display_name, ''), 'Membro') else 'Membro' end as post_author
from public.community_reports r
join public.community_posts p on p.id = r.post_id
left join public.profiles pr on pr.id = p.user_id
where r.status = 'open'
  and exists (select 1 from public.profiles me where me.id = (select auth.uid()) and me.role = 'admin');
grant select on public.community_admin_report_feed to authenticated;

create or replace function public.review_community_report(p_report_id uuid, p_action text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  report_post_id uuid;
begin
  if not exists (select 1 from public.profiles where id = (select auth.uid()) and role = 'admin') then
    raise exception 'Apenas administradores podem revisar denúncias.' using errcode = '42501';
  end if;
  if p_action not in ('keep', 'remove') then
    raise exception 'Ação de moderação inválida.' using errcode = '22023';
  end if;
  select post_id into report_post_id from public.community_reports where id = p_report_id and status = 'open';
  if report_post_id is null then return; end if;
  if p_action = 'remove' then
    delete from public.community_posts where id = report_post_id;
    update public.community_reports set status = 'removed' where id = p_report_id;
  else
    update public.community_reports set status = 'dismissed' where id = p_report_id;
  end if;
end;
$$;
revoke all on function public.review_community_report(uuid, text) from public;
grant execute on function public.review_community_report(uuid, text) to authenticated;
