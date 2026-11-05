begin;
create policy support_owner_read on public.private_support_requests for select to authenticated
  using(user_id=(select auth.uid()));
create table public.private_support_replies(
  id uuid primary key default gen_random_uuid(),
  request_id uuid not null references public.private_support_requests(id) on delete cascade,
  message text not null check(length(btrim(message)) between 1 and 2000),
  created_at timestamptz not null default now()
);
create index private_support_replies_request_time on public.private_support_replies(request_id,created_at,id);
alter table public.private_support_replies enable row level security;
revoke all on public.private_support_replies from public,anon,authenticated;
grant select on public.private_support_replies to authenticated;
create policy support_reply_read on public.private_support_replies for select to authenticated using(
  exists(select 1 from public.private_support_requests r where r.id=request_id
    and (r.user_id=(select auth.uid()) or (select public.is_admin()))));
create function public.reply_private_support(p_request uuid,p_message text) returns void
language plpgsql security definer set search_path='' as $$
begin
  if not coalesce(public.is_admin(),false) then raise exception 'Acesso restrito.' using errcode='42501'; end if;
  if p_message is null or length(btrim(p_message)) not between 1 and 2000 then raise exception 'Revise sua resposta.' using errcode='22023'; end if;
  perform 1 from public.private_support_requests where id=p_request for update;
  if not found then raise exception 'Solicitação indisponível.' using errcode='22023'; end if;
  insert into public.private_support_replies(request_id,message) values(p_request,btrim(p_message));
end $$;
revoke all on function public.reply_private_support(uuid,text) from public,anon;
grant execute on function public.reply_private_support(uuid,text) to authenticated;
commit;
