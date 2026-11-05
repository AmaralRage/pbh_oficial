begin;
create function public.search_community_members(p_query text default '',p_offset integer default 0)
returns table(user_id uuid,name text,avatar_url text,handle text)
language plpgsql stable security definer set search_path='' as $$
declare term text:=lower(left(ltrim(btrim(coalesce(p_query,'')),'@'),100));
begin
 if auth.uid() is null then raise exception 'Entre na sua conta.' using errcode='42501'; end if;
 if length(term)<2 then return; end if;
 return query with members as (
 select p.id,left(coalesce(nullif(btrim(u.raw_user_meta_data->>'display_name'),''),nullif(p.display_name,''),'Membro'),40) as display_name,
 left(case when u.raw_user_meta_data ? 'avatar_url' then nullif(u.raw_user_meta_data->>'avatar_url','') else p.avatar_url end,2048) as photo,h.handle as username
 from public.profiles p join auth.users u on u.id=p.id left join public.member_handles h on h.user_id=p.id
 where u.email_confirmed_at is not null and (p.id=auth.uid() or coalesce(p.is_public,true))
 and not exists(select 1 from public.community_blocks b where
 (b.blocker_id=auth.uid() and b.blocked_id=p.id) or (b.blocker_id=p.id and b.blocked_id=auth.uid()))
 ) select m.id,m.display_name,m.photo,m.username from members m
 where strpos(lower(m.display_name),term)>0 or strpos(m.username,term)>0
 order by (m.username=term) desc nulls last,lower(m.display_name),m.id
 limit 30 offset greatest(0,least(coalesce(p_offset,0),10000));
end $$;
revoke all on function public.search_community_members(text,integer) from public,anon;
grant execute on function public.search_community_members(text,integer) to authenticated;
commit;
