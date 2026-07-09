-- LazyChef row level security. Convention: per-verb named policies.
-- Tables with RLS enabled and NO policies are service-role only: scans (insert),
-- recipes (all writes), rate_limits, subscriptions, popular_combos.

-- profiles: own row only. Other users' handles reach the feed via the
-- denormalized recipes.author_handle, so no cross-user select is needed.
alter table public.profiles enable row level security;

create policy "select own profile" on public.profiles
  for select using (id = auth.uid());
create policy "update own profile" on public.profiles
  for update using (id = auth.uid()) with check (id = auth.uid());

-- scans: read own history. Inserts happen only in the scan edge function
-- (service role) so the lifetime free-scan count stays authoritative; no
-- client insert/update/delete.
alter table public.scans enable row level security;

create policy "select own scans" on public.scans
  for select using (user_id = auth.uid());

-- recipes: readers see published recipes and their own generated ones. All
-- writes go through edge functions or the admin import script (service role):
-- generate inserts, publish-recipe flips is_published after moderation.
alter table public.recipes enable row level security;

create policy "select published or own recipes" on public.recipes
  for select using (is_published or author_id = auth.uid());

-- recipe_saves: own rows.
alter table public.recipe_saves enable row level security;

create policy "select own saves" on public.recipe_saves
  for select using (user_id = auth.uid());
create policy "insert own saves" on public.recipe_saves
  for insert with check (user_id = auth.uid());
create policy "delete own saves" on public.recipe_saves
  for delete using (user_id = auth.uid());

-- recipe_cooks: own rows; rating and notes are editable.
alter table public.recipe_cooks enable row level security;

create policy "select own cooks" on public.recipe_cooks
  for select using (user_id = auth.uid());
create policy "insert own cooks" on public.recipe_cooks
  for insert with check (user_id = auth.uid());
create policy "update own cooks" on public.recipe_cooks
  for update using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy "delete own cooks" on public.recipe_cooks
  for delete using (user_id = auth.uid());

-- reports: write-only for users; admins review via dashboard (service role).
alter table public.reports enable row level security;

create policy "insert own reports" on public.reports
  for insert with check (user_id = auth.uid());

-- blocked_users: own block list.
alter table public.blocked_users enable row level security;

create policy "select own blocks" on public.blocked_users
  for select using (blocker_id = auth.uid());
create policy "insert own blocks" on public.blocked_users
  for insert with check (blocker_id = auth.uid());
create policy "delete own blocks" on public.blocked_users
  for delete using (blocker_id = auth.uid());

-- analytics_events: fire-and-forget inserts, never readable by clients.
alter table public.analytics_events enable row level security;

create policy "insert own events" on public.analytics_events
  for insert with check (user_id = auth.uid());

-- Service-role only tables: RLS on, no policies.
alter table public.popular_combos enable row level security;
alter table public.rate_limits enable row level security;
alter table public.subscriptions enable row level security;
