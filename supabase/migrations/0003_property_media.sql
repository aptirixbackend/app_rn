-- =====================================================================
-- 0003_property_media.sql — amenities, features, media & review fields
-- on properties_home.
-- =====================================================================

alter table public.properties_home
    add column if not exists amenities           text[] default '{}',
    add column if not exists additional_features text[] default '{}',
    add column if not exists highlights          text,
    add column if not exists cover_image_url     text,
    add column if not exists photo_urls          text[] default '{}',
    add column if not exists video_url           text,
    add column if not exists floor_plan_url      text,
    add column if not exists title               text,
    add column if not exists city                text,
    add column if not exists area                text,
    add column if not exists price               numeric,
    add column if not exists price_period        text, -- 'month' | 'total'
    add column if not exists posted_by           text,
    add column if not exists poster_tag          text,
    add column if not exists latitude            numeric,
    add column if not exists longitude           numeric;

-- STORAGE ------------------------------------------------------------
-- Public bucket `property-media` holds cover photos, images and floor plans.
