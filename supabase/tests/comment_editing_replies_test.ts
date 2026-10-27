import { PGlite } from 'npm:@electric-sql/pglite@0.3';
import assert from 'node:assert/strict';
Deno.test('only owners edit; replies stay within the post and respect blocks',async()=>{
  const db=new PGlite();
  const a='ad270000-0000-4000-8000-000000000001',b='ad270000-0000-4000-8000-000000000002';
  const post='ad270000-0000-4000-8000-000000000003',otherPost='ad270000-0000-4000-8000-000000000004';
  try{
    await db.exec(`create role anon;create role authenticated;create schema auth;
      create function auth.uid() returns uuid language sql stable as $$select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid$$;
      create table public.profiles(id uuid primary key,display_name text,is_public boolean,avatar_url text);
      create table public.community_blocks(blocker_id uuid,blocked_id uuid);
      create table public.community_comments(id uuid primary key default gen_random_uuid(),post_id uuid,user_id uuid,content text,created_at timestamptz default now());
      create table public.community_sample_comments(id uuid primary key default gen_random_uuid(),sample_post_key text,user_id uuid,content text,created_at timestamptz default now());
      grant usage on schema auth to authenticated;
      grant insert(post_id,user_id,content) on public.community_comments to authenticated;
      grant insert(sample_post_key,user_id,content) on public.community_sample_comments to authenticated;
      alter table public.community_comments enable row level security;
      alter table public.community_sample_comments enable row level security;
      create policy own_insert on public.community_comments for insert to authenticated with check(user_id=auth.uid());
      create policy own_sample_insert on public.community_sample_comments for insert to authenticated with check(user_id=auth.uid());
      insert into public.profiles values('${a}','Autor',true,null),('${b}','Visitante',true,null);`);
    await db.exec(await Deno.readTextFile(new URL('../migrations/20261027000400_comment_editing_replies.sql',import.meta.url)));
    for(const sample of [false,true]){
      const table=sample?'community_sample_comments':'community_comments';
      const column=sample?'sample_post_key':'post_id';
      const key=sample?'sample-samuel':post;
      const parent=(await db.query<any>(`insert into public.${table}(${column},user_id,content) values($1,$2,'original') returning *`,[key,a])).rows[0];
      await db.exec(`select set_config('request.jwt.claim.sub','${b}',false);set role authenticated`);
      await assert.rejects(db.query('select public.edit_community_comment($1,$2,$3)',[parent.id,'forged',sample]),/próprio comentário/);
      await db.exec(`select set_config('request.jwt.claim.sub','${a}',false)`);
      await db.query('select public.edit_community_comment($1,$2,$3)',[parent.id,'edited',sample]);
      await assert.rejects(db.query('select public.edit_community_comment($1,$2,$3)',[parent.id,' ',sample]));
      await db.exec('reset role');
      const edited=(await db.query<any>(`select * from public.${table} where id=$1`,[parent.id])).rows[0];
      assert.equal(edited.content,'edited');assert.ok(edited.edited_at);
      assert.equal(String(edited.created_at),String(parent.created_at));
      await db.exec(`select set_config('request.jwt.claim.sub','${b}',false);set role authenticated`);
      await db.query(`insert into public.${table}(${column},user_id,content,reply_to_id) values($1,$2,'reply',$3)`,[key,b,parent.id]);
      await assert.rejects(db.query(`insert into public.${table}(${column},user_id,content,reply_to_id) values($1,$2,'wrong post',$3)`,[sample?'sample-chad':otherPost,b,parent.id]),/original/);
      await db.exec(`reset role;insert into public.community_blocks values('${a}','${b}');set role authenticated`);
      await assert.rejects(db.query(`insert into public.${table}(${column},user_id,content,reply_to_id) values($1,$2,'blocked',$3)`,[key,b,parent.id]),/responder/);
      const view=sample?'community_sample_comment_feed':'community_comment_feed';
      assert.equal((await db.query<any>(`select * from public.${view} where id=$1`,[parent.id])).rows.length,0);
      await db.exec('reset role;delete from public.community_blocks');
    }
  }finally{await db.close();}
});
