begin;
-- Validate cosmetic rewards from completed journey members, never user metadata.
create or replace function public.community_member_profile(p_user_id uuid)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare
  target record;
  viewer uuid := (select auth.uid());
  metadata jsonb;
  appearance jsonb;
  founder boolean;
  own_profile boolean;
  visible_progress boolean;
  completed_ids text[];
  awards text[];
  completed integer;
  total integer;
  followers integer;
  streak integer;
  zone text;
  selected_keys text[];
  today date;
  anchor date;
  frame text;
  cover text;
  frame_effect text;
  cover_effect text;
  theme text;
  public_style jsonb;
  original_platinum boolean;
  knowledge_platinum boolean;
  result jsonb;
begin
  select p.id, p.display_name, p.avatar_url, p.is_public, p.share_progress,
    u.raw_user_meta_data, u.email, u.email_confirmed_at
    into target from public.profiles p join auth.users u on u.id = p.id
    where p.id = p_user_id;
  if not found then return null; end if;
  own_profile := viewer is not null and viewer = target.id;
  if (not coalesce(target.is_public, true) and not own_profile)
     or exists (select 1 from public.community_blocks b
       where (b.blocker_id = viewer and b.blocked_id = target.id)
          or (b.blocker_id = target.id and b.blocked_id = viewer)) then
    return null;
  end if;
  founder := lower(coalesce(target.email, '')) = 'amaralaragao31@gmail.com' and target.email_confirmed_at is not null;
  visible_progress := target.share_progress or own_profile;
  metadata := coalesce(target.raw_user_meta_data, '{}'::jsonb);
  appearance := case when jsonb_typeof(metadata -> 'profile_style') = 'object' then metadata -> 'profile_style' else '{}'::jsonb end;

  select count(*)::integer into total from public.challenge_catalog;
  select coalesce(array_agg(c.id order by c.id), '{}'::text[]) into completed_ids
    from public.challenge_catalog c where founder or c.total_days <= (
      select count(*) from public.challenge_day_completions d where d.user_id = target.id and d.challenge_id = c.id
    );
  completed := cardinality(completed_ids);
  original_platinum := (select count(*)=57 and bool_and(challenge_id=any(completed_ids)) from public.challenge_journey_members where journey_id='original');
  knowledge_platinum := (select count(*)=5 and bool_and(challenge_id=any(completed_ids)) from public.challenge_journey_members where journey_id='knowledge');
  -- Cosmetic unlocks are checked privately even when progress isn't shared.
  frame := coalesce(appearance ->> 'frame', case when founder then 'founder' else 'orange' end);
  if not (frame = 'orange' or (frame = 'bronze' and completed >= 1)
    or (frame = 'silver' and completed >= 10) or (frame = 'gold' and completed >= 30)
    or (frame = 'platinum' and original_platinum) or (frame = 'founder' and founder)) then frame := 'orange'; end if;
  cover := coalesce(appearance ->> 'cover', case when founder then 'founder' else 'ember' end);
  if not (cover in ('ember', 'night', 'bonfire') or (cover = 'forest' and completed >= 1)
    or (cover = 'gold' and completed >= 30) or (cover = 'founder' and founder)) then cover := 'ember'; end if;
  frame_effect := coalesce(appearance ->> 'frame_effect', case when founder then 'crown' else 'orbit' end);
  if not (frame_effect in ('none', 'orbit', 'pulse', 'sparks', 'double', 'rain', 'snow', 'fireflies', 'halloween', 'christmas', 'new_year') or (frame_effect = 'crown' and founder)
    or (frame_effect='platinum_orbit' and original_platinum)
    or (frame_effect='knowledge_orbit' and knowledge_platinum)
    or (frame_effect='journey_crown' and original_platinum and knowledge_platinum)) then frame_effect := 'orbit'; end if;
  cover_effect := coalesce(appearance ->> 'cover_effect', case when founder then 'legacy' else 'shimmer' end);
  if not (cover_effect in ('none', 'shimmer', 'stars', 'meteors', 'aurora', 'embers', 'rain', 'snow', 'fireflies', 'halloween', 'christmas', 'new_year') or (cover_effect = 'legacy' and founder)
    or (cover_effect='platinum_ascent' and original_platinum)
    or (cover_effect='knowledge_constellation' and knowledge_platinum)
    or (cover_effect='journey_legacy' and original_platinum and knowledge_platinum)) then cover_effect := 'shimmer'; end if;
  theme := coalesce(appearance ->> 'profile_theme', 'app');
  if theme = 'app' then theme := coalesce(metadata ->> 'app_theme', 'pbh'); end if;
  if not (theme in ('pbh', 'midnight', 'starlight', 'cosmic', 'galactic', 'nova', 'emerald') or (theme = 'founder' and founder)) then theme := 'pbh'; end if;
  public_style := jsonb_build_object('frame', frame, 'cover', cover,
    'frame_effect', frame_effect, 'cover_effect', cover_effect, 'profile_theme', theme,
    'cover_variant', case when founder and cover_effect='legacy'
      and appearance->>'cover_variant' in ('royal','astral','eclipse')
      then appearance->>'cover_variant' else 'royal' end,
    'frame_intensity', case when jsonb_typeof(appearance -> 'frame_intensity') = 'number'
      then greatest(0, least(1, (appearance ->> 'frame_intensity')::numeric)) else 0.5 end,
    'cover_intensity', case when jsonb_typeof(appearance -> 'cover_intensity') = 'number'
      then greatest(0, least(1, (appearance ->> 'cover_intensity')::numeric)) else 0.5 end,
    'title', case when visible_progress then left(coalesce(appearance ->> 'title', case when founder then 'founder' else 'member' end), 64)
                  when founder then 'founder' else 'member' end);
  if visible_progress and jsonb_typeof(appearance -> 'featured') = 'array' then
    public_style := public_style || jsonb_build_object('featured', (select coalesce(jsonb_agg(v), '[]'::jsonb) from (select value v from jsonb_array_elements(appearance -> 'featured') limit 3) x));
  elsif not visible_progress then public_style := public_style || '{"featured":[]}'::jsonb;
  end if;
  result := jsonb_build_object('id', target.id, 'name', left(coalesce(nullif(target.display_name, ''), 'Membro'), 40),
    'bio', left(coalesce(metadata ->> 'bio', ''), 120), 'avatar_url', left(target.avatar_url, 2048),
    'cover_url', left(metadata ->> 'cover_url', 2048), 'founder', founder,
    'is_own', own_profile, 'progress_shared', target.share_progress, 'style', public_style);
  if visible_progress then
    select count(*)::integer into followers from public.community_follows where followed_id = target.id;
    select coalesce(array_agg(achievement_key), '{}'::text[]) into awards from public.profile_achievement_awards where user_id = target.id;
    select r.time_zone, r.selected_habit_keys into zone, selected_keys from public.habit_reminder_settings r
      where r.user_id = target.id order by r.updated_at desc limit 1;
    if zone is null or not exists (select 1 from pg_catalog.pg_timezone_names where name = zone) then zone := 'America/Sao_Paulo'; end if;
    selected_keys := coalesce(selected_keys, array['train', 'read', 'digital_fast', 'meditate', 'sleep_early']);
    today := (now() at time zone zone)::date;
    anchor := case when exists (select 1 from public.habit_completions where user_id = target.id and completed_on = today and habit_key = any(selected_keys)) then today else today - 1 end;
    select count(*)::integer into streak from (
      select completed_on, row_number() over (order by completed_on desc) n
      from (select distinct completed_on from public.habit_completions where user_id = target.id and completed_on <= anchor and habit_key = any(selected_keys)) d
    ) d where completed_on = anchor - (n::integer - 1);
    if founder then streak := greatest(0, today - date '2021-01-01' + 1); end if;
    result := result || jsonb_build_object('progress', jsonb_build_object('completed', completed, 'total', total,
      'completed_ids', to_jsonb(completed_ids), 'manual_awards', to_jsonb(awards), 'followers', followers, 'streak', streak));
  end if;
  return result;
end;
$$;
revoke all on function public.community_member_profile(uuid) from public;
grant execute on function public.community_member_profile(uuid) to anon, authenticated;



commit;
