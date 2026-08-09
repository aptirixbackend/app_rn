-- =====================================================================
-- 0009_notifications.sql — device tokens + per-user notification settings
-- for backend-sent FCM push notifications.
-- =====================================================================

create table if not exists public.device_tokens_home (
    id         uuid primary key default gen_random_uuid(),
    user_id    uuid not null,
    token      text not null unique,
    platform   text default 'android',
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);
create index if not exists device_tokens_home_user_idx
    on public.device_tokens_home (user_id);

alter table public.device_tokens_home enable row level security;
-- Only the backend (service key, bypasses RLS) reads/writes tokens.

-- Per-user notification preferences (mirrors the app's settings toggles).
alter table public.profiles_home
    add column if not exists notif_settings jsonb not null default '{}'::jsonb;
