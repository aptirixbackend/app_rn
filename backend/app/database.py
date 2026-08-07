from functools import lru_cache

from supabase import Client, create_client

from .config import settings


@lru_cache
def get_supabase() -> Client:
    """Server-side Supabase client using the service-role key.

    Bypasses RLS, so only use it in trusted backend code after the request
    has been authenticated via `get_current_user`.
    """
    if not settings.supabase_url or not settings.supabase_service_key:
        raise RuntimeError(
            "Supabase env vars missing. Copy backend/.env.example to .env and fill them in."
        )
    return create_client(settings.supabase_url, settings.supabase_service_key)
