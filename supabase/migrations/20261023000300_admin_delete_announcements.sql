alter table public.announcement_schedules drop constraint announcement_schedules_status_check;
alter table public.announcement_schedules add constraint announcement_schedules_status_check
  check(status in ('pending','published','cancelled','failed','deleted'));

create function public.admin_delete_announcement(p_id uuid)
returns void language plpgsql security definer set search_path='' as $$
begin
  if not coalesce(public.is_admin(),false) then
    raise exception 'Admin access required' using errcode='42501';
  end if;
  -- Preserve the scheduling history but stop further attempts and detach its FK.
  update public.announcement_schedules set status='deleted',announcement_id=null,
    push_status='failed',lease_id=null,lease_until=null,last_error='Removed by administrator'
    where announcement_id=p_id;
  -- Read receipts and push receipts cascade with the announcement.
  delete from public.announcements where id=p_id;
  if not found then raise exception 'Announcement no longer exists'; end if;
end $$;
revoke all on function public.admin_delete_announcement(uuid) from public,anon;
grant execute on function public.admin_delete_announcement(uuid) to authenticated;
