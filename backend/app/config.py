from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    supabase_url: str = ""
    supabase_anon_key: str = ""
    supabase_service_key: str = ""
    supabase_jwt_secret: str = ""
    cors_origins: str = "*"

    # While the app is on mock auth (no JWT), let unauthenticated requests act
    # as the demo owner so the API is usable as the primary backend. Set to
    # false at go-live once real Supabase auth is on.
    allow_demo_auth: bool = True

    model_config = SettingsConfigDict(env_file=".env", extra="ignore")


settings = Settings()
