-- RLS hardening pass. Closes gaps found in a security review of the M1
-- schema/policies: a privilege-escalation hole on profiles.is_admin, missing
-- visibility checks on recipe_saves/recipe_cooks/reports (IDOR-adjacent),
-- no auto-unpublish on the report threshold (risk register item 1), and no
-- storage upload limits. Additive only; nothing here removes access that
-- legitimate clients rely on today.

-- 1. profiles: stop clients from writing is_admin through the "own row"
-- update policy. RLS only checks row ownership, not which columns changed,
-- so `update profiles set is_admin = true where id = auth.uid()` currently
-- succeeds for any signed-in user. A BEFORE UPDATE trigger pins is_admin
-- back to its previous value unless the write comes from the service role
-- (edge functions, admin dashboard) -- the standard Supabase pattern for
-- protecting a privileged column without a second table.
create function public.protect_profile_privileges()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if auth.role() <> 'service_role' then
    new.is_admin := old.is_admin;
  end if;
  return new;
end;
$$;

create trigger profiles_protect_privileges
  before update on public.profiles
  for each row execute function public.protect_profile_privileges();

-- Defensive shape/format constraints (fresh project, no existing rows to
-- violate these; the handle_new_user trigger's generated handles already fit).
alter table public.profiles
  add constraint profiles_handle_format check (handle ~ '^[a-z0-9_]{3,24}$'),
  add constraint profiles_dietary_prefs_is_object check (jsonb_typeof(dietary_prefs) = 'object');

-- 2. recipes: bound sizes so a bug in an edge function (or a future direct
-- insert path) can't wedge oversized rows into the feed.
alter table public.recipes
  add constraint recipes_title_length check (char_length(title) between 1 and 200),
  add constraint recipes_description_length check (description is null or char_length(description) <= 1000),
  add constraint recipes_time_minutes_range check (time_minutes between 1 and 180),
  add constraint recipes_servings_range check (servings between 1 and 12);

-- 3. recipe_saves / recipe_cooks: the insert (and, for cooks, update) checks
-- only verified user_id = auth.uid(). They did not verify the referenced
-- recipe is actually visible to the caller (published, or their own
-- unpublished generation), so a client that learned a stray recipe_id
-- (another user's unpublished draft, a since-unpublished recipe) could still
-- save/cook against it and inflate its counters. Tighten both to require
-- visibility, matching the recipes select policy exactly.
drop policy "insert own saves" on public.recipe_saves;
create policy "insert own saves" on public.recipe_saves
  for insert with check (
    user_id = auth.uid()
    and exists (
      select 1 from public.recipes r
      where r.id = recipe_id and (r.is_published or r.author_id = auth.uid())
    )
  );

drop policy "insert own cooks" on public.recipe_cooks;
create policy "insert own cooks" on public.recipe_cooks
  for insert with check (
    user_id = auth.uid()
    and exists (
      select 1 from public.recipes r
      where r.id = recipe_id and (r.is_published or r.author_id = auth.uid())
    )
  );

drop policy "update own cooks" on public.recipe_cooks;
create policy "update own cooks" on public.recipe_cooks
  for update using (user_id = auth.uid())
  with check (
    user_id = auth.uid()
    and exists (
      select 1 from public.recipes r
      where r.id = recipe_id and (r.is_published or r.author_id = auth.uid())
    )
  );

alter table public.recipe_cooks
  add constraint recipe_cooks_notes_length check (notes is null or char_length(notes) <= 2000);

-- 4. reports: same visibility gap, plus nothing stopped a user from
-- reporting their own recipe (harmless alone, but combined with the new
-- auto-unpublish trigger below it would let an author yank their own
-- published recipe on a whim and muddy the report signal). Require the
-- recipe be published and authored by someone else.
drop policy "insert own reports" on public.reports;
create policy "insert own reports" on public.reports
  for insert with check (
    user_id = auth.uid()
    and exists (
      select 1 from public.recipes r
      where r.id = recipe_id and r.is_published and r.author_id is distinct from auth.uid()
    )
  );

alter table public.reports
  add constraint reports_reason_length check (char_length(reason) between 1 and 500);

-- Risk register item 1 (App Review UGC guideline 1.2): report AND block-user
-- AND moderation must all demonstrably work. Report and block already exist;
-- this closes the missing piece, auto-unpublish at the 3-report threshold
-- pending admin review, exactly as documented in the spec and CLAUDE.md.
-- security definer because the inserting user has no update grant on
-- recipes (no client update policy exists there by design).
create function public.auto_unpublish_reported_recipes()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  total_reports integer;
begin
  select count(*) into total_reports from public.reports where recipe_id = new.recipe_id;
  if total_reports >= 3 then
    update public.recipes set is_published = false where id = new.recipe_id and is_published = true;
  end if;
  return new;
end;
$$;

create trigger reports_auto_unpublish
  after insert on public.reports
  for each row execute function public.auto_unpublish_reported_recipes();

-- 5. blocked_users: a self-block is inert but wastes a row and complicates
-- feed-filtering logic ("exclude blocked authors, but not yourself" becomes
-- unnecessary if it can't happen). Enforce at the table level, not just in
-- client code.
alter table public.blocked_users
  add constraint blocked_users_no_self_block check (blocker_id <> blocked_id);

-- 6. analytics_events: insert-only and never client-readable already, but
-- nothing stopped arbitrary event names or oversized props from a
-- compromised or buggy client. Allow-list the event names the app actually
-- emits (spec section 10) and cap payload size.
alter table public.analytics_events
  add constraint analytics_events_known_name check (name in (
    'scan_completed', 'ingredients_edited', 'level_selected',
    'recipe_generated', 'recipe_regenerated', 'cook_started', 'cook_completed',
    'recipe_saved', 'recipe_published', 'recipe_cooked_community',
    'paywall_shown', 'trial_started', 'subscribed'
  )),
  add constraint analytics_events_props_size check (octet_length(props::text) <= 4096);

-- 7. Storage: neither bucket had a size or MIME restriction, so an
-- authenticated user could upload arbitrarily large or non-image files into
-- their own folder (cost abuse; recipe-photos is public-read, so it could
-- also serve arbitrary file types to anyone). Cap both at 8 MB, images only.
update storage.buckets
set file_size_limit = 8388608, allowed_mime_types = array['image/jpeg', 'image/png']
where id in ('scan-images', 'recipe-photos');
