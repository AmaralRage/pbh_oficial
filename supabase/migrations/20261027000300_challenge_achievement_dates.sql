begin;
create function public.my_challenge_achievement_dates()
returns table(challenge_id text,completed_on date)
language sql stable security definer set search_path='' as $$
  select d.challenge_id,d.completed_on from (
    select c.challenge_id,c.completed_on,row_number() over(partition by c.challenge_id order by c.completed_on) as n
    from public.challenge_day_completions c where c.user_id=(select auth.uid())
  ) d join public.challenge_catalog p on p.id=d.challenge_id where d.n=p.total_days;
$$;
revoke all on function public.my_challenge_achievement_dates() from public,anon;
grant execute on function public.my_challenge_achievement_dates() to authenticated;
commit;
