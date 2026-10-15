create table if not exists public.announcements (
  id uuid primary key default gen_random_uuid(),
  title text not null check (char_length(title) between 1 and 80),
  message text not null check (char_length(message) between 1 and 500),
  created_by uuid not null references auth.users (id) on delete cascade,
  created_at timestamptz not null default now()
);

create table if not exists public.announcement_reads (
  announcement_id uuid not null references public.announcements (id) on delete cascade,
  user_id uuid not null references auth.users (id) on delete cascade,
  read_at timestamptz not null default now(),
  primary key (announcement_id, user_id)
);

alter table public.announcements enable row level security;
alter table public.announcement_reads enable row level security;

revoke all on table public.announcements from anon, authenticated;
grant select on table public.announcements to authenticated;
grant insert (title, message, created_by) on table public.announcements to authenticated;

drop policy if exists "Authenticated users can read announcements"
on public.announcements;
create policy "Authenticated users can read announcements"
on public.announcements
for select to authenticated
using (true);

drop policy if exists "Admins can publish announcements"
on public.announcements;
create policy "Admins can publish announcements"
on public.announcements
for insert to authenticated
with check (
  created_by = (select auth.uid())
  and (select public.is_admin())
);

revoke all on table public.announcement_reads from anon, authenticated;
grant select, insert, update on table public.announcement_reads to authenticated;

drop policy if exists "Users can read their announcement receipts"
on public.announcement_reads;
create policy "Users can read their announcement receipts"
on public.announcement_reads
for select to authenticated
using (user_id = (select auth.uid()));

drop policy if exists "Users can mark their announcements read"
on public.announcement_reads;
create policy "Users can mark their announcements read"
on public.announcement_reads
for insert to authenticated
with check (user_id = (select auth.uid()));

drop policy if exists "Users can update their announcement receipts"
on public.announcement_reads;
create policy "Users can update their announcement receipts"
on public.announcement_reads
for update to authenticated
using (user_id = (select auth.uid()))
with check (user_id = (select auth.uid()));

do $$
begin
  if not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'announcements'
  ) then
    alter publication supabase_realtime add table public.announcements;
  end if;
end;
$$;
