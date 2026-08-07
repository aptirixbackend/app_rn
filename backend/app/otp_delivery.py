"""Deliver Supabase-generated OTPs over Plivo — WhatsApp first, SMS fallback.

Supabase Auth still generates, expires and verifies the code; this module only
delivers it, called from the `POST /auth/send-otp` Send-SMS hook.
"""
import base64
import hashlib
import hmac
import re

import httpx

from .config import settings


def _plivo_url() -> str:
    return f"https://api.plivo.com/v1/Account/{settings.plivo_auth_id}/Message/"


def _auth_header() -> str:
    raw = f"{settings.plivo_auth_id}:{settings.plivo_auth_token}".encode()
    return "Basic " + base64.b64encode(raw).decode()


async def _plivo_post(body: dict) -> bool:
    async with httpx.AsyncClient(timeout=15) as client:
        r = await client.post(
            _plivo_url(),
            json=body,
            headers={
                "Authorization": _auth_header(),
                "Content-Type": "application/json",
            },
        )
    if r.status_code >= 300:
        print("Plivo error", r.status_code, r.text)
    return r.status_code < 300


async def _send_whatsapp(dst: str, otp: str) -> bool:
    if not settings.plivo_whatsapp_src:
        return False
    # Matches the live "otp" template: body with one {{1}} param, no button.
    return await _plivo_post({
        "src": settings.plivo_whatsapp_src,
        "dst": dst,
        "type": "whatsapp",
        "template": {
            "name": settings.wa_template_name,
            "language": settings.wa_template_lang,
            "components": [
                {"type": "body", "parameters": [{"type": "text", "text": otp}]},
            ],
        },
    })


async def _send_sms(dst: str, otp: str) -> bool:
    if not settings.plivo_sms_src:
        return False
    return await _plivo_post({
        "src": settings.plivo_sms_src,
        "dst": dst,
        "text": f"{otp} is your verification code. Valid for 10 minutes.",
    })


async def deliver_otp(phone: str, otp: str) -> bool:
    dst = re.sub(r"\D", "", phone)
    return await _send_whatsapp(dst, otp) or await _send_sms(dst, otp)


def verify_hook_signature(secret: str, headers, body: str) -> bool:
    """Standard-webhooks HMAC verification of a Supabase auth hook."""
    try:
        b64 = secret.split("whsec_", 1)[-1] if "whsec_" in secret \
            else secret.rsplit(",", 1)[-1]
        key = base64.b64decode(b64)
        msg_id = headers.get("webhook-id", "")
        ts = headers.get("webhook-timestamp", "")
        signed = f"{msg_id}.{ts}.{body}".encode()
        expected = base64.b64encode(
            hmac.new(key, signed, hashlib.sha256).digest()
        ).decode()
        for part in headers.get("webhook-signature", "").split():
            _, _, sig = part.partition(",")
            if sig and hmac.compare_digest(sig, expected):
                return True
    except Exception:  # noqa: BLE001
        return False
    return False
