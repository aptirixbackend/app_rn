from fastapi import APIRouter, Depends, HTTPException

from ..auth import get_current_user
from ..database import get_supabase
from ..models.user import GoalIn, OnboardingIn

router = APIRouter(tags=["users"])


@router.get("/me")
def get_me(user: dict = Depends(get_current_user)):
    """Return the current user's profile + preferences."""
    sb = get_supabase()
    profile = sb.table("profiles_home").select("*").eq("id", user["id"]).single().execute()
    prefs = (
        sb.table("user_preferences_home")
        .select("preference")
        .eq("user_id", user["id"])
        .execute()
    )
    if not profile.data:
        raise HTTPException(status_code=404, detail="Profile not found")
    return {
        "profile": profile.data,
        "preferences": [p["preference"] for p in prefs.data],
    }


@router.post("/onboarding/goal")
def set_goal(payload: GoalIn, user: dict = Depends(get_current_user)):
    """Save the primary goal ('post' | 'search')."""
    sb = get_supabase()
    sb.table("profiles_home").update({"primary_goal": payload.goal}).eq(
        "id", user["id"]
    ).execute()
    return {"ok": True}


@router.post("/onboarding")
def complete_onboarding(payload: OnboardingIn, user: dict = Depends(get_current_user)):
    """Save the 'Tell us about yourself' step + preferences, mark complete."""
    sb = get_supabase()
    uid = user["id"]

    update = {
        "first_name": payload.first_name,
        "last_name": payload.last_name,
        "dob": payload.dob.isoformat() if payload.dob else None,
        "email": payload.email,
        "onboarding_completed": True,
    }
    if payload.primary_goal is not None:
        update["primary_goal"] = payload.primary_goal
    sb.table("profiles_home").update(update).eq("id", uid).execute()

    if payload.preferences:
        rows = [{"user_id": uid, "preference": p} for p in payload.preferences]
        sb.table("user_preferences_home").upsert(
            rows, on_conflict="user_id,preference"
        ).execute()

    return {"ok": True}
