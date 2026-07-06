-- Schema for News Application Maker
-- Run with: supabase db push   (or apply via the SQL editor)

-- ---------------------------------------------------------------------------
-- user_holdings: the user's "내 주식" list, synced across devices.
-- The whole ordered list is stored as one jsonb array so the user's manual
-- ordering is preserved. Written by the Flutter client (upsert on user_id).
-- `holdings` shape: [{ code, reutersCode, name, market, exchange }, ...]
-- ---------------------------------------------------------------------------
create table if not exists public.user_holdings (
  user_id     uuid primary key references auth.users (id) on delete cascade,
  holdings    jsonb not null default '[]'::jsonb,
  updated_at  timestamptz not null default now()
);

alter table public.user_holdings enable row level security;

drop policy if exists "user_holdings_select_own" on public.user_holdings;
create policy "user_holdings_select_own"
  on public.user_holdings for select using (auth.uid() = user_id);

drop policy if exists "user_holdings_insert_own" on public.user_holdings;
create policy "user_holdings_insert_own"
  on public.user_holdings for insert with check (auth.uid() = user_id);

drop policy if exists "user_holdings_update_own" on public.user_holdings;
create policy "user_holdings_update_own"
  on public.user_holdings for update
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);
