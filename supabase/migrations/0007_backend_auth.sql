-- =====================================================================
-- 0007_backend_auth.sql — Backend-owned phone-OTP auth (no Supabase Auth).
--
-- The FastAPI backend now generates, stores, delivers (Plivo WhatsApp) and
-- verifies OTPs, then mints its own JWT. This also DETACHES identity from
-- Supabase's `auth.users` so the database can be swapped for another provider
-- later without touching the app's login. Existing profile rows are kept.
-- =====================================================================

-- 1) OTP store — short-lived, hashed codes (never the plaintext).
create table if not exists public.otp_codes_home (
    id         uuid primary key default gen_random_uuid(),
    phone      text not null,
    code_hash  text not null,
    attempts   int  not null default 0,
    consumed   boolean not null default false,
    expires_at timestamptz not null,
    created_at timestamptz not null default now()
);
create index if not exists otp_codes_home_phone_idx
    on public.otp_codes_home (phone, created_at desc);

alter table public.otp_codes_home enable row level security;
-- No anon policy on purpose: only the backend (service key, bypasses RLS)
-- ever reads/writes OTP codes.

-- 2) Detach profiles from Supabase Auth so the backend owns identity.
--    Drops the auth.users foreign key by whatever name it has, gives id its
--    own default, and removes the auth.users signup trigger.
do $$
declare cname text;
begin
    select conname into cname
    from pg_constraint
    where conrelid = 'public.profiles_home'::regclass
      and contype = 'f'
      and confrelid = 'auth.users'::regclass;
    if cname is not null then
        execute format('alter table public.profiles_home drop constraint %I', cname);
    end if;
end $$;

alter table public.profiles_home alter column id set default gen_random_uuid();
drop trigger if exists on_auth_user_created_home on auth.users;
