begin;
-- Operational codes only; no message content or device tokens.
alter table public.chat_push_jobs add column last_error text;
commit;
