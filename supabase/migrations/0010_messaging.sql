-- =====================================================================
-- 0010_messaging.sql — 1:1 real-time chat (WhatsApp-style).
-- A single flat table of direct messages between two users. Conversations
-- are derived (latest message per partner). Delivery lifecycle is tracked on
-- each row: sent -> delivered -> read.
-- =====================================================================

create table if not exists public.messages_home (
    id           uuid primary key default gen_random_uuid(),
    sender_id    uuid not null,
    receiver_id  uuid not null,
    body         text not null default '',
    image_url    text not null default '',
    message_type text not null default 'text',      -- text | image
    status       text not null default 'sent',       -- sent | delivered | read
    -- Optional property this conversation is about (chat is usually started
    -- from a listing). Lets the chat header show a "Re: <listing>" banner.
    property_id  uuid,
    created_at   timestamptz not null default now()
);

-- Fetch a conversation between two users, newest-first, fast.
create index if not exists messages_home_pair_idx
    on public.messages_home (sender_id, receiver_id, created_at desc);
create index if not exists messages_home_pair_rev_idx
    on public.messages_home (receiver_id, sender_id, created_at desc);
-- Unread lookups + "mark delivered on connect".
create index if not exists messages_home_inbox_idx
    on public.messages_home (receiver_id, status);

alter table public.messages_home enable row level security;
-- Only the backend (service key, bypasses RLS) reads/writes messages; the
-- Flutter client talks to chat exclusively through the FastAPI backend
-- (REST history + WebSocket), never Supabase-direct. No client policy needed.
