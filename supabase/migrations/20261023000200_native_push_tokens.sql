create table public.native_push_tokens (
  installation_id uuid primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  token text unique not null check(char_length(token) between 20 and 4096),
  updated_at timestamptz not null default now()
);
create index native_push_tokens_user on public.native_push_tokens(user_id);
alter table public.native_push_tokens enable row level security;
revoke all on public.native_push_tokens from anon,authenticated;
grant all on public.native_push_tokens to service_role;

create function public.register_native_push(p_installation_id uuid,p_token text)
returns void language plpgsql security definer set search_path='' as $$
begin
  if auth.uid() is null then raise exception 'Authentication required' using errcode='42501'; end if;
  -- Move the same installation/token on account switches; never retain both owners.
  delete from public.native_push_tokens where token=p_token and installation_id<>p_installation_id;
  insert into public.native_push_tokens(installation_id,user_id,token)
  values(p_installation_id,auth.uid(),p_token)
  on conflict(installation_id) do update set user_id=auth.uid(),token=excluded.token,updated_at=now();
end $$;
create function public.unregister_native_push(p_installation_id uuid)
returns void language sql security definer set search_path='' as $$
  delete from public.native_push_tokens where installation_id=p_installation_id and user_id=auth.uid();
$$;
revoke all on function public.register_native_push(uuid,text),public.unregister_native_push(uuid) from public,anon;
grant execute on function public.register_native_push(uuid,text),public.unregister_native_push(uuid) to authenticated;
