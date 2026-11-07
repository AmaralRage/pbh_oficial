begin;
alter table public.chat_messages add column audio_path text, add column audio_duration_ms integer, add column audio_format text;
alter table public.chat_messages drop constraint chat_messages_check;
alter table public.chat_messages add constraint chat_messages_content check(length(btrim(body))>0 or image_path is not null or audio_path is not null);
alter table public.chat_messages add constraint chat_messages_audio_valid check(
 (audio_path is null and audio_duration_ms is null and audio_format is null) or
 (audio_path is not null and audio_duration_ms is not null and audio_format is not null and audio_duration_ms between 1 and 120000 and audio_format in ('m4a','webm') and image_path is null and body=''));
create unique index chat_messages_audio on public.chat_messages(audio_path) where audio_path is not null;
alter table public.chat_media_cleanup add column bucket text not null default 'chat-photos' check(bucket in('chat-photos','chat-audio')),
 add column audio_format text,add column validated_duration_ms integer,add column validated_size integer;

create function public.chat_prepare_audio(p_thread uuid,p_message uuid,p_format text) returns text
language plpgsql security definer set search_path='' as $$
declare result_path text;
begin
 if not public.chat_has_access(p_thread) then raise exception 'Conversa indisponível.' using errcode='42501'; end if;
 if p_message is null or p_format is null or p_format not in('m4a','webm') then raise exception 'Áudio inválido.' using errcode='22023'; end if;
 perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(auth.uid()::text,110703));
 if exists(select 1 from public.chat_messages where id=p_message) then raise exception 'Mensagem já enviada.'; end if;
 result_path:=auth.uid()::text||'/'||p_thread::text||'/'||p_message::text||'.'||p_format;
 if not exists(select 1 from public.chat_media_cleanup q where q.path=result_path and q.owner_id=auth.uid() and q.claim_token is null)
 and (select count(*) from public.chat_media_cleanup where owner_id=auth.uid() and not_before>now())>=5 then raise exception 'Conclua os anexos anteriores.'; end if;
 insert into public.chat_media_cleanup(path,owner_id,thread_id,bucket,audio_format) values(result_path,auth.uid(),p_thread,'chat-audio',p_format)
 on conflict(path) do update set not_before=now()+interval '15 minutes'
 where public.chat_media_cleanup.owner_id=auth.uid() and public.chat_media_cleanup.claim_token is null;
 if not found then raise exception 'Anexo expirado. Grave novamente.'; end if;
 return result_path;
end $$;
create function public.chat_audio_upload_allowed(p_path text) returns boolean
language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.chat_media_cleanup q where q.path=p_path and q.bucket='chat-audio' and q.owner_id=auth.uid()
 and q.not_before>now() and q.claim_token is null and public.chat_has_access(q.thread_id));
$$;
create or replace function public.chat_image_upload_allowed(p_path text) returns boolean
language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.chat_media_cleanup q where q.path=p_path and q.bucket='chat-photos' and q.owner_id=auth.uid()
 and q.not_before>now() and q.claim_token is null and public.chat_has_access(q.thread_id));
$$;

-- Only the server validator can attest to the actual file's duration and size.
create function public.chat_verify_audio(p_owner uuid,p_path text,p_duration integer,p_size integer,p_format text) returns void
language plpgsql security definer set search_path='' as $$
begin
 if p_duration is null or p_duration not between 1 and 120000 or p_size is null or p_size not between 1 and 1048576 then raise exception 'Áudio deve ter até dois minutos e 1 MB.' using errcode='22023'; end if;
 update public.chat_media_cleanup q set validated_duration_ms=p_duration,validated_size=p_size
 where q.path=p_path and q.owner_id=p_owner and q.bucket='chat-audio' and q.audio_format=p_format and q.not_before>now() and q.claim_token is null
 and exists(select 1 from public.chat_threads t where t.id=q.thread_id and p_owner in(t.member_a,t.member_b)
 and not exists(select 1 from public.community_blocks b where (b.blocker_id=t.member_a and b.blocked_id=t.member_b) or (b.blocker_id=t.member_b and b.blocked_id=t.member_a)));
 if not found then raise exception 'Anexo indisponível.' using errcode='42501'; end if;
end $$;

create function public.chat_send_audio(p_thread uuid,p_id uuid,p_audio text,p_reply uuid default null) returns uuid
language plpgsql security definer set search_path='' as $$
declare existing public.chat_messages; reservation public.chat_media_cleanup;
begin
 if not public.chat_has_access(p_thread) then raise exception 'Conversa indisponível.' using errcode='42501'; end if;
 if p_id is null or p_audio is null then raise exception 'Revise o áudio.' using errcode='22023'; end if;
 perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(auth.uid()::text,110704));
 select * into existing from public.chat_messages where id=p_id;
 if found then
  if existing.sender_id=auth.uid() and existing.thread_id=p_thread and existing.audio_path=p_audio and existing.reply_to is not distinct from p_reply and existing.expires_at>now() then return existing.id; end if;
  raise exception 'Identificador de mensagem indisponível.' using errcode='40001';
 end if;
 if (select count(*) from public.chat_messages where sender_id=auth.uid() and created_at>now()-interval '1 minute')>=30 then raise exception 'Aguarde antes de enviar mais mensagens.'; end if;
 if p_reply is not null and not exists(select 1 from public.chat_messages where id=p_reply and thread_id=p_thread and expires_at>now()) then raise exception 'A mensagem respondida expirou.'; end if;
 select * into reservation from public.chat_media_cleanup where path=p_audio for update;
 if not found or reservation.owner_id<>auth.uid() or reservation.thread_id<>p_thread or reservation.bucket<>'chat-audio' or reservation.claim_token is not null or reservation.not_before<=now()
 or reservation.validated_duration_ms is null or reservation.validated_size is null
 or p_audio<>auth.uid()::text||'/'||p_thread::text||'/'||p_id::text||'.'||reservation.audio_format
 or not exists(select 1 from storage.objects where bucket_id='chat-audio' and name=p_audio) then raise exception 'Áudio indisponível ou não validado.' using errcode='22023'; end if;
 insert into public.chat_messages(id,thread_id,sender_id,audio_path,audio_duration_ms,audio_format,reply_to)
 values(p_id,p_thread,auth.uid(),p_audio,reservation.validated_duration_ms,reservation.audio_format,p_reply);
 delete from public.chat_media_cleanup where path=p_audio;
 update public.chat_threads set updated_at=clock_timestamp() where id=p_thread;
 return p_id;
end $$;

create or replace function public.chat_queue_photo_cleanup() returns trigger language plpgsql security definer set search_path='' as $$
begin
 if old.image_path is not null then
  insert into public.chat_media_cleanup(path,owner_id,thread_id,not_before,bucket) values(old.image_path,old.sender_id,old.thread_id,now(),'chat-photos')
  on conflict(path) do update set not_before=least(public.chat_media_cleanup.not_before,now());
 end if;
 if old.audio_path is not null then
  insert into public.chat_media_cleanup(path,owner_id,thread_id,not_before,bucket) values(old.audio_path,old.sender_id,old.thread_id,now(),'chat-audio')
  on conflict(path) do update set not_before=least(public.chat_media_cleanup.not_before,now());
 end if;
 return old;
end $$;
create or replace function public.chat_claim_cleanup() returns setof public.chat_media_cleanup
language sql security definer set search_path='' as $$
 update public.chat_media_cleanup q set claim_token=gen_random_uuid(),claimed_until=now()+interval '5 minutes'
 where path in(select x.path from public.chat_media_cleanup x where x.not_before<=now() and (x.claim_token is null or x.claimed_until<now())
 and not exists(select 1 from public.chat_messages m where m.image_path=x.path or m.audio_path=x.path)
 order by x.not_before,x.path limit 30 for update skip locked) returning q.*;
$$;
create or replace function public.chat_ack_cleanup(p_path text,p_claim uuid) returns void
language sql security definer set search_path='' as $$
 delete from public.chat_media_cleanup q where q.path=p_path and q.claim_token=p_claim
 and not exists(select 1 from public.chat_messages m where m.image_path=q.path or m.audio_path=q.path);
$$;
revoke all on function public.chat_prepare_audio(uuid,uuid,text),public.chat_audio_upload_allowed(text),public.chat_send_audio(uuid,uuid,text,uuid),public.chat_verify_audio(uuid,text,integer,integer,text) from public,anon,authenticated;
grant execute on function public.chat_prepare_audio(uuid,uuid,text),public.chat_audio_upload_allowed(text),public.chat_send_audio(uuid,uuid,text,uuid) to authenticated;
grant execute on function public.chat_verify_audio(uuid,text,integer,integer,text) to service_role;
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types) values('chat-audio','chat-audio',false,1048576,array['audio/mp4','audio/webm']);
create policy chat_audio_upload on storage.objects for insert to authenticated
 with check(bucket_id='chat-audio' and public.chat_audio_upload_allowed(name));
create policy chat_audio_read on storage.objects for select to authenticated
 using(bucket_id='chat-audio' and (public.chat_audio_upload_allowed(name) or exists(select 1 from public.chat_messages m where m.audio_path=name and m.expires_at>now() and public.chat_has_access(m.thread_id))));
create or replace function public.chat_inbox(p_before timestamptz default null,p_before_id uuid default null,p_thread uuid default null,p_query text default '')
returns table(thread_id uuid,peer_id uuid,name text,avatar_url text,handle text,last_body text,last_image boolean,last_at timestamptz,last_sender uuid,unread integer,peer_read_at timestamptz,activity_at timestamptz)
language sql stable security definer set search_path='' as $$
 select t.id,u.id,
 case when coalesce(p.is_public,true) then left(coalesce(nullif(btrim(u.raw_user_meta_data->>'display_name'),''),nullif(p.display_name,''),'Membro'),40) else 'Membro' end,
 case when coalesce(p.is_public,true) then left(case when u.raw_user_meta_data ? 'avatar_url' then nullif(u.raw_user_meta_data->>'avatar_url','') else p.avatar_url end,2048) end,
 case when coalesce(p.is_public,true) then h.handle end,
 case when m.audio_path is not null then '🎤 Áudio' else m.body end,coalesce(m.image_path is not null,false),coalesce(m.created_at,t.updated_at),m.sender_id,
 (select count(*)::integer from public.chat_messages x where x.thread_id=t.id and x.sender_id<>auth.uid() and x.expires_at>now() and x.created_at>case when auth.uid()=t.member_a then t.read_a_at else t.read_b_at end),
 case when auth.uid()=t.member_a then t.read_b_at else t.read_a_at end,t.updated_at
 from public.chat_threads t join auth.users u on u.id=case when auth.uid()=t.member_a then t.member_b else t.member_a end
 join public.profiles p on p.id=u.id left join public.member_handles h on h.user_id=u.id
 left join lateral(select * from public.chat_messages x where x.thread_id=t.id and x.expires_at>now() order by x.created_at desc,x.id desc limit 1) m on true
 where public.chat_has_access(t.id) and (p_thread is null or t.id=p_thread) and (p_before is null or (t.updated_at,t.id)<(p_before,p_before_id))
 and (coalesce(btrim(p_query),'')='' or strpos(lower(case when coalesce(p.is_public,true) then coalesce(nullif(btrim(u.raw_user_meta_data->>'display_name'),''),nullif(p.display_name,''),'Membro') else 'Membro' end),lower(left(btrim(p_query),100)))>0
 or (coalesce(p.is_public,true) and strpos(lower(coalesce(h.handle,'')),lower(left(ltrim(btrim(p_query),'@'),100)))>0))
 order by t.updated_at desc,t.id desc limit 30;
$$;
commit;
