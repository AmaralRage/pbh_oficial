import { PGlite } from 'npm:@electric-sql/pglite@0.3';
import assert from 'node:assert/strict';

Deno.test('public weather effects preserve intensity, privacy and founder restrictions', async () => {
  const db = new PGlite();
  const owner = 'ad260000-0000-4000-8000-000000000001';
  const viewer = 'ad260000-0000-4000-8000-000000000002';
  try {
    await db.exec(`
      create role anon; create role authenticated; create schema auth;
      create function auth.uid() returns uuid language sql stable as $$
        select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid $$;
      create table auth.users(id uuid primary key, email text, email_confirmed_at timestamptz, raw_user_meta_data jsonb);
      create table public.profiles(id uuid primary key, display_name text, avatar_url text, is_public boolean, share_progress boolean);
      create table public.community_blocks(blocker_id uuid, blocked_id uuid);
      create table public.challenge_catalog(id text, total_days integer);
      create table public.challenge_day_completions(user_id uuid, challenge_id text, completed_on date);
      create table public.community_follows(follower_id uuid, followed_id uuid);
      create table public.profile_achievement_awards(user_id uuid, achievement_key text);
      create table public.habit_reminder_settings(user_id uuid, time_zone text, selected_habit_keys text[], updated_at timestamptz);
      create table public.habit_completions(user_id uuid, completed_on date, habit_key text);
      insert into auth.users values('${owner}','member@example.invalid',now(),'{}');
      insert into public.profiles values('${owner}','Membro',null,true,false);
      select set_config('request.jwt.claim.sub','${viewer}',false);
    `);
    await db.exec(await Deno.readTextFile(new URL('../migrations/20261026001000_profile_weather_effects.sql', import.meta.url)));
    await db.exec(await Deno.readTextFile(new URL('../migrations/20261026001100_profile_seasonal_effects.sql', import.meta.url)));
    await db.exec(await Deno.readTextFile(new URL('../migrations/20261027000500_founder_nebula_variants.sql', import.meta.url)));
    await db.exec(await Deno.readTextFile(new URL('../migrations/20261027000600_bonfire_cover.sql', import.meta.url)));
    const read = async () => (await db.query<{ profile: any }>(
      'select public.community_member_profile($1) as profile', [owner],
    )).rows[0].profile;
    const setStyle = async (style: unknown) => db.query(
      'update auth.users set raw_user_meta_data=$1::jsonb where id=$2',
      [JSON.stringify({ profile_style: style }), owner],
    );
    await db.exec('set role authenticated');
    const defaults = await read();
    assert.equal(defaults.style.frame_intensity, .5);
    assert.equal(defaults.style.cover_intensity, .5);
    assert.equal(defaults.progress, undefined);
    await db.exec('reset role');
    await setStyle({cover:'bonfire',cover_effect:'embers'});
    await db.exec('set role authenticated');
    const bonfire=await read();
    assert.equal(bonfire.style.cover,'bonfire');
    assert.equal(bonfire.style.cover_effect,'embers');
    for (const effect of ['rain', 'snow', 'fireflies', 'halloween', 'christmas', 'new_year']) {
      await db.exec('reset role');
      await setStyle({ frame_effect: effect, cover_effect: effect, frame_intensity: .2, cover_intensity: .9 });
      await db.exec('set role authenticated');
      const result = await read();
      assert.equal(result.style.frame_effect, effect);
      assert.equal(result.style.cover_effect, effect);
      assert.equal(result.style.frame_intensity, .2);
      assert.equal(result.style.cover_intensity, .9);
      assert.equal(result.progress, undefined);
    }
    await db.exec('reset role');
    await setStyle({ frame_effect: 'crown', cover_effect: 'legacy', frame_intensity: -10, cover_intensity: 20 });
    let result = await read();
    assert.equal(result.style.frame_effect, 'orbit');
    assert.equal(result.style.cover_effect, 'shimmer');
    assert.equal(result.style.frame_intensity, 0);
    assert.equal(result.style.cover_intensity, 1);
    await setStyle({ frame_intensity: 'invalid', cover_intensity: {} });
    result = await read();
    assert.equal(result.style.frame_intensity, .5);
    assert.equal(result.style.cover_intensity, .5);
    await setStyle({cover_effect:'legacy',cover_variant:'astral'});
    assert.equal((await read()).style.cover_effect,'shimmer');
    assert.equal((await read()).style.cover_variant,'royal');
    await db.exec("update auth.users set email='amaralaragao31@gmail.com',email_confirmed_at=now()");
    for(const variant of ['royal','astral','eclipse']) {
      await setStyle({cover_effect:'legacy',cover_variant:variant});
      result=await read();
      assert.equal(result.style.cover_effect,'legacy');
      assert.equal(result.style.cover_variant,variant);
    }
    await setStyle({cover_effect:'legacy',cover_variant:'unknown'});
    assert.equal((await read()).style.cover_variant,'royal');
    await db.exec(`update public.profiles set is_public=false; set role authenticated`);
    assert.equal(await read(), null);
    await db.exec(`reset role; update public.profiles set is_public=true;
      insert into public.community_blocks values('${owner}','${viewer}'); set role authenticated`);
    assert.equal(await read(), null);
  } finally {
    await db.close();
  }
});
