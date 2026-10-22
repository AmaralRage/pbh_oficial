-- Aggregate the authenticated member's history without returning every daily row.
create or replace function public.my_challenge_completion_counts()
returns table(challenge_id text, completed_days bigint)
language sql
stable
security invoker
set search_path = ''
as $$
  select c.challenge_id::text, count(*)
  from public.challenge_day_completions c
  where c.user_id = (select auth.uid())
  group by c.challenge_id;
$$;

revoke all on function public.my_challenge_completion_counts() from public, anon;
grant execute on function public.my_challenge_completion_counts() to authenticated;
