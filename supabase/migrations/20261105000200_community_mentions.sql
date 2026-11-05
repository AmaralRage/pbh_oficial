begin;
alter table public.community_activity_preferences add column mentions boolean not null default true;
alter table public.community_reply_notifications drop constraint community_reply_notifications_kind_check;
alter table public.community_reply_notifications add constraint community_reply_notifications_kind_check check(kind in ('reply','post_comment','post_like','mention'));
create unique index community_activity_post_mention_once on public.community_reply_notifications(recipient_id,actor_id,post_id) where kind='mention' and comment_id is null;

create function public.community_handles_in_text(p_content text) returns text[]
language sql immutable set search_path='' as $$
 select coalesce(array_agg(handle order by first_at),'{}'::text[]) from (
 select lower(m[2]) handle,min(n) first_at from regexp_matches(left(coalesce(p_content,''),2000),
 '(^|[^A-Za-z0-9_@.])@([A-Za-z][A-Za-z0-9_]{2,39})(?![A-Za-z0-9_])','g') with ordinality t(m,n)
 group by lower(m[2]) order by min(n) limit 20) x;
$$;
revoke all on function public.community_handles_in_text(text) from public,anon,authenticated;

create function public.resolve_community_handles(p_handles text[])
returns table(user_id uuid,handle text) language sql stable security definer set search_path='' as $$
 select h.user_id,h.handle from public.member_handles h join public.profiles p on p.id=h.user_id join auth.users u on u.id=h.user_id
 where h.handle in(select lower(btrim(x)) from unnest(p_handles)x limit 20)
 and u.email_confirmed_at is not null and (p.id=auth.uid() or coalesce(p.is_public,true))
 and not exists(select 1 from public.community_blocks b where
 (b.blocker_id=auth.uid() and b.blocked_id=p.id) or (b.blocker_id=p.id and b.blocked_id=auth.uid()));
$$;
revoke all on function public.resolve_community_handles(text[]) from public;
grant execute on function public.resolve_community_handles(text[]) to anon,authenticated;

create or replace function public.get_community_activity_preferences() returns jsonb
language sql stable security definer set search_path='' as $$
 select coalesce((select jsonb_build_object('replies',replies,'post_comments',post_comments,'post_likes',post_likes,'mentions',mentions)
 from public.community_activity_preferences where user_id=auth.uid()),'{"replies":true,"post_comments":true,"post_likes":true,"mentions":true}'::jsonb);
$$;
create function public.set_community_activity_options(p_replies boolean,p_comments boolean,p_likes boolean,p_mentions boolean) returns void
language plpgsql security definer set search_path='' as $$
begin
 if auth.uid() is null then raise exception 'Entre na sua conta.' using errcode='42501'; end if;
 if p_replies is null or p_comments is null or p_likes is null or p_mentions is null then raise exception 'Escolha suas preferências.'; end if;
 insert into public.community_activity_preferences(user_id,replies,post_comments,post_likes,mentions) values(auth.uid(),p_replies,p_comments,p_likes,p_mentions)
 on conflict(user_id) do update set replies=excluded.replies,post_comments=excluded.post_comments,post_likes=excluded.post_likes,mentions=excluded.mentions;
end $$;
revoke all on function public.set_community_activity_options(boolean,boolean,boolean,boolean) from public,anon;
grant execute on function public.set_community_activity_options(boolean,boolean,boolean,boolean) to authenticated;

create function public.notify_community_mentions() returns trigger
language plpgsql security definer set search_path='' as $$
declare post uuid; comment uuid; recipients text[];
begin
 if tg_op='UPDATE' then if new.content is not distinct from old.content then return new; end if; end if;
 if tg_table_name='community_posts' then post:=new.id; comment:=null;
 else post:=new.post_id; comment:=new.id; end if;
 recipients:=public.community_handles_in_text(new.content);
 insert into public.community_reply_notifications(recipient_id,actor_id,post_id,comment_id,kind)
 select h.user_id,new.user_id,post,comment,'mention'
 from public.member_handles h join public.profiles p on p.id=h.user_id join auth.users u on u.id=h.user_id
 where h.handle=any(recipients) and h.user_id<>new.user_id and coalesce(p.is_public,true) and u.email_confirmed_at is not null
 and coalesce((select mentions from public.community_activity_preferences where user_id=h.user_id),true)
 and not exists(select 1 from public.community_blocks b where
 (b.blocker_id=h.user_id and b.blocked_id=new.user_id) or (b.blocker_id=new.user_id and b.blocked_id=h.user_id))
 on conflict do nothing;
 return new;
end $$;
revoke all on function public.notify_community_mentions() from public,anon,authenticated;
-- Run after comment/reply notifications so one interaction stays one notice.
create trigger zz_notify_community_post_mentions after insert or update of content on public.community_posts for each row execute function public.notify_community_mentions();
create trigger zz_notify_community_comment_mentions after insert or update of content on public.community_comments for each row execute function public.notify_community_mentions();
commit;
