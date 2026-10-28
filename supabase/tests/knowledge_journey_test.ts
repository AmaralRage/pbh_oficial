import { PGlite } from 'npm:@electric-sql/pglite@0.3';
import assert from 'node:assert/strict';

Deno.test('knowledge migration freezes original platinum and preserves privacy', async () => {
  const db = new PGlite();
  const owner = 'ad280000-0000-4000-8000-000000000001';
  const viewer = 'ad280000-0000-4000-8000-000000000002';
  try {
    const sql = await Deno.readTextFile(new URL('../migrations/20261028000200_knowledge_journey.sql', import.meta.url));
    const originalIds = [...sql.matchAll(/\('original','([^']+)'\)/g)].map(m => m[1]);
    assert.equal(originalIds.length, 57);
    await db.exec(`
      create role anon; create role authenticated; create schema auth;
      create function auth.uid() returns uuid language sql stable as $$select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid$$;
      create table auth.users(id uuid primary key,email text,email_confirmed_at timestamptz,raw_user_meta_data jsonb);
      create table public.profiles(id uuid primary key,display_name text,avatar_url text,is_public boolean,share_progress boolean);
      create table public.challenge_catalog(id text primary key,title text not null default '',description text not null default '',total_days integer not null default 1,level text not null default 'iniciante',icon_key text not null default 'book');
      create table public.challenge_day_completions(user_id uuid,challenge_id text,completed_on date);
      create table public.community_blocks(blocker_id uuid,blocked_id uuid);
      create table public.community_follows(follower_id uuid,followed_id uuid);
      create table public.profile_achievement_awards(user_id uuid,achievement_key text);
      create table public.habit_reminder_settings(user_id uuid,time_zone text,selected_habit_keys text[],updated_at timestamptz);
      create table public.habit_completions(user_id uuid,completed_on date,habit_key text);
      insert into auth.users values('${owner}','member@example.invalid',now(),' {"profile_style":{"frame":"platinum"}}');
      insert into public.profiles values('${owner}','Membro',null,true,true);
      select set_config('request.jwt.claim.sub','${viewer}',false);
    `);
    for (const id of originalIds) {
      await db.query('insert into public.challenge_catalog(id) values($1)', [id]);
      await db.query('insert into public.challenge_day_completions values($1,$2,current_date)', [owner,id]);
    }
    await db.exec(sql);
    await db.exec('set role authenticated');
    const read = async () => (await db.query<{profile: any}>('select public.community_member_profile($1) as profile',[owner])).rows[0].profile;
    let result = await read();
    assert.equal(result.style.frame,'platinum');
    assert.equal(result.progress.completed,57);
    assert.equal(result.progress.total,62);
    assert.equal(result.progress.completed_ids.filter((id: string) => id.startsWith('knowledge_')).length,0);
    assert.equal((await db.query('select * from public.challenge_journey_members')).rows.length,62);
    await assert.rejects(db.exec("delete from public.challenge_journey_members where journey_id='original'"),/permission denied/);
    await db.exec('reset role');
    await db.exec(`delete from public.challenge_day_completions;
      insert into public.challenge_day_completions select '${owner}',c.id,current_date-n::integer from public.challenge_catalog c cross join lateral generate_series(1,c.total_days) n where c.id like 'knowledge_%';`);
    await db.exec('set role authenticated');
    result = await read();
    assert.equal(result.style.frame,'orange');
    assert.equal(result.progress.completed,5);
    await db.exec('reset role; update public.profiles set share_progress=false; set role authenticated');
    result = await read();
    assert.equal(result.progress,undefined);
    assert.deepEqual(result.style.featured,[]);
    await db.exec(`reset role; delete from public.challenge_day_completions;
      update auth.users set email='amaralaragao31@gmail.com',email_confirmed_at=now();
      update public.profiles set share_progress=true; set role authenticated`);
    result = await read();
    assert.equal(result.founder,true);
    assert.equal(result.progress.completed,62);
    assert.equal(result.progress.completed_ids.filter((id: string) => id.startsWith('knowledge_')).length,5);
    assert.equal(result.style.frame,'platinum');
    await db.exec('reset role; update public.profiles set is_public=false; set role authenticated');
    assert.equal(await read(),null);
  } finally { await db.close(); }
});
