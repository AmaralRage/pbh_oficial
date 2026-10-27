begin;
-- HTML is downloaded as plain text, then rendered in an isolated sandbox.
-- Never serve user-provided HTML as an executable page in the Storage origin.
update storage.buckets
set allowed_mime_types = array['image/jpeg','image/png','image/webp','image/gif','text/plain'],
    file_size_limit = 5242880
where id = 'profile-covers';
commit;
