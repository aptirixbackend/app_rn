-- =====================================================================
-- 0008_storage_policies.sql — let the app write to the public
-- `property-media` bucket.
--
-- The Flutter app uploads with the anon key and NO Supabase session (auth is
-- backend-owned), so without an insert policy every upload hits an RLS 403 and
-- posted photos silently fall back to a placeholder asset. This is
-- dev-permissive (consistent with the app's other policies); harden later by
-- routing uploads through the backend (service key), which bypasses RLS.
-- =====================================================================

drop policy if exists "property-media anon write" on storage.objects;
create policy "property-media anon write"
    on storage.objects for all
    to anon, authenticated
    using (bucket_id = 'property-media')
    with check (bucket_id = 'property-media');
