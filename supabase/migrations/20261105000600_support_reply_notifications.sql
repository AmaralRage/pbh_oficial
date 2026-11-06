begin;
alter table public.private_support_replies add column read_at timestamptz;
create index private_support_replies_unread on public.private_support_replies(request_id,created_at desc,id)
  where read_at is null;
create function public.support_reply_unread_count() returns integer
language sql stable security definer set search_path='' as $$
  select count(*)::integer from public.private_support_replies s
  join public.private_support_requests r on r.id=s.request_id
  where r.user_id=(select auth.uid()) and s.read_at is null;
$$;
create function public.latest_unread_support_request() returns jsonb
language sql stable security definer set search_path='' as $$
  select jsonb_build_object('id',r.id,'kind',r.kind,'message',r.message,'resolved',r.resolved)
  from public.private_support_requests r join public.private_support_replies s on s.request_id=r.id
  where r.user_id=(select auth.uid()) and s.read_at is null
  order by s.created_at desc,s.id desc limit 1;
$$;
create function public.mark_support_replies_read(p_ids uuid[]) returns void
language plpgsql security definer set search_path='' as $$
begin
  if auth.uid() is null then raise exception 'Entre na sua conta.' using errcode='42501'; end if;
  if p_ids is null or cardinality(p_ids)>100 then raise exception 'Avisos inválidos.' using errcode='22023'; end if;
  update public.private_support_replies s set read_at=now()
    where s.id=any(p_ids) and s.read_at is null and exists(
      select 1 from public.private_support_requests r where r.id=s.request_id and r.user_id=(select auth.uid()));
end $$;
revoke all on function public.support_reply_unread_count(),public.latest_unread_support_request(),public.mark_support_replies_read(uuid[]) from public,anon;
grant execute on function public.support_reply_unread_count(),public.latest_unread_support_request(),public.mark_support_replies_read(uuid[]) to authenticated;
commit;
