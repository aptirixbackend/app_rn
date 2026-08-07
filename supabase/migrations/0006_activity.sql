-- =====================================================================
-- 0006_activity.sql — user activity log (views, detail clicks, searches).
-- Powers future recommendations + owner-facing insights. Dev-permissive
-- RLS (mock auth) — harden with auth.uid() when real auth lands.
-- =====================================================================
create table if not exists public.activity_home (
    id          uuid primary key default gen_random_uuid(),
    user_id     text,
    event_type  text not null, -- view / detail_click / search / save / contact / visit / booking
    property_id uuid references public.properties_home(id) on delete set null,
    owner_id    uuid,          -- property owner, so activity can be shared with them
    meta        jsonb not null default '{}'::jsonb,
    created_at  timestamptz not null default now()
);

create index if not exists activity_home_user_idx on public.activity_home(user_id);
create index if not exists activity_home_owner_idx on public.activity_home(owner_id);
create index if not exists activity_home_prop_idx on public.activity_home(property_id);
create index if not exists activity_home_event_idx on public.activity_home(event_type);

alter table public.activity_home enable row level security;
drop policy if exists "dev - all" on public.activity_home;
create policy "dev - all" on public.activity_home for all using (true) with check (true);
