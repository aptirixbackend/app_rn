"""Backend-owned phone-OTP auth: generate, store (hashed), verify, and mint
the app's own JWT. No dependency on Supabase Auth — only on a SQL database
(currently Supabase Postgres via the service key, swappable later)."""
import datetime as dt
import hashlib
import re
import secrets

import jwt

from .config import settings
from .database import get_supabase


def _now_iso() -> str:
    return dt.datetime.now(dt.timezone.utc).isoformat()


def normalize_phone(p: str) -> str:
    """Collapse to `+<digits>` so storage, lookup and Plivo all agree."""
    return "+" + re.sub(r"\D", "", p or "")


def new_code() -> str:
    return f"{secrets.randbelow(1_000_000):06d}"


def _hash(phone: str, code: str) -> str:
    # Peppered with the signing secret; codes are short-lived + attempt-capped.
    return hashlib.sha256(
        f"{phone}:{code}:{settings.auth_jwt_secret}".encode()
    ).hexdigest()


def can_resend(phone: str) -> bool:
    sb = get_supabase()
    since = (
        dt.datetime.now(dt.timezone.utc)
        - dt.timedelta(seconds=settings.otp_resend_seconds)
    ).isoformat()
    r = (
        sb.table("otp_codes_home")
        .select("id")
        .eq("phone", phone)
        .gt("created_at", since)
        .limit(1)
        .execute()
    )
    return not r.data


def store_code(phone: str, code: str) -> None:
    sb = get_supabase()
    expires = (
        dt.datetime.now(dt.timezone.utc)
        + dt.timedelta(seconds=settings.otp_ttl_seconds)
    ).isoformat()
    sb.table("otp_codes_home").insert(
        {"phone": phone, "code_hash": _hash(phone, code), "expires_at": expires}
    ).execute()


def verify_code(phone: str, code: str) -> bool:
    sb = get_supabase()
    r = (
        sb.table("otp_codes_home")
        .select("*")
        .eq("phone", phone)
        .eq("consumed", False)
        .gt("expires_at", _now_iso())
        .order("created_at", desc=True)
        .limit(1)
        .execute()
    )
    if not r.data:
        return False
    row = r.data[0]
    if row.get("attempts", 0) >= settings.otp_max_attempts:
        return False
    if not secrets.compare_digest(row["code_hash"], _hash(phone, code)):
        sb.table("otp_codes_home").update(
            {"attempts": row.get("attempts", 0) + 1}
        ).eq("id", row["id"]).execute()
        return False
    sb.table("otp_codes_home").update({"consumed": True}).eq(
        "id", row["id"]
    ).execute()
    return True


def upsert_user(phone: str) -> dict:
    """Find the user by phone or create one. Backend owns the row now, so no
    Supabase Auth / auth.users involvement."""
    sb = get_supabase()
    r = (
        sb.table("profiles_home")
        .select("*")
        .eq("phone", phone)
        .limit(1)
        .execute()
    )
    if r.data:
        return r.data[0]
    ins = sb.table("profiles_home").insert({"phone": phone}).execute()
    return ins.data[0]


def issue_jwt(user_id: str, phone: str) -> str:
    now = dt.datetime.now(dt.timezone.utc)
    payload = {
        "sub": user_id,
        "phone": phone,
        "iat": int(now.timestamp()),
        "exp": int((now + dt.timedelta(days=settings.auth_token_days)).timestamp()),
    }
    return jwt.encode(payload, settings.auth_jwt_secret, algorithm="HS256")
