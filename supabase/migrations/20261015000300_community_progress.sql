-- Persisted community, habit and challenge progress.
alter table public.profiles add column if not exists display_name text;

create or replace function public.sync_profile_from_auth_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.profiles (id, email, role, display_name)
  values (
    new.id,
    coalesce(new.email, ''),
    case
      when lower(coalesce(new.email, '')) = 'amaralaragao31@gmail.com'
       and new.email_confirmed_at is not null then 'admin'
      else 'member'
    end,
    coalesce(
      nullif(btrim(coalesce(new.raw_user_meta_data ->> 'display_name', '')), ''),
      case when lower(coalesce(new.email, '')) = 'amaralaragao31@gmail.com' then 'Amaral Aragão' end
    )
  )
  on conflict (id) do update
    set email = excluded.email,
        role = excluded.role,
        display_name = coalesce(excluded.display_name, public.profiles.display_name);
  return new;
end;
$$;

drop trigger if exists sync_profile_after_auth_user_change on auth.users;
create trigger sync_profile_after_auth_user_change
after insert or update of email, email_confirmed_at, raw_user_meta_data on auth.users
for each row execute function public.sync_profile_from_auth_user();

update public.profiles p
set display_name = nullif(btrim(coalesce(u.raw_user_meta_data ->> 'display_name', '')), '')
from auth.users u
where p.id = u.id and p.display_name is null;
update public.profiles
set display_name = 'Amaral Aragão'
where lower(email) = 'amaralaragao31@gmail.com' and display_name is null;

revoke all on table public.profiles from anon;
revoke select on table public.profiles from authenticated;
grant select (id, role, display_name) on table public.profiles to authenticated;
grant select (display_name) on table public.profiles to anon;
grant select (id) on table public.profiles to anon;
drop policy if exists "Public profile names are readable" on public.profiles;
create policy "Public profile names are readable" on public.profiles for select to anon, authenticated using (true);

create table if not exists public.community_posts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  content text not null check (char_length(btrim(content)) between 1 and 2000),
  achievement_tag text check (achievement_tag is null or char_length(achievement_tag) <= 80),
  created_at timestamptz not null default now()
);

create table if not exists public.community_post_likes (
  post_id uuid not null references public.community_posts(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (post_id, user_id)
);

create table if not exists public.community_comments (
  id uuid primary key default gen_random_uuid(),
  post_id uuid not null references public.community_posts(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  content text not null check (char_length(btrim(content)) between 1 and 1000),
  created_at timestamptz not null default now()
);

create table if not exists public.community_follows (
  follower_id uuid not null references auth.users(id) on delete cascade,
  followed_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (follower_id, followed_id),
  check (follower_id <> followed_id)
);
create table if not exists public.community_saved_posts (
  user_id uuid not null references auth.users(id) on delete cascade,
  post_id uuid not null references public.community_posts(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, post_id)
);
create table if not exists public.community_reports (
  id uuid primary key default gen_random_uuid(),
  reporter_id uuid not null references auth.users(id) on delete cascade,
  post_id uuid not null references public.community_posts(id) on delete cascade,
  created_at timestamptz not null default now(),
  unique (reporter_id, post_id)
);

create index if not exists community_posts_created_at_idx on public.community_posts(created_at desc);
create index if not exists community_comments_post_created_idx on public.community_comments(post_id, created_at);
create index if not exists community_follows_followed_idx on public.community_follows(followed_id, follower_id);

alter table public.community_posts enable row level security;
alter table public.community_post_likes enable row level security;
alter table public.community_comments enable row level security;
alter table public.community_follows enable row level security;
alter table public.community_saved_posts enable row level security;
alter table public.community_reports enable row level security;

revoke all on public.community_posts, public.community_post_likes, public.community_comments, public.community_follows, public.community_saved_posts, public.community_reports from anon, authenticated;
grant select on public.community_posts to anon, authenticated;
revoke select on public.community_post_likes, public.community_comments from anon, authenticated;
grant insert (user_id, content, achievement_tag), delete on public.community_posts to authenticated;
grant insert (post_id, user_id), delete on public.community_post_likes to authenticated;
grant insert (post_id, user_id, content), delete on public.community_comments to authenticated;
grant select, insert (follower_id, followed_id), delete on public.community_follows to authenticated;
grant select, insert (user_id, post_id), delete on public.community_saved_posts to authenticated;
grant insert (reporter_id, post_id) on public.community_reports to authenticated;

drop policy if exists "Community posts are public" on public.community_posts;
create policy "Community posts are public" on public.community_posts for select to anon, authenticated using (true);
drop policy if exists "Members publish their own posts" on public.community_posts;
create policy "Members publish their own posts" on public.community_posts for insert to authenticated with check (user_id = (select auth.uid()));
drop policy if exists "Members delete their own posts" on public.community_posts;
create policy "Members delete their own posts" on public.community_posts for delete to authenticated using (user_id = (select auth.uid()));

drop policy if exists "Like totals are public" on public.community_post_likes;
create policy "Like totals are public" on public.community_post_likes for select to anon, authenticated using (true);
drop policy if exists "Members like as themselves" on public.community_post_likes;
create policy "Members like as themselves" on public.community_post_likes for insert to authenticated with check (user_id = (select auth.uid()));
drop policy if exists "Members remove their likes" on public.community_post_likes;
create policy "Members remove their likes" on public.community_post_likes for delete to authenticated using (user_id = (select auth.uid()));

drop policy if exists "Comments are public" on public.community_comments;
create policy "Comments are public" on public.community_comments for select to anon, authenticated using (true);
drop policy if exists "Members comment as themselves" on public.community_comments;
create policy "Members comment as themselves" on public.community_comments for insert to authenticated with check (user_id = (select auth.uid()));
drop policy if exists "Members delete their comments" on public.community_comments;
create policy "Members delete their comments" on public.community_comments for delete to authenticated using (user_id = (select auth.uid()));

drop policy if exists "Follow lists are visible to members" on public.community_follows;
create policy "Follow lists are visible to members" on public.community_follows for select to authenticated using (true);
drop policy if exists "Members manage their own follows" on public.community_follows;
create policy "Members manage their own follows" on public.community_follows for insert to authenticated with check (follower_id = (select auth.uid()));
drop policy if exists "Members remove their own follows" on public.community_follows;
create policy "Members remove their own follows" on public.community_follows for delete to authenticated using (follower_id = (select auth.uid()));
drop policy if exists "Members read their saved posts" on public.community_saved_posts;
create policy "Members read their saved posts" on public.community_saved_posts for select to authenticated using (user_id = (select auth.uid()));
drop policy if exists "Members save posts for themselves" on public.community_saved_posts;
create policy "Members save posts for themselves" on public.community_saved_posts for insert to authenticated with check (user_id = (select auth.uid()));
drop policy if exists "Members unsave their own posts" on public.community_saved_posts;
create policy "Members unsave their own posts" on public.community_saved_posts for delete to authenticated using (user_id = (select auth.uid()));
drop policy if exists "Members report posts as themselves" on public.community_reports;
create policy "Members report posts as themselves" on public.community_reports for insert to authenticated with check (reporter_id = (select auth.uid()));

create or replace view public.community_feed with (security_invoker = false) as
select p.id, p.user_id, coalesce(nullif(pr.display_name, ''), 'Membro') as author_name,
       p.content, p.achievement_tag, p.created_at,
       (select count(*)::integer from public.community_post_likes l where l.post_id = p.id) as likes_count,
       (select count(*)::integer from public.community_comments c where c.post_id = p.id) as comments_count,
       exists(select 1 from public.community_post_likes l where l.post_id = p.id and l.user_id = (select auth.uid())) as liked_by_me
from public.community_posts p
left join public.profiles pr on pr.id = p.user_id;
grant select on public.community_feed to anon, authenticated;

create or replace function public.community_stats()
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'posts', (select count(*) from public.community_posts),
    'comments', (select count(*) from public.community_comments),
    'likes', (select count(*) from public.community_post_likes)
  );
$$;
revoke all on function public.community_stats() from public;
grant execute on function public.community_stats() to anon, authenticated;

create or replace view public.community_comment_feed with (security_invoker = false) as
select c.id, c.post_id, c.user_id, coalesce(nullif(pr.display_name, ''), 'Membro') as author_name,
       c.content, c.created_at
from public.community_comments c
left join public.profiles pr on pr.id = c.user_id;
grant select on public.community_comment_feed to anon, authenticated;

create table if not exists public.habit_completions (
  user_id uuid not null references auth.users(id) on delete cascade,
  habit_key text not null check (habit_key in ('train', 'read', 'digital_fast', 'meditate', 'sleep_early')),
  completed_on date not null,
  created_at timestamptz not null default now(),
  primary key (user_id, habit_key, completed_on)
);
create index if not exists habit_completions_user_date_idx on public.habit_completions(user_id, completed_on);
alter table public.habit_completions enable row level security;
revoke all on public.habit_completions from anon, authenticated;
grant select, insert (user_id, habit_key, completed_on), delete on public.habit_completions to authenticated;
drop policy if exists "Members read their own habit history" on public.habit_completions;
create policy "Members read their own habit history" on public.habit_completions for select to authenticated using (user_id = (select auth.uid()));
drop policy if exists "Members record their own habits" on public.habit_completions;
create policy "Members record their own habits" on public.habit_completions for insert to authenticated with check (user_id = (select auth.uid()) and completed_on <= current_date);
drop policy if exists "Members remove their own habit records" on public.habit_completions;
create policy "Members remove their own habit records" on public.habit_completions for delete to authenticated using (user_id = (select auth.uid()));

create table if not exists public.challenge_catalog (
  id text primary key,
  title text not null,
  description text not null,
  total_days integer not null check (total_days > 0),
  level text not null check (level in ('iniciante', 'intermediario', 'avancado')),
  icon_key text not null,
  created_at timestamptz not null default now()
);
insert into public.challenge_catalog (id, title, description, total_days, level, icon_key) values
 ('discipline_30', '30 Dias de Disciplina', 'Construa rotina, foco e consistência em 30 dias.', 30, 'intermediario', 'flag'),
 ('wake_5', 'Despertar 5h', 'Domine suas manhãs e ganhe vantagem sobre o dia.', 21, 'avancado', 'sunrise'),
 ('digital_fast', 'Jejum Mental Digital', 'Reduza ruído e recupere o controle da sua atenção.', 14, 'iniciante', 'phone'),
 ('iron_body', 'Corpo de Ferro', 'Treinos progressivos para força e resistência.', 60, 'avancado', 'fitness'),
 ('daily_reading', 'Leitura Diária', 'Vinte minutos de leitura para expandir sua mente.', 30, 'iniciante', 'book')
on conflict (id) do nothing;
alter table public.challenge_catalog enable row level security;
revoke all on public.challenge_catalog from anon, authenticated;
grant select on public.challenge_catalog to anon, authenticated;
drop policy if exists "Challenge catalog is public" on public.challenge_catalog;
create policy "Challenge catalog is public" on public.challenge_catalog for select to anon, authenticated using (true);

create table if not exists public.user_challenges (
  user_id uuid not null references auth.users(id) on delete cascade,
  challenge_id text not null references public.challenge_catalog(id) on delete cascade,
  started_at timestamptz not null default now(),
  primary key (user_id, challenge_id)
);
create table if not exists public.challenge_day_completions (
  user_id uuid not null,
  challenge_id text not null,
  completed_on date not null,
  created_at timestamptz not null default now(),
  primary key (user_id, challenge_id, completed_on),
  foreign key (user_id, challenge_id) references public.user_challenges(user_id, challenge_id) on delete cascade
);
alter table public.user_challenges enable row level security;
alter table public.challenge_day_completions enable row level security;
revoke all on public.user_challenges, public.challenge_day_completions from anon, authenticated;
grant select, insert (user_id, challenge_id), delete on public.user_challenges to authenticated;
grant select, insert (user_id, challenge_id, completed_on), delete on public.challenge_day_completions to authenticated;
drop policy if exists "Members read their own challenges" on public.user_challenges;
create policy "Members read their own challenges" on public.user_challenges for select to authenticated using (user_id = (select auth.uid()));
drop policy if exists "Members join challenges" on public.user_challenges;
create policy "Members join challenges" on public.user_challenges for insert to authenticated with check (user_id = (select auth.uid()));
drop policy if exists "Members leave their own challenges" on public.user_challenges;
create policy "Members leave their own challenges" on public.user_challenges for delete to authenticated using (user_id = (select auth.uid()));
drop policy if exists "Members read their own challenge progress" on public.challenge_day_completions;
create policy "Members read their own challenge progress" on public.challenge_day_completions for select to authenticated using (user_id = (select auth.uid()));
drop policy if exists "Members record their own challenge progress" on public.challenge_day_completions;
create policy "Members record their own challenge progress" on public.challenge_day_completions for insert to authenticated with check (user_id = (select auth.uid()) and completed_on <= current_date);
drop policy if exists "Members remove their own challenge progress" on public.challenge_day_completions;
create policy "Members remove their own challenge progress" on public.challenge_day_completions for delete to authenticated using (user_id = (select auth.uid()));

create table if not exists public.web_push_subscriptions (
  user_id uuid not null references auth.users(id) on delete cascade,
  endpoint text not null,
  p256dh text not null,
  auth text not null,
  created_at timestamptz not null default now(),
  primary key (user_id, endpoint)
);
alter table public.web_push_subscriptions enable row level security;
revoke all on public.web_push_subscriptions from anon, authenticated;
grant select, insert (user_id, endpoint, p256dh, auth), delete on public.web_push_subscriptions to authenticated;
drop policy if exists "Members manage only their push subscriptions" on public.web_push_subscriptions;
create policy "Members manage only their push subscriptions" on public.web_push_subscriptions for select to authenticated using (user_id = (select auth.uid()));
drop policy if exists "Members register their own push subscriptions" on public.web_push_subscriptions;
create policy "Members register their own push subscriptions" on public.web_push_subscriptions for insert to authenticated with check (user_id = (select auth.uid()));
drop policy if exists "Members remove their own push subscriptions" on public.web_push_subscriptions;
create policy "Members remove their own push subscriptions" on public.web_push_subscriptions for delete to authenticated using (user_id = (select auth.uid()));
