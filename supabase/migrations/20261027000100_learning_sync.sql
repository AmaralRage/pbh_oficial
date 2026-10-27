begin;
alter table public.content_progress add column if not exists completed_at jsonb not null default '{}';
alter table public.content_progress add constraint content_completion_dates_object
  check (jsonb_typeof(completed_at) = 'object');

create function public.merge_content_progress_v2(
  p_program_id text, p_saved boolean, p_saved_at timestamptz,
  p_started boolean, p_completed text[], p_opened_at timestamptz,
  p_completed_at jsonb default '{}'
) returns jsonb language plpgsql security definer set search_path='' as $$
declare result jsonb; item record; known timestamptz; incoming timestamptz;
begin
  if jsonb_typeof(p_completed_at) is distinct from 'object'
    or octet_length(p_completed_at::text)>300000 then raise exception 'Invalid completion dates'; end if;
  result := public.merge_content_progress(p_program_id,p_saved,p_saved_at,p_started,p_completed,p_opened_at);
  -- The existing RPC locks this member's row; never replace another lesson's date.
  for item in select * from jsonb_each_text(p_completed_at) loop
    if not (item.key = any(p_completed)) then raise exception 'Date without completion'; end if;
    if item.value is null then raise exception 'Invalid completion date'; end if;
    incoming := least(item.value::timestamptz, now());
    if incoming is null then raise exception 'Invalid completion date'; end if;
    select (completed_at->>item.key)::timestamptz into known from public.content_progress
      where user_id=auth.uid() and program_id=p_program_id;
    update public.content_progress set completed_at=jsonb_set(completed_at,array[item.key],to_jsonb(least(known,incoming)))
      where user_id=auth.uid() and program_id=p_program_id;
  end loop;
  select to_jsonb(p) into result from public.content_progress p
    where user_id=auth.uid() and program_id=p_program_id;
  return result;
end $$;
revoke all on function public.merge_content_progress_v2(text,boolean,timestamptz,boolean,text[],timestamptz,jsonb) from public,anon;
grant execute on function public.merge_content_progress_v2(text,boolean,timestamptz,boolean,text[],timestamptz,jsonb) to authenticated;

create table public.lesson_notes (
  user_id uuid not null references auth.users(id) on delete cascade,
  program_id text not null check(length(program_id) between 1 and 160),
  lesson_id text not null check(length(lesson_id) between 1 and 160),
  content text not null check(length(content)<=6000),
  revision bigint not null default 1,
  updated_at timestamptz not null default now(),
  primary key(user_id,program_id,lesson_id)
);
alter table public.lesson_notes enable row level security;
revoke all on public.lesson_notes from anon,authenticated;
grant select on public.lesson_notes to authenticated;
create policy "Members read only their notes" on public.lesson_notes for select to authenticated
  using ((select auth.uid())=user_id);
create function public.save_lesson_note(p_program_id text,p_lesson_id text,p_content text,p_revision bigint)
returns jsonb language plpgsql security definer set search_path='' as $$
declare member uuid:=auth.uid(); result public.lesson_notes;
begin
  if member is null then raise exception 'Authentication required' using errcode='42501'; end if;
  if p_program_id is null or length(p_program_id) not between 1 and 160
    or p_lesson_id is null or length(p_lesson_id) not between 1 and 160
    or p_content is null or length(p_content)>6000 or p_revision is null or p_revision<0
    then raise exception 'Invalid note'; end if;
  -- Serialize concurrent first inserts as well as edits of an existing note.
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(member::text||':'||p_program_id||':'||p_lesson_id,0));
  select * into result from public.lesson_notes
    where user_id=member and program_id=p_program_id and lesson_id=p_lesson_id for update;
  if coalesce(result.revision,0)<>p_revision then
    return jsonb_build_object('conflict',true,'note',to_jsonb(result));
  end if;
  insert into public.lesson_notes(user_id,program_id,lesson_id,content,revision)
    values(member,p_program_id,p_lesson_id,p_content,1)
    on conflict(user_id,program_id,lesson_id) do update set
      content=excluded.content,revision=lesson_notes.revision+1,updated_at=now()
    returning * into result;
  return jsonb_build_object('conflict',false,'note',to_jsonb(result));
end $$;
revoke all on function public.save_lesson_note(text,text,text,bigint) from public,anon;
grant execute on function public.save_lesson_note(text,text,text,bigint) to authenticated;
commit;
