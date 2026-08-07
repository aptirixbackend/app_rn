# Supabase setup

## 1. Create the project
1. Go to https://supabase.com → **New project**.
2. Note down (Project Settings → API):
   - **Project URL**
   - **anon public key** (used by the Flutter app)
   - **service_role key** (used by the FastAPI backend — keep secret!)
   - **JWT secret** (Project Settings → API → JWT Settings — used by the backend to verify tokens)

## 2. Run migrations
Open **SQL Editor** and run each file in `migrations/` in order (0001, 0002, …).

## 3. Enable Google Sign-In
Authentication → Providers → **Google** → enable, and paste your Google OAuth client ID/secret.
(Google Cloud Console → Credentials → OAuth client.)

## 4. Storage (added when we build the media/upload flow)
Create a bucket `property-media` (public read) for listing photos/videos.

## Migrations log
| File | Adds |
|------|------|
| 0001_init.sql | profiles, user_preferences, signup trigger, RLS |
| 0002_properties.sql | properties (draft listings) + RLS |
| 0003_property_media.sql | amenities, features, media URLs, price/location cols |
