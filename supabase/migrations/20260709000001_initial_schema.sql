-- FridgeSnap initial schema. Canonical shapes for ingredients/steps/nutrition
-- jsonb live in lazychef-spec.md sections 4 and 5.

-- 1. profiles -----------------------------------------------------------------

create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  handle text unique not null,
  dietary_prefs jsonb not null default '{}'::jsonb,
  staples boolean not null default true,
  is_admin boolean not null default false,
  created_at timestamptz not null default now()
);

-- Auto-create a profile row for every new auth user with a placeholder handle.
create function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  insert into public.profiles (id, handle)
  values (new.id, 'chef_' || substr(replace(new.id::text, '-', ''), 1, 8))
  on conflict (id) do nothing;
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- 2. scans ---------------------------------------------------------------------
-- Rows are never deleted by users: count(*) per user is the lifetime free-tier
-- counter, so the 3-free-scans gate survives app reinstalls. image_set_hash
-- keys the 24h result cache; expires_at drives image deletion (privacy label
-- promises photos are deleted after processing).

create table public.scans (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  image_paths text[] not null default '{}',
  image_set_hash text not null,
  ingredients jsonb,
  expires_at timestamptz not null default now() + interval '24 hours',
  images_deleted boolean not null default false,
  created_at timestamptz not null default now()
);

create index scans_user_id_idx on public.scans (user_id);
create index scans_cache_idx on public.scans (user_id, image_set_hash, created_at desc);
create index scans_cleanup_idx on public.scans (expires_at) where not images_deleted;

-- 3. recipes ---------------------------------------------------------------------
-- author_handle is denormalized at publish time so the feed never needs to read
-- other users' profiles (dietary prefs and allergies stay private).

create table public.recipes (
  id uuid primary key default gen_random_uuid(),
  author_id uuid references auth.users (id) on delete set null,
  author_handle text,
  source text not null check (source in ('generated', 'community', 'admin')),
  title text not null,
  description text,
  level text not null check (level in ('lazy_af', 'some_effort', 'chef_mode')),
  time_minutes integer not null,
  servings integer not null default 2,
  ingredients jsonb not null,
  steps jsonb not null,
  nutrition jsonb,
  photo_url text,
  is_published boolean not null default false,
  is_chefs_pick boolean not null default false,
  cooked_count integer not null default 0,
  saves_count integer not null default 0,
  report_count integer not null default 0,
  created_at timestamptz not null default now()
);

create index recipes_author_idx on public.recipes (author_id);
create index recipes_feed_idx on public.recipes (is_published, created_at desc);
create index recipes_chefs_pick_idx on public.recipes (is_chefs_pick) where is_chefs_pick;

-- 4. recipe_saves / recipe_cooks --------------------------------------------------

create table public.recipe_saves (
  user_id uuid not null references auth.users (id) on delete cascade,
  recipe_id uuid not null references public.recipes (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, recipe_id)
);

create table public.recipe_cooks (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  recipe_id uuid not null references public.recipes (id) on delete cascade,
  rating integer check (rating between 1 and 5),
  notes text,
  created_at timestamptz not null default now()
);

create index recipe_cooks_user_idx on public.recipe_cooks (user_id, recipe_id);
create index recipe_cooks_recipe_idx on public.recipe_cooks (recipe_id);

-- Denormalized counters on recipes, maintained by triggers.
create function public.bump_recipe_counter()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  target uuid := coalesce(new.recipe_id, old.recipe_id);
  delta integer := case when tg_op = 'INSERT' then 1 else -1 end;
begin
  if tg_table_name = 'recipe_saves' then
    update public.recipes set saves_count = greatest(saves_count + delta, 0) where id = target;
  elsif tg_table_name = 'recipe_cooks' then
    update public.recipes set cooked_count = greatest(cooked_count + delta, 0) where id = target;
  elsif tg_table_name = 'reports' then
    update public.recipes set report_count = greatest(report_count + delta, 0) where id = target;
  end if;
  return coalesce(new, old);
end;
$$;

create trigger recipe_saves_counter
  after insert or delete on public.recipe_saves
  for each row execute function public.bump_recipe_counter();
create trigger recipe_cooks_counter
  after insert or delete on public.recipe_cooks
  for each row execute function public.bump_recipe_counter();

-- 5. reports / blocked_users (App Review UGC requirements) -------------------------

create table public.reports (
  id uuid primary key default gen_random_uuid(),
  recipe_id uuid not null references public.recipes (id) on delete cascade,
  user_id uuid not null references auth.users (id) on delete cascade,
  reason text not null,
  created_at timestamptz not null default now(),
  unique (recipe_id, user_id)
);

create trigger reports_counter
  after insert or delete on public.reports
  for each row execute function public.bump_recipe_counter();

create table public.blocked_users (
  blocker_id uuid not null references auth.users (id) on delete cascade,
  blocked_id uuid not null references auth.users (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (blocker_id, blocked_id)
);

-- 6. popular_combos (nightly job output, injected into generation prompts) ---------

create table public.popular_combos (
  id uuid primary key default gen_random_uuid(),
  summary text not null,
  updated_at timestamptz not null default now()
);

-- 7. rate_limits (written only by edge functions) -----------------------------------
-- action is e.g. 'scan' (daily window) or 'generate:<scan_id>' (per-scan window).

create table public.rate_limits (
  user_id uuid not null references auth.users (id) on delete cascade,
  action text not null,
  window_start timestamptz not null,
  count integer not null default 0,
  primary key (user_id, action, window_start)
);

-- 8. subscriptions (written only by rc-sync after RevenueCat REST verification) -----

create table public.subscriptions (
  user_id uuid primary key references auth.users (id) on delete cascade,
  entitlement text not null default 'pro',
  is_active boolean not null default false,
  expires_at timestamptz,
  rc_payload jsonb,
  updated_at timestamptz not null default now()
);

-- 9. analytics_events (spec section 10 event names by convention) --------------------

create table public.analytics_events (
  id bigint generated always as identity primary key,
  user_id uuid references auth.users (id) on delete set null,
  name text not null,
  props jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index analytics_events_name_idx on public.analytics_events (name, created_at desc);
