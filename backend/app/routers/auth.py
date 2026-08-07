import json

from fastapi import APIRouter, Depends, HTTPException, Request
from pydantic import BaseModel

from ..auth import get_current_user
from ..config import settings
from ..otp_auth import (
    can_resend,
    issue_jwt,
    new_code,
    normalize_phone,
    store_code,
    upsert_user,
    verify_code,
)
from ..otp_delivery import deliver_otp, verify_hook_signature

router = APIRouter(prefix="/auth", tags=["auth"])


class PhoneIn(BaseModel):
    phone: str


class VerifyIn(BaseModel):
    phone: str
    code: str


@router.get("/session")
def session(user: dict = Depends(get_current_user)):
    """Verify the current token and echo back the authenticated user."""
    return {"user": {"id": user["id"], "email": user["email"], "phone": user["phone"]}}


@router.post("/request-otp")
async def request_otp(body: PhoneIn):
    """Backend-owned login step 1: generate a code, store it hashed, and send
    it over Plivo WhatsApp. No Supabase Auth involved."""
    phone = normalize_phone(body.phone)
    if len(phone) < 9:
        raise HTTPException(status_code=400, detail="Enter a valid phone number")
    if not can_resend(phone):
        raise HTTPException(
            status_code=429,
            detail="Please wait a moment before requesting another code",
        )
    code = new_code()
    store_code(phone, code)
    if not await deliver_otp(phone, code):
        raise HTTPException(status_code=502, detail="Could not send the code")
    return {"ok": True, "expires_in": settings.otp_ttl_seconds}


@router.post("/verify-otp")
def verify_otp(body: VerifyIn):
    """Backend-owned login step 2: verify the code, find/create the user, and
    return the app's own session JWT."""
    phone = normalize_phone(body.phone)
    if not verify_code(phone, body.code):
        raise HTTPException(status_code=401, detail="Invalid or expired code")
    user = upsert_user(phone)
    token = issue_jwt(str(user["id"]), phone)
    return {
        "access_token": token,
        "token_type": "bearer",
        "user": {
            "id": user["id"],
            "phone": user.get("phone"),
            "name": user.get("first_name"),
            "onboarded": user.get("onboarding_completed", False),
        },
    }


@router.post("/send-otp")
async def send_otp_hook(request: Request):
    """(Optional) Supabase Auth Send-SMS hook target — only needed if you keep
    Supabase generating OTPs. Superseded by /request-otp + /verify-otp above."""
    raw = (await request.body()).decode()
    if settings.send_sms_hook_secret and not verify_hook_signature(
        settings.send_sms_hook_secret, request.headers, raw
    ):
        raise HTTPException(status_code=401, detail="Invalid signature")
    try:
        payload = json.loads(raw)
        phone = str(payload.get("user", {}).get("phone", ""))
        otp = str(payload.get("sms", {}).get("otp", ""))
    except Exception:  # noqa: BLE001
        raise HTTPException(status_code=400, detail="Bad payload")
    if not phone or not otp:
        raise HTTPException(status_code=400, detail="Missing phone or otp")
    if not await deliver_otp(phone, otp):
        raise HTTPException(status_code=502, detail="OTP delivery failed")
    return {}
