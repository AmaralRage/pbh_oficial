begin;
create table public.member_handles(
 user_id uuid primary key references auth.users(id) on delete cascade,
 handle text not null unique check(handle ~ '^[a-z][a-z0-9_]{2,39}$')
);
alter table public.member_handles enable row level security;
revoke all on public.member_handles from public,anon,authenticated;
create function public.initialize_member_handle() returns trigger
language plpgsql security definer set search_path='' as $$
begin
 insert into public.member_handles values(new.id,'m_'||replace(new.id::text,'-','')) on conflict(user_id) do nothing;
 return new;
end $$;
revoke all on function public.initialize_member_handle() from public,anon,authenticated;
create trigger initialize_member_handle after insert on auth.users for each row execute function public.initialize_member_handle();
insert into public.member_handles select id,'m_'||replace(id::text,'-','') from auth.users;
create function public.set_member_handle(p_handle text) returns text
language plpgsql security definer set search_path='' as $$
declare h text:=lower(btrim(p_handle));
begin
 if auth.uid() is null then raise exception 'Entre na sua conta.' using errcode='42501'; end if;
 if h is null or h !~ '^[a-z][a-z0-9_]{2,39}$' then raise exception 'Use de 3 a 40 letras, números ou sublinhado, começando por uma letra.' using errcode='22023'; end if;
 insert into public.member_handles values(auth.uid(),h) on conflict(user_id) do update set handle=excluded.handle;
 return h;
exception when unique_violation then raise exception 'Este nome de usuário já está em uso.' using errcode='23505';
end $$;
create function public.member_handle(p_user uuid) returns text
language sql stable security definer set search_path='' as $$
 select h.handle from public.member_handles h join public.profiles p on p.id=h.user_id
 where h.user_id=p_user and (p_user=auth.uid() or coalesce(p.is_public,true))
 and not exists(select 1 from public.community_blocks b where
 (b.blocker_id=auth.uid() and b.blocked_id=p_user) or (b.blocker_id=p_user and b.blocked_id=auth.uid()));
$$;
revoke all on function public.set_member_handle(text),public.member_handle(uuid) from public,anon,authenticated;
grant execute on function public.set_member_handle(text) to authenticated;
grant execute on function public.member_handle(uuid) to anon,authenticated;

drop function public.admin_search_members(text,integer);
create function public.admin_search_members(p_query text default '',p_offset integer default 0)
returns table(user_id uuid,name text,avatar_url text,joined_at timestamptz,handle text)
language plpgsql stable security definer set search_path='' as $$
declare term text:=lower(left(ltrim(btrim(coalesce(p_query,'')),'@'),100));
begin
 if not (coalesce(public.is_admin(),false) or exists(select 1 from auth.users where id=auth.uid() and lower(email)='amaralaragao31@gmail.com' and email_confirmed_at is not null)) then raise exception 'Admin access required' using errcode='42501'; end if;
 return query with members as (
 select u.id,left(coalesce(nullif(btrim(u.raw_user_meta_data->>'display_name'),''),nullif(p.display_name,''),'Membro'),40) as display_name,
 left(case when u.raw_user_meta_data ? 'avatar_url' then nullif(u.raw_user_meta_data->>'avatar_url','') else p.avatar_url end,2048) as photo,u.created_at,h.handle as username
 from auth.users u left join public.profiles p on p.id=u.id left join public.member_handles h on h.user_id=u.id where u.email_confirmed_at is not null
 ) select m.id,m.display_name,m.photo,m.created_at,m.username from members m
 where strpos(lower(m.display_name),term)>0 or strpos(m.id::text,term)>0 or strpos(m.username,term)>0
 order by (m.username=term) desc nulls last,lower(m.display_name),m.id limit 30 offset greatest(0,least(coalesce(p_offset,0),100000));
end $$;
revoke all on function public.admin_search_members(text,integer) from public,anon;
grant execute on function public.admin_search_members(text,integer) to authenticated;
commit;
