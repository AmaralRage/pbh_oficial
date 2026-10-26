begin;
create table public.personal_goals(
  user_id uuid primary key references auth.users(id) on delete cascade,
  title text not null check(length(btrim(title)) between 1 and 180),
  next_step text not null default '' check(length(next_step)<=300),
  is_public boolean not null default false,
  updated_at timestamptz not null default now()
);
create table public.personal_goal_entries(
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.personal_goals(user_id) on delete cascade,
  goal_title text not null check(length(goal_title) between 1 and 180),
  content text not null check(length(btrim(content)) between 1 and 1000),
  created_at timestamptz not null default now()
);
create index personal_goal_entries_owner_time on public.personal_goal_entries(user_id,created_at desc);
alter table public.personal_goals enable row level security;
alter table public.personal_goal_entries enable row level security;
revoke all on public.personal_goals,public.personal_goal_entries from anon,authenticated;
grant select,insert,update,delete on public.personal_goals to authenticated;
grant select,insert,delete on public.personal_goal_entries to authenticated;
create policy "Members manage their goal" on public.personal_goals for all to authenticated
  using((select auth.uid())=user_id) with check((select auth.uid())=user_id);
create policy "Members manage their private goal entries" on public.personal_goal_entries for all to authenticated
  using((select auth.uid())=user_id) with check((select auth.uid())=user_id);

create function public.public_profile_goal(p_user_id uuid) returns jsonb
language sql stable security definer set search_path='' as $$
  select jsonb_build_object('title',g.title,'next_step',g.next_step,'is_public',g.is_public)
    from public.personal_goals g join public.profiles p on p.id=g.user_id
    where g.user_id=p_user_id
      and (g.user_id=(select auth.uid()) or (g.is_public and coalesce(p.is_public,true)))
      and not exists(select 1 from public.community_blocks b
        where (b.blocker_id=(select auth.uid()) and b.blocked_id=g.user_id)
           or (b.blocker_id=g.user_id and b.blocked_id=(select auth.uid())));
$$;
revoke all on function public.public_profile_goal(uuid) from public;
grant execute on function public.public_profile_goal(uuid) to anon,authenticated;
commit;
