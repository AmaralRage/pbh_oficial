begin;
create table public.member_badge_awards(
 user_id uuid not null references auth.users(id) on delete cascade,
 badge_key text not null check(badge_key in ('guardian','mentor','ambassador')),
 granted_by uuid references auth.users(id) on delete set null,
 granted_at timestamptz not null default now(), primary key(user_id,badge_key)
);
alter table public.member_badge_awards enable row level security;
revoke all on public.member_badge_awards from public,anon,authenticated;
create function public.admin_set_member_badge(p_email text,p_badge text,p_grant boolean) returns void
language plpgsql security definer set search_path='' as $$
declare recipient uuid;
begin
 if not coalesce(public.is_admin(),false) then raise exception 'Admin access required' using errcode='42501'; end if;
 if p_badge is null or p_badge not in ('guardian','mentor','ambassador') or p_grant is null then raise exception 'Invalid badge'; end if;
 select id into recipient from auth.users where lower(email)=lower(btrim(p_email)) and email_confirmed_at is not null;
 if recipient is null then raise exception 'Conta confirmada não encontrada.'; end if;
 if p_grant then insert into public.member_badge_awards(user_id,badge_key,granted_by) values(recipient,p_badge,auth.uid()) on conflict do nothing;
 else delete from public.member_badge_awards where user_id=recipient and badge_key=p_badge; end if;
end $$;
revoke all on function public.admin_set_member_badge(text,text,boolean) from public,anon;
grant execute on function public.admin_set_member_badge(text,text,boolean) to authenticated;
drop function if exists public.community_member_identities(uuid[]);
create function public.community_member_identities(p_ids uuid[])
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
      (select b.badge_key from public.member_badge_awards b where b.user_id=p.id order by case b.badge_key when 'guardian' then 0 when 'mentor' then 1 else 2 end limit 1) else null end
  from public.profiles p join auth.users u on u.id=p.id
  where p.id in (select x from unnest(p_ids) x limit 100)
    and not exists(select 1 from public.community_blocks b where
      (b.blocker_id=(select auth.uid()) and b.blocked_id=p.id) or
      (b.blocker_id=p.id and b.blocked_id=(select auth.uid())));
$$;
revoke all on function public.community_member_identities(uuid[]) from public;
grant execute on function public.community_member_identities(uuid[]) to anon,authenticated;


commit;
