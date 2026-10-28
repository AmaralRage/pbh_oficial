begin;
-- Privacy settings read these columns on the signed-in user's own row.
-- Keep the existing RLS policies and all other column permissions unchanged.
grant select (id, is_public, share_progress) on public.profiles to authenticated;
commit;
