import { PGlite } from 'npm:@electric-sql/pglite@0.3';
import assert from 'node:assert/strict';

Deno.test('notes are private and concurrent edits never overwrite; completion dates keep earliest', async () => {
  const db = new PGlite();
  const owner = 'ad270000-0000-4000-8000-000000000001';
  const other = 'ad270000-0000-4000-8000-000000000002';
  try {
    await db.exec(`create role anon;create role authenticated;create role service_role;create schema auth;
      grant usage on schema auth to authenticated,anon;
      create table auth.users(id uuid primary key);
      create function auth.uid() returns uuid language sql stable as $$
        select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid $$;
      create function public.is_admin() returns boolean language sql as $$ select false $$;
      insert into auth.users values('${owner}'),('${other}');
      create table public.challenge_catalog(id text,total_days integer);
      create table public.challenge_day_completions(user_id uuid,challenge_id text,completed_on date);
      insert into public.challenge_catalog values('challenge',2);
      insert into public.challenge_day_completions values
        ('${owner}','challenge','2026-10-20'),('${owner}','challenge','2026-10-21'),
        ('${owner}','challenge','2026-10-22'),('${other}','challenge','2026-10-19');`);
    for (const file of ['20261026000100_content_learning.sql', '20261027000100_learning_sync.sql']) {
      await db.exec(await Deno.readTextFile(new URL('../migrations/' + file, import.meta.url)));
    }
    for (const file of ['20261023000200_native_push_tokens.sql','20261027000200_device_notification_sound.sql','20261027000300_challenge_achievement_dates.sql']) {
      await db.exec(await Deno.readTextFile(new URL('../migrations/' + file, import.meta.url)));
    }
    await db.exec(`select set_config('request.jwt.claim.sub','${owner}',false);set role authenticated`);
    const dateRows = (await db.query<any>('select * from public.my_challenge_achievement_dates()')).rows;
    assert.equal(dateRows.length,1);
    assert.equal(new Date(dateRows[0].completed_on).toISOString().slice(0,10),'2026-10-21');
    const installation='ad270000-0000-4000-8000-000000000099';
    await db.query('select public.register_native_push_v2($1,$2,false)',[installation,'fixture-device-token-123456']);
    await db.exec('reset role');
    assert.equal((await db.query<any>('select sound_enabled from public.native_push_tokens')).rows[0].sound_enabled,false);
    await db.exec('set role authenticated');
    const save = async (content: string, revision: number) => (await db.query<any>(
      'select public.save_lesson_note($1,$2,$3,$4) as result', ['program','lesson',content,revision],
    )).rows[0].result;
    assert.equal((await save('first',0)).note.revision,1);
    assert.equal((await save('edited',1)).note.revision,2);
    const conflict = await save('stale draft',1);
    assert.equal(conflict.conflict,true);
    assert.equal(conflict.note.content,'edited');
    const merge = async (dates: object) => (await db.query<any>(
      `select public.merge_content_progress_v2('program',false,null,true,array['lesson','old'],null,$1::jsonb) as result`,
      [JSON.stringify(dates)],
    )).rows[0].result;
    await merge({lesson:'2026-10-20T15:00:00Z'});
    await merge({lesson:'2026-10-21T15:00:00Z'});
    const progress = await merge({lesson:'2026-10-19T15:00:00Z'});
    assert.equal(Date.parse(progress.completed_at.lesson),Date.parse('2026-10-19T15:00:00Z'));
    assert.equal(progress.completed_at.old,undefined);
    await assert.rejects(merge({missing:'2026-10-19T15:00:00Z'}));
    await assert.rejects(merge({lesson:null}));
    await db.exec(`select set_config('request.jwt.claim.sub','${other}',false)`);
    assert.equal((await db.query('select * from public.my_challenge_achievement_dates()')).rows.length,0);
    assert.equal((await db.query('select * from public.lesson_notes')).rows.length,0);
    assert.equal((await db.query('select * from public.content_progress')).rows.length,0);
    assert.equal((await save('different account',0)).note.content,'different account');
    await db.exec(`select set_config('request.jwt.claim.sub','',false);reset role;set role anon`);
    await assert.rejects(save('anonymous',0),/permission denied/);
  } finally { await db.close(); }
});
