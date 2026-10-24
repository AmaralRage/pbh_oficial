-- Publish scheduled announcements atomically, independently of any open app.
create extension if not exists pg_cron;
create extension if not exists pg_net with schema extensions;
create extension if not exists supabase_vault with schema vault;

create table public.announcement_schedules (
  id uuid primary key default gen_random_uuid(),
  title text not null check (char_length(btrim(title)) between 1 and 80),
  message text not null check (char_length(btrim(message)) between 1 and 500),
  audience text not null check (audience in ('all','members','admins')),
  destination_url text check (destination_url is null or destination_url ~ '^https://'),
  sound_enabled boolean not null default true,
  scheduled_at timestamptz not null,
  created_by uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  status text not null default 'pending' check (status in ('pending','published','cancelled','failed')),
  announcement_id uuid unique references public.announcements(id),
  published_at timestamptz,
  push_status text not null default 'pending' check (push_status in ('pending','processing','sent','failed')),
  attempts integer not null default 0,
  retry_at timestamptz not null default now(),
  lease_id uuid,
  lease_until timestamptz,
  last_error text
);
create index announcement_schedules_due on public.announcement_schedules(scheduled_at) where status = 'pending';
alter table public.announcement_schedules enable row level security;
revoke all on public.announcement_schedules from anon, authenticated;
grant select on public.announcement_schedules to authenticated;
create policy "Admins see their schedules" on public.announcement_schedules for select to authenticated
using ((select public.is_admin()) and created_by = (select auth.uid()));

create table public.announcement_push_receipts (
  announcement_id uuid not null references public.announcements(id) on delete cascade,
  endpoint text not null,
  accepted boolean not null,
  primary key (announcement_id, endpoint)
);
alter table public.announcement_push_receipts enable row level security;
revoke all on public.announcement_push_receipts from anon, authenticated;
grant all on public.announcement_schedules, public.announcement_push_receipts to service_role;

create function public.schedule_announcement(p_title text, p_message text, p_audience text,
  p_destination_url text, p_sound_enabled boolean, p_scheduled_at timestamptz)
returns uuid language plpgsql security definer set search_path = '' as $$
declare result uuid;
begin
  if not coalesce(public.is_admin(), false) then raise exception 'Admin access required' using errcode='42501'; end if;
  if p_scheduled_at is null or p_scheduled_at <= now() then raise exception 'Choose a future date'; end if;
  insert into public.announcement_schedules(title,message,audience,destination_url,sound_enabled,scheduled_at,created_by)
  values (btrim(p_title),btrim(p_message),p_audience,nullif(btrim(p_destination_url),''),p_sound_enabled,p_scheduled_at,auth.uid()) returning id into result;
  return result;
end $$;

create function public.cancel_announcement_schedule(p_id uuid)
returns void language plpgsql security definer set search_path = '' as $$
begin
  if not coalesce(public.is_admin(), false) then raise exception 'Admin access required' using errcode='42501'; end if;
  update public.announcement_schedules set status='cancelled'
    where id=p_id and created_by=auth.uid() and status='pending';
  if not found then raise exception 'Schedule is no longer pending'; end if;
end $$;

-- Only the trusted cron/service role executes this; users cannot publish early.
create function public.publish_due_announcements()
returns integer language plpgsql security definer set search_path = '' as $$
declare item record; announcement uuid; published integer := 0;
begin
  for item in select * from public.announcement_schedules
    where status='pending' and scheduled_at <= now() order by scheduled_at limit 100 for update skip locked
  loop
    if not exists(select 1 from public.profiles where id=item.created_by and role='admin') then
      update public.announcement_schedules set status='failed',last_error='Creator is no longer an administrator' where id=item.id;
      continue;
    end if;
    insert into public.announcements(title,message,audience,destination_url,sound_enabled,created_by)
    values(item.title,item.message,item.audience,item.destination_url,item.sound_enabled,item.created_by) returning id into announcement;
    update public.announcement_schedules set status='published',announcement_id=announcement,published_at=now(),retry_at=now() where id=item.id;
    published := published+1;
  end loop;
  return published;
end $$;

create function public.claim_scheduled_announcement_push()
returns setof public.announcement_schedules language sql security definer set search_path = '' as $$
  update public.announcement_schedules s set push_status='processing',attempts=attempts+1,
    lease_id=gen_random_uuid(),lease_until=now()+interval '5 minutes'
  where id=(select id from public.announcement_schedules where status='published' and attempts<5
    and (push_status='pending' and retry_at<=now() or push_status='processing' and lease_until<now())
    order by scheduled_at limit 1 for update skip locked)
  returning s.*;
$$;

create function public.finish_scheduled_announcement_push(p_id uuid,p_lease uuid,p_error text default null)
returns void language sql security definer set search_path = '' as $$
  update public.announcement_schedules set
    push_status=case when p_error is null then 'sent' when attempts>=5 then 'failed' else 'pending' end,
    retry_at=now()+make_interval(mins => (power(2,least(attempts,5)))::integer),
    last_error=left(p_error,200),lease_until=null
  where id=p_id and lease_id=p_lease and push_status='processing';
$$;

create function public.run_announcement_scheduler()
returns void language plpgsql security definer set search_path = '' as $$
declare endpoint text; secret text;
begin
  perform public.publish_due_announcements();
  update public.announcement_schedules set push_status='failed',last_error='Delivery worker timed out'
    where push_status='processing' and lease_until<now() and attempts>=5;
  if not exists(select 1 from public.announcement_schedules where status='published' and attempts<5
    and (push_status='pending' and retry_at<=now() or push_status='processing' and lease_until<now())) then return; end if;
  select decrypted_secret into endpoint from vault.decrypted_secrets where name='pbh_announcements_project_url' limit 1;
  select decrypted_secret into secret from vault.decrypted_secrets where name='pbh_announcements_cron_secret' limit 1;
  if endpoint is null or secret is null then return; end if;
  perform net.http_post(url:=endpoint||'/functions/v1/process-announcement-schedules',
    headers:=jsonb_build_object('Content-Type','application/json','x-pbh-cron-secret',secret),body:='{}'::jsonb,timeout_milliseconds:=10000);
end $$;

revoke all on function public.schedule_announcement(text,text,text,text,boolean,timestamptz) from public,anon;
revoke all on function public.cancel_announcement_schedule(uuid) from public,anon;
grant execute on function public.schedule_announcement(text,text,text,text,boolean,timestamptz), public.cancel_announcement_schedule(uuid) to authenticated;
revoke all on function public.publish_due_announcements(),public.claim_scheduled_announcement_push(),public.finish_scheduled_announcement_push(uuid,uuid,text),public.run_announcement_scheduler() from public,anon,authenticated;
grant execute on function public.publish_due_announcements(),public.claim_scheduled_announcement_push(),public.finish_scheduled_announcement_push(uuid,uuid,text) to service_role;

-- Runs every minute. No messages are created by installing the scheduler.
select cron.schedule('pbh-announcement-scheduler','* * * * *','select public.run_announcement_scheduler()');
