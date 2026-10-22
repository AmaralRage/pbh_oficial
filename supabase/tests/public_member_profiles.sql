-- Run with: supabase db query --linked --file supabase/tests/public_member_profiles.sql
-- Fixtures and every change are rolled back, including when an assertion fails.
begin;
do $$
declare
  a uuid := 'fa718c20-0000-4000-8000-000000000001';
  b uuid := 'fa718c20-0000-4000-8000-000000000002';
  payload jsonb;
begin
  if exists (select 1 from auth.users where id in (a, b)) then raise exception 'Fixture IDs already exist'; end if;
  insert into auth.users(id, email, email_confirmed_at, raw_user_meta_data)
  values (a, 'public-profile-fixture-a@example.invalid', now(), '{"display_name":"Perfil de teste", "bio":"Bio pública", "private_secret":"never expose", "app_theme":"founder", "profile_style":{"frame":"founder","cover":"founder","frame_effect":"crown","cover_effect":"legacy","title":"platinum","featured":["platinum","daily_reading"]}}'),
         (b, 'public-profile-fixture-b@example.invalid', now(), '{"display_name":"Visitante de teste"}');
  perform set_config('request.jwt.claim.sub', b::text, true);
  payload := public.community_member_profile(a);
  if payload is null or payload ? 'progress' or payload ? 'email' or payload ? 'raw_user_meta_data' or payload::text like '%never expose%' then raise exception 'Hidden information leaked'; end if;
  if payload -> 'style' ->> 'frame' <> 'orange' or payload -> 'style' ->> 'profile_theme' <> 'pbh'
     or payload -> 'style' ->> 'frame_effect' <> 'orbit' or payload -> 'style' ->> 'cover_effect' <> 'shimmer'
     or payload -> 'style' ->> 'title' <> 'member' then raise exception 'Forged founder styles exposed'; end if;
  if payload -> 'style' -> 'featured' <> '[]'::jsonb then raise exception 'Hidden highlights leaked'; end if;
  update public.profiles set is_public = false where id = a;
  if public.community_member_profile(a) is not null then raise exception 'Private profile exposed'; end if;
  perform set_config('request.jwt.claim.sub', a::text, true);
  payload := public.community_member_profile(a);
  if payload is null or not (payload ->> 'is_own')::boolean or not (payload ? 'progress') then raise exception 'Owner preview unavailable'; end if;
  perform set_config('request.jwt.claim.sub', b::text, true);
  update public.profiles set is_public = true, share_progress = true where id = a;
  insert into public.user_challenges(user_id, challenge_id) values(a, 'daily_reading');
  insert into public.challenge_day_completions(user_id, challenge_id, completed_on)
    select a, 'daily_reading', current_date - day from generate_series(0, (select total_days - 1 from public.challenge_catalog where id = 'daily_reading')) day;
  insert into public.habit_reminder_settings(user_id, time_zone, selected_habit_keys) values(a, 'UTC', array['read']);
  insert into public.habit_completions(user_id, habit_key, completed_on) values(a, 'read', current_date), (a, 'read', current_date - 1);
  insert into public.community_follows(follower_id, followed_id) values(b, a);
  payload := public.community_member_profile(a);
  if (payload -> 'progress' ->> 'completed')::integer <> 1 or (payload -> 'progress' ->> 'streak')::integer <> 2
     or (payload -> 'progress' ->> 'followers')::integer <> 1
     or not (payload -> 'progress' -> 'completed_ids' @> '["daily_reading"]'::jsonb) then raise exception 'Public aggregates are incorrect'; end if;
  insert into public.community_blocks(blocker_id, blocked_id) values(a, b);
  if public.community_member_profile(a) is not null then raise exception 'Reverse block bypassed'; end if;
  delete from public.community_blocks where blocker_id = a and blocked_id = b;
  insert into public.community_blocks(blocker_id, blocked_id) values(b, a);
  if public.community_member_profile(a) is not null then raise exception 'Forward block bypassed'; end if;
  perform set_config('request.jwt.claim.sub', '', true);
  update public.profiles set share_progress = false where id = a;
  payload := public.community_member_profile(a);
  if payload is null or payload ? 'progress' then raise exception 'Anonymous visibility incorrect'; end if;
  update public.profiles set is_public = false where id = a;
  if public.community_member_profile(a) is not null then raise exception 'Anonymous private profile leak'; end if;
  if public.community_member_profile('fa718c20-0000-4000-8000-000000000099') is not null then raise exception 'Unknown profile must be unavailable'; end if;
  if not has_function_privilege('anon', 'public.community_member_profile(uuid)', 'EXECUTE')
     or has_column_privilege('anon', 'public.profiles', 'email', 'SELECT') then raise exception 'Public permissions are incorrect'; end if;
end;
$$;
rollback;
select 'Public profile privacy, blocks, owner preview and aggregates passed; fixtures rolled back' as result;
