"""Backend-owned phone-OTP auth: generate, store (hashed), verify, and mint
the app's own JWT. No dependency on Supabase Auth — only on a SQL database
(currently Supabase Postgres via the service key, swappable later)."""
import datetime as dt
import hashlib
import re
import secrets

import jwt
from google.auth.transport import requests as google_requests
from google.oauth2 import id_token as google_id_token

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


def verify_google_token(token: str) -> dict | None:
    """Verify a Google ID token was issued for our Web client, and return its
    claims (email, name, picture, …) or None if invalid."""
    if not settings.google_client_id:
        return None
    try:
        return google_id_token.verify_oauth2_token(
            token, google_requests.Request(), settings.google_client_id
        )
    except Exception:  # noqa: BLE001
        return None


def upsert_user_by_email(email: str, name: str | None, avatar: str | None) -> dict:
    """Find a user by email or create one (Google Sign-In). Backend-owned, so no
    Supabase Auth involvement."""
    sb = get_supabase()
    r = (
        sb.table("profiles_home")
        .select("*")
        .eq("email", email)
        .limit(1)
        .execute()
    )
    if r.data:
        return r.data[0]
    row: dict = {"email": email}
    if name:
        row["first_name"] = name
    if avatar:
        row["avatar_url"] = avatar
    ins = sb.table("profiles_home").insert(row).execute()
    return ins.data[0]


def phone_in_use(phone: str, exclude_user_id: str) -> bool:
    """True if [phone] already belongs to a different user."""
    sb = get_supabase()
    r = (
        sb.table("profiles_home")
        .select("id")
        .eq("phone", phone)
        .neq("id", exclude_user_id)
        .limit(1)
        .execute()
    )
    return bool(r.data)


def set_user_phone(user_id: str, phone: str) -> dict:
    sb = get_supabase()
    sb.table("profiles_home").update({"phone": phone}).eq("id", user_id).execute()
    r = (
        sb.table("profiles_home")
        .select("*")
        .eq("id", user_id)
        .limit(1)
        .execute()
    )
    return r.data[0] if r.data else {}


def issue_jwt(user_id: str, phone: str) -> str:
    now = dt.datetime.now(dt.timezone.utc)
    payload = {
        "sub": user_id,
        "phone": phone,
        "iat": int(now.timestamp()),
        "exp": int((now + dt.timedelta(days=settings.auth_token_days)).timestamp()),
    }
    return jwt.encode(payload, settings.auth_jwt_secret, algorithm="HS256")


def decode_token(token: str) -> dict | None:
    """Verify one of our session JWTs and return its claims, or None. Used to
    authenticate the chat WebSocket (the token is passed in the URL path, where
    an Authorization header can't be set)."""
    try:
        return jwt.decode(token, settings.auth_jwt_secret, algorithms=["HS256"])
    except jwt.PyJWTError:
        return None
