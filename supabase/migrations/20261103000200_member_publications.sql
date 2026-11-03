begin;
create index if not exists community_posts_author_time on public.community_posts(user_id,created_at desc,id);
-- Profile publications require profile visibility as well as the feed's blocks.
create function public.member_publications(p_user uuid,p_offset integer default 0)
returns setof public.community_feed language sql stable security definer set search_path='' as $$
 select f.* from public.community_feed f
 where f.user_id=p_user and exists(select 1 from public.profiles p where p.id=p_user and
 (p.id=auth.uid() or coalesce(p.is_public,true)))
 order by f.created_at desc,f.id desc limit 20 offset greatest(0,least(coalesce(p_offset,0),100000));
$$;
revoke all on function public.member_publications(uuid,integer) from public;
grant execute on function public.member_publications(uuid,integer) to anon,authenticated;
commit;
