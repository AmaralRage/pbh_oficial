begin;
alter table public.native_push_tokens add column chat_style_version integer not null default 0 check(chat_style_version between 0 and 1);

create or replace function public.register_native_push(p_installation_id uuid,p_token text)
returns void language plpgsql security definer set search_path='' as $$
begin
 if auth.uid() is null then raise exception 'Authentication required' using errcode='42501'; end if;
 delete from public.native_push_tokens where token=p_token and installation_id<>p_installation_id;
 insert into public.native_push_tokens(installation_id,user_id,token) values(p_installation_id,auth.uid(),p_token)
 on conflict(installation_id) do update set user_id=auth.uid(),token=excluded.token,updated_at=now(),chat_style_version=0;
end $$;

create or replace function public.register_native_push_v2(p_installation_id uuid,p_token text,p_sound_enabled boolean)
returns void language plpgsql security definer set search_path='' as $$
begin
 if p_sound_enabled is null then raise exception 'Sound preference required'; end if;
 perform public.register_native_push(p_installation_id,p_token);
 update public.native_push_tokens set sound_enabled=p_sound_enabled,chat_style_version=0
 where installation_id=p_installation_id and user_id=auth.uid();
end $$;
create function public.register_native_push_v3(p_installation_id uuid,p_token text,p_sound_enabled boolean)
returns void language plpgsql security definer set search_path='' as $$
begin
 perform public.register_native_push_v2(p_installation_id,p_token,p_sound_enabled);
 update public.native_push_tokens set chat_style_version=1 where installation_id=p_installation_id and user_id=auth.uid();
end $$;
revoke all on function public.register_native_push_v3(uuid,text,boolean) from public,anon;
grant execute on function public.register_native_push_v3(uuid,text,boolean) to authenticated;

-- Private job metadata: only the worker receives message previews.
create or replace function public.chat_claim_push() returns jsonb language plpgsql security definer set search_path='' as $$
declare job public.chat_push_jobs; item public.chat_messages; recipient uuid; identity record;
begin
 update public.chat_push_jobs set state='failed' where state='processing' and lease_until<now() and attempts>=5;
 select * into job from public.chat_push_jobs where attempts<5 and ((state='pending' and retry_at<=now()) or (state='processing' and lease_until<now())) order by retry_at,message_id limit 1 for update skip locked;
 if not found then return null; end if;
 select * into item from public.chat_messages where id=job.message_id;
 select case when t.member_a=item.sender_id then t.member_b else t.member_a end into recipient from public.chat_threads t
 where t.id=item.thread_id and item.expires_at>now()
 and (case when t.member_a=item.sender_id then t.read_b_at else t.read_a_at end)<item.created_at
 and not exists(select 1 from public.community_blocks b where (b.blocker_id=t.member_a and b.blocked_id=t.member_b) or (b.blocker_id=t.member_b and b.blocked_id=t.member_a));
 if recipient is null then update public.chat_push_jobs set state='sent' where message_id=job.message_id; return jsonb_build_object('skipped',true); end if;
 select
  case when coalesce(p.is_public,true) then left(coalesce(nullif(btrim(u.raw_user_meta_data->>'display_name'),''),nullif(p.display_name,''),'Membro'),40) else 'Membro' end as name,
  case when coalesce(p.is_public,true) then left(case when u.raw_user_meta_data ? 'avatar_url' then nullif(u.raw_user_meta_data->>'avatar_url','') else p.avatar_url end,2048) end as avatar,
  coalesce(p.is_public,true) and u.email_confirmed_at is not null and coalesce(u.raw_app_meta_data->'pbh_project_leader'='true'::jsonb,false) as founder
 into identity from auth.users u join public.profiles p on p.id=u.id where u.id=item.sender_id;
 update public.chat_push_jobs set state='processing',attempts=attempts+1,lease_id=gen_random_uuid(),lease_until=now()+interval '5 minutes' where message_id=job.message_id returning * into job;
 return jsonb_build_object('message_id',item.id,'thread_id',item.thread_id,'recipient_id',recipient,'lease_id',job.lease_id,
  'sender_id',item.sender_id,'sender_name',coalesce(identity.name,'Membro'),'sender_avatar',identity.avatar,'sender_founder',coalesce(identity.founder,false),
  'content',item.body,'has_image',item.image_path is not null,'audio_duration_ms',item.audio_duration_ms,'sent_at',item.created_at,'expires_at',item.expires_at);
end $$;
revoke all on function public.chat_claim_push() from public,anon,authenticated;
grant execute on function public.chat_claim_push() to service_role;
commit;
