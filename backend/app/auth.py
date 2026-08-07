import jwt
from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer

from .config import settings

# Demo owner (seed user "Sneha Reddy"). While the mobile app is still on mock
# auth it sends no Supabase JWT, so authenticated endpoints act as this owner —
# mirroring the app's direct-Supabase fallback so both write as the same user.
# Real JWTs take over automatically once auth is wired in; set
# ALLOW_DEMO_AUTH=false in the backend env to turn this off at go-live.
DEMO_OWNER_ID = "c508f4a5-272c-4aaa-bf3d-b8c23a3e26e1"

# auto_error=False → a missing Authorization header yields None instead of 401,
# letting us fall back to the demo owner in mock mode.
security = HTTPBearer(auto_error=False)


def _demo_user() -> dict:
    return {"id": DEMO_OWNER_ID, "email": None, "phone": None, "claims": {},
            "demo": True}


def get_current_user(
    creds: HTTPAuthorizationCredentials | None = Depends(security),
) -> dict:
    """Resolve the current user.

    - No token: mock mode → the demo owner (if ALLOW_DEMO_AUTH), else 401.
    - Token present: verify the Supabase HS256 access token and read `sub`.
      A *present but invalid* token is always rejected (401) — we never
      silently accept a bad token.
    """
    if creds is None:
        if settings.allow_demo_auth:
            return _demo_user()
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED, detail="Not authenticated"
        )

    try:
        # The backend signs its own session JWTs (see otp_auth.issue_jwt).
        payload = jwt.decode(
            creds.credentials,
            settings.auth_jwt_secret,
            algorithms=["HS256"],
        )
    except jwt.PyJWTError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired token",
        )

    return {
        "id": payload.get("sub"),
        "email": payload.get("email"),
        "phone": payload.get("phone"),
        "claims": payload,
    }
