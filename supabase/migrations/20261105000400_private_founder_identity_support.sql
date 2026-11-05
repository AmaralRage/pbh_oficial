begin;
-- Server-only identity; never trust editable user_metadata for founder status.
-- Existing login, password, profile role and server authorizations are preserved.
create function public.assign_project_leader_claim() returns trigger
language plpgsql security definer set search_path='' as $$
begin
  new.raw_app_meta_data := coalesce(new.raw_app_meta_data,'{}'::jsonb) ||
    jsonb_build_object('pbh_project_leader',
      lower(coalesce(new.email,''))='amaralaragao31@gmail.com'
      and new.email_confirmed_at is not null);
  return new;
end $$;
revoke all on function public.assign_project_leader_claim() from public,anon,authenticated;
create trigger assign_project_leader_claim before insert or update of email,email_confirmed_at,raw_app_meta_data
  on auth.users for each row execute function public.assign_project_leader_claim();
update auth.users set raw_app_meta_data=coalesce(raw_app_meta_data,'{}'::jsonb)
  where raw_app_meta_data->'pbh_project_leader' is distinct from to_jsonb(
    lower(coalesce(email,''))='amaralaragao31@gmail.com' and email_confirmed_at is not null);

-- No personal contact address is returned to clients.
create table public.private_support_requests(
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  kind text not null check(kind in ('help','account_deletion')),
  message text not null check(length(btrim(message)) between 1 and 2000),
  created_at timestamptz not null default now(),
  resolved boolean not null default false
);
create index private_support_requests_time on public.private_support_requests(created_at desc,id);
create index private_support_requests_owner_time on public.private_support_requests(user_id,created_at desc);
alter table public.private_support_requests enable row level security;
revoke all on public.private_support_requests from public,anon,authenticated;
grant select on public.private_support_requests to authenticated;
grant update(resolved) on public.private_support_requests to authenticated;
create policy support_admin_read on public.private_support_requests for select to authenticated
  using((select public.is_admin()));
create policy support_admin_resolve on public.private_support_requests for update to authenticated
  using((select public.is_admin())) with check((select public.is_admin()));
create function public.submit_private_support_request(p_kind text,p_message text) returns uuid
language plpgsql security definer set search_path='' as $$
declare request_id uuid;
begin
  if auth.uid() is null then raise exception 'Entre na sua conta.' using errcode='42501'; end if;
  if p_kind is null or p_kind not in ('help','account_deletion') or p_message is null
    or length(btrim(p_message)) not between 1 and 2000 then raise exception 'Revise sua mensagem.' using errcode='22023'; end if;
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(auth.uid()::text,110504));
  if (select count(*) from public.private_support_requests where user_id=auth.uid()
      and created_at>now()-interval '1 day')>=20 then
    raise exception 'Limite de solicitações atingido. Tente novamente amanhã.' using errcode='22023'; end if;
  insert into public.private_support_requests(user_id,kind,message)
    values(auth.uid(),p_kind,btrim(p_message)) returning id into request_id;
  return request_id;
end $$;
revoke all on function public.submit_private_support_request(text,text) from public,anon;
grant execute on function public.submit_private_support_request(text,text) to authenticated;
commit;
