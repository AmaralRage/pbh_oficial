begin;
create table public.chat_push_jobs(
 message_id uuid primary key references public.chat_messages(id) on delete cascade,
 state text not null default 'pending' check(state in('pending','processing','sent','failed')),
 attempts integer not null default 0,retry_at timestamptz not null default now(),
 lease_id uuid,lease_until timestamptz
);
create index chat_push_jobs_due on public.chat_push_jobs(state,retry_at);
create table public.chat_push_receipts(
 message_id uuid not null references public.chat_messages(id) on delete cascade,
 endpoint text not null,primary key(message_id,endpoint)
);
alter table public.chat_push_jobs enable row level security;
alter table public.chat_push_receipts enable row level security;
revoke all on public.chat_push_jobs,public.chat_push_receipts from public,anon,authenticated;
grant all on public.chat_push_jobs,public.chat_push_receipts to service_role;

create function public.chat_wake_worker() returns void language plpgsql security definer set search_path='' as $$
declare endpoint text; secret text;
begin
 if not exists(select 1 from public.chat_push_jobs where attempts<5 and ((state='pending' and retry_at<=now()) or (state='processing' and lease_until<now())))
 and not exists(select 1 from public.chat_media_cleanup where not_before<=now() and (claim_token is null or claimed_until<now())) then return; end if;
 -- Reuse the existing private scheduler configuration; no secret reaches a client.
 select decrypted_secret into endpoint from vault.decrypted_secrets where name='pbh_announcements_project_url' limit 1;
 select decrypted_secret into secret from vault.decrypted_secrets where name='pbh_announcements_cron_secret' limit 1;
 if endpoint is null or secret is null then return; end if;
 perform net.http_post(url:=endpoint||'/functions/v1/process-private-chat',
 headers:=jsonb_build_object('Content-Type','application/json','x-pbh-cron-secret',secret),body:='{}'::jsonb,timeout_milliseconds:=10000);
end $$;
create function public.chat_queue_push() returns trigger language plpgsql security definer set search_path='' as $$
begin
 insert into public.chat_push_jobs(message_id) values(new.id) on conflict do nothing;
 perform public.chat_wake_worker(); return new;
end $$;
create trigger chat_message_push after insert on public.chat_messages for each row execute function public.chat_queue_push();
create function public.chat_queue_photo_cleanup() returns trigger language plpgsql security definer set search_path='' as $$
begin
 if old.image_path is not null then
  insert into public.chat_media_cleanup(path,owner_id,thread_id,not_before) values(old.image_path,old.sender_id,old.thread_id,now())
  on conflict(path) do update set not_before=least(public.chat_media_cleanup.not_before,now());
 end if;
 return old;
end $$;
create trigger chat_message_media_cleanup after delete on public.chat_messages for each row execute function public.chat_queue_photo_cleanup();

create function public.chat_claim_push() returns jsonb language plpgsql security definer set search_path='' as $$
declare job public.chat_push_jobs; item public.chat_messages; recipient uuid;
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
 update public.chat_push_jobs set state='processing',attempts=attempts+1,lease_id=gen_random_uuid(),lease_until=now()+interval '5 minutes' where message_id=job.message_id returning * into job;
 return jsonb_build_object('message_id',item.id,'thread_id',item.thread_id,'recipient_id',recipient,'lease_id',job.lease_id);
end $$;
create function public.chat_finish_push(p_message uuid,p_lease uuid,p_success boolean) returns void
language sql security definer set search_path='' as $$
 update public.chat_push_jobs set state=case when p_success then 'sent' when attempts>=5 then 'failed' else 'pending' end,
 retry_at=now()+make_interval(mins=>power(2,least(attempts,5))::integer),lease_until=null
 where message_id=p_message and lease_id=p_lease and state='processing';
$$;
create function public.chat_claim_cleanup() returns setof public.chat_media_cleanup
language sql security definer set search_path='' as $$
 update public.chat_media_cleanup q set claim_token=gen_random_uuid(),claimed_until=now()+interval '5 minutes'
 where path in(select x.path from public.chat_media_cleanup x where x.not_before<=now() and (x.claim_token is null or x.claimed_until<now())
 and not exists(select 1 from public.chat_messages m where m.image_path=x.path)
 order by x.not_before,x.path limit 30 for update skip locked) returning q.*;
$$;
create function public.chat_ack_cleanup(p_path text,p_claim uuid) returns void
language sql security definer set search_path='' as $$
 delete from public.chat_media_cleanup q where q.path=p_path and q.claim_token=p_claim
 and not exists(select 1 from public.chat_messages m where m.image_path=q.path);
$$;
create function public.chat_maintenance() returns integer language plpgsql security definer set search_path='' as $$
declare removed integer;
begin
 with expired as(select id from public.chat_messages where expires_at<=now() order by expires_at,id limit 1000 for update skip locked),
 deleted as(delete from public.chat_messages m using expired e where m.id=e.id returning m.id)
 select count(*)::integer into removed from deleted;
 perform public.chat_wake_worker(); return removed;
end $$;

revoke all on function public.chat_wake_worker(),public.chat_queue_push(),public.chat_queue_photo_cleanup(),public.chat_claim_push(),public.chat_finish_push(uuid,uuid,boolean),public.chat_claim_cleanup(),public.chat_ack_cleanup(text,uuid),public.chat_maintenance() from public,anon,authenticated;
grant execute on function public.chat_claim_push(),public.chat_finish_push(uuid,uuid,boolean),public.chat_claim_cleanup(),public.chat_ack_cleanup(text,uuid),public.chat_maintenance() to service_role;
select cron.schedule('pbh-private-chat-maintenance','* * * * *','select public.chat_maintenance()');
commit;
