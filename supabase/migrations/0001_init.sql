-- Schema for News Application Maker
-- Run with: supabase db push   (or apply via the SQL editor)

-- ---------------------------------------------------------------------------
-- bookmarks: one row per (user, article url). Synced from the Flutter app.
-- ---------------------------------------------------------------------------
create table if not exists public.bookmarks (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references auth.users (id) on delete cascade,
  url         text not null,
  article     jsonb not null,
  created_at  timestamptz not null default now(),
  unique (user_id, url)
);

alter table public.bookmarks enable row level security;

-- Owners can fully manage only their own bookmarks.
drop policy if exists "bookmarks_select_own" on public.bookmarks;
create policy "bookmarks_select_own"
  on public.bookmarks for select
  using (auth.uid() = user_id);

drop policy if exists "bookmarks_insert_own" on public.bookmarks;
create policy "bookmarks_insert_own"
  on public.bookmarks for insert
  with check (auth.uid() = user_id);

drop policy if exists "bookmarks_update_own" on public.bookmarks;
create policy "bookmarks_update_own"
  on public.bookmarks for update
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

drop policy if exists "bookmarks_delete_own" on public.bookmarks;
create policy "bookmarks_delete_own"
  on public.bookmarks for delete
  using (auth.uid() = user_id);

-- ---------------------------------------------------------------------------
-- crawl_cache: server-side cache for the crawl-proxy Edge Function.
-- Written/read only by the function (service role), so RLS stays enabled with
-- no public policies.
-- ---------------------------------------------------------------------------
create table if not exists public.crawl_cache (
  mode        text not null,
  url         text not null,
  payload     jsonb not null,
  fetched_at  timestamptz not null default now(),
  primary key (mode, url)
);

create index if not exists crawl_cache_fetched_at_idx
  on public.crawl_cache (fetched_at);

alter table public.crawl_cache enable row level security;
