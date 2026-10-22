-- Public profile photos; writes are restricted to each member's own directory.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('profile-avatars', 'profile-avatars', true, 5242880, array['image/jpeg', 'image/png', 'image/webp'])
on conflict (id) do update set public = excluded.public,
  file_size_limit = excluded.file_size_limit, allowed_mime_types = excluded.allowed_mime_types;

create policy "profile_avatar_public_read" on storage.objects
  for select to public using (bucket_id = 'profile-avatars');
create policy "profile_avatar_owner_insert" on storage.objects
  for insert to authenticated with check (
    bucket_id = 'profile-avatars' and (storage.foldername(name))[1] = (select auth.uid())::text
  );
create policy "profile_avatar_owner_delete" on storage.objects
  for delete to authenticated using (
    bucket_id = 'profile-avatars' and (storage.foldername(name))[1] = (select auth.uid())::text
  );

-- An explicit empty avatar must clear the community photo too. The existing
-- sync trigger preserves old non-null values, so this narrow trigger runs after it.
create or replace function public.sync_explicit_profile_avatar()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if new.raw_user_meta_data ? 'avatar_url' then
    update public.profiles set avatar_url = nullif(btrim(new.raw_user_meta_data ->> 'avatar_url'), '')
    where id = new.id;
  end if;
  return new;
end;
$$;
revoke all on function public.sync_explicit_profile_avatar() from public, anon, authenticated;
create trigger zz_sync_explicit_profile_avatar
after update of raw_user_meta_data on auth.users
for each row execute function public.sync_explicit_profile_avatar();
