-- Persist interactions on the built-in example posts and expose profile photos
-- alongside names in the community comment/feed views.
alter table public.profiles add column if not exists avatar_url text;
grant update (avatar_url) on public.profiles to authenticated;

create or replace function public.sync_profile_from_auth_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.profiles (id, email, role, display_name, avatar_url)
  values (
    new.id,
    coalesce(new.email, ''),
    case
      when lower(coalesce(new.email, '')) = 'amaralaragao31@gmail.com'
       and new.email_confirmed_at is not null then 'admin'
      else 'member'
    end,
    case
      when lower(coalesce(new.email, '')) = 'amaralaragao31@gmail.com' then 'Amaral'
      else nullif(btrim(coalesce(new.raw_user_meta_data ->> 'display_name', '')), '')
    end,
    coalesce(
      nullif(btrim(coalesce(new.raw_user_meta_data ->> 'avatar_url', '')), ''),
      nullif(btrim(coalesce(new.raw_user_meta_data ->> 'picture', '')), ''),
      nullif(btrim(coalesce(new.raw_user_meta_data ->> 'avatar', '')), '')
    )
  )
  on conflict (id) do update
    set email = excluded.email,
        role = excluded.role,
        display_name = coalesce(excluded.display_name, public.profiles.display_name),
        avatar_url = coalesce(excluded.avatar_url, public.profiles.avatar_url);
  return new;
end;
$$;

drop trigger if exists sync_profile_after_auth_user_change on auth.users;
create trigger sync_profile_after_auth_user_change
after insert or update of email, email_confirmed_at, raw_user_meta_data on auth.users
for each row execute function public.sync_profile_from_auth_user();

update public.profiles p
set avatar_url = coalesce(
  nullif(btrim(coalesce(u.raw_user_meta_data ->> 'avatar_url', '')), ''),
  nullif(btrim(coalesce(u.raw_user_meta_data ->> 'picture', '')), ''),
  nullif(btrim(coalesce(u.raw_user_meta_data ->> 'avatar', '')), '')
)
from auth.users u
where p.id = u.id and p.avatar_url is null;

create table if not exists public.community_sample_post_likes (
  sample_post_key text not null check (sample_post_key in (
    'sample-samuel', 'sample-wellerson', 'sample-kanye', 'sample-chad'
  )),
  user_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (sample_post_key, user_id)
);

create table if not exists public.community_sample_comments (
  id uuid primary key default gen_random_uuid(),
  sample_post_key text not null check (sample_post_key in (
    'sample-samuel', 'sample-wellerson', 'sample-kanye', 'sample-chad'
  )),
  user_id uuid not null references auth.users(id) on delete cascade,
  content text not null check (char_length(btrim(content)) between 1 and 1000),
  created_at timestamptz not null default now()
);
create index if not exists community_sample_comments_post_created_idx
  on public.community_sample_comments(sample_post_key, created_at);

alter table public.community_sample_post_likes enable row level security;
alter table public.community_sample_comments enable row level security;
revoke all on public.community_sample_post_likes, public.community_sample_comments
  from anon, authenticated;
grant insert (sample_post_key, user_id), delete
  on public.community_sample_post_likes to authenticated;
grant insert (sample_post_key, user_id, content), delete
  on public.community_sample_comments to authenticated;

drop policy if exists "Members like examples as themselves" on public.community_sample_post_likes;
create policy "Members like examples as themselves"
  on public.community_sample_post_likes for insert to authenticated
  with check (user_id = (select auth.uid()));
drop policy if exists "Members remove their example likes" on public.community_sample_post_likes;
create policy "Members remove their example likes"
  on public.community_sample_post_likes for delete to authenticated
  using (user_id = (select auth.uid()));
drop policy if exists "Members comment on examples as themselves" on public.community_sample_comments;
create policy "Members comment on examples as themselves"
  on public.community_sample_comments for insert to authenticated
  with check (user_id = (select auth.uid()));
drop policy if exists "Members delete their own example comments" on public.community_sample_comments;
create policy "Members delete their own example comments"
  on public.community_sample_comments for delete to authenticated
  using (user_id = (select auth.uid()));

create or replace view public.community_sample_post_feed
with (security_invoker = false) as
select sample.sample_post_key,
       (select count(*)::integer from public.community_sample_post_likes l
        where l.sample_post_key = sample.sample_post_key) as likes_count,
       exists(select 1 from public.community_sample_post_likes l
        where l.sample_post_key = sample.sample_post_key
          and l.user_id = (select auth.uid())) as liked_by_me,
       (select count(*)::integer from public.community_sample_comments c
        where c.sample_post_key = sample.sample_post_key) as comments_count
from (values
  ('sample-samuel'::text), ('sample-wellerson'::text),
  ('sample-kanye'::text), ('sample-chad'::text)
) as sample(sample_post_key);
grant select on public.community_sample_post_feed to anon, authenticated;

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
left join public.profiles pr on pr.id = c.user_id;
grant select on public.community_sample_comment_feed to anon, authenticated;

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
left join public.profiles pr on pr.id = p.user_id;
grant select on public.community_feed to anon, authenticated;

create or replace view public.community_comment_feed with (security_invoker = false) as
select c.id, c.post_id, c.user_id,
       case when coalesce(pr.is_public, true)
         then coalesce(nullif(pr.display_name, ''), 'Membro')
         else 'Membro'
       end as author_name,
       c.content, c.created_at,
       case when coalesce(pr.is_public, true) then pr.avatar_url else null end as author_avatar_url
from public.community_comments c
left join public.profiles pr on pr.id = c.user_id;
grant select on public.community_comment_feed to anon, authenticated;
