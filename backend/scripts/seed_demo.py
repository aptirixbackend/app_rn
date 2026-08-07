"""Seed a demo user + published property listings into the dev Supabase DB.

Reads SUPABASE_URL / SUPABASE_SERVICE_KEY from backend/.env. Idempotent:
re-running replaces the demo user's listings. Run from repo root:

    backend/.venv/Scripts/python.exe backend/scripts/seed_demo.py
"""
import os
from pathlib import Path

from dotenv import load_dotenv
from supabase import create_client

ROOT = Path(__file__).resolve().parents[2]
load_dotenv(ROOT / "backend" / ".env")

URL = os.environ["SUPABASE_URL"]
SERVICE_KEY = os.environ.get("SUPABASE_SERVICE_KEY", "").strip()
if not SERVICE_KEY:
    raise SystemExit("SUPABASE_SERVICE_KEY missing in backend/.env")

sb = create_client(URL, SERVICE_KEY)
BUCKET = "property-media"
DEMO_EMAIL = "demo@homevista.app"
IMG_DIR = ROOT / "mobile" / "assets" / "images"

# 1. Public storage bucket -------------------------------------------------
try:
    sb.storage.create_bucket(BUCKET, options={"public": True})
    print("bucket: created")
except Exception as e:  # noqa: BLE001
    print(f"bucket: exists ({type(e).__name__})")

# 2. Demo user (trigger auto-creates its profiles_home row) ----------------
def get_or_create_user() -> str:
    try:
        for u in sb.auth.admin.list_users():
            if getattr(u, "email", None) == DEMO_EMAIL:
                return u.id
    except Exception as e:  # noqa: BLE001
        print("list_users:", e)
    res = sb.auth.admin.create_user({"email": DEMO_EMAIL, "email_confirm": True})
    return res.user.id


uid = get_or_create_user()
print("demo user:", uid)

sb.table("profiles_home").update(
    {
        "first_name": "Sneha",
        "last_name": "Reddy",
        "phone": "+91 98765 43210",
        "email": DEMO_EMAIL,
        "onboarding_completed": True,
        "primary_goal": "post",
    }
).eq("id", uid).execute()


# 3. Upload cover images ---------------------------------------------------
def upload(name: str) -> str:
    data = (IMG_DIR / name).read_bytes()
    path = f"demo/{name}"
    try:
        sb.storage.from_(BUCKET).upload(
            path, data, {"content-type": "image/png", "upsert": "true"}
        )
    except Exception as e:  # noqa: BLE001
        print(f"upload {name}: {type(e).__name__}")
    return sb.storage.from_(BUCKET).get_public_url(path)


IMAGES = {
    "apartment": upload("flat.png"),
    "building": upload("tellus_properity.png"),
    "villa": upload("for_home.png"),
    "house": upload("home_signup.png"),
    "coliving": upload("pg_coliving.png"),
    "commercial": upload("commerial.png"),
    "plot": upload("plot.png"),
    "rent": upload("rent_page.png"),
    "stay": upload("rent_img1.png"),
}

# 4. Published listings — 10 per property type, spread across cities --------
# (city, locality, lat, lng) — approximate coordinates for the Map view.
LOCALITIES = [
    # Bengaluru
    ("Bengaluru", "Whitefield", 12.9698, 77.7500),
    ("Bengaluru", "Koramangala", 12.9352, 77.6245),
    ("Bengaluru", "Indiranagar", 12.9719, 77.6412),
    ("Bengaluru", "HSR Layout", 12.9116, 77.6389),
    ("Bengaluru", "Electronic City", 12.8452, 77.6602),
    # Chennai
    ("Chennai", "Tambaram", 12.9249, 80.1000),
    ("Chennai", "Egmore", 13.0732, 80.2609),
    ("Chennai", "Velachery", 12.9791, 80.2210),
    ("Chennai", "Adyar", 13.0012, 80.2565),
    ("Chennai", "Anna Nagar", 13.0850, 80.2101),
    # Hyderabad
    ("Hyderabad", "Gachibowli", 17.4401, 78.3489),
    ("Hyderabad", "Hitech City", 17.4435, 78.3772),
    ("Hyderabad", "Madhapur", 17.4483, 78.3915),
    ("Hyderabad", "Kondapur", 17.4615, 78.3677),
    ("Hyderabad", "Banjara Hills", 17.4156, 78.4347),
    # Mumbai
    ("Mumbai", "Andheri", 19.1197, 72.8468),
    ("Mumbai", "Bandra", 19.0596, 72.8295),
    ("Mumbai", "Powai", 19.1176, 72.9060),
    ("Mumbai", "Thane", 19.2183, 72.9781),
    ("Mumbai", "Malad", 19.1860, 72.8484),
]

RES_AMEN = ["Lift", "Power Backup", "24x7 Security", "Parking", "Gym",
            "Swimming Pool", "Club House", "Children Play Area", "CCTV",
            "Garden", "Rain Water Harvesting", "Intercom"]
COLIV_AMEN = ["Wi-Fi", "Housekeeping", "Meals", "Laundry", "Security",
              "Power Backup", "AC", "Common Kitchen", "TV Lounge", "Fridge"]
COMM_AMEN = ["Lift", "Power Backup", "24x7 Security", "Parking", "CCTV",
             "Central AC", "Cafeteria", "Conference Room", "Fire Safety",
             "Reception"]
PLOT_AMEN = ["Gated Layout", "Corner Plot", "Road Facing", "Water Connection",
             "Electricity", "Compound Wall", "Park Facing", "Khata A"]

FURN = ["Unfurnished", "Semi Furnished", "Fully Furnished"]
FACING = ["East", "West", "North", "South", "North-East", "South-East"]
AGE = ["New", "1-5 years", "5-10 years", "10+ years"]
OWNERS = ["Sneha Reddy (Owner)", "PropNest Realty", "Anil Kumar (Owner)",
          "UrbanNest Brokers", "Meera Nair (Owner)", "Ravi Sharma (Owner)",
          "Skyline Estates", "Priya Menon (Owner)"]
TAGS = ["Verified", "Verified Broker", "Premium", "Verified"]


def _attrs(ptype: str, i: int, base: dict) -> dict:
    """Per-type structured attributes → jsonb `attributes` column."""
    if ptype in ("PG", "Coliving"):
        return {
            "sharing": base.get("bhk", ""),
            "food": "With Food" if i % 4 != 0 else "Without Food",
            "gender": ["Men", "Women", "Co-ed"][i % 3],
            "gate_timing": ["10:00 PM", "11:00 PM", "No Restriction"][i % 3],
            "notice_period": ["15 Days", "1 Month"][i % 2],
        }
    if ptype == "Coworking":
        return {
            "seats": str([1, 2, 4, 8][i % 4]),
            "lock_in": ["None", "6 Months", "1 Year"][i % 3],
        }
    if ptype == "Commercial":
        return {
            "washrooms": str(1 + i % 2),
            "lock_in": ["6 Months", "1 Year", "2 Years"][i % 3],
        }
    if ptype == "Stay":
        return {
            "stay_type": ["Entire House", "Private Room", "Shared Room",
                          "Studio"][i % 4],
            "max_guests": str([2, 3, 4, 6][i % 4]),
            "price_month": str(22000 + i * 4000),
            "min_nights": str([1, 1, 2, 3][i % 4]),
            "check_in": "2:00 PM",
            "check_out": "11:00 AM",
        }
    if ptype == "Plot":
        return {
            "plot_length": str(30 + i * 3),
            "plot_width": str(40 + i * 2),
            "boundary": "Yes" if i % 2 == 0 else "No",
            "approval": ["DTCP Approved", "BBMP Approved",
                         "Gram Panchayat"][i % 3],
        }
    return {
        "parking": ["Covered", "Open", "2 Covered"][i % 3],
        "balconies": str(1 + i % 3),
    }


def make(ptype: str, i: int, g: int) -> dict:
    city, loc, lat, lng = LOCALITIES[g % len(LOCALITIES)]
    base = dict(
        property_type=ptype, city=city, area=loc,
        furnishing=FURN[i % len(FURN)], facing=FACING[i % len(FACING)],
        property_age=AGE[i % len(AGE)], posted_by=OWNERS[i % len(OWNERS)],
        poster_tag=TAGS[i % len(TAGS)], latitude=lat, longitude=lng,
        available_from="2026-09-01",
    )
    sell = i % 2 == 1

    if ptype == "Apartment":
        bhk = ["1 BHK", "2 BHK", "3 BHK", "4 BHK"][i % 4]
        beds = int(bhk[0])
        base.update(
            title=f"{bhk} Apartment", bhk=bhk, bathrooms=beds,
            purpose="sell" if sell else "rent",
            carpet_area=550 + i * 110,
            price=(5500000 + i * 850000) if sell else (14000 + i * 2600),
            price_period="total" if sell else "month",
            floor_number=(i % 14) + 1, total_floors=15,
            amenities=RES_AMEN[: 6 + (i % 5)],
            highlights=f"Well-appointed {bhk} apartment in {loc} with modern "
                       "amenities, great ventilation and excellent "
                       "connectivity to major IT hubs.",
            cover=IMAGES["apartment"] if i % 2 == 0 else IMAGES["building"],
            photos=6 + (i % 10))
    elif ptype == "Villa":
        bhk = ["3 BHK", "4 BHK", "5 BHK"][i % 3]
        beds = int(bhk[0])
        base.update(
            title=f"{bhk} Villa", bhk=bhk, bathrooms=beds,
            purpose="sell" if sell else "rent",
            carpet_area=1800 + i * 170,
            price=(15000000 + i * 2200000) if sell else (55000 + i * 5500),
            price_period="total" if sell else "month",
            floor_number=2, total_floors=2,
            amenities=RES_AMEN[: 7 + (i % 4)],
            highlights=f"Luxurious {bhk} villa in {loc} with private garden, "
                       "covered parking and 24x7 security in a serene gated "
                       "community.",
            cover=IMAGES["villa"], photos=10 + (i % 8))
    elif ptype == "Independent House":
        bhk = ["2 BHK", "3 BHK", "4 BHK"][i % 3]
        beds = int(bhk[0])
        base.update(
            title=f"{bhk} Independent House", bhk=bhk, bathrooms=beds,
            purpose="sell" if sell else "rent",
            carpet_area=1000 + i * 130,
            price=(8000000 + i * 1300000) if sell else (24000 + i * 3200),
            price_period="total" if sell else "month",
            floor_number=1, total_floors=2,
            amenities=RES_AMEN[: 5 + (i % 4)],
            highlights=f"Well-maintained {bhk} independent house in {loc} with "
                       "parking and a private garden in a quiet residential "
                       "area.",
            cover=IMAGES["house"], photos=6 + (i % 8))
    elif ptype == "Coliving":
        room = ["Single Room", "Twin Sharing", "Private Studio", "1 RK"][i % 4]
        base.update(
            title=f"Co-living · {room}", bhk=room, bathrooms=1,
            purpose="rent", carpet_area=150 + i * 18, price=8000 + i * 950,
            price_period="month", floor_number=(i % 6) + 1, total_floors=6,
            amenities=COLIV_AMEN[: 6 + (i % 4)],
            highlights=f"Fully-furnished {room.lower()} in a managed co-living "
                       f"space in {loc} with meals, housekeeping and "
                       "high-speed Wi-Fi.",
            cover=IMAGES["coliving"], photos=6 + (i % 6))
    elif ptype == "Commercial":
        kind = ["Office Space", "Retail Shop", "Showroom", "Co-working"][i % 4]
        base.update(
            title=f"Commercial {kind}", bhk=kind, bathrooms=1 + (i % 2),
            purpose="sell" if sell else "rent",
            carpet_area=500 + i * 260,
            price=(12000000 + i * 3200000) if sell else (45000 + i * 11000),
            price_period="total" if sell else "month",
            floor_number=(i % 10) + 1, total_floors=12,
            amenities=COMM_AMEN[: 6 + (i % 4)],
            highlights=f"Prime {kind.lower()} in {loc} — ready to move, with "
                       "ample parking, power backup and excellent frontage on "
                       "the main road.",
            cover=IMAGES["commercial"], photos=6 + (i % 8))
    elif ptype == "PG":
        sharing = ["Single Sharing", "Double Sharing", "Triple Sharing",
                   "Private Room"][i % 4]
        gender = ["Men's", "Women's", "Co-ed"][i % 3]
        base.update(
            title=f"{gender} PG · {sharing}", bhk=sharing, bathrooms=1,
            purpose="rent", carpet_area=120 + i * 15, price=6000 + i * 900,
            price_period="month", floor_number=(i % 4) + 1, total_floors=4,
            furnishing="Fully Furnished",
            amenities=["Meals", "Wi-Fi", "Housekeeping", "Laundry",
                       "Power Backup", "Security", "AC", "Warden"][
                : 5 + (i % 3)],
            highlights=f"{gender} PG in {loc} — {sharing.lower()} with meals, "
                       "housekeeping, Wi-Fi and 24x7 security. Walk to tech "
                       "parks and transit.",
            cover=IMAGES["coliving"], photos=5 + (i % 6))
    elif ptype == "Coworking":
        desk = ["Hot Desk", "Dedicated Desk", "Private Cabin",
                "Meeting Room"][i % 4]
        base.update(
            title=f"Coworking · {desk}", bhk=desk, bathrooms=1 + (i % 2),
            purpose="rent", carpet_area=80 + i * 40, price=6000 + i * 1400,
            price_period="month", floor_number=(i % 8) + 1, total_floors=10,
            furnishing="Fully Furnished",
            amenities=["Wi-Fi", "Meeting Rooms", "Cafeteria", "AC", "Printer",
                       "24x7 Access", "Reception", "Power Backup"][
                : 5 + (i % 4)],
            highlights=f"{desk} in a premium coworking space at {loc} — "
                       "high-speed Wi-Fi, meeting rooms, cafeteria and 24x7 "
                       "access.",
            cover=IMAGES["commercial"], photos=5 + (i % 6))
    elif ptype == "Stay":
        stay_type = ["Entire House", "Private Room", "Shared Room",
                     "Studio"][i % 4]
        beds = [2, 1, 1, 1][i % 4]
        base.update(
            title=f"{stay_type} in {loc}", bhk=f"{beds} BHK",
            bathrooms=1 + (i % 2), purpose="stay",
            carpet_area=350 + i * 90, price=1200 + i * 400,
            price_period="night", floor_number=(i % 6) + 1, total_floors=6,
            furnishing="Fully Furnished",
            amenities=["Wi-Fi", "Kitchen", "AC", "TV", "Washing Machine",
                       "Parking", "Power Backup", "Housekeeping"][: 5 + (i % 4)],
            highlights=f"Cosy {stay_type.lower()} in {loc}, available by the "
                       "day or the month. Fully furnished with Wi-Fi, kitchen "
                       "and AC — ideal for travellers and relocating "
                       "professionals.",
            cover=IMAGES["stay"], photos=6 + (i % 8))
    else:  # Plot
        area_sqft = 1200 + i * 400
        base.update(
            title="Residential Plot", bhk="Plot", purpose="sell",
            carpet_area=area_sqft, price=4000000 + i * 1400000,
            price_period="total",
            amenities=PLOT_AMEN[: 5 + (i % 3)],
            highlights=f"DTCP-approved residential plot of {area_sqft} sq.ft in "
                       f"a gated layout at {loc}, clear title and ready for "
                       "construction.",
            cover=IMAGES["plot"], photos=4 + (i % 6))
    base["attributes"] = _attrs(ptype, i, base)
    return base


TYPES = ["Apartment", "Villa", "Independent House", "Coliving", "PG",
         "Commercial", "Coworking", "Plot", "Stay"]
listings = []
_g = 0
for _t in TYPES:
    for _i in range(10):
        listings.append(make(_t, _i, _g))
        _g += 1

# replace previous demo listings
sb.table("properties_home").delete().eq("owner_id", uid).execute()

for l in listings:
    photos = l.pop("photos")
    cover = l.pop("cover")
    sb.table("properties_home").insert(
        {
            **l,
            "owner_id": uid,
            "status": "published",
            "cover_image_url": cover,
            "photo_urls": [cover] * photos,
        }
    ).execute()

print(f"inserted {len(listings)} published listings "
      f"({len(TYPES)} types x 10).")
print("done.")
