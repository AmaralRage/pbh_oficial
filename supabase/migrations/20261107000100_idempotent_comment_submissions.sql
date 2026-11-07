begin;
-- Client-generated UUIDs make retries safe after a lost HTTP response.
-- Existing owner, participation and reply policies/triggers remain in effect.
-- No UPDATE or extra SELECT privileges are granted.
grant insert(id) on public.community_comments,public.community_sample_comments to authenticated;
create function public.submit_community_comment(p_id uuid,p_post text,p_content text,p_reply uuid default null,p_sample boolean default false)
returns void language plpgsql security invoker set search_path='' as $$
begin
  if auth.uid() is null then raise exception 'Entre na sua conta.' using errcode='42501'; end if;
  if p_id is null or p_post is null or p_sample is null or p_content is null or length(btrim(p_content)) not between 1 and 1000 then
    raise exception 'Revise seu comentário.' using errcode='22023'; end if;
  -- No conflict target: deduplication needs no extra SELECT grant on comments.
  -- Invoker privileges retain the existing RLS and all participation triggers.
  if p_sample then
    insert into public.community_sample_comments(id,sample_post_key,user_id,content,reply_to_id)
      values(p_id,p_post,auth.uid(),btrim(p_content),p_reply) on conflict do nothing;
  else
    insert into public.community_comments(id,post_id,user_id,content,reply_to_id)
      values(p_id,p_post::uuid,auth.uid(),btrim(p_content),p_reply) on conflict do nothing;
  end if;
end $$;
revoke all on function public.submit_community_comment(uuid,text,text,uuid,boolean) from public,anon;
grant execute on function public.submit_community_comment(uuid,text,text,uuid,boolean) to authenticated;
commit;
