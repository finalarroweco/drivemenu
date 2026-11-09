-- upsert uploads need SELECT + UPDATE on the owner's own folder
create policy "owners read images" on storage.objects for select to authenticated
using (bucket_id = 'menu-images' and public.is_owner_text((storage.foldername(name))[1]));
drop policy if exists "owners update images" on storage.objects;
create policy "owners update images" on storage.objects for update to authenticated
using (bucket_id = 'menu-images' and public.is_owner_text((storage.foldername(name))[1]))
with check (bucket_id = 'menu-images' and public.is_owner_text((storage.foldername(name))[1]));
