begin;

-- HTML is stored as inert text and rendered only in the isolated artwork viewer.
create or replace function public.valid_community_photo_paths(p_owner uuid,p_id uuid,p_paths text[])
returns boolean language sql immutable set search_path='' as $$
  select p_owner is not null and p_id is not null and p_paths is not null
    and cardinality(p_paths)<=4 and cardinality(p_paths)=(select count(distinct x) from unnest(p_paths) x)
    and not exists(select 1 from unnest(p_paths) x where x is null or
      x !~ ('^'||p_owner::text||'/'||p_id::text||'/[0-3]\.(jpg|png|webp|gif|mp4|webm|html)$'));
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
    expected:=case when ext='html' then 'text/plain' when ext='jpg' then 'image/jpeg' when ext in ('mp4','webm') then 'video/'||ext else 'image/'||ext end;
    cap:=case when ext in ('mp4','webm') then 26214400 when ext='gif' then 10485760 else 5242880 end;
    if info->>'mimetype' is distinct from expected or coalesce((info->>'size')::bigint,0) not between 1 and cap then
      raise exception 'Formato ou tamanho de anexo inválido.' using errcode='22023'; end if;
  end loop;
  return new;
end $$;

update storage.buckets set file_size_limit=26214400,
  allowed_mime_types=array['image/jpeg','image/png','image/webp','image/gif','video/mp4','video/webm','text/plain']
where id='community-photos';
commit;
