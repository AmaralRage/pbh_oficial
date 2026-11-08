begin;
-- Older remote deployments may have the registration RPC but lack its column.
-- Restore it without changing tokens, account ownership or notification choices.
alter table public.native_push_tokens add column if not exists sound_enabled boolean not null default true;
notify pgrst, 'reload schema';
commit;
