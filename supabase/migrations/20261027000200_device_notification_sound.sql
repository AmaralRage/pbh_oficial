begin;
alter table public.native_push_tokens add column if not exists sound_enabled boolean not null default true;
create function public.register_native_push_v2(p_installation_id uuid,p_token text,p_sound_enabled boolean)
returns void language plpgsql security definer set search_path='' as $$
begin
  if p_sound_enabled is null then raise exception 'Sound preference required'; end if;
  perform public.register_native_push(p_installation_id,p_token);
  update public.native_push_tokens set sound_enabled=p_sound_enabled
    where installation_id=p_installation_id and user_id=auth.uid();
end $$;
revoke all on function public.register_native_push_v2(uuid,text,boolean) from public,anon;
grant execute on function public.register_native_push_v2(uuid,text,boolean) to authenticated;
commit;
