# 🏡 AI Real Estate Platform — Master Plan

> Stack: **Flutter** (mobile) · **FastAPI** (backend) · **Supabase** (DB/Auth/Storage/Realtime)
> Roles: **Customer** + **Poster** (one account can be both) · **Admin** = internal
> Working defaults for v1: Core MVP · Mobile only (web-ready) · AI in Phase 2 · Google Sign-In first

---

## 1. Roles

| Role | Who | Does |
|---|---|---|
| Customer | Buyers, renters, seekers | Browse, search, filter, view, favorite, contact, chat, schedule visit |
| Poster | Owner / Broker / Builder / Authorized Rep | Post & manage listings, leads, inquiries, analytics |
| Admin | Internal team | Verify listings, moderate, manage users (Phase 4) |

One account can be both Customer and Poster. Onboarding "goal" step sets the starting mode; users toggle between Browse and My Listings anytime. Poster type (Owner/Broker/Builder/Rep) is an attribute that changes the posting form and verification level.

---

## 2. Architecture

- **Flutter → Supabase directly** (fast path): auth (Google), media upload to Storage, chat via Realtime, simple RLS-protected reads.
- **Flutter → FastAPI** (logic/secrets): publishing rules, search & ranking, personalized feed, lead routing, AI, push notifications, analytics.
- **RLS** protects every table (a customer can't read another user's drafts or leads).

```
Flutter (iOS/Android)
   ├── direct → Supabase (Auth, Storage, Realtime, RLS reads)
   └── logic  → FastAPI → Supabase (service key)
```

---

## 3. Features by role

**Customer:** onboarding → personalized feed; home/trending/new projects/nearby; search + smart filters; interactive map; property detail (gallery, video, floor plan, amenities, map, nearby schools/hospitals, similar); contact/chat/schedule visit; favorites + saved searches.

**Poster:** role identification; multi-step post flow (type → purpose → details → location → pricing → amenities → media → review → publish/draft); My Listings (edit/status/republish); dashboard (views, leads, inquiries, messages, performance).

---

## 4. Phased roadmap

- **Phase 0 — Foundation:** repo structure, Supabase schema + RLS + storage, FastAPI skeleton w/ Supabase-JWT auth, Flutter skeleton (routing/theme/API client), extract design system from UI.
- **Phase 1 — Core MVP:** Google auth → onboarding → Poster posts a property (full form + media + draft/publish) → Customer browse/search/detail/contact → profile & My Listings.
- **Phase 2 — Engagement + first AI:** map/geo-search (PostGIS), favorites & saved searches, chat (Realtime), schedule visit, push (FCM), poster dashboard, verified listings, AI descriptions + semantic search (pgvector).
- **Phase 3 — Full AI:** recommendations (rule-based → ML), matching, price estimation, AI assistant, image enhancement.
- **Phase 4 — Web + dashboards + monetization:** Flutter web (responsive), admin dashboard, property-management dashboard, featured listings/subscriptions, analytics.

---

## 5. Core data model

```
profiles            id, first_name, last_name, dob, email, phone, avatar, created_at
user_preferences    user_id, preference        -- rent/buy/coliving/pg/investment/commercial
properties          id, owner_id, poster_type, prop_type, purpose, bhk, bathrooms,
                    balconies, area, area_unit, furnishing, floor, total_floors,
                    age, facing, parking, availability_date, status, verified
property_location    property_id, lat, lng, address, area, landmark, city, state, pincode
property_pricing     property_id, selling_price, monthly_rent, deposit, maintenance, negotiable
property_amenities   property_id, amenity
property_media       id, property_id, kind(cover/photo/video/floorplan), url, sort_order
favorites            user_id, property_id
saved_searches       user_id, filters_json
leads                id, property_id, customer_id, owner_id, kind, message, status, created_at
visits               id, property_id, customer_id, scheduled_at, status
conversations        id, property_id, customer_id, owner_id
messages             id, conversation_id, sender_id, body, created_at
property_views       property_id, viewer_id, created_at        -- analytics
property_embeddings  property_id, embedding vector(1536)        -- Phase 2 AI
```

---

## 6. API surface (FastAPI)

```
POST /auth/session          verify Supabase JWT, upsert profile
GET  /me                    profile + preferences
POST /onboarding            save basic info, preferences, goal
CRUD /properties            create/update/publish/draft/delete
GET  /properties/mine       poster's listings
POST /media/upload-url      signed upload URL for Storage
GET  /search                filters + geo + sort
GET  /feed                  personalized home feed
POST /favorites             add/remove
POST /leads                 contact owner / schedule visit
GET  /dashboard             poster analytics
POST /ai/describe           (Phase 2) generate description
GET  /ai/search             (Phase 2) semantic search
```

---

## 7. Screen map

```
Splash → Auth (Google) → Onboarding (3 steps)
   → Home (feed / search / map)
   → Property Detail → Contact / Chat / Schedule
   → Favorites
   → Post Property (9-step flow)
   → My Listings → Poster Dashboard
   → Profile / Settings
```

---

## 8. Tech stack

| Layer | Choice |
|---|---|
| Mobile | Flutter |
| State | Riverpod |
| Routing | go_router |
| Backend | FastAPI + Pydantic |
| DB/Auth/Storage/Realtime | Supabase |
| Geo | PostGIS |
| AI vectors | pgvector |
| Push | Firebase Cloud Messaging |
| API hosting | Render / Railway / Fly.io |

---

## 9. Dev workflow

1. Monorepo: `/mobile`, `/backend`, `/supabase` (migrations), `/docs`.
2. Design system first (theme from UI: colors, type, spacing, cards, gradients).
3. Vertical slices: DB → RLS → API → screen, one feature at a time.
4. Migrations as versioned SQL files.
5. Env/secrets in `.env`; service key server-side only.

---

## 10. Open questions / gaps

1. **Monetization** — featured listings, subscriptions, or pay-per-lead?
2. **Verification** — who verifies listings, and how (admin review, KYC)?
3. **Lead delivery** — reveal phone vs create a lead (recommended: lead model).
4. **Region & currency** — confirm India (₹, BHK, PIN) for defaults.
5. **Nearby schools/hospitals** — needs Places API (paid); v1 or later?
6. **Image enhancement AI** — recommend Phase 3.
7. **Legal** — Terms, Privacy, India DPDP Act compliance.
