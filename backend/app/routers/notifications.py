from fastapi import APIRouter, Depends
from pydantic import BaseModel

from ..auth import get_current_user
from ..database import get_supabase
from ..fcm import notify_user

router = APIRouter(tags=["notifications"])


class DeviceIn(BaseModel):
    token: str
    platform: str = "android"


class NotifyIn(BaseModel):
    id: str


@router.post("/devices")
def register_device(body: DeviceIn, user: dict = Depends(get_current_user)):
    """Register/refresh this device's FCM token for the signed-in user."""
    if not body.token:
        return {"ok": False}
    sb = get_supabase()
    sb.table("device_tokens_home").upsert(
        {"user_id": user["id"], "token": body.token, "platform": body.platform},
        on_conflict="token",
    ).execute()
    return {"ok": True}


@router.patch("/me/notif-settings")
def update_notif_settings(payload: dict, user: dict = Depends(get_current_user)):
    """Mirror the app's notification toggles so the backend can gate pushes."""
    clean = {
        k: bool(v) for k, v in (payload or {}).items() if isinstance(k, str)
    }
    get_supabase().table("profiles_home").update(
        {"notif_settings": clean}
    ).eq("id", user["id"]).execute()
    return {"ok": True}


def _title(row: dict) -> str:
    prop = row.get("properties_home") or {}
    return (prop.get("title") if isinstance(prop, dict) else None) or "your property"


# ---- event triggers: the app calls these right after it writes the record ----
@router.post("/notify/lead")
async def notify_lead(body: NotifyIn, _: dict = Depends(get_current_user)):
    sb = get_supabase()
    res = (
        sb.table("leads_home")
        .select("*, properties_home(title)")
        .eq("id", body.id)
        .limit(1)
        .execute()
    )
    if not res.data:
        return {"ok": False}
    l = res.data[0]
    who = l.get("customer_name") or "Someone"
    booking = (l.get("kind") or "enquiry") == "booking"
    await notify_user(
        l.get("owner_id"),
        "notif_leads",
        "New booking request" if booking else "New enquiry",
        f"{who} is interested in {_title(l)}",
        {"type": "lead", "property_id": str(l.get("property_id") or "")},
    )
    return {"ok": True}


@router.post("/notify/visit")
async def notify_visit(body: NotifyIn, _: dict = Depends(get_current_user)):
    sb = get_supabase()
    res = (
        sb.table("visits_home")
        .select("*, properties_home(title)")
        .eq("id", body.id)
        .limit(1)
        .execute()
    )
    if not res.data:
        return {"ok": False}
    v = res.data[0]
    who = v.get("customer_name") or "Someone"
    await notify_user(
        v.get("owner_id"),
        "notif_visits",
        "New site visit request",
        f"{who} wants to visit {_title(v)}",
        {"type": "visit", "property_id": str(v.get("property_id") or "")},
    )
    return {"ok": True}


@router.post("/notify/lead-status")
async def notify_lead_status(body: NotifyIn, _: dict = Depends(get_current_user)):
    sb = get_supabase()
    res = (
        sb.table("leads_home")
        .select("*, properties_home(title)")
        .eq("id", body.id)
        .limit(1)
        .execute()
    )
    if not res.data:
        return {"ok": False}
    l = res.data[0]
    await notify_user(
        l.get("customer_id"),
        "notif_enquiries",
        "Enquiry update",
        f"Your enquiry on {_title(l)} is now {l.get('status') or 'updated'}",
        {"type": "lead", "property_id": str(l.get("property_id") or "")},
    )
    return {"ok": True}


@router.post("/notify/visit-status")
async def notify_visit_status(body: NotifyIn, _: dict = Depends(get_current_user)):
    sb = get_supabase()
    res = (
        sb.table("visits_home")
        .select("*, properties_home(title)")
        .eq("id", body.id)
        .limit(1)
        .execute()
    )
    if not res.data:
        return {"ok": False}
    v = res.data[0]
    await notify_user(
        v.get("customer_id"),
        "notif_visits",
        "Site visit update",
        f"Your visit for {_title(v)} is {v.get('status') or 'updated'}",
        {"type": "visit", "property_id": str(v.get("property_id") or "")},
    )
    return {"ok": True}
