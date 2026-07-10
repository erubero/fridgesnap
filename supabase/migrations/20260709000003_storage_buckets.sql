-- FridgeSnap storage buckets.

-- scan-images (private): fridge photos, uploaded by the client before calling
-- the scan function. Object paths are {user_id}/{uuid}.jpg; the first folder
-- segment must match the caller's uid. The hourly cleanup-scan-images function
-- deletes objects once the scan row passes expires_at.
insert into storage.buckets (id, name, public)
values ('scan-images', 'scan-images', false)
on conflict (id) do nothing;

create policy "read own scan images" on storage.objects
  for select to authenticated
  using (bucket_id = 'scan-images' and (storage.foldername(name))[1] = auth.uid()::text);
create policy "upload own scan images" on storage.objects
  for insert to authenticated
  with check (bucket_id = 'scan-images' and (storage.foldername(name))[1] = auth.uid()::text);
create policy "delete own scan images" on storage.objects
  for delete to authenticated
  using (bucket_id = 'scan-images' and (storage.foldername(name))[1] = auth.uid()::text);

-- recipe-photos (public read): community and Chef's Picks photos. Users upload
-- under their own folder when publishing; everyone can view.
insert into storage.buckets (id, name, public)
values ('recipe-photos', 'recipe-photos', true)
on conflict (id) do nothing;

create policy "read recipe photos" on storage.objects
  for select
  using (bucket_id = 'recipe-photos');
create policy "upload own recipe photos" on storage.objects
  for insert to authenticated
  with check (bucket_id = 'recipe-photos' and (storage.foldername(name))[1] = auth.uid()::text);
create policy "delete own recipe photos" on storage.objects
  for delete to authenticated
  using (bucket_id = 'recipe-photos' and (storage.foldername(name))[1] = auth.uid()::text);
