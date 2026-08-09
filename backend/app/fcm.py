"""Send FCM push notifications via the HTTP v1 API, gated by each user's
notification settings. Uses the Firebase service account (env FCM_SERVICE_ACCOUNT
as JSON, or the local backend/fcm-service-account.json file)."""
import json
import os

import httpx
from google.auth.transport.requests import Request as GoogleRequest
from google.oauth2 import service_account

from .config import settings
from .database import get_supabase

_SCOPE = "https://www.googleapis.com/auth/firebase.messaging"
_LOCAL_FILE = os.path.join(os.path.dirname(__file__), "..", "fcm-service-account.json")


def _load():
    info = None
    if settings.fcm_service_account.strip():
        try:
            info = json.loads(settings.fcm_service_account)
        except Exception:  # noqa: BLE001
            info = None
    elif os.path.exists(_LOCAL_FILE):
        with open(_LOCAL_FILE, encoding="utf-8") as f:
            info = json.load(f)
    if not info:
        return None, None
    creds = service_account.Credentials.from_service_account_info(
        info, scopes=[_SCOPE]
    )
    return creds, info.get("project_id")


_CREDS, _PROJECT_ID = _load()


def _access_token() -> str | None:
    if _CREDS is None:
        return None
    if not _CREDS.valid:
        _CREDS.refresh(GoogleRequest())
    return _CREDS.token


def configured() -> bool:
    return _CREDS is not None and bool(_PROJECT_ID)


async def _send_to_token(token: str, title: str, body: str, data: dict) -> bool:
    at = _access_token()
    if not at:
        return False
    url = f"https://fcm.googleapis.com/v1/projects/{_PROJECT_ID}/messages:send"
    message = {
        "message": {
            "token": token,
            "notification": {"title": title, "body": body},
            "data": {k: str(v) for k, v in (data or {}).items()},
            "android": {"priority": "high"},
        }
    }
    async with httpx.AsyncClient(timeout=15) as client:
        r = await client.post(
            url, json=message, headers={"Authorization": f"Bearer {at}"}
        )
    if r.status_code in (400, 404) and "UNREGISTERED" in r.text:
        # Token is dead — drop it so we stop trying.
        get_supabase().table("device_tokens_home").delete().eq(
            "token", token
        ).execute()
    return r.status_code < 300


async def notify_user(
    user_id: str,
    setting_key: str | None,
    title: str,
    body: str,
    data: dict | None = None,
) -> None:
    """Push to all a user's devices, honouring their notification settings
    (the master `notif_push` plus the per-type toggle)."""
    if not user_id or not configured():
        return
    sb = get_supabase()
    prof = (
        sb.table("profiles_home")
        .select("notif_settings")
        .eq("id", user_id)
        .limit(1)
        .execute()
    )
    prefs = {}
    if prof.data and isinstance(prof.data[0].get("notif_settings"), dict):
        prefs = prof.data[0]["notif_settings"]
    if prefs.get("notif_push", True) is False:
        return
    if setting_key and prefs.get(setting_key, True) is False:
        return

    toks = (
        sb.table("device_tokens_home")
        .select("token")
        .eq("user_id", user_id)
        .execute()
    )
    for row in toks.data or []:
        try:
            await _send_to_token(row["token"], title, body, data or {})
        except Exception:  # noqa: BLE001
            pass
