-- Per-type attributes (PG sharing/food/gender/timing, plot dimensions,
-- commercial seats/lock-in, residential parking, …). One flexible JSONB column
-- keeps the schema stable while each property type stores its own fields.
alter table public.properties_home
  add column if not exists attributes jsonb not null default '{}'::jsonb;
