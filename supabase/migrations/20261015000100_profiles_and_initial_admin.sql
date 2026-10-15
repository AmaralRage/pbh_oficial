create table if not exists public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  email text not null,
  role text not null default 'member' check (role in ('member', 'admin')),
  created_at timestamptz not null default now()
);

alter table public.profiles enable row level security;
revoke all on table public.profiles from anon, authenticated;
grant select on table public.profiles to authenticated;

create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.profiles
    where id = (select auth.uid())
      and role = 'admin'
  );
$$;

revoke all on function public.is_admin() from public, anon;
grant execute on function public.is_admin() to authenticated;

drop policy if exists "Users can read their own profile; admins can read all profiles"
on public.profiles;

create policy "Users can read their own profile; admins can read all profiles"
on public.profiles
for select
to authenticated
using ((select auth.uid()) = id or (select public.is_admin()));

create or replace function public.sync_profile_from_auth_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.profiles (id, email, role)
  values (
    new.id,
    coalesce(new.email, ''),
    case
      when lower(coalesce(new.email, '')) = 'amaralaragao31@gmail.com'
       and new.email_confirmed_at is not null then 'admin'
      else 'member'
    end
  )
  on conflict (id) do update
    set email = excluded.email,
        role = excluded.role;

  return new;
end;
$$;

revoke all on function public.sync_profile_from_auth_user() from public, anon, authenticated;

drop trigger if exists sync_profile_after_auth_user_change on auth.users;

create trigger sync_profile_after_auth_user_change
after insert or update of email, email_confirmed_at on auth.users
for each row execute function public.sync_profile_from_auth_user();

insert into public.profiles (id, email, role)
select
  id,
  coalesce(email, ''),
  case
    when lower(coalesce(email, '')) = 'amaralaragao31@gmail.com'
     and email_confirmed_at is not null then 'admin'
    else 'member'
  end
from auth.users
on conflict (id) do update
  set email = excluded.email,
      role = excluded.role;
