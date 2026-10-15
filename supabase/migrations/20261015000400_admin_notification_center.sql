-- Admin notification center: audience targeting, delivery metrics and drafts.
alter table public.announcements
  add column if not exists audience text not null default 'all'
    check (audience in ('all', 'members', 'admins')),
  add column if not exists destination_url text,
  add column if not exists sound_enabled boolean not null default true,
  add column if not exists push_attempted_count integer not null default 0 check (push_attempted_count >= 0),
  add column if not exists push_accepted_count integer not null default 0 check (push_accepted_count >= 0);

revoke insert (title, message, created_by) on public.announcements from authenticated;
grant insert (title, message, created_by, audience, destination_url, sound_enabled)
  on public.announcements to authenticated;

drop policy if exists "Authenticated users can read announcements" on public.announcements;
drop policy if exists "Users can read announcements for their audience" on public.announcements;
create policy "Users can read announcements for their audience"
on public.announcements for select to authenticated
using (
  (select public.is_admin())
  or audience = 'all'
  or (audience = 'members' and not (select public.is_admin()))
);

drop policy if exists "Users can read their announcement receipts" on public.announcement_reads;
create policy "Users can read their announcement receipts"
on public.announcement_reads for select to authenticated
using (user_id = (select auth.uid()) or (select public.is_admin()));

drop policy if exists "Users can mark their announcements read" on public.announcement_reads;
create policy "Users can mark their announcements read"
on public.announcement_reads for insert to authenticated
with check (
  user_id = (select auth.uid())
  and exists (
    select 1 from public.announcements a
    where a.id = announcement_id
      and (
        a.audience = 'all'
        or (a.audience = 'members' and not (select public.is_admin()))
        or (a.audience = 'admins' and (select public.is_admin()))
      )
  )
);

create table if not exists public.announcement_drafts (
  id uuid primary key default gen_random_uuid(),
  title text not null check (char_length(title) between 1 and 80),
  message text not null check (char_length(message) between 1 and 500),
  audience text not null default 'all' check (audience in ('all', 'members', 'admins')),
  destination_url text,
  sound_enabled boolean not null default true,
  created_by uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.announcement_drafts enable row level security;
revoke all on public.announcement_drafts from anon, authenticated;
grant select, insert (title, message, audience, destination_url, sound_enabled, created_by),
  update (title, message, audience, destination_url, sound_enabled, updated_at), delete
  on public.announcement_drafts to authenticated;

drop policy if exists "Admins manage their announcement drafts" on public.announcement_drafts;
create policy "Admins manage their announcement drafts"
on public.announcement_drafts for all to authenticated
using ((select public.is_admin()) and created_by = (select auth.uid()))
with check ((select public.is_admin()) and created_by = (select auth.uid()));

create index if not exists announcements_created_at_idx
  on public.announcements(created_at desc);
create index if not exists announcement_drafts_updated_at_idx
  on public.announcement_drafts(updated_at desc);

create or replace function public.admin_announcement_metrics()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  sent_total bigint;
  reads_total bigint;
  push_attempted bigint;
  push_accepted bigint;
  recipients bigint;
  eligible_total bigint;
begin
  if not (select public.is_admin()) then
    raise exception 'Admin access required' using errcode = '42501';
  end if;

  select count(*), coalesce(sum(a.push_attempted_count), 0), coalesce(sum(a.push_accepted_count), 0)
    into sent_total, push_attempted, push_accepted
    from public.announcements a
    where a.created_at >= now() - interval '30 days';

  select count(*) into reads_total
    from public.announcement_reads r
    join public.announcements a on a.id = r.announcement_id
    where a.created_at >= now() - interval '30 days';

  select count(*) into recipients from auth.users;
  select coalesce(sum(case
      when a.audience = 'admins' then (select count(*) from public.profiles p where p.role = 'admin')
      when a.audience = 'members' then (select count(*) from public.profiles p where p.role = 'member')
      else recipients
    end), 0)
    into eligible_total
    from public.announcements a
    where a.created_at >= now() - interval '30 days';

  return jsonb_build_object(
    'sent', sent_total,
    'read_receipts', reads_total,
    'push_attempted', push_attempted,
    'push_accepted', push_accepted,
    'registered_users', recipients,
    'member_users', (select count(*) from public.profiles p where p.role = 'member'),
    'admin_users', (select count(*) from public.profiles p where p.role = 'admin'),
    'push_delivery_rate', case when push_attempted = 0 then null else round(push_accepted::numeric * 100 / push_attempted, 1) end,
    'read_rate', case when eligible_total = 0 then null else round(reads_total::numeric * 100 / eligible_total, 1) end
  );
end;
$$;
revoke all on function public.admin_announcement_metrics() from public, anon;
grant execute on function public.admin_announcement_metrics() to authenticated;

create or replace function public.admin_announcement_read_counts()
returns table (announcement_id uuid, read_count bigint)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if not (select public.is_admin()) then
    raise exception 'Admin access required' using errcode = '42501';
  end if;
  return query
    select a.id, count(r.user_id)
    from public.announcements a
    left join public.announcement_reads r on r.announcement_id = a.id
    group by a.id;
end;
$$;
revoke all on function public.admin_announcement_read_counts() from public, anon;
grant execute on function public.admin_announcement_read_counts() to authenticated;
