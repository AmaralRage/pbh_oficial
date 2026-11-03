begin;
-- Keep original attachments; normalized rectangles apply only to feed previews.
alter table public.community_posts add column image_framings jsonb not null default '[]'::jsonb;
create function public.valid_community_image_framings(value jsonb) returns boolean
language plpgsql immutable set search_path='' as $$
declare item jsonb; x numeric; y numeric; w numeric; h numeric;
begin
  if jsonb_typeof(value)<>'array' or jsonb_array_length(value)>4 then return false; end if;
  for item in select * from jsonb_array_elements(value) loop
    if item='null'::jsonb then continue; end if;
    if jsonb_typeof(item)<>'array' or jsonb_array_length(item)<>4 then return false; end if;
    if exists(select 1 from jsonb_array_elements(item) n where jsonb_typeof(n)<>'number') then return false; end if;
    x:=(item->>0)::numeric; y:=(item->>1)::numeric;
    w:=(item->>2)::numeric; h:=(item->>3)::numeric;
    if x<0 or y<0 or w<=0 or h<=0 or x+w>1.001 or y+h>1.001 then return false; end if;
  end loop;
  return true;
exception when others then return false;
end $$;
alter table public.community_posts add constraint community_image_framings_valid check(public.valid_community_image_framings(image_framings));
grant insert(image_framings) on public.community_posts to authenticated;
create or replace view public.community_feed with(security_invoker=false) as
select p.id,p.user_id,
  case when coalesce(pr.is_public,true) then coalesce(nullif(pr.display_name,''),'Membro') else 'Membro' end as author_name,
  p.content,p.achievement_tag,p.created_at,
  (select count(*)::integer from public.community_post_likes l where l.post_id=p.id) as likes_count,
  (select count(*)::integer from public.community_comments c where c.post_id=p.id) as comments_count,
  exists(select 1 from public.community_post_likes l where l.post_id=p.id and l.user_id=(select auth.uid())) as liked_by_me,
  p.topic,case when coalesce(pr.is_public,true) then pr.avatar_url else null end as author_avatar_url,
  p.image_paths,p.edited_at,p.pinned_at,p.image_framings
from public.community_posts p left join public.profiles pr on pr.id=p.user_id
where not exists(select 1 from public.community_blocks b where
  (b.blocker_id=(select auth.uid()) and b.blocked_id=p.user_id) or
  (b.blocker_id=p.user_id and b.blocked_id=(select auth.uid())));
grant select on public.community_feed to anon,authenticated;

commit;
