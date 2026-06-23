-- Store the article title with each interaction so taste analysis can learn
-- specific topics/entities (not just category + source).

alter table public.user_events
  add column if not exists title text;
