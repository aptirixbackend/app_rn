from fastapi import APIRouter, Depends, HTTPException

from ..auth import get_current_user
from ..database import get_supabase
from ..models.property import PropertyDraftIn, PropertyUpdateIn

router = APIRouter(prefix="/properties", tags=["properties"])

# Columns a listing's owner may write via PATCH. Anything else in the payload
# (owner_id, id, created_at, …) is ignored, so the update stays safe even though
# the input model accepts arbitrary fields.
EDITABLE_COLUMNS = {
    "title", "poster_type", "poster_tag", "posted_by",
    "property_type", "purpose", "bhk", "bathrooms", "carpet_area", "area_unit",
    "furnishing", "floor_number", "total_floors", "property_age", "facing",
    "available_from", "city", "area", "latitude", "longitude",
    "price", "price_period",
    "amenities", "additional_features", "highlights",
    "cover_image_url", "photo_urls", "video_url", "floor_plan_url",
    "attributes", "status",
}


def _ensure_owner(sb, property_id: str, uid: str) -> None:
    row = (
        sb.table("properties_home")
        .select("owner_id")
        .eq("id", property_id)
        .single()
        .execute()
    )
    if not row.data or row.data["owner_id"] != uid:
        raise HTTPException(status_code=403, detail="Not your property")


@router.post("")
def create_draft(payload: PropertyDraftIn, user: dict = Depends(get_current_user)):
    """Create a draft listing; returns its id."""
    sb = get_supabase()
    data = payload.model_dump(exclude_none=True)
    if payload.available_from:
        data["available_from"] = payload.available_from.isoformat()
    data["owner_id"] = user["id"]
    data["status"] = "draft"
    res = sb.table("properties_home").insert(data).execute()
    return {"id": res.data[0]["id"]}


@router.get("")
def list_published(limit: int = 200):
    """Public feed of published listings (no auth required)."""
    sb = get_supabase()
    res = (
        sb.table("properties_home")
        .select("*")
        .eq("status", "published")
        .order("created_at", desc=True)
        .limit(limit)
        .execute()
    )
    return res.data


@router.get("/mine")
def list_mine(user: dict = Depends(get_current_user)):
    """The current owner's listings — all statuses, drafts included."""
    sb = get_supabase()
    res = (
        sb.table("properties_home")
        .select("*")
        .eq("owner_id", user["id"])
        .order("created_at", desc=True)
        .execute()
    )
    return res.data


@router.get("/mine/latest-draft")
def latest_draft(user: dict = Depends(get_current_user)):
    """The current user's most recent draft (used by the Review step)."""
    sb = get_supabase()
    res = (
        sb.table("properties_home")
        .select("*")
        .eq("owner_id", user["id"])
        .eq("status", "draft")
        .order("created_at", desc=True)
        .limit(1)
        .execute()
    )
    return res.data[0] if res.data else None


@router.patch("/{property_id}")
def update_property(
    property_id: str,
    payload: PropertyUpdateIn,
    user: dict = Depends(get_current_user),
):
    """Update fields on a listing you own (amenities, media, pricing, status,
    per-type attributes, ...). Only allow-listed columns are written."""
    sb = get_supabase()
    _ensure_owner(sb, property_id, user["id"])
    raw = payload.model_dump(exclude_none=True)
    data = {k: v for k, v in raw.items() if k in EDITABLE_COLUMNS}
    if data:
        sb.table("properties_home").update(data).eq("id", property_id).execute()
    return {"ok": True}


@router.post("/{property_id}/publish")
def publish(property_id: str, user: dict = Depends(get_current_user)):
    """Publish a listing you own."""
    sb = get_supabase()
    _ensure_owner(sb, property_id, user["id"])
    sb.table("properties_home").update({"status": "published"}).eq(
        "id", property_id
    ).execute()
    return {"ok": True}


@router.get("/{property_id}")
def get_one(property_id: str):
    """Public detail read for a single listing."""
    sb = get_supabase()
    res = (
        sb.table("properties_home")
        .select("*")
        .eq("id", property_id)
        .limit(1)
        .execute()
    )
    return res.data[0] if res.data else None
