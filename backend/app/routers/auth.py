from fastapi import APIRouter, Depends

from ..auth import get_current_user

router = APIRouter(prefix="/auth", tags=["auth"])


@router.get("/session")
def session(user: dict = Depends(get_current_user)):
    """Verify the current token and echo back the authenticated user."""
    return {"user": {"id": user["id"], "email": user["email"], "phone": user["phone"]}}
