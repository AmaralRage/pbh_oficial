begin;
do $$
declare
  admin_id uuid := 'ad230000-0000-4000-8000-000000000001';
  member_id uuid := 'ad230000-0000-4000-8000-000000000002';
  message_id uuid; schedule_id uuid;
begin
  insert into auth.users(id,email,email_confirmed_at,raw_user_meta_data)
  values(admin_id,'delete-admin@example.invalid',now(),'{}'),(member_id,'delete-member@example.invalid',now(),'{}');
  update public.profiles set role='admin' where id=admin_id;
  insert into public.announcements(title,message,created_by) values('Delete test','Body',admin_id) returning id into message_id;
  insert into public.announcement_reads(announcement_id,user_id) values(message_id,member_id);
  insert into public.announcement_push_receipts(announcement_id,endpoint,accepted) values(message_id,'fixture-endpoint',true);
  insert into public.announcement_schedules(title,message,audience,scheduled_at,created_by,status,announcement_id,push_status)
  values('Delete test','Body','all',now(),admin_id,'published',message_id,'pending') returning id into schedule_id;
  perform set_config('request.jwt.claim.sub',member_id::text,true);
  begin
    perform public.admin_delete_announcement(message_id);
    raise exception 'Member deleted an announcement';
  exception when insufficient_privilege then null;
  end;
  if not exists(select 1 from public.announcements where id=message_id) then raise exception 'Unauthorized deletion changed data'; end if;
  perform set_config('request.jwt.claim.sub',admin_id::text,true);
  perform public.admin_delete_announcement(message_id);
  if exists(select 1 from public.announcements where id=message_id)
    or exists(select 1 from public.announcement_reads where announcement_id=message_id)
    or exists(select 1 from public.announcement_push_receipts where announcement_id=message_id) then raise exception 'Announcement or receipts retained'; end if;
  if not exists(select 1 from public.announcement_schedules where id=schedule_id and status='deleted' and announcement_id is null and lease_id is null) then raise exception 'Schedule still references deleted notification'; end if;
  perform public.publish_due_announcements();
  if exists(select 1 from public.claim_scheduled_announcement_push() where id=schedule_id) then raise exception 'Deleted push claimed again'; end if;
  if has_function_privilege('anon','public.admin_delete_announcement(uuid)','execute') then raise exception 'Anonymous delete exposed'; end if;
end $$;
rollback;
select 'Admin-only deletion, cascading receipts and stopping scheduled retries passed; fixtures rolled back' as result;
