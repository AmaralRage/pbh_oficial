begin;
-- Framing changes preserve original Storage objects and use optimistic concurrency.
create function public.edit_community_image_framing(p_id uuid,p_expected jsonb,p_framings jsonb)
returns void language plpgsql security definer set search_path='' as $$
declare item public.community_posts;
begin
 if auth.uid() is null then raise exception 'Entre na sua conta.' using errcode='42501'; end if;
 select * into item from public.community_posts where id=p_id and user_id=auth.uid() for update;
 if not found then raise exception 'Publicação indisponível.' using errcode='42501'; end if;
 if item.image_framings is distinct from p_expected then raise exception 'O enquadramento mudou. Atualize a publicação.' using errcode='40001'; end if;
 if p_framings is null or not public.valid_community_image_framings(p_framings) or jsonb_array_length(p_framings)>cardinality(item.image_paths) then raise exception 'Enquadramento inválido.'; end if;
 update public.community_posts set image_framings=p_framings where id=p_id;
end $$;
revoke all on function public.edit_community_image_framing(uuid,jsonb,jsonb) from public,anon;
grant execute on function public.edit_community_image_framing(uuid,jsonb,jsonb) to authenticated;

create function public.community_comment_context(p_id uuid,p_post uuid) returns jsonb
language sql stable security definer set search_path='' as $$
 with recursive ancestors as (
  select c.id,c.reply_to_id, array[c.id] as visited from public.community_comment_feed c
   where c.id=p_id and c.post_id=p_post and exists(select 1 from public.community_feed p where p.id=p_post)
  union all
  select c.id,c.reply_to_id,a.visited||c.id from ancestors a join public.community_comment_feed c on c.id=a.reply_to_id
   where c.post_id=p_post and not c.id=any(a.visited) and cardinality(a.visited)<20
 )
 select coalesce(jsonb_agg(to_jsonb(c) order by c.created_at,c.id),'[]'::jsonb)
 from public.community_comment_feed c where c.id in(select id from ancestors);
$$;
revoke all on function public.community_comment_context(uuid,uuid) from public,anon;
grant execute on function public.community_comment_context(uuid,uuid) to authenticated;

create function public.admin_list_member_badges(p_offset integer default 0,p_query text default '')
returns table(user_id uuid,email text,name text,badge_key text,granted_at timestamptz)
language plpgsql stable security definer set search_path='' as $$
begin
 if not coalesce(public.is_admin(),false) then raise exception 'Admin access required' using errcode='42501'; end if;
 return query select b.user_id,u.email::text,
  left(coalesce(nullif(btrim(u.raw_user_meta_data->>'display_name'),''),nullif(p.display_name,''),'Membro'),40),b.badge_key,b.granted_at
 from public.member_badge_awards b join auth.users u on u.id=b.user_id left join public.profiles p on p.id=b.user_id
 where coalesce(u.email,'') ilike '%'||left(coalesce(p_query,''),100)||'%' or coalesce(p.display_name,'') ilike '%'||left(coalesce(p_query,''),100)||'%'
    or coalesce(u.raw_user_meta_data->>'display_name','') ilike '%'||left(coalesce(p_query,''),100)||'%'
 order by b.granted_at desc,b.user_id,b.badge_key limit 30 offset greatest(0,least(coalesce(p_offset,0),100000));
end $$;
revoke all on function public.admin_list_member_badges(integer,text) from public,anon;
grant execute on function public.admin_list_member_badges(integer,text) to authenticated;
commit;
