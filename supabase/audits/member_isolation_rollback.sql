-- Execute this ENTIRE file in SQL Editor as project owner, preferably in staging.
-- Uses two synthetic users, never existing member IDs. All writes roll back.
-- If interrupted or any assertion fails, execute ROLLBACK before other commands.
-- Does not sign in through Auth HTTP; validates deployed SQL grants/RLS/RPCs.
begin;
do $$
declare
  members uuid[] := array[gen_random_uuid(),gen_random_uuid()];
  tickets uuid[] := '{}'::uuid[];
  replies uuid[] := '{}'::uuid[];
  own uuid; other uuid; ticket uuid; reply uuid;
  goal public.personal_goals;
  i integer; affected integer; table_name text;
begin
  for i in 1..2 loop
    own:=members[i];
    insert into auth.users(id,email,email_confirmed_at,raw_user_meta_data,raw_app_meta_data)
      values(own,'security-fixture-'||own::text||'@example.invalid',now(),'{"display_name":"Security fixture"}','{}');
    perform set_config('request.jwt.claim.sub',own::text,true);
    execute 'set local role authenticated';
    if public.is_admin() then raise exception 'Fixture unexpectedly has administrative access'; end if;
    insert into public.habit_completions(user_id,habit_key,completed_on) values(own,'read',current_date);
    insert into public.habit_reminder_settings(user_id) values(own);
    insert into public.web_push_subscriptions(user_id,endpoint,p256dh,auth)
      values(own,'https://example.invalid/security-fixture/'||own::text,'fixture','fixture');
    perform public.register_native_push(own,'security-fixture-not-a-real-device-'||own::text);
    perform public.save_personal_goal('Security fixture','Private',false,null,null);
    select * into goal from public.personal_goals where user_id=own;
    insert into public.personal_goal_entries(user_id,goal_title,content,goal_id)
      values(own,goal.title,'Security fixture private entry',goal.goal_id);
    perform public.complete_personal_goal(goal.goal_id,goal.updated_at);
    ticket:=public.submit_private_support_request('help','Security fixture rolled back');
    tickets:=array_append(tickets,ticket);
    execute 'reset role';
    insert into public.private_support_replies(request_id,message)
      values(ticket,'Security fixture rolled back') returning id into reply;
    replies:=array_append(replies,reply);
  end loop;
  for i in 1..2 loop
    own:=members[i]; other:=members[3-i];
    perform set_config('request.jwt.claim.sub',own::text,true);
    execute 'set local role authenticated';
    foreach table_name in array array['habit_completions','habit_reminder_settings','web_push_subscriptions',
      'personal_goals','personal_goal_entries','personal_goal_history','private_support_requests'] loop
      execute format('select count(*) from public.%I where user_id=$1',table_name) into affected using own;
      if affected<>1 then raise exception 'Own fixture unavailable in %',table_name; end if;
      execute format('select count(*) from public.%I where user_id=$1',table_name) into affected using other;
      if affected<>0 then raise exception 'Cross-account read in %',table_name; end if;
    end loop;
    if (select count(*) from public.private_support_replies where request_id=tickets[i])<>1
      or exists(select 1 from public.private_support_replies where request_id=tickets[3-i]) then
      raise exception 'Support reply isolation failed';
    end if;
    begin
      perform email from public.profiles where id=other;
      raise exception 'Member can select profile email';
    exception when insufficient_privilege then null; end;
    begin
      update public.profiles set role='admin' where id=own;
      raise exception 'Member can change administrative role';
    exception when insufficient_privilege then null; end;
    begin
      perform token from public.native_push_tokens where user_id=other;
      raise exception 'Member can read native push credentials';
    exception when insufficient_privilege then null; end;
    begin
      insert into public.habit_completions(user_id,habit_key,completed_on) values(other,'train',current_date);
      raise exception 'Member can forge other habits';
    exception when insufficient_privilege then null; end;
    begin
      insert into public.web_push_subscriptions(user_id,endpoint,p256dh,auth)
        values(other,'https://example.invalid/forged/'||own::text,'fixture','fixture');
      raise exception 'Member can forge other push subscriptions';
    exception when insufficient_privilege then null; end;
    begin
      perform public.reply_private_support(tickets[3-i],'Forged fixture');
      raise exception 'Member can call administrative support reply';
    exception when insufficient_privilege then null; end;
    foreach table_name in array array['habit_completions','web_push_subscriptions','personal_goal_entries'] loop
      execute format('delete from public.%I where user_id=$1',table_name) using other;
      get diagnostics affected=row_count;
      if affected<>0 then raise exception 'Cross-account delete in %',table_name; end if;
    end loop;
    update public.habit_reminder_settings set enabled=true where user_id=other;
    get diagnostics affected=row_count;
    if affected<>0 then raise exception 'Cross-account reminder update'; end if;
    perform public.mark_support_replies_read(array[replies[3-i]]);
    perform public.unregister_native_push(other);
    execute 'reset role';
    if exists(select 1 from public.private_support_replies where id=replies[3-i] and read_at is not null)
      or not exists(select 1 from public.native_push_tokens where user_id=other) then
      raise exception 'Cross-account RPC changed another fixture';
    end if;
  end loop;
end $$;
rollback;
select 'PASS: two-member SQL isolation; all fixtures rolled back' as result;
