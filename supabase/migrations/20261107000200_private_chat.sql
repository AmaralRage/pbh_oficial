begin;
create table public.chat_threads(
 id uuid primary key default gen_random_uuid(),
 member_a uuid not null references auth.users(id) on delete cascade,
 member_b uuid not null references auth.users(id) on delete cascade,
 created_at timestamptz not null default now(),updated_at timestamptz not null default now(),
 read_a_at timestamptz not null default 'epoch',read_b_at timestamptz not null default 'epoch',messages_revision bigint not null default 0,
 unique(member_a,member_b),check(member_a<member_b)
);
create index chat_threads_a on public.chat_threads(member_a,updated_at desc,id);
create index chat_threads_b on public.chat_threads(member_b,updated_at desc,id);
create table public.chat_messages(
 id uuid primary key,thread_id uuid not null references public.chat_threads(id) on delete cascade,
 sender_id uuid not null references auth.users(id) on delete cascade,
 body text not null default '' check(length(body)<=2000),image_path text,
 reply_to uuid references public.chat_messages(id) on delete set null,
 created_at timestamptz not null default now(),expires_at timestamptz not null default now()+interval '7 days',
 check(length(btrim(body))>0 or image_path is not null)
);
create index chat_messages_thread_page on public.chat_messages(thread_id,created_at desc,id desc);
create index chat_messages_expiry on public.chat_messages(expires_at,id);
create index chat_messages_sender_rate on public.chat_messages(sender_id,created_at desc);
create unique index chat_messages_image on public.chat_messages(image_path) where image_path is not null;
-- Keep cleanup paths even if an account or thread is removed.
create table public.chat_media_cleanup(
 path text primary key,owner_id uuid not null,thread_id uuid not null,
 not_before timestamptz not null default now()+interval '15 minutes',
 claim_token uuid,claimed_until timestamptz
);
alter table public.chat_threads enable row level security;
alter table public.chat_messages enable row level security;
alter table public.chat_media_cleanup enable row level security;
revoke all on public.chat_threads,public.chat_messages,public.chat_media_cleanup from public,anon,authenticated;
grant select on public.chat_threads,public.chat_messages to authenticated;
grant all on public.chat_threads,public.chat_messages,public.chat_media_cleanup to service_role;

create function public.chat_has_access(p_thread uuid) returns boolean
language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.chat_threads t join auth.users u on u.id=auth.uid()
 where t.id=p_thread and u.email_confirmed_at is not null and auth.uid() in(t.member_a,t.member_b)
 and not exists(select 1 from public.community_blocks b where
 (b.blocker_id=t.member_a and b.blocked_id=t.member_b) or (b.blocker_id=t.member_b and b.blocked_id=t.member_a)));
$$;
revoke all on function public.chat_has_access(uuid) from public,anon;
grant execute on function public.chat_has_access(uuid) to authenticated;
create policy chat_thread_participants on public.chat_threads for select to authenticated using(public.chat_has_access(id));
create policy chat_message_participants on public.chat_messages for select to authenticated
 using(expires_at>now() and public.chat_has_access(thread_id));

create function public.chat_open(p_member uuid) returns uuid
language plpgsql security definer set search_path='' as $$
declare viewer uuid:=auth.uid(); a uuid; b uuid; result uuid;
begin
 if viewer is null or not exists(select 1 from auth.users where id=viewer and email_confirmed_at is not null) then raise exception 'Entre em uma conta confirmada.' using errcode='42501'; end if;
 if p_member is null or p_member=viewer then raise exception 'Escolha outro membro.' using errcode='22023'; end if;
 if not exists(select 1 from auth.users u join public.profiles p on p.id=u.id where u.id=p_member and u.email_confirmed_at is not null and coalesce(p.is_public,true)) then raise exception 'Membro indisponível.' using errcode='42501'; end if;
 if exists(select 1 from public.community_blocks where (blocker_id=viewer and blocked_id=p_member) or (blocker_id=p_member and blocked_id=viewer)) then raise exception 'Conversa indisponível.' using errcode='42501'; end if;
 a:=least(viewer,p_member); b:=greatest(viewer,p_member);
 perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(viewer::text,110702));
 select id into result from public.chat_threads where member_a=a and member_b=b;
 if found then return result; end if;
 if (select count(*) from public.chat_threads where viewer in(member_a,member_b) and created_at>now()-interval '1 day')>=20 then raise exception 'Limite de novas conversas atingido. Tente amanhã.'; end if;
 insert into public.chat_threads(member_a,member_b) values(a,b) on conflict(member_a,member_b) do nothing returning id into result;
 if result is null then select id into result from public.chat_threads where member_a=a and member_b=b; end if;
 return result;
end $$;

create function public.chat_inbox(p_before timestamptz default null,p_before_id uuid default null,p_thread uuid default null,p_query text default '')
returns table(thread_id uuid,peer_id uuid,name text,avatar_url text,handle text,last_body text,last_image boolean,last_at timestamptz,last_sender uuid,unread integer,peer_read_at timestamptz,activity_at timestamptz)
language sql stable security definer set search_path='' as $$
 select t.id,u.id,
 case when coalesce(p.is_public,true) then left(coalesce(nullif(btrim(u.raw_user_meta_data->>'display_name'),''),nullif(p.display_name,''),'Membro'),40) else 'Membro' end,
 case when coalesce(p.is_public,true) then left(case when u.raw_user_meta_data ? 'avatar_url' then nullif(u.raw_user_meta_data->>'avatar_url','') else p.avatar_url end,2048) end,
 case when coalesce(p.is_public,true) then h.handle end,
 m.body,coalesce(m.image_path is not null,false),coalesce(m.created_at,t.updated_at),m.sender_id,
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
create function public.chat_messages_page(p_thread uuid,p_before timestamptz default null,p_before_id uuid default null)
returns setof public.chat_messages language sql stable security invoker set search_path='' as $$
 select * from public.chat_messages where thread_id=p_thread and expires_at>now()
 and (p_before is null or (created_at,id)<(p_before,p_before_id))
 order by created_at desc,id desc limit 40;
$$;
create function public.chat_unread_count() returns integer language sql stable security definer set search_path='' as $$
 select count(*)::integer from public.chat_messages m join public.chat_threads t on t.id=m.thread_id
 where m.expires_at>now() and m.sender_id<>auth.uid() and public.chat_has_access(t.id)
 and m.created_at>case when auth.uid()=t.member_a then t.read_a_at else t.read_b_at end;
$$;

create function public.chat_prepare_image(p_thread uuid,p_message uuid) returns text
language plpgsql security definer set search_path='' as $$
declare image text;
begin
 if not public.chat_has_access(p_thread) then raise exception 'Conversa indisponível.' using errcode='42501'; end if;
 if p_message is null then raise exception 'Anexo inválido.'; end if;
 perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(auth.uid()::text,110703));
 if exists(select 1 from public.chat_messages where id=p_message) then raise exception 'Mensagem já enviada.'; end if;
 if (select count(*) from public.chat_media_cleanup where owner_id=auth.uid() and not_before>now())>=5 then raise exception 'Conclua os anexos anteriores antes de enviar mais fotos.'; end if;
 image:=auth.uid()::text||'/'||p_thread::text||'/'||p_message::text||'.jpg';
 insert into public.chat_media_cleanup(path,owner_id,thread_id) values(image,auth.uid(),p_thread)
 on conflict(path) do update set not_before=now()+interval '15 minutes'
 where public.chat_media_cleanup.owner_id=auth.uid() and public.chat_media_cleanup.claim_token is null;
 if not found then raise exception 'Anexo expirado. Escolha a foto novamente.'; end if;
 return image;
end $$;
create function public.chat_image_upload_allowed(p_path text) returns boolean
language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.chat_media_cleanup q where q.path=p_path and q.owner_id=auth.uid()
 and q.not_before>now() and q.claim_token is null and public.chat_has_access(q.thread_id));
$$;

create function public.chat_send(p_thread uuid,p_id uuid,p_body text default '',p_image text default null,p_reply uuid default null) returns uuid
language plpgsql security definer set search_path='' as $$
declare existing public.chat_messages; reservation public.chat_media_cleanup;
begin
 if not public.chat_has_access(p_thread) then raise exception 'Conversa indisponível.' using errcode='42501'; end if;
 if p_id is null or p_body is null or length(p_body)>2000 or (length(btrim(p_body))=0 and p_image is null) then raise exception 'Revise sua mensagem.' using errcode='22023'; end if;
 perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(auth.uid()::text,110704));
 select * into existing from public.chat_messages where id=p_id;
 if found then
  if existing.sender_id=auth.uid() and existing.thread_id=p_thread and existing.body=btrim(p_body) and existing.image_path is not distinct from p_image and existing.reply_to is not distinct from p_reply and existing.expires_at>now() then return existing.id; end if;
  raise exception 'Identificador de mensagem indisponível.' using errcode='40001';
 end if;
 if (select count(*) from public.chat_messages where sender_id=auth.uid() and created_at>now()-interval '1 minute')>=30 then raise exception 'Aguarde um pouco antes de enviar mais mensagens.'; end if;
 if p_reply is not null and not exists(select 1 from public.chat_messages where id=p_reply and thread_id=p_thread and expires_at>now()) then raise exception 'A mensagem respondida expirou.'; end if;
 if p_image is not null then
  select * into reservation from public.chat_media_cleanup where path=p_image for update;
  if not found or reservation.owner_id<>auth.uid() or reservation.thread_id<>p_thread or reservation.claim_token is not null or reservation.not_before<=now()
    or p_image<>auth.uid()::text||'/'||p_thread::text||'/'||p_id::text||'.jpg'
    or not exists(select 1 from storage.objects where bucket_id='chat-photos' and name=p_image) then raise exception 'Anexo indisponível. Escolha a foto novamente.'; end if;
 end if;
 insert into public.chat_messages(id,thread_id,sender_id,body,image_path,reply_to) values(p_id,p_thread,auth.uid(),btrim(p_body),p_image,p_reply);
 if p_image is not null then delete from public.chat_media_cleanup where path=p_image; end if;
 update public.chat_threads set updated_at=clock_timestamp() where id=p_thread;
 return p_id;
end $$;

create function public.chat_mark_read(p_thread uuid,p_through uuid) returns void
language plpgsql security definer set search_path='' as $$
declare stamp timestamptz;
begin
 if not public.chat_has_access(p_thread) then raise exception 'Conversa indisponível.' using errcode='42501'; end if;
 select created_at into stamp from public.chat_messages where id=p_through and thread_id=p_thread and expires_at>now();
 if stamp is null then return; end if;
 update public.chat_threads set read_a_at=case when member_a=auth.uid() then greatest(read_a_at,stamp) else read_a_at end,
 read_b_at=case when member_b=auth.uid() then greatest(read_b_at,stamp) else read_b_at end
 where id=p_thread and (case when member_a=auth.uid() then read_a_at else read_b_at end)<stamp;
end $$;
create function public.chat_delete_message(p_id uuid) returns void language plpgsql security definer set search_path='' as $$
declare thread uuid;
begin
 select thread_id into thread from public.chat_messages where id=p_id and sender_id=auth.uid();
 if thread is null or not public.chat_has_access(thread) then raise exception 'Mensagem indisponível.' using errcode='42501'; end if;
 delete from public.chat_messages where id=p_id;
 update public.chat_threads set updated_at=clock_timestamp(),messages_revision=messages_revision+1 where id=thread;
end $$;

revoke all on function public.chat_open(uuid),public.chat_inbox(timestamptz,uuid,uuid,text),public.chat_messages_page(uuid,timestamptz,uuid),public.chat_unread_count(),public.chat_prepare_image(uuid,uuid),public.chat_image_upload_allowed(text),public.chat_send(uuid,uuid,text,text,uuid),public.chat_mark_read(uuid,uuid),public.chat_delete_message(uuid) from public,anon;
grant execute on function public.chat_open(uuid),public.chat_inbox(timestamptz,uuid,uuid,text),public.chat_messages_page(uuid,timestamptz,uuid),public.chat_unread_count(),public.chat_prepare_image(uuid,uuid),public.chat_image_upload_allowed(text),public.chat_send(uuid,uuid,text,text,uuid),public.chat_mark_read(uuid,uuid),public.chat_delete_message(uuid) to authenticated;

insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types) values('chat-photos','chat-photos',false,524288,array['image/jpeg'])
on conflict(id) do update set public=false,file_size_limit=excluded.file_size_limit,allowed_mime_types=excluded.allowed_mime_types;
create policy chat_photo_upload on storage.objects for insert to authenticated
 with check(bucket_id='chat-photos' and public.chat_image_upload_allowed(name));
create policy chat_photo_read on storage.objects for select to authenticated
 using(bucket_id='chat-photos' and (public.chat_image_upload_allowed(name) or exists(select 1 from public.chat_messages m where m.image_path=name and m.expires_at>now() and public.chat_has_access(m.thread_id))));

-- INSERT/UPDATE subscriptions only; clients never subscribe to DELETE events.
do $$ begin
 if exists(select 1 from pg_publication where pubname='supabase_realtime') then
  alter publication supabase_realtime add table public.chat_threads,public.chat_messages;
 end if;
end $$;
commit;
