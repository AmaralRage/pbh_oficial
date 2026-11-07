begin;
-- At most one small, temporary typing state per participant and conversation.
create table public.chat_typing(
 thread_id uuid not null references public.chat_threads(id) on delete cascade,
 user_id uuid not null references auth.users(id) on delete cascade,
 until_at timestamptz not null, primary key(thread_id,user_id)
);
alter table public.chat_typing enable row level security;
revoke all on public.chat_typing from public,anon,authenticated;
grant select on public.chat_typing to authenticated;
grant all on public.chat_typing to service_role;
create policy chat_typing_members on public.chat_typing for select to authenticated
 using(public.chat_has_access(thread_id));
create function public.chat_set_typing(p_thread uuid,p_active boolean) returns void
language plpgsql security definer set search_path='' as $$
begin
 if not public.chat_has_access(p_thread) then raise exception 'Conversa indisponível.' using errcode='42501'; end if;
 if p_active is null then raise exception 'Estado inválido.' using errcode='22023'; end if;
 insert into public.chat_typing values(p_thread,auth.uid(),case when p_active then now()+interval '6 seconds' else now() end)
 on conflict(thread_id,user_id) do update set until_at=excluded.until_at
 where not p_active or public.chat_typing.until_at<now()+interval '3 seconds';
end $$;
create table public.chat_preferences(
 thread_id uuid not null references public.chat_threads(id) on delete cascade,
 user_id uuid not null references auth.users(id) on delete cascade,
 muted boolean not null default false,primary key(thread_id,user_id)
);
alter table public.chat_preferences enable row level security;
revoke all on public.chat_preferences from public,anon,authenticated;
grant select on public.chat_preferences to authenticated;
grant all on public.chat_preferences to service_role;
create policy chat_preferences_owner on public.chat_preferences for select to authenticated
 using(user_id=(select auth.uid()) and public.chat_has_access(thread_id));
create function public.chat_set_muted(p_thread uuid,p_muted boolean) returns void
language plpgsql security definer set search_path='' as $$
begin
 if not public.chat_has_access(p_thread) then raise exception 'Conversa indisponível.' using errcode='42501'; end if;
 if p_muted is null then raise exception 'Estado inválido.' using errcode='22023'; end if;
 insert into public.chat_preferences values(p_thread,auth.uid(),p_muted)
 on conflict(thread_id,user_id) do update set muted=excluded.muted;
end $$;
create function public.chat_search_messages(p_thread uuid,p_query text,p_before timestamptz default null,p_before_id uuid default null)
returns setof public.chat_messages language sql stable security invoker set search_path='' as $$
 select * from public.chat_messages where thread_id=p_thread and expires_at>now()
 and length(btrim(p_query)) between 2 and 100
 and strpos(lower(body),lower(btrim(p_query)))>0
 and (p_before is null or (created_at,id)<(p_before,p_before_id))
 order by created_at desc,id desc limit 30;
$$;
create function public.chat_reply_context(p_thread uuid,p_ids uuid[])
returns setof public.chat_messages language sql stable security invoker set search_path='' as $$
 select * from public.chat_messages where thread_id=p_thread and expires_at>now()
 and id in(select x from unnest(p_ids) x limit 40);
$$;
-- Recheck queued deliveries immediately before a worker sends an alert.
create function public.chat_push_delivery_allowed(p_message uuid,p_recipient uuid) returns boolean
language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.chat_messages m join public.chat_threads t on t.id=m.thread_id
 where m.id=p_message and m.expires_at>now()
 and p_recipient=case when m.sender_id=t.member_a then t.member_b else t.member_a end
 and (case when p_recipient=t.member_a then t.read_a_at else t.read_b_at end)<m.created_at
 and not exists(select 1 from public.chat_preferences p where p.thread_id=t.id and p.user_id=p_recipient and p.muted)
 and not exists(select 1 from public.community_blocks b where (b.blocker_id=t.member_a and b.blocked_id=t.member_b) or (b.blocker_id=t.member_b and b.blocked_id=t.member_a)));
$$;
revoke all on function public.chat_push_delivery_allowed(uuid,uuid) from public,anon,authenticated;
grant execute on function public.chat_push_delivery_allowed(uuid,uuid) to service_role;
revoke all on function public.chat_set_typing(uuid,boolean),public.chat_set_muted(uuid,boolean),public.chat_search_messages(uuid,text,timestamptz,uuid),public.chat_reply_context(uuid,uuid[]) from public,anon;
grant execute on function public.chat_set_typing(uuid,boolean),public.chat_set_muted(uuid,boolean),public.chat_search_messages(uuid,text,timestamptz,uuid),public.chat_reply_context(uuid,uuid[]) to authenticated;
do $$ begin
 if exists(select 1 from pg_publication where pubname='supabase_realtime') then
  alter publication supabase_realtime add table public.chat_typing;
 end if;
 if to_regclass('cron.job') is not null then
  perform cron.schedule('pbh-clear-chat-typing','*/5 * * * *', 'delete from public.chat_typing where until_at<now()-interval ''5 minutes''');
 end if;
end $$;
commit;
