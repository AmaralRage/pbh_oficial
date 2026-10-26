-- Biblioteca publicada e progresso privado de aprendizado.
begin;

create or replace function public.valid_content_curriculum(value jsonb, published boolean)
returns boolean language plpgsql immutable set search_path = '' as $$
declare
  m jsonb; l jsonb; module_ids text[] := '{}'; lesson_ids text[] := '{}';
begin
  if jsonb_typeof(value) is distinct from 'array' then return false; end if;
  if published and jsonb_array_length(value) = 0 then return false; end if;
  for m in select * from jsonb_array_elements(value) loop
    if coalesce(btrim(m->>'id'), '') = '' or coalesce(btrim(m->>'title'), '') = ''
      or (m->>'id') = any(module_ids) or jsonb_typeof(m->'lessons') is distinct from 'array'
      then return false; end if;
    module_ids := array_append(module_ids, m->>'id');
    if published and jsonb_array_length(m->'lessons') = 0 then return false; end if;
    for l in select * from jsonb_array_elements(m->'lessons') loop
      if coalesce(btrim(l->>'id'), '') = '' or coalesce(btrim(l->>'title'), '') = ''
        or (l->>'id') = any(lesson_ids) then return false; end if;
      if jsonb_typeof(l->'minutes') is distinct from 'number' then return false; end if;
      if (l->>'minutes')::numeric <> trunc((l->>'minutes')::numeric)
        or (l->>'minutes')::numeric not between 1 and 180 then return false; end if;
      if published and (coalesce(btrim(l->>'body'), '') = '' or coalesce(btrim(l->>'practice'), '') = '')
        then return false; end if;
      if l->>'habit_key' is not null and l->>'habit_key' not in
        ('train', 'read', 'digital_fast', 'meditate', 'sleep_early') then return false; end if;
      lesson_ids := array_append(lesson_ids, l->>'id');
    end loop;
  end loop;
  return true;
exception when others then return false;
end;
$$;
revoke all on function public.valid_content_curriculum(jsonb, boolean) from public;
grant execute on function public.valid_content_curriculum(jsonb, boolean) to anon, authenticated;

create table public.content_programs (
  id text primary key check (length(id) between 1 and 160),
  title text not null check (length(btrim(title)) between 1 and 200),
  tagline text not null default '',
  description text not null default '',
  topic text not null check (length(btrim(topic)) between 1 and 80),
  level text not null check (level in ('iniciante', 'intermediario', 'avancado')),
  weeks integer not null check (weeks between 1 and 104),
  outcomes jsonb not null default '[]' check (jsonb_typeof(outcomes) = 'array'),
  curriculum jsonb not null default '[]',
  published boolean not null default false,
  created_at timestamptz not null default now(),
  check (public.valid_content_curriculum(curriculum, published)),
  check (not published or (length(btrim(tagline)) > 0 and length(btrim(description)) > 0
    and jsonb_array_length(outcomes) > 0))
);
alter table public.content_programs enable row level security;
revoke all on public.content_programs from anon, authenticated;
grant select on public.content_programs to anon, authenticated;
grant insert, update, delete on public.content_programs to authenticated;
create policy "Published programs are public" on public.content_programs for select
  to anon, authenticated using (published);
create policy "Admins manage programs" on public.content_programs for all to authenticated
  using ((select public.is_admin())) with check ((select public.is_admin()));

create table public.content_progress (
  user_id uuid not null references auth.users(id) on delete cascade,
  -- Sem FK no programa: mantém o progresso após despublicação e permite fila offline.
  program_id text not null check (length(program_id) between 1 and 160),
  saved boolean not null default false,
  saved_at timestamptz,
  started boolean not null default false,
  completed text[] not null default '{}',
  opened_at timestamptz,
  primary key (user_id, program_id),
  check (cardinality(completed) <= 2000)
);
alter table public.content_progress enable row level security;
revoke all on public.content_progress from anon, authenticated;
grant select on public.content_progress to authenticated;
create policy "Members read their learning progress" on public.content_progress for select
  to authenticated using ((select auth.uid()) = user_id);

create or replace function public.merge_content_progress(
  p_program_id text, p_saved boolean, p_saved_at timestamptz,
  p_started boolean, p_completed text[], p_opened_at timestamptz
) returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  member_id uuid := auth.uid(); result public.content_progress;
begin
  if member_id is null then raise exception 'Authentication required'; end if;
  if p_program_id is null or length(p_program_id) not between 1 and 160
    or p_saved is null or p_started is null or p_completed is null
    or cardinality(p_completed) > 2000 or array_position(p_completed, null) is not null
    or exists (select 1 from unnest(p_completed) as v where length(v) not between 1 and 160)
    then raise exception 'Invalid progress'; end if;
  insert into public.content_progress as current_progress
    (user_id, program_id, saved, saved_at, started, completed, opened_at)
  values (member_id, p_program_id, p_saved,
    case when p_saved_at is null then null else least(p_saved_at, now()) end, p_started,
    array(select distinct unnest(p_completed)),
    case when p_opened_at is null then null else least(p_opened_at, now()) end)
  on conflict (user_id, program_id) do update set
    saved = case when excluded.saved_at is not null and
      (current_progress.saved_at is null or excluded.saved_at > current_progress.saved_at)
      then excluded.saved else current_progress.saved end,
    saved_at = greatest(current_progress.saved_at, excluded.saved_at),
    started = current_progress.started or excluded.started,
    completed = array(select distinct unnest(current_progress.completed || excluded.completed)),
    opened_at = greatest(current_progress.opened_at, excluded.opened_at)
  returning * into result;
  return to_jsonb(result);
end;
$$;
revoke all on function public.merge_content_progress(text, boolean, timestamptz, boolean, text[], timestamptz) from public, anon;
grant execute on function public.merge_content_progress(text, boolean, timestamptz, boolean, text[], timestamptz) to authenticated;

-- O catálogo inicial é inserido pela migration seguinte com os mesmos IDs do app.
commit;
