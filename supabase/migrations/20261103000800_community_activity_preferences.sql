begin;
create table public.community_activity_preferences(
 user_id uuid primary key references auth.users(id) on delete cascade,
 replies boolean not null default true,post_comments boolean not null default true,post_likes boolean not null default true
);
alter table public.community_activity_preferences enable row level security;
revoke all on public.community_activity_preferences from public,anon,authenticated;
create function public.get_community_activity_preferences() returns jsonb
language sql stable security definer set search_path='' as $$
 select coalesce((select jsonb_build_object('replies',replies,'post_comments',post_comments,'post_likes',post_likes)
 from public.community_activity_preferences where user_id=auth.uid()),'{"replies":true,"post_comments":true,"post_likes":true}'::jsonb);
$$;
create function public.set_community_activity_preferences(p_replies boolean,p_comments boolean,p_likes boolean) returns void
language plpgsql security definer set search_path='' as $$
begin
 if auth.uid() is null then raise exception 'Entre na sua conta.' using errcode='42501'; end if;
 if p_replies is null or p_comments is null or p_likes is null then raise exception 'Escolha suas preferências.'; end if;
 insert into public.community_activity_preferences values(auth.uid(),p_replies,p_comments,p_likes)
 on conflict(user_id) do update set replies=excluded.replies,post_comments=excluded.post_comments,post_likes=excluded.post_likes;
end $$;
revoke all on function public.get_community_activity_preferences(),public.set_community_activity_preferences(boolean,boolean,boolean) from public,anon;
grant execute on function public.get_community_activity_preferences(),public.set_community_activity_preferences(boolean,boolean,boolean) to authenticated;

alter table public.community_reply_notifications alter column comment_id drop not null,alter column parent_comment_id drop not null;
alter table public.community_reply_notifications add column kind text not null default 'reply' check(kind in ('reply','post_comment','post_like'));
alter table public.community_reply_notifications drop constraint community_reply_notifications_comment_id_key;
create unique index community_activity_comment_once on public.community_reply_notifications(recipient_id,comment_id) where comment_id is not null;
create unique index community_activity_like_once on public.community_reply_notifications(recipient_id,actor_id,post_id) where kind='post_like';
create or replace function public.notify_community_reply() returns trigger
language plpgsql security definer set search_path='' as $$
declare recipient uuid;
begin
 select user_id into recipient from public.community_comments where id=new.reply_to_id and post_id=new.post_id;
 if recipient is not null and recipient<>new.user_id
 and coalesce((select replies from public.community_activity_preferences where user_id=recipient),true)
 and not exists(select 1 from public.community_blocks b where (b.blocker_id=recipient and b.blocked_id=new.user_id) or (b.blocker_id=new.user_id and b.blocked_id=recipient)) then
 insert into public.community_reply_notifications(recipient_id,actor_id,post_id,comment_id,parent_comment_id,kind)
 values(recipient,new.user_id,new.post_id,new.id,new.reply_to_id,'reply') on conflict do nothing;
 end if;
 return new;
end $$;
create function public.notify_community_post_activity() returns trigger
language plpgsql security definer set search_path='' as $$
declare recipient uuid; parent_owner uuid; is_like boolean:=tg_table_name='community_post_likes';
begin
 select user_id into recipient from public.community_posts where id=new.post_id;
 if recipient is null or recipient=new.user_id or exists(select 1 from public.community_blocks b where
 (b.blocker_id=recipient and b.blocked_id=new.user_id) or (b.blocker_id=new.user_id and b.blocked_id=recipient)) then return new; end if;
 if is_like then
 if coalesce((select post_likes from public.community_activity_preferences where user_id=recipient),true) then
 insert into public.community_reply_notifications(recipient_id,actor_id,post_id,kind) values(recipient,new.user_id,new.post_id,'post_like') on conflict do nothing;
 end if;
 else
 select user_id into parent_owner from public.community_comments where id=new.reply_to_id;
 -- A reply to the author's comment already has its own notification.
 if parent_owner is distinct from recipient and coalesce((select post_comments from public.community_activity_preferences where user_id=recipient),true) then
 insert into public.community_reply_notifications(recipient_id,actor_id,post_id,comment_id,kind) values(recipient,new.user_id,new.post_id,new.id,'post_comment') on conflict do nothing;
 end if;
 end if;
 return new;
end $$;
revoke all on function public.notify_community_post_activity() from public,anon,authenticated;
create trigger notify_community_post_comment after insert on public.community_comments for each row execute function public.notify_community_post_activity();
create trigger notify_community_post_like after insert on public.community_post_likes for each row execute function public.notify_community_post_activity();
commit;
