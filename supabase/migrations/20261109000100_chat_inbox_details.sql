begin;
-- Preserve the old inbox for installed APKs; enrich only the new client response.
create function public.chat_inbox_v2(p_before timestamptz default null,p_before_id uuid default null,p_thread uuid default null,p_query text default '')
returns setof jsonb language sql stable security invoker set search_path='' as $$
 select to_jsonb(i)||jsonb_build_object('muted',coalesce(p.muted,false),'last_audio_duration_ms',m.audio_duration_ms)
 from public.chat_inbox(p_before,p_before_id,p_thread,p_query) i
 left join public.chat_preferences p on p.thread_id=i.thread_id and p.user_id=(select auth.uid())
 left join lateral(select x.audio_duration_ms from public.chat_messages x
   where x.thread_id=i.thread_id and x.created_at=i.last_at and x.sender_id=i.last_sender and x.expires_at>now()
   order by x.id desc limit 1) m on true;
$$;
revoke all on function public.chat_inbox_v2(timestamptz,uuid,uuid,text) from public,anon;
grant execute on function public.chat_inbox_v2(timestamptz,uuid,uuid,text) to authenticated;
commit;
