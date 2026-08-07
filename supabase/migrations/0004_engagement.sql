-- =====================================================================
-- 0004_engagement.sql — favorites, leads (enquiries) & site visits.
--
-- DEV NOTE: auth is currently mocked, so these use PERMISSIVE RLS
-- (anon full access) keyed by a local mock user id. When real Supabase
-- auth is integrated, replace the "dev - all" policies with
-- auth.uid()-based ones and change user/customer ids to auth.uid().
-- =====================================================================

create table if not exists public.favorites_home (
    id          uuid primary key default gen_random_uuid(),
    user_id     text not null,
    property_id uuid not null references public.properties_home(id) on delete cascade,
    created_at  timestamptz not null default now(),
    unique (user_id, property_id)
);

create table if not exists public.leads_home (
    id             uuid primary key default gen_random_uuid(),
    property_id    uuid not null references public.properties_home(id) on delete cascade,
    owner_id       uuid,
    customer_id    text not null,
    customer_name  text,
    customer_phone text,
    kind           text not null default 'enquiry', -- enquiry / contact / whatsapp / message
    message        text,
    status         text not null default 'new',     -- new / contacted / closed
    created_at     timestamptz not null default now()
);

create table if not exists public.visits_home (
    id             uuid primary key default gen_random_uuid(),
    property_id    uuid not null references public.properties_home(id) on delete cascade,
    owner_id       uuid,
    customer_id    text not null,
    customer_name  text,
    customer_phone text,
    scheduled_for  date,
    slot           text,
    status         text not null default 'requested', -- requested / confirmed / done / cancelled
    created_at     timestamptz not null default now()
);

create index if not exists favorites_home_user_idx on public.favorites_home(user_id);
create index if not exists leads_home_owner_idx on public.leads_home(owner_id);
create index if not exists leads_home_customer_idx on public.leads_home(customer_id);
create index if not exists visits_home_customer_idx on public.visits_home(customer_id);

alter table public.favorites_home enable row level security;
alter table public.leads_home enable row level security;
alter table public.visits_home enable row level security;

drop policy if exists "dev - all" on public.favorites_home;
create policy "dev - all" on public.favorites_home for all using (true) with check (true);
drop policy if exists "dev - all" on public.leads_home;
create policy "dev - all" on public.leads_home for all using (true) with check (true);
drop policy if exists "dev - all" on public.visits_home;
create policy "dev - all" on public.visits_home for all using (true) with check (true);
