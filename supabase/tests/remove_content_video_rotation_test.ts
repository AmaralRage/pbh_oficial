import { PGlite } from 'npm:@electric-sql/pglite@0.3';
import assert from 'node:assert/strict';

const cleanup = () => Deno.readTextFile(new URL('../migrations/20261026000600_remove_content_video_rotation.sql', import.meta.url));
Deno.test('cancellation is safe on a fresh database and can run twice', async () => {
  const db = new PGlite();
  try {
    const sql = await cleanup();
    await db.exec(sql);
    await db.exec(sql);
  } finally { await db.close(); }
});
Deno.test('cancellation removes only rotation and preserves content, progress and other jobs', async () => {
  const db = new PGlite();
  try {
    await db.exec(`
      create table public.content_programs(id text primary key, curriculum jsonb);
      insert into public.content_programs values('program','[{"lessons":[{"id":"lesson","media":{"url":"https://example.com/video"}}]}]');
      create table public.content_progress(user_id text,completed text[]);
      insert into public.content_progress values('member',array['lesson']);
      create schema cron;
      create table cron.job(jobid bigint primary key,jobname text);
      insert into cron.job values(1,'pbh-content-video-rotation'),(2,'pbh-announcement-scheduler');
      create function cron.unschedule(bigint) returns boolean language plpgsql as $$
        begin delete from cron.job where jobid=$1; return found; end $$;
      create schema vault;
      create table vault.secrets(name text primary key, secret text);
      insert into vault.secrets values('pbh_content_project_url','fixture'),('pbh_content_cron_secret','fixture'),('other-secret','preserve');
      create table public.content_video_rotation(program_id text primary key);
      create table public.content_video_suggestions(id uuid primary key);
      create table public.content_media_history(id uuid,suggestion_id uuid references public.content_video_suggestions(id));
      create function public.initialize_content_video_rotation() returns trigger language plpgsql as $$ begin return new; end $$;
      create trigger content_video_rotation_after_insert after insert on public.content_programs
        for each row execute function public.initialize_content_video_rotation();
      create function public.claim_content_video_rotation() returns setof public.content_video_rotation language sql as $$ select * from public.content_video_rotation $$;
      create function public.run_content_video_scheduler() returns void language sql as $$ select $$;
      create function public.finish_content_video_rotation(text,uuid,jsonb,text,jsonb,text) returns boolean language sql as $$ select true $$;
      create function public.admin_configure_content_rotation(text,boolean,text) returns void language sql as $$ select $$;
      create function public.admin_review_content_video(uuid,boolean) returns void language sql as $$ select $$;
      create function public.admin_restore_content_media(uuid) returns void language sql as $$ select $$;
    `);
    const before = (await db.query('select * from public.content_programs')).rows;
    const progress = (await db.query('select * from public.content_progress')).rows;
    await db.exec(await cleanup());
    assert.deepEqual((await db.query('select * from public.content_programs')).rows,before);
    assert.deepEqual((await db.query('select * from public.content_progress')).rows,progress);
    assert.deepEqual((await db.query('select jobname from cron.job')).rows,[{jobname:'pbh-announcement-scheduler'}]);
    assert.deepEqual((await db.query('select name from vault.secrets')).rows,[{name:'other-secret'}]);
    for (const table of ['content_video_rotation','content_video_suggestions','content_media_history']) {
      assert.equal((await db.query<{name:string|null}>('select to_regclass($1) as name',[`public.${table}`])).rows[0].name,null);
    }
    assert.equal((await db.query('select * from pg_trigger where tgname=\'content_video_rotation_after_insert\'')).rows.length,0);
    await db.exec(await cleanup());
  } finally { await db.close(); }
});
