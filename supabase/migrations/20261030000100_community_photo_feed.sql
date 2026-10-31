begin;

alter table public.community_posts add column image_paths text[] not null default '{}';
create function public.valid_community_photo_paths(p_owner uuid,p_id uuid,p_paths text[])
returns boolean language sql immutable set search_path='' as $$
  select p_owner is not null and p_id is not null and p_paths is not null
    and cardinality(p_paths)<=4 and cardinality(p_paths)=(select count(distinct x) from unnest(p_paths) x)
    and not exists(select 1 from unnest(p_paths) x where x is null or
      x !~ ('^'||p_owner::text||'/'||p_id::text||'/[0-3]\.(jpg|png|webp)$'));
$$;
revoke all on function public.valid_community_photo_paths(uuid,uuid,text[]) from public;
grant execute on function public.valid_community_photo_paths(uuid,uuid,text[]) to anon,authenticated;
alter table public.community_posts add constraint community_photo_paths_check
  check(public.valid_community_photo_paths(user_id,id,image_paths));
grant insert(id,image_paths) on public.community_posts to authenticated;
grant select on public.community_posts to authenticated;
drop policy if exists "Community posts are public" on public.community_posts;
create policy "Members read own posts for media management" on public.community_posts
  for select to authenticated using(user_id=(select auth.uid()));

-- Upload reservations also retain unfinished files after a crash or failed send.
create table public.community_photo_cleanup(
  -- Retain the owner UUID for cleanup even if the account itself is removed.
  post_id uuid primary key,user_id uuid not null,
  paths text[] not null,not_before timestamptz not null default now()+interval '15 minutes'
);
alter table public.community_photo_cleanup enable row level security;
revoke all on public.community_photo_cleanup from public,anon,authenticated;
grant select on public.community_photo_cleanup to authenticated;
create policy "Owners and admins inspect photo cleanup" on public.community_photo_cleanup
  for select to authenticated using(user_id=(select auth.uid()) or (select public.is_admin()));

create function public.prepare_community_photos(p_id uuid,p_paths text[]) returns void
language plpgsql security definer set search_path='' as $$
declare member uuid:=(select auth.uid());
begin
  if member is null or not exists(select 1 from auth.users where id=member) then
    raise exception 'Entre na sua conta.' using errcode='42501'; end if;
  if not public.valid_community_photo_paths(member,p_id,p_paths) or cardinality(p_paths)=0 then
    raise exception 'Escolha até quatro fotos válidas.' using errcode='22023'; end if;
  if exists(select 1 from public.community_posts where id=p_id) then
    raise exception 'Esta publicação já foi enviada.' using errcode='40001'; end if;
  insert into public.community_photo_cleanup(post_id,user_id,paths) values(p_id,member,p_paths)
    on conflict(post_id) do update set
      paths=(select array_agg(distinct x) from unnest(public.community_photo_cleanup.paths||excluded.paths) x),
      not_before=now()+interval '15 minutes'
    where public.community_photo_cleanup.user_id=member;
  if not found then raise exception 'Reserva indisponível.' using errcode='42501'; end if;
end $$;
revoke all on function public.prepare_community_photos(uuid,text[]) from public,anon;
grant execute on function public.prepare_community_photos(uuid,text[]) to authenticated;

create function public.validate_community_photo_objects() returns trigger
language plpgsql security definer set search_path='' as $$
begin
  if not public.valid_community_photo_paths(new.user_id,new.id,new.image_paths) then
    raise exception 'Fotos inválidas.' using errcode='22023'; end if;
  if exists(select 1 from unnest(new.image_paths) path where not exists(
    select 1 from storage.objects o where o.bucket_id='community-photos' and o.name=path)) then
    raise exception 'Envie todas as fotos antes de publicar.' using errcode='22023'; end if;
  return new;
end $$;
revoke all on function public.validate_community_photo_objects() from public,anon,authenticated;
create trigger validate_community_photo_objects before insert or update of image_paths,user_id,id
  on public.community_posts for each row execute function public.validate_community_photo_objects();

create function public.track_community_photo_cleanup() returns trigger
language plpgsql security definer set search_path='' as $$
begin
  if tg_op='DELETE' then
    if cardinality(old.image_paths)>0 then
      insert into public.community_photo_cleanup(post_id,user_id,paths,not_before)
        values(old.id,old.user_id,old.image_paths,now()) on conflict(post_id)
        do update set paths=(select array_agg(distinct x) from
          unnest(public.community_photo_cleanup.paths||excluded.paths) x),not_before=now();
    end if;
    return old;
  end if;
  update public.community_photo_cleanup q set
    paths=array(select x from unnest(q.paths) x where not(x=any(new.image_paths))),not_before=now()
    where post_id=new.id and user_id=new.user_id;
  delete from public.community_photo_cleanup where post_id=new.id and cardinality(paths)=0;
  return new;
end $$;
revoke all on function public.track_community_photo_cleanup() from public,anon,authenticated;
create trigger track_community_photo_cleanup after insert or delete on public.community_posts
  for each row execute function public.track_community_photo_cleanup();

create function public.ack_community_photo_cleanup(p_id uuid) returns void
language plpgsql security definer set search_path='' as $$
begin
  delete from public.community_photo_cleanup q where q.post_id=p_id and q.not_before<=now()
    and (q.user_id=(select auth.uid()) or public.is_admin())
    and not exists(select 1 from storage.objects o where o.bucket_id='community-photos' and o.name=any(q.paths));
end $$;
revoke all on function public.ack_community_photo_cleanup(uuid) from public,anon;
grant execute on function public.ack_community_photo_cleanup(uuid) to authenticated;

create function public.pending_community_photo_cleanup() returns setof public.community_photo_cleanup
language sql stable security definer set search_path='' as $$
  select q.* from public.community_photo_cleanup q where q.not_before<=now()
    and (q.user_id=(select auth.uid()) or public.is_admin())
    order by q.not_before,q.post_id limit 10;
$$;
revoke all on function public.pending_community_photo_cleanup() from public,anon;
grant execute on function public.pending_community_photo_cleanup() to authenticated;

insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
  values('community-photos','community-photos',false,2097152,array['image/jpeg','image/png','image/webp'])
  on conflict(id) do update set public=false,file_size_limit=excluded.file_size_limit,
    allowed_mime_types=excluded.allowed_mime_types;
create function public.can_read_community_photo(p_name text) returns boolean
language sql stable security definer set search_path='' as $$
  select split_part(p_name,'/',1)=(select auth.uid())::text or exists(
    select 1 from public.community_posts p where p_name=any(p.image_paths) and not exists(
      select 1 from public.community_blocks b where
        (b.blocker_id=(select auth.uid()) and b.blocked_id=p.user_id) or
        (b.blocker_id=p.user_id and b.blocked_id=(select auth.uid()))))
    or (public.is_admin() and exists(select 1 from public.community_photo_cleanup q
      where p_name=any(q.paths) and q.not_before<=now()));
$$;
revoke all on function public.can_read_community_photo(text) from public;
grant execute on function public.can_read_community_photo(text) to anon,authenticated;
create policy "Community photos readable with post visibility" on storage.objects
  for select to anon,authenticated using(bucket_id='community-photos' and public.can_read_community_photo(name));
create policy "Members upload reserved community photos" on storage.objects
  for insert to authenticated with check(bucket_id='community-photos' and exists(
    select 1 from public.community_photo_cleanup q where q.user_id=(select auth.uid())
      and name=any(q.paths) and q.not_before>now()));
create policy "Owners or cleanup admins delete community photos" on storage.objects
  for delete to authenticated using(bucket_id='community-photos'
    and not exists(select 1 from public.community_posts p where name=any(p.image_paths)) and (
    split_part(name,'/',1)=(select auth.uid())::text or (public.is_admin() and exists(
      select 1 from public.community_photo_cleanup q where name=any(q.paths) and q.not_before<=now()))));

-- Append the new column without changing existing clients' column order.
create or replace view public.community_feed with(security_invoker=false) as
select p.id,p.user_id,
  case when coalesce(pr.is_public,true) then coalesce(nullif(pr.display_name,''),'Membro') else 'Membro' end as author_name,
  p.content,p.achievement_tag,p.created_at,
  (select count(*)::integer from public.community_post_likes l where l.post_id=p.id) as likes_count,
  (select count(*)::integer from public.community_comments c where c.post_id=p.id) as comments_count,
  exists(select 1 from public.community_post_likes l where l.post_id=p.id and l.user_id=(select auth.uid())) as liked_by_me,
  p.topic,case when coalesce(pr.is_public,true) then pr.avatar_url else null end as author_avatar_url,
  p.image_paths
from public.community_posts p left join public.profiles pr on pr.id=p.user_id
where not exists(select 1 from public.community_blocks b where
  (b.blocker_id=(select auth.uid()) and b.blocked_id=p.user_id) or
  (b.blocker_id=p.user_id and b.blocked_id=(select auth.uid())));
grant select on public.community_feed to anon,authenticated;
commit;
