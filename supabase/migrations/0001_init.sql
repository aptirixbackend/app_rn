-- =====================================================================
-- 0001_init.sql — Foundation: profiles_home + onboarding.
-- Tables are suffixed _home so they never collide with the project's
-- existing tables (there is already a different public.profiles).
-- =====================================================================

create extension if not exists "pgcrypto";

-- Remove the earlier (pre-_home) artifacts that mis-linked to the existing
-- public.profiles table and broke auth signups.
drop trigger if exists on_auth_user_created on auth.users;
drop function if exists public.handle_new_user();
drop table if exists public.user_preferences cascade;

-- PROFILES ---------------------------------------------------------------
create table if not exists public.profiles_home (
    id uuid primary key references auth.users(id) on delete cascade,
    first_name text,
    last_name  text,
    dob        date,
    email      text,
    phone      text,
    avatar_url text,
    primary_goal text check (primary_goal in ('post', 'search')),
    onboarding_completed boolean not null default false,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);

-- USER PREFERENCES -------------------------------------------------------
create table if not exists public.user_preferences_home (
    id uuid primary key default gen_random_uuid(),
    user_id uuid not null references public.profiles_home(id) on delete cascade,
    preference text not null check (preference in
        ('rent', 'buy', 'coliving', 'pg', 'investment', 'commercial')),
    created_at timestamptz not null default now(),
    unique (user_id, preference)
);

-- AUTO-CREATE PROFILE ON SIGNUP -----------------------------------------
create or replace function public.handle_new_user_home()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
    insert into public.profiles_home (id, email, phone)
    values (new.id, new.email, new.phone)
    on conflict (id) do nothing;
    return new;
end;
$$;

drop trigger if exists on_auth_user_created_home on auth.users;
create trigger on_auth_user_created_home
    after insert on auth.users
    for each row execute function public.handle_new_user_home();

-- UPDATED_AT TRIGGER -----------------------------------------------------
create or replace function public.set_updated_at_home()
returns trigger language plpgsql as $$
begin new.updated_at = now(); return new; end; $$;

drop trigger if exists trg_profiles_home_updated on public.profiles_home;
create trigger trg_profiles_home_updated
    before update on public.profiles_home
    for each row execute function public.set_updated_at_home();

-- ROW LEVEL SECURITY -----------------------------------------------------
alter table public.profiles_home enable row level security;
alter table public.user_preferences_home enable row level security;

drop policy if exists "own profile - select" on public.profiles_home;
create policy "own profile - select" on public.profiles_home
    for select using (auth.uid() = id);
drop policy if exists "own profile - update" on public.profiles_home;
create policy "own profile - update" on public.profiles_home
    for update using (auth.uid() = id);
drop policy if exists "own profile - insert" on public.profiles_home;
create policy "own profile - insert" on public.profiles_home
    for insert with check (auth.uid() = id);

drop policy if exists "own prefs - all" on public.user_preferences_home;
create policy "own prefs - all" on public.user_preferences_home
    for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
