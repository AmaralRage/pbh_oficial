begin;
do $$
declare
  first_user uuid := 'af230000-0000-4000-8000-000000000001';
  second_user uuid := 'af230000-0000-4000-8000-000000000002';
  device uuid := 'af230000-0000-4000-8000-000000000003';
begin
  insert into auth.users(id,email,email_confirmed_at,raw_user_meta_data)
  values(first_user,'push-a@example.invalid',now(),'{}'),(second_user,'push-b@example.invalid',now(),'{}');
  perform set_config('request.jwt.claim.sub','',true);
  begin
    perform public.register_native_push(device,'test-token-12345678901234567890');
    raise exception 'Anonymous registration accepted';
  exception when insufficient_privilege then null;
  end;
  perform set_config('request.jwt.claim.sub',first_user::text,true);
  perform public.register_native_push(device,'test-token-12345678901234567890');
  perform public.register_native_push(device,'new-token-12345678901234567890');
  if (select count(*) from public.native_push_tokens where installation_id=device and user_id=first_user and token='new-token-12345678901234567890')<>1 then raise exception 'Token renewal failed'; end if;
  perform set_config('request.jwt.claim.sub',second_user::text,true);
  perform public.unregister_native_push(device);
  if not exists(select 1 from public.native_push_tokens where installation_id=device) then raise exception 'Other account revoked a device'; end if;
  perform public.register_native_push(device,'new-token-12345678901234567890');
  if exists(select 1 from public.native_push_tokens where installation_id=device and user_id=first_user) then raise exception 'Old owner retained'; end if;
  perform public.unregister_native_push(device);
  if exists(select 1 from public.native_push_tokens where installation_id=device) then raise exception 'Logout did not revoke push'; end if;
  if has_table_privilege('authenticated','public.native_push_tokens','select') or has_table_privilege('authenticated','public.native_push_tokens','insert')
    or has_function_privilege('anon','public.register_native_push(uuid,text)','execute') then raise exception 'Device credentials exposed'; end if;
end $$;
rollback;
select 'Device registration, renewal, account switch, logout and token privacy passed; fixtures rolled back' as result;
