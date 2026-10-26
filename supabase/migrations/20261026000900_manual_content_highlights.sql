begin;
alter table public.content_programs
  add column featured_until timestamptz,
  add column featured_lesson_id text,
  add column featured_note text not null default '' check(length(featured_note)<=400);
create function public.content_has_lesson(curriculum jsonb,lesson_id text)returns boolean
language sql immutable set search_path='' as $$
  select exists(select 1 from jsonb_array_elements(curriculum) m,
    jsonb_array_elements(m->'lessons') l where l->>'id'=lesson_id);
$$;
revoke all on function public.content_has_lesson(jsonb,text) from public;
grant execute on function public.content_has_lesson(jsonb,text) to anon,authenticated;
alter table public.content_programs add constraint content_featured_lesson_check
  check(featured_until is null or public.content_has_lesson(curriculum,featured_lesson_id));
commit;
