-- =====================================================================
-- 0002_properties.sql — Property listings (properties_home).
-- =====================================================================

drop table if exists public.properties cascade;

create table if not exists public.properties_home (
    id            uuid primary key default gen_random_uuid(),
    owner_id      uuid not null references public.profiles_home(id) on delete cascade,

    poster_type   text, -- owner / broker / builder / representative

    property_type text, -- apartment / villa / independent_house / plot / others
    purpose       text, -- sell / rent / pg_coliving / lease
    bhk           text,
    bathrooms     int,
    carpet_area   numeric,
    area_unit     text default 'sqft',
    furnishing    text,
    floor_number  int,
    total_floors  int,
    property_age  text,
    facing        text,
    available_from date,

    status        text not null default 'draft',
    created_at    timestamptz not null default now(),
    updated_at    timestamptz not null default now()
);

create index if not exists properties_home_owner_idx on public.properties_home(owner_id);
create index if not exists properties_home_status_idx on public.properties_home(status);

drop trigger if exists trg_properties_home_updated on public.properties_home;
create trigger trg_properties_home_updated
    before update on public.properties_home
    for each row execute function public.set_updated_at_home();

-- ROW LEVEL SECURITY --------------------------------------------------
alter table public.properties_home enable row level security;

drop policy if exists "own properties - all" on public.properties_home;
create policy "own properties - all" on public.properties_home
    for all using (auth.uid() = owner_id) with check (auth.uid() = owner_id);

drop policy if exists "published properties - read" on public.properties_home;
create policy "published properties - read" on public.properties_home
    for select using (status = 'published');
