-- Run as project owner in SQL Editor. Read-only; no emails, tokens or secrets.
begin read only;

-- Every row must report exists=true, rls=true, anon_can_read=false.
with expected(name) as (values
  ('personal_goals'),('personal_goal_entries'),('personal_goal_history'),
  ('habit_completions'),('habit_reminder_settings'),('native_push_tokens'),
  ('web_push_subscriptions'),('private_support_requests'),('private_support_replies'),
  ('member_badge_awards'),('community_restrictions'),('community_post_broadcasts')
), objects as (
  select name,to_regclass('public.'||name) as id from expected
)
select o.name, c.oid is not null as exists,coalesce(c.relrowsecurity,false) as rls,
  case when c.oid is not null then has_any_column_privilege('anon',c.oid,'select') else null end as anon_can_read
from objects o left join pg_class c on c.oid=o.id order by o.name;

-- All permission flags must be false. A missing schema/column is an error to fix.
select role_name,
  has_column_privilege(role_name,'public.profiles','email','select') as can_read_profile_email,
  has_column_privilege(role_name,'public.profiles','role','update') as can_change_admin_role
from (values ('anon'),('authenticated')) r(role_name);
select role_name,
  has_table_privilege(role_name,'public.native_push_tokens','select') as can_read_native_tokens
from (values ('anon'),('authenticated')) r(role_name);

-- Internal helpers must exist and must not be callable by these client roles.
with expected(signature) as (values
  ('public.assign_project_leader_claim()'),('public.effective_member_badge(uuid)'),
  ('public.claim_habit_reminder(uuid,date)'),('public.release_habit_reminder(uuid,date)')
)
select signature,to_regprocedure(signature) is not null as exists,
  case when to_regprocedure(signature) is not null then has_function_privilege('anon',to_regprocedure(signature),'execute') end as anon_can_execute,
  case when to_regprocedure(signature) is not null then has_function_privilege('authenticated',to_regprocedure(signature),'execute') end as member_can_execute
from expected;

-- Review definer functions missing an explicit search_path. Never blanket-revoke
-- public RPCs: some are intentionally public after their own privacy checks.
select n.nspname as schema,p.proname as function,pg_get_function_identity_arguments(p.oid) as arguments
from pg_proc p join pg_namespace n on n.oid=p.pronamespace
where n.nspname='public' and p.prosecdef and not exists(
  select 1 from unnest(coalesce(p.proconfig,'{}'::text[])) setting where setting like 'search_path=%'
) order by p.proname;

-- Only profile artwork buckets should be public. Community photos stay private.
-- Counts are metadata counts, not proof that actual file bytes can be restored.
select b.id,b.public,b.file_size_limit,b.allowed_mime_types,
  (select count(*) from storage.objects o where o.bucket_id=b.id) as objects,
  case when b.id in ('profile-avatars','profile-covers','profile-backgrounds') then 'public artwork by design'
    when b.public then 'REVIEW: unexpected public bucket' else 'private bucket' end as review
from storage.buckets b order by b.id;

-- Owners of policies and destinations can be reviewed without printing personal data.
select schemaname,tablename,policyname,roles,cmd
from pg_policies where schemaname='storage' and tablename='objects'
order by policyname;
rollback;
