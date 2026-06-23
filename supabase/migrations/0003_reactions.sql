-- Allow explicit like / dislike interaction events (in addition to the
-- original open / bookmark / dismiss). Run on an existing database to widen
-- the user_events.type check constraint.

alter table public.user_events
  drop constraint if exists user_events_type_check;

alter table public.user_events
  add constraint user_events_type_check
  check (type in ('open', 'bookmark', 'like', 'dislike', 'dismiss'));
