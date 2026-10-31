begin;
alter table public.personal_goals add column goal_id uuid not null default gen_random_uuid(),add column started_at timestamptz,add column completed_at timestamptz;
alter table public.personal_goal_entries add column goal_id uuid;
create index personal_goal_entries_goal_time on public.personal_goal_entries(user_id,goal_id,created_at desc,id);
-- Legacy records have no reliable goal identifier and remain separately visible.
create table public.personal_goal_history(
  id uuid primary key,user_id uuid not null references auth.users(id) on delete cascade,
  title text not null,next_step text not null,started_at timestamptz,completed_at timestamptz not null
);
create index personal_goal_history_owner_time on public.personal_goal_history(user_id,completed_at desc);
alter table public.personal_goal_history enable row level security;
revoke all on public.personal_goal_history from public,anon,authenticated;
grant select on public.personal_goal_history to authenticated;
create policy "Members read their completed goals" on public.personal_goal_history for select to authenticated using(user_id=(select auth.uid()));
revoke insert,update,delete on public.personal_goals from authenticated;

create function public.save_personal_goal(p_title text,p_next_step text,p_public boolean,p_expected_goal uuid,p_expected_updated timestamptz) returns void
language plpgsql security definer set search_path='' as $$
declare current_goal public.personal_goals;
begin
  if auth.uid() is null then raise exception 'Entre na sua conta.' using errcode='42501'; end if;
  if p_title is null or length(btrim(p_title)) not between 1 and 180 or p_next_step is null or length(p_next_step)>300 or p_public is null then raise exception 'Revise seu objetivo.'; end if;
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(auth.uid()::text,310002));
  select * into current_goal from public.personal_goals where user_id=auth.uid() for update;
  if not found then
    if p_expected_goal is not null then raise exception 'O objetivo mudou. Atualize a tela.' using errcode='40001'; end if;
    insert into public.personal_goals(user_id,title,next_step,is_public,started_at) values(auth.uid(),btrim(p_title),btrim(p_next_step),p_public,now());
  else
    if current_goal.goal_id is distinct from p_expected_goal or current_goal.updated_at is distinct from p_expected_updated then raise exception 'O objetivo mudou. Atualize antes de salvar.' using errcode='40001'; end if;
    update public.personal_goals set title=btrim(p_title),next_step=btrim(p_next_step),is_public=p_public,
      goal_id=case when current_goal.completed_at is null then goal_id else gen_random_uuid() end,
      started_at=case when current_goal.completed_at is null then started_at else now() end,completed_at=null,updated_at=now() where user_id=auth.uid();
  end if;
end $$;
create function public.complete_personal_goal(p_goal uuid,p_expected_updated timestamptz) returns void
language plpgsql security definer set search_path='' as $$
declare current_goal public.personal_goals;
begin
  select * into current_goal from public.personal_goals where user_id=auth.uid() for update;
  if not found or current_goal.goal_id is distinct from p_goal then raise exception 'Objetivo indisponível.' using errcode='40001'; end if;
  if current_goal.completed_at is not null then return; end if;
  if current_goal.updated_at is distinct from p_expected_updated then raise exception 'O objetivo mudou. Atualize antes de concluir.' using errcode='40001'; end if;
  insert into public.personal_goal_history(id,user_id,title,next_step,started_at,completed_at) values(current_goal.goal_id,auth.uid(),current_goal.title,current_goal.next_step,current_goal.started_at,now());
  update public.personal_goals set completed_at=now(),is_public=false,updated_at=now() where user_id=auth.uid();
end $$;
create function public.assign_personal_goal_entry() returns trigger
language plpgsql security definer set search_path='' as $$
declare current_goal public.personal_goals;
begin
  select * into current_goal from public.personal_goals where user_id=new.user_id for share;
  if new.user_id is distinct from auth.uid() or not found or current_goal.completed_at is not null or current_goal.title<>new.goal_title or new.goal_id is distinct from current_goal.goal_id then raise exception 'O objetivo mudou. Atualize antes de registrar.' using errcode='40001'; end if;
  new.goal_id:=current_goal.goal_id;return new;
end $$;
revoke all on function public.assign_personal_goal_entry() from public,anon,authenticated;
create trigger assign_personal_goal_entry before insert on public.personal_goal_entries for each row execute function public.assign_personal_goal_entry();
revoke all on function public.save_personal_goal(text,text,boolean,uuid,timestamptz),public.complete_personal_goal(uuid,timestamptz) from public,anon;
grant execute on function public.save_personal_goal(text,text,boolean,uuid,timestamptz),public.complete_personal_goal(uuid,timestamptz) to authenticated;

create or replace function public.public_profile_goal(p_user_id uuid) returns jsonb
language sql stable security definer set search_path='' as $$
  select jsonb_build_object('title',g.title,'next_step',g.next_step,'is_public',g.is_public)
    from public.personal_goals g join public.profiles p on p.id=g.user_id
    where g.user_id=p_user_id and g.completed_at is null
      and (g.user_id=(select auth.uid()) or (g.is_public and coalesce(p.is_public,true)))
      and not exists(select 1 from public.community_blocks b where (b.blocker_id=(select auth.uid()) and b.blocked_id=g.user_id) or (b.blocker_id=g.user_id and b.blocked_id=(select auth.uid())));
$$;
commit;
