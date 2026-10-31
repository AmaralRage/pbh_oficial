begin;

-- Only the public identity is returned. Private metadata and email stay private.
create function public.community_member_identities(p_ids uuid[])
returns table(user_id uuid,name text,avatar_url text,founder boolean)
language sql stable security definer set search_path='' as $$
  select p.id,
    case when p.id=(select auth.uid()) or coalesce(p.is_public,true)
      then left(coalesce(nullif(btrim(u.raw_user_meta_data->>'display_name'),''),nullif(p.display_name,''),'Membro'),40)
      else 'Membro' end,
    case when p.id=(select auth.uid()) or coalesce(p.is_public,true)
      then left(case when u.raw_user_meta_data ? 'avatar_url'
        then nullif(u.raw_user_meta_data->>'avatar_url','') else p.avatar_url end,2048)
      else null end,
    (p.id=(select auth.uid()) or coalesce(p.is_public,true))
      and lower(coalesce(u.email,''))='amaralaragao31@gmail.com' and u.email_confirmed_at is not null
  from public.profiles p join auth.users u on u.id=p.id
  where p.id in (select x from unnest(p_ids) x limit 100)
    and not exists(select 1 from public.community_blocks b where
      (b.blocker_id=(select auth.uid()) and b.blocked_id=p.id) or
      (b.blocker_id=p.id and b.blocked_id=(select auth.uid())));
$$;
revoke all on function public.community_member_identities(uuid[]) from public;
grant execute on function public.community_member_identities(uuid[]) to anon,authenticated;

create or replace function public.valid_community_photo_paths(p_owner uuid,p_id uuid,p_paths text[])
returns boolean language sql immutable set search_path='' as $$
  select p_owner is not null and p_id is not null and p_paths is not null
    and cardinality(p_paths)<=4 and cardinality(p_paths)=(select count(distinct x) from unnest(p_paths) x)
    and not exists(select 1 from unnest(p_paths) x where x is null or
      x !~ ('^'||p_owner::text||'/'||p_id::text||'/[0-3]\.(jpg|png|webp|gif|mp4|webm)$'));
$$;

create or replace function public.validate_community_photo_objects() returns trigger
language plpgsql security definer set search_path='' as $$
declare item text; info jsonb; ext text; expected text; cap bigint;
begin
  if not public.valid_community_photo_paths(new.user_id,new.id,new.image_paths) then
    raise exception 'Anexos inválidos.' using errcode='22023'; end if;
  foreach item in array new.image_paths loop
    select o.metadata into info from storage.objects o where o.bucket_id='community-photos' and o.name=item;
    if not found then raise exception 'Envie todos os anexos antes de publicar.' using errcode='22023'; end if;
    ext:=substring(item from '\.([a-z0-9]+)$');
    expected:=case when ext='jpg' then 'image/jpeg' when ext in ('mp4','webm') then 'video/'||ext else 'image/'||ext end;
    cap:=case when ext in ('mp4','webm') then 26214400 when ext='gif' then 10485760 else 5242880 end;
    if info->>'mimetype' is distinct from expected or coalesce((info->>'size')::bigint,0) not between 1 and cap then
      raise exception 'Formato ou tamanho de anexo inválido.' using errcode='22023'; end if;
  end loop;
  return new;
end $$;

update storage.buckets set file_size_limit=26214400,
  allowed_mime_types=array['image/jpeg','image/png','image/webp','image/gif','video/mp4','video/webm']
where id='community-photos';
commit;
