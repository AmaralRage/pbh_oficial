-- Fixtures and messages are rolled back; this test never sends Web Push.
begin;
do $$
declare
  admin_id uuid := 'ab230000-0000-4000-8000-000000000001';
  member_id uuid := 'ab230000-0000-4000-8000-000000000002';
  scheduled uuid; cancelled uuid; demoted uuid; claimed record;
begin
  insert into auth.users(id,email,email_confirmed_at,raw_user_meta_data)
  values(admin_id,'schedule-admin@example.invalid',now(),'{}'),(member_id,'schedule-member@example.invalid',now(),'{}');
  update public.profiles set role='admin' where id=admin_id;
  perform set_config('request.jwt.claim.sub',member_id::text,true);
  begin
    perform public.schedule_announcement('Test','Body','all',null,true,now()+interval '1 hour');
    raise exception 'Member unexpectedly scheduled a message';
  exception when insufficient_privilege then null;
  end;
  perform set_config('request.jwt.claim.sub',admin_id::text,true);
  begin
    perform public.schedule_announcement('Test','Body','all',null,true,now()-interval '1 minute');
    raise exception 'Past date accepted';
  exception when raise_exception then
    if sqlerrm <> 'Choose a future date' then raise; end if;
  end;
  scheduled := public.schedule_announcement('Future test','Body','admins',null,true,now()+interval '1 hour');
  perform public.publish_due_announcements();
  if (select announcement_id is not null from public.announcement_schedules where id=scheduled) then raise exception 'Published early'; end if;
  update public.announcement_schedules set scheduled_at=now()-interval '1 minute' where id=scheduled;
  perform public.publish_due_announcements();
  perform public.publish_due_announcements();
  if (select count(*) from public.announcements where title='Future test' and created_by=admin_id) <> 1 then raise exception 'Publication is not idempotent'; end if;
  if not exists(select 1 from public.announcements a join public.announcement_schedules s on s.announcement_id=a.id
    where s.id=scheduled and a.audience='admins') then raise exception 'Audience not preserved'; end if;
  select * into claimed from public.claim_scheduled_announcement_push() where id=scheduled;
  if claimed.id is null then raise exception 'Push not claimed'; end if;
  if exists(select 1 from public.claim_scheduled_announcement_push() where id=scheduled) then raise exception 'Concurrent claim allowed'; end if;
  perform public.finish_scheduled_announcement_push(scheduled,gen_random_uuid(),null);
  if (select push_status from public.announcement_schedules where id=scheduled)<>'processing' then raise exception 'Stale lease accepted'; end if;
  perform public.finish_scheduled_announcement_push(scheduled,claimed.lease_id,'Temporary error');
  if (select push_status from public.announcement_schedules where id=scheduled)<>'pending' then raise exception 'Retry missing'; end if;
  update public.announcement_schedules set retry_at=now(),attempts=4 where id=scheduled;
  select * into claimed from public.claim_scheduled_announcement_push() where id=scheduled;
  perform public.finish_scheduled_announcement_push(scheduled,claimed.lease_id,'Temporary error');
  if (select push_status from public.announcement_schedules where id=scheduled)<>'failed' then raise exception 'Retry limit missing'; end if;
  cancelled := public.schedule_announcement('Cancelled test','Body','all',null,true,now()+interval '1 hour');
  perform public.cancel_announcement_schedule(cancelled);
  update public.announcement_schedules set scheduled_at=now()-interval '1 minute' where id=cancelled;
  perform public.publish_due_announcements();
  if (select announcement_id is not null from public.announcement_schedules where id=cancelled) then raise exception 'Cancelled message published'; end if;
  demoted := public.schedule_announcement('Demoted test','Body','all',null,true,now()+interval '1 hour');
  update public.profiles set role='member' where id=admin_id;
  update public.announcement_schedules set scheduled_at=now()-interval '1 minute' where id=demoted;
  perform public.publish_due_announcements();
  if (select status from public.announcement_schedules where id=demoted)<>'failed' then raise exception 'Former admin published'; end if;
  if has_function_privilege('authenticated','public.publish_due_announcements()','execute')
    or has_function_privilege('anon','public.schedule_announcement(text,text,text,text,boolean,timestamptz)','execute')
    or has_table_privilege('authenticated','public.announcement_schedules','insert')
    or has_table_privilege('authenticated','public.announcement_push_receipts','select') then raise exception 'Worker access exposed'; end if;
end $$;
rollback;
select 'Scheduling, authorization, cancellation, idempotency, push leases and retry limit passed; fixtures rolled back' as result;
