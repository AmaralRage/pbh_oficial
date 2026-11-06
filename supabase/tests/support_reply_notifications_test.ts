import { PGlite } from 'npm:@electric-sql/pglite@0.3';
import assert from 'node:assert/strict';

Deno.test('support reply alerts preserve ownership and never mark later replies read', async () => {
  const db = new PGlite();
  const leader = 'ef500000-0000-4000-8000-000000000001';
  const member = 'ef500000-0000-4000-8000-000000000002';
  const other = 'ef500000-0000-4000-8000-000000000003';
  try {
    await db.exec(`create role anon; create role authenticated; create schema auth;
      grant usage on schema auth to anon,authenticated;
      create function auth.uid() returns uuid language sql stable as $$
        select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid $$;
      create table auth.users(id uuid primary key,email text,email_confirmed_at timestamptz,
        raw_app_meta_data jsonb,raw_user_meta_data jsonb);
      create function public.is_admin() returns boolean language sql stable as $$
        select auth.uid()='${leader}'::uuid $$;`);
    const migration = await Deno.readTextFile(new URL('../migrations/20261105000400_private_founder_identity_support.sql', import.meta.url));
    const email = migration.match(/lower\(coalesce\(new.email,''\)\)='([^']+)'/)![1];
    await db.query(`insert into auth.users values
      ($1,$2,now(),' {"provider":"email"}', '{}'),
      ($3,'member@example.invalid',now(),'{"pbh_project_leader":true}', '{"pbh_project_leader":true}'),
      ($4,'other@example.invalid',now(),'{}','{}')`, [leader,email,member,other]);
    await db.exec(migration);
    await db.exec(await Deno.readTextFile(new URL('../migrations/20261105000500_private_support_replies.sql',import.meta.url)));
    await db.exec(await Deno.readTextFile(new URL('../migrations/20261105000600_support_reply_notifications.sql',import.meta.url)));
    const claims = (await db.query<{id:string,raw_app_meta_data:Record<string,unknown>}>(
      'select id,raw_app_meta_data from auth.users order by id')).rows;
    assert.equal(claims[0].raw_app_meta_data.pbh_project_leader,true);
    assert.equal(claims[0].raw_app_meta_data.provider,'email');
    assert.equal(claims[1].raw_app_meta_data.pbh_project_leader,false);
    await db.query("update auth.users set raw_app_meta_data=raw_app_meta_data||'{\"pbh_project_leader\":true}' where id=$1",[member]);
    assert.equal((await db.query<{claim:boolean}>("select (raw_app_meta_data->>'pbh_project_leader')::boolean as claim from auth.users where id=$1",[member])).rows[0].claim,false);
    await db.query('update auth.users set email_confirmed_at=null where id=$1',[leader]);
    assert.equal((await db.query<{claim:boolean}>("select (raw_app_meta_data->>'pbh_project_leader')::boolean as claim from auth.users where id=$1",[leader])).rows[0].claim,false);
    await db.query('update auth.users set email_confirmed_at=now() where id=$1',[leader]);
    const asUser=async(id:string,role='authenticated')=>{
      await db.exec('reset role');
      await db.query("select set_config('request.jwt.claim.sub',$1,false)",[id]);
      await db.exec(`set role ${role}`);
    };
    await asUser('', 'anon');
    await assert.rejects(db.query("select public.submit_private_support_request('help','test')"),/permission denied/);
    await asUser(member);
    await assert.rejects(db.query('select email from auth.users'),/permission denied/);
    await assert.rejects(db.query("select public.assign_project_leader_claim()"),/permission denied/);
    await assert.rejects(db.query("select public.submit_private_support_request('other','test')"),/Revise/);
    await assert.rejects(db.query("select public.submit_private_support_request('help','  ')"),/Revise/);
    const id=(await db.query<{id:string}>("select public.submit_private_support_request('account_deletion','Delete my account') as id")).rows[0].id;
    assert.equal((await db.query('select * from public.private_support_requests')).rows.length,1);
    await assert.rejects(db.query("select public.reply_private_support($1,'forged')",[id]),/restrito/);
    await assert.rejects(db.query("insert into public.private_support_requests(user_id,kind,message) values($1,'help','forged')",[other]),/permission denied/);
    await db.query('update public.private_support_requests set resolved=true where id=$1',[id]);
    await asUser(other);
    assert.equal((await db.query('select * from public.private_support_requests')).rows.length,0);
    await asUser(leader);
    const row=(await db.query<{user_id:string,resolved:boolean}>('select * from public.private_support_requests where id=$1',[id])).rows[0];
    assert.equal(row.user_id,member);assert.equal(row.resolved,false);
    await db.query("select public.reply_private_support($1,'Private response')",[id]);
    await asUser(other); assert.equal((await db.query('select * from public.private_support_replies')).rows.length,0);
    await asUser(member); assert.equal((await db.query('select * from public.private_support_replies')).rows.length,1);
    const count=async()=>Number((await db.query('select public.support_reply_unread_count() as n')).rows[0].n);
    assert.equal(await count(),1);
    assert.equal((await db.query('select public.latest_unread_support_request() as r')).rows[0].r.id,id);
    const first=(await db.query('select id from public.private_support_replies')).rows.map(r=>r.id);
    await asUser(other);assert.equal(await count(),0);
    assert.equal((await db.query('select public.latest_unread_support_request() as r')).rows[0].r,null);
    await db.query('select public.mark_support_replies_read($1)',[first]);
    await asUser(leader);await db.query('select public.mark_support_replies_read($1)',[first]);
    await asUser(member);assert.equal(await count(),1);
    await asUser(leader);await db.query("select public.reply_private_support($1,'Later reply')",[id]);
    await asUser(member);await db.query('select public.mark_support_replies_read($1)',[first]);
    assert.equal(await count(),1);
    await assert.rejects(db.query('update public.private_support_replies set read_at=now()'),/permission denied/);
    const all=(await db.query('select id from public.private_support_replies')).rows.map(r=>r.id);
    await db.query('select public.mark_support_replies_read($1)',[all]);assert.equal(await count(),0);
    await asUser(leader);
    await db.query('update public.private_support_requests set resolved=true where id=$1',[id]);
    await assert.rejects(db.query("update public.private_support_requests set user_id=$1 where id=$2",[other,id]),/permission denied/);
    await asUser(member);
    for(let i=0;i<19;i++) await db.query("select public.submit_private_support_request('help','test')");
    await assert.rejects(db.query("select public.submit_private_support_request('help','test')"),/Limite/);
  } finally { await db.close(); }
});
