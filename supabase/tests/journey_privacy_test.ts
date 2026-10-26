import { PGlite } from 'npm:@electric-sql/pglite@0.3';
import assert from 'node:assert/strict';

Deno.test('goals require opt-in, respect profile privacy and blocks, and never expose private entries',async()=>{
  const db=new PGlite();
  const owner='ad260000-0000-4000-8000-000000000001',viewer='ad260000-0000-4000-8000-000000000002';
  try{
    await db.exec(`create role anon;create role authenticated;create schema auth;
      grant usage on schema auth to anon,authenticated;
      create table auth.users(id uuid primary key);
      create function auth.uid() returns uuid language sql stable as $$ select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid $$;
      create table public.profiles(id uuid primary key,is_public boolean default true);
      create table public.community_blocks(blocker_id uuid,blocked_id uuid);
      insert into auth.users values('${owner}'),('${viewer}');
      insert into public.profiles values('${owner}',true),('${viewer}',true);
      create table public.community_posts(topic text constraint community_posts_topic_check check(topic in ('disciplina')));
      insert into public.community_posts values('disciplina');`);
    await db.exec(await Deno.readTextFile(new URL('../migrations/20261026000700_community_topics.sql',import.meta.url)));
    await db.exec("insert into public.community_posts values('duvidas'),('conquistas'),('recomendacoes')");
    await db.exec(await Deno.readTextFile(new URL('../migrations/20261026000800_personal_goals.sql',import.meta.url)));
    await db.exec(`create table public.content_programs(id text primary key,curriculum jsonb);
      insert into public.content_programs values('program','[{"lessons":[{"id":"lesson"}]}]');`);
    await db.exec(await Deno.readTextFile(new URL('../migrations/20261026000900_manual_content_highlights.sql',import.meta.url)));
    await assert.rejects(db.exec("update public.content_programs set featured_until=now()+interval '1 day',featured_lesson_id='missing'"),/content_featured_lesson_check/);
    await db.exec("update public.content_programs set featured_until=now()+interval '1 day',featured_lesson_id='lesson'");
    await db.exec(`insert into public.personal_goals(user_id,title,next_step) values('${owner}','Aprender','Ler');
      insert into public.personal_goal_entries(user_id,goal_title,content) values('${owner}','Aprender','Registro privado');
      select set_config('request.jwt.claim.sub','${viewer}',false);set role authenticated;`);
    assert.equal((await db.query<any>('select public.public_profile_goal($1) as goal',[owner])).rows[0].goal,null);
    assert.equal((await db.query('select * from public.personal_goals')).rows.length,0);
    assert.equal((await db.query('select * from public.personal_goal_entries')).rows.length,0);
    await assert.rejects(db.query('insert into public.personal_goals(user_id,title) values($1,$2)',[owner,'Sobrescrever']),/row-level security/);
    await db.exec(`reset role;update public.personal_goals set is_public=true where user_id='${owner}';set role authenticated;`);
    const goal=(await db.query<any>('select public.public_profile_goal($1) as goal',[owner])).rows[0].goal;
    assert.deepEqual(Object.keys(goal).sort(),['is_public','next_step','title']);
    assert.equal(goal.title,'Aprender');
    await db.exec(`reset role;update public.profiles set is_public=false where id='${owner}';set role authenticated;`);
    assert.equal((await db.query<any>('select public.public_profile_goal($1) as goal',[owner])).rows[0].goal,null);
    await db.exec(`reset role;update public.profiles set is_public=true where id='${owner}';
      insert into public.community_blocks values('${owner}','${viewer}');set role authenticated;`);
    assert.equal((await db.query<any>('select public.public_profile_goal($1) as goal',[owner])).rows[0].goal,null);
    assert.equal((await db.query('select * from public.personal_goal_entries')).rows.length,0);
  }finally{await db.close();}
});
