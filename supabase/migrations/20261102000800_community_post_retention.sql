begin;
create extension if not exists pg_cron;

-- Deletes member posts in bounded batches. Existing DELETE triggers enqueue media
-- cleanup; Storage objects must be removed through the Storage API, not SQL.
create function public.expire_community_member_posts(p_limit integer default 500)
returns integer language plpgsql security definer set search_path='' as $$
declare removed integer;
begin
 with expired as (
  select p.id from public.community_posts p
  where p.created_at <= now()-interval '7 days'
    and not exists(select 1 from auth.users u where u.id=p.user_id
      and lower(coalesce(u.email,''))='amaralaragao31@gmail.com'
      and u.email_confirmed_at is not null)
  order by p.created_at,p.id limit greatest(1,least(coalesce(p_limit,500),2000))
  for update of p skip locked
 ), deleted as (
  delete from public.community_posts p using expired e where p.id=e.id returning p.id
 ) select count(*)::integer into removed from deleted;
 return removed;
end $$;
revoke all on function public.expire_community_member_posts(integer) from public,anon,authenticated;

-- Named scheduling replaces this job if its schedule is configured again.
-- Every five minutes; posts expire at age 7 days, independently of app access.
select cron.schedule('pbh-expire-community-member-posts','*/5 * * * *',
  'select public.expire_community_member_posts(500)');
commit;
