# 📋 Flow & Field Specs

This is the living spec. For each screen we build, we record **exactly what data it
collects / shows**, so DB + API + UI stay in sync. You give me the fields per screen;
I fill this in and build the slice.

Legend: 🟢 done · 🟡 in progress · ⚪ not started

---

## AUTH — HOMELY (🟢 built)

### Sign In / Sign Up  🟢
Brand: **HOMELY** — "Find your perfect space". Primary color `#5B4EE8`.
Assets: `home_signup.png` (hero), `bottom_design.png` (skyline).

| Field | Type | Required | Notes |
|-------|------|----------|-------|
| Country code | fixed `+91` 🇮🇳 | ✓ | India only for v1 (picker later) |
| Mobile number | 10 digits | ✓ | → sends OTP via Supabase |
| Google | OAuth | — | "Continue with Google" (one-tap later) |

Actions: **Continue with Mobile** → OTP screen · **Continue with Google** → home/onboarding.
Trust badges (static): Verified Listings · Best Prices · 24/7 Support.

### OTP Verification  🟢
Asset: `otp_screen.png` (illustration).

| Field | Type | Notes |
|-------|------|-------|
| 6-digit OTP | numeric, auto-advance | verified via Supabase `verifyOTP` |
| Resend | countdown 25s | re-sends OTP after timer |

Actions: **Verify & Continue** → if `onboarding_completed` → `/home`, else `/onboarding`.

Backend: Supabase Auth sends/verifies the SMS OTP; the signup trigger auto-creates
the `profiles` row; FastAPI `/me` exposes `onboarding_completed` for routing.
Needs: an SMS provider configured in Supabase (or a test number) to receive real OTPs.

---

## ONBOARDING (3 steps)

### Step 1 — Basic info  ⚪
| Field | Type | Required |
|-------|------|----------|
| First name | text | ✓ |
| Last name | text | ✓ |
| Date of birth | date | ? |
| Email | email | ? (prefilled from Google) |

### Step 2 — Preferences (multi-select)  ⚪
Options: Rent · Buy · Co-living · PG/Hostel · Investment · Commercial

### Step 3 — Primary goal ("How would you like to get started?")  🟢
Shown right after OTP. Brand on this screen: **HomeVista** ⚠️ (sign-in says HOMELY — needs reconciling).
Assets: `for_home.png` (post), `search_home.png` (search), `bottom_design.png` (skyline).

| Card | Accent | Saves | Routes to |
|------|--------|-------|-----------|
| 🏠 Post a Home | purple | `primary_goal = 'post'` | → Tell us about your property |
| 🔍 Search a Home | green | `primary_goal = 'search'` | → Tell us about yourself |

Saved via `profiles.primary_goal`. Footer: "We'll personalize your experience based on your choice".

> ⚠️ **Brand name mismatch:** sign-in/OTP say **HOMELY**, this screen says **HomeVista**. Pick one to standardize app-wide.

### 🟢 "Tell us about yourself" (Search path) — realizes onboarding Steps 1 + 2
Route: `/onboarding/about-you`. 5-dot progress, Skip → Home.

| Field | Control | Saves to |
|-------|---------|----------|
| First / Last name | text | `profiles.first_name/last_name` |
| Date of Birth | date picker | `profiles.dob` |
| Email | email | `profiles.email` |
| "What are you looking for?" (multi-select) | Rent · Co-living · PG/Hostel · Buy · Invest | `user_preferences` |

Continue → sets `onboarding_completed = true` → `/home`.

### 🟢 "Tell us about your property" (Post path) — posting flow step 3 of 5
Route: `/post-property`. Asset: `tellus_properity.png`. Inserts a `draft` into new `properties` table.

| Field | Control |
|-------|---------|
| Property Type | chips: Apartment / Villa / Independent House / Plot / Others |
| Purpose | chips: Sell / Rent / PG-Co-living / Lease |
| BHK · Bathrooms | dropdowns |
| Carpet Area (sq.ft) · Furnishing | text + dropdown |
| Floor Number · Total Floors | number |
| Property Age · Facing | dropdowns |
| Available From | date picker |

Continue → insert draft → `/post-property/next` (steps 4–5 TBD: location, pricing, media).
DB: migration `0002_properties.sql`.

---

## POSTER FLOW (5 steps — step numbers normalized; mockups were inconsistent)
1. ⚪ Who are you? (role: Owner/Broker/Builder/Rep) — not designed yet
2. 🟢 Property details — `/post-property`
3. 🟢 Amenities & features — `/post-property/amenities` (12 popular amenities + custom features + highlights)
4. 🟢 Photos & media — `/post-property/media` (cover + photos via image_picker → Supabase Storage `property-media`, video link, floor plan)
5. 🟢 Review & publish — `/post-property/review` (preview card + posted-by + publish → status `published`)

Each step carries the draft `propertyId` via go_router `extra` and updates the same `properties` row.
DB: migration `0003_property_media.sql` (amenities, features, media URLs, price/location columns) + a public Storage bucket `property-media`.

## DISCOVERY / CUSTOMER
### 🟢 Home feed ("HomeVista") — `/home`
Bottom nav: Home · Search · **Post Property (+, center → `/post-property`)** · My Leads · Profile.
Sections: top bar (menu/logo/bell+badge/avatar) · search bar · category chips (All/Rent/Buy/PG/Commercial/Plots) · hero banner ("Discover a place you'll love to live in") · Recommended for You (property cards) · Explore by Category · trust row.
Data: **live from DB** (`properties_home`, published) via `publishedPropertiesProvider`. Search page `/search` (same feed). Tapping any card → Property Detail.

### 🟢 Property Detail — `/property/:id`
Gallery + thumbnails, title/price/specs, verified/owner/available bar, description (read more), amenities grid, location (map placeholder `location.png` + nearby), Property Details grid, Photos & Videos, Nearby Landmarks, Owner card (WhatsApp/Call/Message), Similar Properties, sticky Save + Schedule Visit. DB-driven via `propertyByIdProvider` (`getPropertyById`). Landmarks/rating/tenure static; contact/save/schedule are "Coming soon" (need auth + leads/visits tables).

## PROPERTY DETAIL  ⚪

---

### Template for a new screen
```
### <Screen name>  ⚪
Purpose:
| Field | Type | Required | Notes |
|-------|------|----------|-------|
| ...   | ...  | ...      | ...   |
Actions/buttons:
Next screen:
```
