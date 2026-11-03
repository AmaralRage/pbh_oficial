begin;
alter table public.member_badge_awards drop constraint member_badge_awards_badge_key_check;
alter table public.member_badge_awards add constraint member_badge_awards_badge_key_check
 check(badge_key in ('guardian','mentor','ambassador','beginner','consistent','veteran'));

-- Private helper: only public identity RPCs may expose its result after privacy checks.
create function public.effective_member_badge(p_user uuid) returns text
language sql stable security definer set search_path='' as $$
 with routine as (
   select count(*) as tasks,count(distinct completed_on) as days from public.habit_completions
    where user_id=p_user and completed_on <= (now() at time zone 'America/Sao_Paulo')::date
 ), candidates as (
  select badge_key from public.member_badge_awards where user_id=p_user
  union select 'veteran' from auth.users where id=p_user and created_at <= now()-interval '1 year'
  union select 'consistent' from routine where days>=90
  union select 'beginner' from routine where tasks>=5
 ) select badge_key from candidates order by case badge_key when 'guardian' then 0 when 'mentor' then 1
 when 'ambassador' then 2 when 'veteran' then 3 when 'consistent' then 4 else 5 end limit 1;
$$;
revoke all on function public.effective_member_badge(uuid) from public,anon,authenticated;

create function public.admin_set_user_member_badge(p_user uuid,p_badge text,p_grant boolean) returns void
language plpgsql security definer set search_path='' as $$
declare leader boolean;
begin
 select exists(select 1 from auth.users where id=auth.uid() and lower(email)='amaralaragao31@gmail.com' and email_confirmed_at is not null) into leader;
 if not (leader or coalesce(public.is_admin(),false)) then raise exception 'Admin access required' using errcode='42501'; end if;
 if p_badge is null or p_badge not in ('guardian','mentor','ambassador','beginner','consistent','veteran') or p_grant is null then raise exception 'Invalid badge'; end if;
 if p_badge in ('beginner','consistent','veteran') and not leader then raise exception 'Somente o líder pode antecipar estes selos.' using errcode='42501'; end if;
 if not exists(select 1 from auth.users where id=p_user and email_confirmed_at is not null) then raise exception 'Conta confirmada não encontrada.'; end if;
 if p_grant then insert into public.member_badge_awards(user_id,badge_key,granted_by) values(p_user,p_badge,auth.uid()) on conflict do nothing;
 else delete from public.member_badge_awards where user_id=p_user and badge_key=p_badge; end if;
end $$;
revoke all on function public.admin_set_user_member_badge(uuid,text,boolean) from public,anon;
grant execute on function public.admin_set_user_member_badge(uuid,text,boolean) to authenticated;

-- Preserve the old email entry point, with the same authorization as UUID grants.
create or replace function public.admin_set_member_badge(p_email text,p_badge text,p_grant boolean) returns void
language plpgsql security definer set search_path='' as $$
declare recipient uuid;
begin
 if not (coalesce(public.is_admin(),false) or exists(select 1 from auth.users where id=auth.uid() and lower(email)='amaralaragao31@gmail.com' and email_confirmed_at is not null)) then raise exception 'Admin access required' using errcode='42501'; end if;
 select id into recipient from auth.users where lower(email)=lower(btrim(p_email)) and email_confirmed_at is not null;
 perform public.admin_set_user_member_badge(recipient,p_badge,p_grant);
end $$;

create function public.admin_search_members(p_query text default '',p_offset integer default 0)
returns table(user_id uuid,name text,avatar_url text,joined_at timestamptz)
language plpgsql stable security definer set search_path='' as $$
begin
 if not (coalesce(public.is_admin(),false) or exists(select 1 from auth.users where id=auth.uid() and lower(email)='amaralaragao31@gmail.com' and email_confirmed_at is not null)) then raise exception 'Admin access required' using errcode='42501'; end if;
 return query with members as (
  select u.id,left(coalesce(nullif(btrim(u.raw_user_meta_data->>'display_name'),''),nullif(p.display_name,''),'Membro'),40) as display_name,
   left(case when u.raw_user_meta_data ? 'avatar_url' then nullif(u.raw_user_meta_data->>'avatar_url','') else p.avatar_url end,2048) as photo,u.created_at
  from auth.users u left join public.profiles p on p.id=u.id where u.email_confirmed_at is not null
 ) select m.id,m.display_name,m.photo,m.created_at from members m
 where strpos(lower(m.display_name),lower(left(btrim(coalesce(p_query,'')),100)))>0
    or strpos(m.id::text,lower(left(btrim(coalesce(p_query,'')),100)))>0
 order by lower(m.display_name),m.id limit 30 offset greatest(0,least(coalesce(p_offset,0),100000));
end $$;
revoke all on function public.admin_search_members(text,integer) from public,anon;
grant execute on function public.admin_search_members(text,integer) to authenticated;
create or replace function public.community_member_identities(p_ids uuid[])
returns table(user_id uuid,name text,avatar_url text,founder boolean,member_badge text)
language sql stable security definer set search_path='' as $$
  select p.id,
    case when p.id=(select auth.uid()) or coalesce(p.is_public,true)
      then left(coalesce(nullif(btrim(u.raw_user_meta_data->>'display_name'),''),nullif(p.display_name,''),'Membro'),40)
      else 'Membro' end,
    case when p.id=(select auth.uid()) or coalesce(p.is_public,true)
      then left(case when u.raw_user_meta_data ? 'avatar_url'
        then nullif(u.raw_user_meta_data->>'avatar_url','') else p.avatar_url end,2048)
      else null end,
    (p.id=(select auth.uid()) or coalesce(p.is_public,true))
      and lower(coalesce(u.email,''))='amaralaragao31@gmail.com' and u.email_confirmed_at is not null,
    case when p.id=(select auth.uid()) or coalesce(p.is_public,true) then
      public.effective_member_badge(p.id) else null end
  from public.profiles p join auth.users u on u.id=p.id
  where p.id in (select x from unnest(p_ids) x limit 100)
    and not exists(select 1 from public.community_blocks b where
      (b.blocker_id=(select auth.uid()) and b.blocked_id=p.id) or
      (b.blocker_id=p.id and b.blocked_id=(select auth.uid())));
$$;
revoke all on function public.community_member_identities(uuid[]) from public;
grant execute on function public.community_member_identities(uuid[]) to anon,authenticated;



commit;
