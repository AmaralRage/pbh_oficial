import { PGlite } from 'npm:@electric-sql/pglite@0.3.16';
import assert from 'node:assert/strict';
Deno.test('retry UUID deduplicates comments without granting updates or bypassing ownership', async () => {
  const db = new PGlite();
  const a='bb070000-0000-4000-8000-000000000001',b='bb070000-0000-4000-8000-000000000002';
  try {
    await db.exec(`create role anon; create role authenticated; create schema auth; grant usage on schema auth to authenticated;
      create function auth.uid() returns uuid language sql stable as $$select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid$$;
      create table public.community_comments(id uuid primary key default gen_random_uuid(),post_id uuid,user_id uuid,content text,reply_to_id uuid);
      create table public.community_sample_comments(id uuid primary key default gen_random_uuid(),sample_post_key text,user_id uuid,content text,reply_to_id uuid);
      grant insert(post_id,user_id,content,reply_to_id) on public.community_comments to authenticated;
      grant insert(sample_post_key,user_id,content,reply_to_id) on public.community_sample_comments to authenticated;
      alter table public.community_comments enable row level security;
      alter table public.community_sample_comments enable row level security;
      create policy own_insert on public.community_comments for insert to authenticated with check(user_id=auth.uid());
      create policy own_sample_insert on public.community_sample_comments for insert to authenticated with check(user_id=auth.uid());`);
    await db.exec(await Deno.readTextFile(new URL('../migrations/20261107000100_idempotent_comment_submissions.sql',import.meta.url)));
    for (const table of ['community_comments','community_sample_comments']) {
      await db.query("select set_config('request.jwt.claim.sub',$1,false)",[a]);
      await db.exec('set role authenticated');
      const column=table==='community_comments'?'post_id':'sample_post_key';
      const post=table==='community_comments'?a:'sample-samuel';
      for (let i=0;i<2;i++) await db.query("select public.submit_community_comment($1,$2,'same attempt',null,$3)",[a,post,table==='community_sample_comments']);
      await assert.rejects(db.query(`insert into public.${table}(id,${column},user_id,content) values($1,$2,$3,'forged')`,[b,post,b]),/row-level security/);
      await assert.rejects(db.exec(`update public.${table} set content='overwrite'`),/permission denied/);
      await db.exec('reset role');
      assert.equal((await db.query(`select * from public.${table}`)).rows.length,1);
    }
  } finally { await db.close(); }
});
