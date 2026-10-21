alter table public.profile_achievement_awards
  drop constraint if exists profile_achievement_awards_achievement_key_check;
alter table public.profile_achievement_awards
  add constraint profile_achievement_awards_achievement_key_check
  check (achievement_key in ('supreme_meditation', 'supreme_training', 'supreme_reading', 'supreme_porn_free'));

create or replace function public.grant_profile_achievement(p_email text, p_achievement_key text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare recipient uuid;
begin
  if not exists (
    select 1 from auth.users
    where id = (select auth.uid())
      and lower(email) = 'amaralaragao31@gmail.com'
      and email_confirmed_at is not null
  ) then
    raise exception 'Somente o líder do projeto pode conceder este selo.' using errcode = '42501';
  end if;
  if p_achievement_key not in ('supreme_meditation', 'supreme_training', 'supreme_reading', 'supreme_porn_free') or p_achievement_key is null then
    raise exception 'Selo inválido.' using errcode = '22023';
  end if;
  select id into recipient from auth.users
    where lower(email) = lower(trim(p_email)) and email_confirmed_at is not null;
  if recipient is null then
    raise exception 'Nenhuma conta com e-mail confirmado foi encontrada.' using errcode = '22023';
  end if;
  insert into public.profile_achievement_awards (user_id, achievement_key, granted_by)
    values (recipient, p_achievement_key, (select auth.uid()))
    on conflict (user_id, achievement_key) do nothing;
end;
$$;

revoke all on function public.grant_profile_achievement(text, text) from public, anon;
grant execute on function public.grant_profile_achievement(text, text) to authenticated;

insert into public.profile_achievement_awards (user_id, achievement_key, granted_by)
select id, 'supreme_porn_free', id from auth.users
where lower(email) = 'amaralaragao31@gmail.com' and email_confirmed_at is not null
on conflict (user_id, achievement_key) do nothing;
