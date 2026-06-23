-- News AI features: interaction signals + learned taste profile.
-- Run after 0001_init.sql.

-- ---------------------------------------------------------------------------
-- user_events: interaction signals that feed preference learning.
-- One row per (open / bookmark / like / dislike) action.
-- ---------------------------------------------------------------------------
create table if not exists public.user_events (
  id           uuid primary key default gen_random_uuid(),
  user_id      uuid not null references auth.users (id) on delete cascade,
  url          text not null,
  type         text not null
    check (type in ('open', 'bookmark', 'like', 'dislike', 'dismiss')),
  category     text,
  source_name  text,
  created_at   timestamptz not null default now()
);

create index if not exists user_events_user_idx
  on public.user_events (user_id, created_at desc);

alter table public.user_events enable row level security;

drop policy if exists "user_events_select_own" on public.user_events;
create policy "user_events_select_own"
  on public.user_events for select using (auth.uid() = user_id);

drop policy if exists "user_events_insert_own" on public.user_events;
create policy "user_events_insert_own"
  on public.user_events for insert with check (auth.uid() = user_id);

-- ---------------------------------------------------------------------------
-- user_taste: AI-learned preference profile (one row per user).
-- `profile` shape: { category_weights: {..}, keywords: [..], summary: "..." }
-- Written by the ai-taste Edge Function; read by the client to re-rank.
-- ---------------------------------------------------------------------------
create table if not exists public.user_taste (
  user_id     uuid primary key references auth.users (id) on delete cascade,
  profile     jsonb not null default '{}'::jsonb,
  updated_at  timestamptz not null default now()
);

alter table public.user_taste enable row level security;

drop policy if exists "user_taste_select_own" on public.user_taste;
create policy "user_taste_select_own"
  on public.user_taste for select using (auth.uid() = user_id);

-- Writes happen via the Edge Function (service role); no public write policy.

-- ---------------------------------------------------------------------------
-- user_settings: per-user app preferences synced across devices.
-- `enabled_categories` is the set of category ids the user chose to see.
-- A NULL/empty array is treated by the app as "all categories".
-- ---------------------------------------------------------------------------
create table if not exists public.user_settings (
  user_id             uuid primary key references auth.users (id) on delete cascade,
  enabled_categories  text[] not null default '{}',
  updated_at          timestamptz not null default now()
);

alter table public.user_settings enable row level security;

drop policy if exists "user_settings_select_own" on public.user_settings;
create policy "user_settings_select_own"
  on public.user_settings for select using (auth.uid() = user_id);

drop policy if exists "user_settings_upsert_own" on public.user_settings;
create policy "user_settings_upsert_own"
  on public.user_settings for insert with check (auth.uid() = user_id);

drop policy if exists "user_settings_update_own" on public.user_settings;
create policy "user_settings_update_own"
  on public.user_settings for update
  using (auth.uid() = user_id) with check (auth.uid() = user_id);
