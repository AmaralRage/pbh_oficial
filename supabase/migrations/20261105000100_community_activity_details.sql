begin;
create index if not exists community_activity_unread on public.community_reply_notifications(recipient_id,created_at desc,id) where read_at is null;

create function public.community_activity_page(p_offset integer default 0)
returns table(id uuid,actor_id uuid,post_id uuid,comment_id uuid,kind text,created_at timestamptz,read_at timestamptz,
 actor_name text,actor_avatar_url text,preview text)
language plpgsql stable security definer set search_path='' as $$
begin
 if auth.uid() is null then raise exception 'Entre na sua conta.' using errcode='42501'; end if;
 return query select n.id,n.actor_id,n.post_id,n.comment_id,n.kind,n.created_at,n.read_at,
 case when coalesce(pr.is_public,true) then left(coalesce(nullif(btrim(u.raw_user_meta_data->>'display_name'),''),nullif(pr.display_name,''),'Membro'),40) else 'Membro' end,
 case when coalesce(pr.is_public,true) then left(case when u.raw_user_meta_data ? 'avatar_url' then nullif(u.raw_user_meta_data->>'avatar_url','') else pr.avatar_url end,2048) else null end,
 left(coalesce(c.content,p.content,''),160)
 from public.community_reply_notifications n
 join public.community_posts p on p.id=n.post_id
 join auth.users u on u.id=n.actor_id
 left join public.profiles pr on pr.id=n.actor_id
 left join public.community_comments c on c.id=n.comment_id and c.post_id=n.post_id
 where n.recipient_id=auth.uid() and public.can_view_community_reply(n.post_id,n.actor_id)
 order by n.created_at desc,n.id desc limit 30 offset greatest(0,least(coalesce(p_offset,0),10000));
end $$;

create function public.community_activity_unread_count() returns integer
language plpgsql stable security definer set search_path='' as $$
begin
 if auth.uid() is null then raise exception 'Entre na sua conta.' using errcode='42501'; end if;
 return (select count(*)::integer from public.community_reply_notifications n
 where n.recipient_id=auth.uid() and n.read_at is null and public.can_view_community_reply(n.post_id,n.actor_id));
end $$;

-- The client's newest observed timestamp leaves later arrivals unread.
create function public.mark_community_activity_read(p_through timestamptz) returns void
language plpgsql security definer set search_path='' as $$
begin
 if auth.uid() is null then raise exception 'Entre na sua conta.' using errcode='42501'; end if;
 if p_through is null then raise exception 'Atualize a atividade antes de continuar.' using errcode='22023'; end if;
 update public.community_reply_notifications n set read_at=now()
 where n.recipient_id=auth.uid() and n.read_at is null and n.created_at<=least(p_through,now())
 and public.can_view_community_reply(n.post_id,n.actor_id);
end $$;
revoke all on function public.community_activity_page(integer),public.community_activity_unread_count(),public.mark_community_activity_read(timestamptz) from public,anon;
grant execute on function public.community_activity_page(integer),public.community_activity_unread_count(),public.mark_community_activity_read(timestamptz) to authenticated;
commit;
