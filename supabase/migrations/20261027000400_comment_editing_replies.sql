begin;
alter table public.community_comments add column edited_at timestamptz,
  add column reply_to_id uuid references public.community_comments(id) on delete set null;
alter table public.community_sample_comments add column edited_at timestamptz,
  add column reply_to_id uuid references public.community_sample_comments(id) on delete set null;
grant insert(reply_to_id) on public.community_comments,public.community_sample_comments to authenticated;
create function public.validate_comment_reply() returns trigger
language plpgsql security definer set search_path='' as $$
declare parent_user uuid;
begin
  if new.reply_to_id is null then return new; end if;
  if tg_table_name='community_comments' then
    select user_id into parent_user from public.community_comments where id=new.reply_to_id and post_id=new.post_id;
  else
    select user_id into parent_user from public.community_sample_comments where id=new.reply_to_id and sample_post_key=new.sample_post_key;
  end if;
  if parent_user is null then raise exception 'O comentário original não está disponível nesta publicação.'; end if;
  if exists(select 1 from public.community_blocks where
      (blocker_id=new.user_id and blocked_id=parent_user) or
      (blocker_id=parent_user and blocked_id=new.user_id)) then
    raise exception 'Não é possível responder a este comentário.' using errcode='42501';
  end if;
  return new;
end $$;
revoke all on function public.validate_comment_reply() from public,anon,authenticated;
create trigger validate_member_comment_reply before insert on public.community_comments
  for each row execute function public.validate_comment_reply();
create trigger validate_sample_comment_reply before insert on public.community_sample_comments
  for each row execute function public.validate_comment_reply();

create function public.edit_community_comment(p_id uuid,p_content text,p_sample boolean default false)
returns void language plpgsql security definer set search_path='' as $$
begin
  if auth.uid() is null then raise exception 'Entre na sua conta.' using errcode='42501'; end if;
  if p_content is null or length(btrim(p_content)) not between 1 and 1000 or p_sample is null then
    raise exception 'Escreva um comentário de até 1000 caracteres.'; end if;
  if p_sample then
    update public.community_sample_comments set content=btrim(p_content),
      edited_at=case when content<>btrim(p_content) then now() else edited_at end
      where id=p_id and user_id=auth.uid();
  else
    update public.community_comments set content=btrim(p_content),
      edited_at=case when content<>btrim(p_content) then now() else edited_at end
      where id=p_id and user_id=auth.uid();
  end if;
  if not found then raise exception 'Só é possível editar seu próprio comentário.' using errcode='42501'; end if;
end $$;
revoke all on function public.edit_community_comment(uuid,text,boolean) from public,anon;
grant execute on function public.edit_community_comment(uuid,text,boolean) to authenticated;

create or replace view public.community_sample_comment_feed with(security_invoker=false) as
select c.id,c.sample_post_key,c.user_id,
  case when coalesce(pr.is_public,true) then coalesce(nullif(pr.display_name,''),'Membro') else 'Membro' end as author_name,
  case when coalesce(pr.is_public,true) then pr.avatar_url else null end as author_avatar_url,
  c.content,c.created_at,c.edited_at,c.reply_to_id
from public.community_sample_comments c left join public.profiles pr on pr.id=c.user_id
where not exists(select 1 from public.community_blocks b where
  (b.blocker_id=(select auth.uid()) and b.blocked_id=c.user_id) or
  (b.blocker_id=c.user_id and b.blocked_id=(select auth.uid())));
create or replace view public.community_comment_feed with(security_invoker=false) as
select c.id,c.post_id,c.user_id,
  case when coalesce(pr.is_public,true) then coalesce(nullif(pr.display_name,''),'Membro') else 'Membro' end as author_name,
  c.content,c.created_at,
  case when coalesce(pr.is_public,true) then pr.avatar_url else null end as author_avatar_url,
  c.edited_at,c.reply_to_id
from public.community_comments c left join public.profiles pr on pr.id=c.user_id
where not exists(select 1 from public.community_blocks b where
  (b.blocker_id=(select auth.uid()) and b.blocked_id=c.user_id) or
  (b.blocker_id=c.user_id and b.blocked_id=(select auth.uid())));
grant select on public.community_comment_feed,public.community_sample_comment_feed to anon,authenticated;
commit;
