begin;
create trigger guard_community_post_edit before update of content,image_paths,image_framings on public.community_posts
 for each row execute function public.guard_community_participation();
-- Revision suffixes let edits upload new files without overwriting originals.
create or replace function public.valid_community_photo_paths(p_owner uuid,p_id uuid,p_paths text[])
returns boolean language sql immutable set search_path='' as $$
 select p_owner is not null and p_id is not null and p_paths is not null
 and cardinality(p_paths)<=4 and cardinality(p_paths)=(select count(distinct x) from unnest(p_paths)x)
 and not exists(select 1 from unnest(p_paths)x where x is null or x !~
 ('^'||p_owner::text||'/'||p_id::text||'/[0-3](_[0-9a-f]{32})?\.(jpg|png|webp|gif|mp4|webm|html)$'));
$$;
create function public.prepare_community_post_edit(p_id uuid,p_paths text[]) returns void
language plpgsql security definer set search_path='' as $$
begin
 if auth.uid() is null or not exists(select 1 from public.community_posts where id=p_id and user_id=auth.uid()) then raise exception 'Publicação indisponível.' using errcode='42501'; end if;
 if not public.valid_community_photo_paths(auth.uid(),p_id,p_paths) or cardinality(p_paths)=0 then raise exception 'Anexos inválidos.'; end if;
 insert into public.community_photo_cleanup(post_id,user_id,paths,not_before) values(p_id,auth.uid(),p_paths,now()+interval '15 minutes')
 on conflict(post_id) do update set paths=(select array_agg(distinct x) from unnest(public.community_photo_cleanup.paths||excluded.paths)x),not_before=excluded.not_before
 where public.community_photo_cleanup.user_id=auth.uid();
 if not found then raise exception 'Reserva indisponível.' using errcode='42501'; end if;
end $$;
create function public.edit_community_publication(p_id uuid,p_expected jsonb,p_content text,p_paths text[],p_framings jsonb) returns void
language plpgsql security definer set search_path='' as $$
declare item public.community_posts;
begin
 if auth.uid() is null then raise exception 'Entre na sua conta.' using errcode='42501'; end if;
 select * into item from public.community_posts where id=p_id and user_id=auth.uid() for update;
 if not found then raise exception 'Publicação indisponível.' using errcode='42501'; end if;
 if exists(select 1 from public.community_restrictions where user_id=auth.uid() and until_at>now()) then raise exception 'Sua participação está temporariamente restrita.' using errcode='42501'; end if;
 if jsonb_build_object('content',item.content,'paths',to_jsonb(item.image_paths),'framings',item.image_framings) is distinct from p_expected then raise exception 'A publicação mudou. Reabra o editor antes de salvar.' using errcode='40001'; end if;
 if p_content is null or length(btrim(p_content)) not between 1 and 2000 or not public.valid_community_photo_paths(auth.uid(),p_id,p_paths)
 or p_framings is null or not public.valid_community_image_framings(p_framings) or jsonb_array_length(p_framings)>cardinality(p_paths) then raise exception 'Revise o texto e os anexos.' using errcode='22023'; end if;
 update public.community_posts set content=btrim(p_content),image_paths=p_paths,image_framings=p_framings,edited_at=now() where id=p_id;
end $$;
create function public.track_community_edited_media() returns trigger
language plpgsql security definer set search_path='' as $$
declare removed text[];
begin
 removed:=array(select x from unnest(old.image_paths)x where not(x=any(new.image_paths)));
 if cardinality(removed)>0 then
 insert into public.community_photo_cleanup(post_id,user_id,paths,not_before) values(new.id,new.user_id,removed,now())
 on conflict(post_id) do update set paths=(select array_agg(distinct x) from unnest(public.community_photo_cleanup.paths||excluded.paths)x);
 end if;
 update public.community_photo_cleanup q set paths=array(select x from unnest(q.paths)x where not(x=any(new.image_paths))) where post_id=new.id and user_id=new.user_id;
 delete from public.community_photo_cleanup where post_id=new.id and cardinality(paths)=0;
 return new;
end $$;
revoke all on function public.track_community_edited_media() from public,anon,authenticated;
create trigger track_community_edited_media after update of image_paths on public.community_posts for each row execute function public.track_community_edited_media();
revoke all on function public.prepare_community_post_edit(uuid,text[]),public.edit_community_publication(uuid,jsonb,text,text[],jsonb) from public,anon;
grant execute on function public.prepare_community_post_edit(uuid,text[]),public.edit_community_publication(uuid,jsonb,text,text[],jsonb) to authenticated;
commit;
