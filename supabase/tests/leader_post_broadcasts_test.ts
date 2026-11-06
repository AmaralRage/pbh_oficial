import { PGlite } from 'npm:@electric-sql/pglite@0.3';
import assert from 'node:assert/strict';

Deno.test('only the confirmed leader queues one durable broadcast per own post',async()=>{
  const db=new PGlite();
  const leader='bc500000-0000-4000-8000-000000000001',admin='bc500000-0000-4000-8000-000000000002';
  const post='bc500000-0000-4000-8000-000000000003',other='bc500000-0000-4000-8000-000000000004';
  try{
    await db.exec(`create role anon;create role authenticated;create role service_role;
      create schema auth;create schema vault;create schema cron;create schema net;
      grant usage on schema auth to authenticated,anon;
      create function auth.uid() returns uuid language sql stable as $$select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid$$;
      create table auth.users(id uuid primary key,email_confirmed_at timestamptz,raw_app_meta_data jsonb,raw_user_meta_data jsonb);
      create table public.profiles(id uuid primary key,role text);
      create function public.is_admin() returns boolean language sql stable security definer set search_path='' as $$select exists(select 1 from public.profiles where id=auth.uid() and role='admin')$$;
      create table public.community_posts(id uuid primary key,user_id uuid references auth.users(id),content text);
      alter table public.community_posts enable row level security;
      grant delete on public.community_posts to authenticated;
      create policy owner_delete on public.community_posts for delete to authenticated using(user_id=auth.uid());
      create table public.announcements(id uuid primary key default gen_random_uuid(),title text not null,message text not null check(length(message)<=500),
        audience text,destination_url text,sound_enabled boolean,created_by uuid references auth.users(id));
      create table vault.decrypted_secrets(name text,decrypted_secret text);
      create function cron.schedule(text,text,text) returns bigint language sql as $$select 1::bigint$$;
      create function net.http_post(url text,headers jsonb,body jsonb,timeout_milliseconds integer) returns bigint language sql as $$select 1::bigint$$;
      insert into auth.users values('${leader}',now(),'{"pbh_project_leader":true}','{}'),
        ('${admin}',now(),'{"pbh_project_leader":false}','{"pbh_project_leader":true}');
      insert into public.profiles values('${leader}','admin'),('${admin}','admin');
      insert into public.community_posts values('${post}','${leader}',repeat('Test ',200)),('${other}','${admin}','Other post');`);
    const scheduler=(await Deno.readTextFile(new URL('../migrations/20261023000100_scheduled_announcements.sql',import.meta.url)))
      .replace(/^create extension[^;]+;/gm,'');
    await db.exec(scheduler);
    await db.exec(await Deno.readTextFile(new URL('../migrations/20261105000700_leader_post_broadcasts.sql',import.meta.url)));
    const asUser=async(id:string,role='authenticated')=>{
      await db.exec('reset role');await db.query("select set_config('request.jwt.claim.sub',$1,false)",[id]);await db.exec(`set role ${role}`);
    };
    await asUser('', 'anon');
    await assert.rejects(db.query('select public.queue_community_post_broadcast($1)',[post]),/permission denied/);
    await asUser(admin);
    await assert.rejects(db.query('select public.queue_community_post_broadcast($1)',[other]),/Somente/);
    await asUser(leader);
    await assert.rejects(db.query('select public.queue_community_post_broadcast($1)',[other]),/indisponível/);
    const id=(await db.query('select public.queue_community_post_broadcast($1) as id',[post])).rows[0].id;
    assert.equal((await db.query('select public.queue_community_post_broadcast($1) as id',[post])).rows[0].id,id);
    await assert.rejects(db.query('select * from public.community_post_broadcasts'),/permission denied/);
    await db.exec('reset role');
    assert.equal((await db.query('select * from public.community_post_broadcasts')).rows.length,1);
    const notice=(await db.query('select * from public.announcements')).rows[0];
    assert.equal(notice.audience,'all');assert.equal(notice.message.length,500);
    assert.equal(notice.destination_url,`https://pbh-oficial.vercel.app/?community_post=${post}`);
    const job=(await db.query('select * from public.announcement_schedules')).rows[0];
    assert.equal(job.status,'published');assert.equal(job.push_status,'pending');assert.equal(job.announcement_id,id);
    await db.query('update auth.users set email_confirmed_at=null where id=$1',[leader]);
    await asUser(leader);
    await assert.rejects(db.query('select public.queue_community_post_broadcast($1)',[post]),/Somente/);
    await db.exec('reset role');await db.query('update auth.users set email_confirmed_at=now() where id=$1',[leader]);
    await db.query('delete from public.community_posts where id=$1',[post]);
    assert.equal((await db.query('select * from public.announcements')).rows.length,0);
    assert.equal((await db.query('select * from public.announcement_schedules')).rows.length,0);
  }finally{await db.close();}
});
