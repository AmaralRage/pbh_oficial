import { PGlite } from 'npm:@electric-sql/pglite@0.3.16';
import assert from 'node:assert/strict';

Deno.test('two ordinary members cannot read, forge, change or delete each other private data', async () => {
  const db = new PGlite();
  const a = 'bb070000-0000-4000-8000-000000000001';
  const b = 'bb070000-0000-4000-8000-000000000002';
  const users = [a, b];
  const tickets: string[] = [], replies: string[] = [], goals: string[] = [];
  const asUser = async (id: string) => {
    await db.exec('reset role');
    await db.query("select set_config('request.jwt.claim.sub',$1,false)", [id]);
    await db.exec('set role authenticated');
  };
  try {
    await db.exec(`create role anon; create role authenticated; create role service_role;
      create schema auth; grant usage on schema auth to anon,authenticated;
      create function auth.uid() returns uuid language sql stable as $$
        select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid $$;
      create table auth.users(id uuid primary key,email text,email_confirmed_at timestamptz,
        raw_user_meta_data jsonb default '{}',raw_app_meta_data jsonb default '{}');
      create table public.community_blocks(blocker_id uuid,blocked_id uuid);`);
    for (const migration of [
      '20261015000100_profiles_and_initial_admin.sql',
      '20261015000300_community_progress.sql',
      '20261017000100_profile_privacy.sql',
      '20261019000100_habit_routine_reminders.sql',
      '20261023000200_native_push_tokens.sql',
      '20261026000800_personal_goals.sql',
      '20261031000200_goal_history.sql',
      '20261105000400_private_founder_identity_support.sql',
      '20261105000500_private_support_replies.sql',
      '20261105000600_support_reply_notifications.sql',
    ]) await db.exec(await Deno.readTextFile(new URL('../migrations/' + migration, import.meta.url)));
    for (let i = 0; i < users.length; i++) {
      const id = users[i];
      await db.exec('reset role');
      await db.query("insert into auth.users(id,email,email_confirmed_at) values($1,$2,now())", [id, `isolation-${i}@example.invalid`]);
      await asUser(id);
      await db.query("insert into public.habit_completions(user_id,habit_key,completed_on) values($1,'read',current_date)", [id]);
      await db.query("insert into public.habit_reminder_settings(user_id) values($1)", [id]);
      await db.query("insert into public.web_push_subscriptions(user_id,endpoint,p256dh,auth) values($1,$2,'fixture','fixture')", [id, `https://example.invalid/push/${i}`]);
      await db.query("select public.register_native_push($1,$2)", [id, `fixture-token-not-a-real-device-${i}`]);
      await db.query("select public.save_personal_goal('Private goal','Read',false,null,null)");
      let goal = (await db.query<any>('select * from public.personal_goals')).rows[0];
      await db.query("insert into public.personal_goal_entries(user_id,goal_title,content,goal_id) values($1,'Private goal','Private entry',$2)", [id, goal.goal_id]);
      await db.query('select public.complete_personal_goal($1,$2)', [goal.goal_id, goal.updated_at]);
      goal = (await db.query<any>('select * from public.personal_goals')).rows[0];
      await db.query("select public.save_personal_goal('Active private goal','Read',false,$1,$2)", [goal.goal_id, goal.updated_at]);
      goals.push((await db.query<any>('select goal_id from public.personal_goals')).rows[0].goal_id);
      tickets.push((await db.query<any>("select public.submit_private_support_request('help','Private ticket') as id")).rows[0].id);
      await db.exec('reset role');
      replies.push((await db.query<any>("insert into public.private_support_replies(request_id,message) values($1,'Private reply') returning id", [tickets[i]])).rows[0].id);
    }
    for (let i = 0; i < users.length; i++) {
      const own = users[i], other = users[1 - i];
      await asUser(own);
      assert.equal((await db.query<any>('select public.is_admin() as value')).rows[0].value, false);
      for (const table of ['habit_completions', 'habit_reminder_settings', 'web_push_subscriptions',
        'personal_goals', 'personal_goal_entries', 'personal_goal_history', 'private_support_requests']) {
        const rows = (await db.query<any>(`select * from public.${table}`)).rows;
        assert.equal(rows.length, 1, `${table}: owner must still see their own fixture`);
        assert.equal(rows[0].user_id, own, `${table}: other owner's row leaked`);
      }
      assert.equal((await db.query<any>('select request_id from public.private_support_replies')).rows[0].request_id, tickets[i]);
      assert.equal((await db.query<any>('select public.public_profile_goal($1) as value', [other])).rows[0].value, null);
      await assert.rejects(db.query('select email from public.profiles'), /permission denied/);
      await assert.rejects(db.query('select * from auth.users'), /permission denied/);
      await assert.rejects(db.query('select * from public.native_push_tokens'), /permission denied/);
      await assert.rejects(db.query("update public.profiles set role='admin' where id=$1", [own]), /permission denied/);
      await assert.rejects(db.query("insert into public.habit_completions(user_id,habit_key,completed_on) values($1,'train',current_date)", [other]), /row-level security/);
      await assert.rejects(db.query("insert into public.web_push_subscriptions(user_id,endpoint,p256dh,auth) values($1,'https://example.invalid/forged','x','x')", [other]), /row-level security/);
      await assert.rejects(db.query("insert into public.private_support_requests(user_id,kind,message) values($1,'help','forged')", [other]), /permission denied/);
      await assert.rejects(db.query("select public.reply_private_support($1,'forged')", [tickets[1 - i]]), /restrito/);
      await assert.rejects(db.query('select public.complete_personal_goal($1,null)', [goals[1 - i]]), /indisponível/);
      for (const table of ['habit_completions', 'web_push_subscriptions', 'personal_goal_entries']) {
        assert.equal((await db.query(`delete from public.${table} where user_id=$1 returning user_id`, [other])).rows.length, 0);
      }
      assert.equal((await db.query('update public.habit_reminder_settings set enabled=true where user_id=$1 returning user_id', [other])).rows.length, 0);
      await assert.rejects(db.query('update public.habit_reminder_settings set user_id=$1 where user_id=$2', [other, own]), /row-level security/);
      await db.query('select public.mark_support_replies_read($1)', [[replies[1 - i]]]);
      await db.query('select public.unregister_native_push($1)', [other]);
      await db.exec('reset role');
      assert.equal((await db.query<any>('select read_at from public.private_support_replies where id=$1', [replies[1 - i]])).rows[0].read_at, null);
      assert.equal((await db.query('select * from public.native_push_tokens where user_id=$1', [other])).rows.length, 1);
    }
    await db.exec('reset role');
    const before = (await db.query<any>('select count(*)::int as count from auth.users')).rows[0].count;
    await db.exec(await Deno.readTextFile(new URL('../audits/member_isolation_rollback.sql', import.meta.url)));
    assert.equal((await db.query<any>('select count(*)::int as count from auth.users')).rows[0].count, before, 'deployed audit must roll back every synthetic user');
    await db.exec(`create schema storage;
      create table storage.buckets(id text,public boolean,file_size_limit bigint,allowed_mime_types text[]);
      create table storage.objects(bucket_id text);`);
    const audit = await Deno.readTextFile(new URL('../audits/security_configuration.sql', import.meta.url));
    const auditRows = (await db.exec(audit)).flatMap(result => result.rows) as any[];
    assert.equal(auditRows.filter(row => 'can_read_profile_email' in row).every(row => row.can_read_profile_email === false && row.can_change_admin_role === false), true);
    // Prove the audit notices a deliberately introduced local misconfiguration.
    await db.exec('grant select(email) on public.profiles to authenticated');
    const unsafe = (await db.exec(audit)).flatMap(result => result.rows) as any[];
    assert.equal(unsafe.some(row => row.role_name === 'authenticated' && row.can_read_profile_email === true), true);
    await db.exec('revoke select(email) on public.profiles from authenticated');
  } finally { await db.close(); }
});
