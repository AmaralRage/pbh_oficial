import { PGlite } from 'npm:@electric-sql/pglite@0.3';
import assert from 'node:assert/strict';

Deno.test('profile backgrounds keep ownership and profile privacy', async () => {
  const db = new PGlite();
  const owner='ad300000-0000-4000-8000-000000000001', viewer='ad300000-0000-4000-8000-000000000002';
  const path=`${owner}/123456.png`;
  try {
    await db.exec(`create role anon;create role authenticated;create schema auth;create schema storage;
      grant usage on schema auth,storage to anon,authenticated;
      create function auth.uid() returns uuid language sql stable as $$select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid$$;
      create table auth.users(id uuid primary key,email text,email_confirmed_at timestamptz,raw_user_meta_data jsonb);
      create table public.profiles(id uuid primary key,display_name text,avatar_url text,is_public boolean,share_progress boolean);
      create table public.community_blocks(blocker_id uuid,blocked_id uuid);
      create table public.challenge_catalog(id text primary key,total_days integer);
      create table public.challenge_day_completions(user_id uuid,challenge_id text,completed_on date);
      create table public.challenge_journey_members(journey_id text,challenge_id text);
      create table public.community_follows(follower_id uuid,followed_id uuid);
      create table public.profile_achievement_awards(user_id uuid,achievement_key text);
      create table public.habit_reminder_settings(user_id uuid,time_zone text,selected_habit_keys text[],updated_at timestamptz);
      create table public.habit_completions(user_id uuid,completed_on date,habit_key text);
      create table storage.buckets(id text primary key,name text,public boolean,file_size_limit bigint,allowed_mime_types text[]);
      create table storage.objects(bucket_id text,name text,primary key(bucket_id,name));
      create function storage.foldername(p_name text) returns text[] language sql immutable as $$select string_to_array(p_name,'/')$$;
      alter table storage.objects enable row level security;
      grant select,insert,delete on storage.objects to anon,authenticated;
      insert into auth.users values('${owner}','member@example.invalid',now(),'{}'),('${viewer}','viewer@example.invalid',now(),'{}');
      insert into public.profiles values('${owner}','Member',null,true,false);`);
    await db.exec(await Deno.readTextFile(new URL('../migrations/20261030000400_profile_backgrounds.sql',import.meta.url)));
    const asUser=async(id:string,role='authenticated')=>{
      await db.exec('reset role');await db.query("select set_config('request.jwt.claim.sub',$1,false)",[id]);await db.exec(`set role ${role}`);
    };
    await asUser(viewer);
    await assert.rejects(db.query("insert into storage.objects values('profile-backgrounds',$1)",[path]),/row-level security/);
    await asUser(owner);
    await assert.rejects(db.query("insert into storage.objects values('profile-backgrounds',$1)",[`${owner}/123.html`]),/row-level security/);
    await db.query("insert into storage.objects values('profile-backgrounds',$1)",[path]);
    await db.exec('reset role');
    const setStyle=async(style:object)=>{
      await db.exec('reset role');await db.query("update auth.users set raw_user_meta_data=jsonb_build_object('profile_style',$1::jsonb) where id=$2",[JSON.stringify(style),owner]);await asUser(viewer);
    };
    const read=async()=>(await db.query<any>('select public.community_member_profile($1) as profile',[owner])).rows[0].profile;
    await setStyle({background:'custom',background_path:path,background_dim:9});
    let profile=await read();assert.equal(profile.style.background,'custom');assert.equal(profile.style.background_path,path);assert.equal(profile.style.background_dim,.85);
    assert.equal(profile.progress,undefined);assert.equal(profile.email,undefined);
    await setStyle({background:'script',background_path:`${viewer}/999.png`,background_dim:-1});
    profile=await read();assert.equal(profile.style.background,'none');assert.equal(profile.style.background_path,'');assert.equal(profile.style.background_dim,0);
    await db.exec('reset role');await db.query('update public.profiles set is_public=false where id=$1',[owner]);await asUser(viewer);assert.equal(await read(),null);
    await db.exec('reset role');await db.query('update public.profiles set is_public=true where id=$1',[owner]);await db.query('insert into public.community_blocks values($1,$2)',[owner,viewer]);await asUser(viewer);assert.equal(await read(),null);
    await db.query("delete from storage.objects where bucket_id='profile-backgrounds' and name=$1",[path]);
    assert.equal((await db.query('select * from storage.objects')).rows.length,1);
    await asUser(owner);await db.query("delete from storage.objects where name=$1",[path]);assert.equal((await db.query('select * from storage.objects')).rows.length,0);
    await db.exec('reset role');
    const bucket=(await db.query<any>('select * from storage.buckets')).rows[0];assert.equal(bucket.public,true);assert.equal(Number(bucket.file_size_limit),5242880);
  } finally { await db.close(); }
});
