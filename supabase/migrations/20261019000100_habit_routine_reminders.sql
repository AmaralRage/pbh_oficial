-- Per-user routine reminder preferences and an idempotency ledger for push sends.
create table if not exists public.habit_reminder_settings (
  user_id uuid not null references auth.users(id) on delete cascade,
  delivery_mode text not null default 'web'
    check (delivery_mode in ('web', 'native')),
  enabled boolean not null default false,
  reminder_time time not null default time '20:00',
  time_zone text not null default 'America/Sao_Paulo'
    check (char_length(time_zone) between 1 and 64),
  selected_habit_keys text[] not null default array['train', 'read', 'digital_fast', 'meditate', 'sleep_early'],
  updated_at timestamptz not null default now(),
  last_sent_on date,
  constraint habit_reminder_settings_habits_check check (
    cardinality(selected_habit_keys) > 0
    and selected_habit_keys <@ array['train', 'read', 'digital_fast', 'meditate', 'sleep_early']::text[]
  ),
  primary key (user_id, delivery_mode)
);

-- Upgrade installations that already have the original web-only settings table.
-- Existing rows become web preferences through the column's default.
alter table public.habit_reminder_settings
  add column if not exists delivery_mode text not null default 'web';
alter table public.habit_reminder_settings
  drop constraint if exists habit_reminder_settings_delivery_mode_check;
alter table public.habit_reminder_settings
  add constraint habit_reminder_settings_delivery_mode_check
  check (delivery_mode in ('web', 'native'));

-- The previous schema used user_id alone as the primary key. Replace it with
-- (user_id, delivery_mode), allowing a member to keep web and native settings.
do $$
declare
  primary_key_name text;
begin
  select conname into primary_key_name
  from pg_constraint
  where conrelid = 'public.habit_reminder_settings'::regclass
    and contype = 'p';

  if primary_key_name is not null then
    execute format('alter table public.habit_reminder_settings drop constraint %I', primary_key_name);
  end if;
end;
$$;
alter table public.habit_reminder_settings
  add constraint habit_reminder_settings_pkey primary key (user_id, delivery_mode);

alter table public.habit_reminder_settings enable row level security;
revoke all on public.habit_reminder_settings from anon, authenticated;
grant select on public.habit_reminder_settings to authenticated;
grant insert (user_id, delivery_mode, enabled, reminder_time, time_zone, selected_habit_keys, updated_at)
  on public.habit_reminder_settings to authenticated;
grant update (user_id, delivery_mode, enabled, reminder_time, time_zone, selected_habit_keys, updated_at)
  on public.habit_reminder_settings to authenticated;

drop policy if exists "Members read their own habit reminder settings" on public.habit_reminder_settings;
create policy "Members read their own habit reminder settings"
  on public.habit_reminder_settings for select to authenticated
  using (user_id = (select auth.uid()));
drop policy if exists "Members create their own habit reminder settings" on public.habit_reminder_settings;
create policy "Members create their own habit reminder settings"
  on public.habit_reminder_settings for insert to authenticated
  with check (user_id = (select auth.uid()));
drop policy if exists "Members update their own habit reminder settings" on public.habit_reminder_settings;
create policy "Members update their own habit reminder settings"
  on public.habit_reminder_settings for update to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));

create table if not exists public.habit_reminder_deliveries (
  user_id uuid not null references auth.users(id) on delete cascade,
  reminder_on date not null,
  claimed_at timestamptz not null default now(),
  primary key (user_id, reminder_on)
);
alter table public.habit_reminder_deliveries enable row level security;
revoke all on public.habit_reminder_deliveries from public, anon, authenticated, service_role;

create or replace function public.claim_habit_reminder(p_user_id uuid, p_reminder_on date)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not exists (
    select 1 from public.habit_reminder_settings s
    where s.user_id = p_user_id and s.enabled
  ) then
    return false;
  end if;

  insert into public.habit_reminder_deliveries (user_id, reminder_on)
  values (p_user_id, p_reminder_on)
  on conflict do nothing;
  return found;
end;
$$;
revoke all on function public.claim_habit_reminder(uuid, date) from public, anon, authenticated;
grant execute on function public.claim_habit_reminder(uuid, date) to service_role;

create or replace function public.release_habit_reminder(p_user_id uuid, p_reminder_on date)
returns void
language sql
security definer
set search_path = ''
as $$
  delete from public.habit_reminder_deliveries
  where user_id = p_user_id and reminder_on = p_reminder_on;
$$;
revoke all on function public.release_habit_reminder(uuid, date) from public, anon, authenticated;
grant execute on function public.release_habit_reminder(uuid, date) to service_role;

create index if not exists habit_reminder_settings_enabled_time_idx
  on public.habit_reminder_settings(delivery_mode, enabled, reminder_time)
  where enabled;
