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

    # ---- Plivo OTP delivery (Supabase Send-SMS hook → this backend) ----
    plivo_auth_id: str = ""
    plivo_auth_token: str = ""
    plivo_whatsapp_src: str = ""  # WhatsApp sender, e.g. 918035397000
    plivo_sms_src: str = ""       # optional SMS fallback sender
    wa_template_name: str = "otp"
    wa_template_lang: str = "en"
    # Supabase → Auth → Hooks → Send SMS signing secret (v1,whsec_...).
    send_sms_hook_secret: str = ""

    # ---- Backend-owned auth (no Supabase Auth) ----
    # Secret used to sign the app's session JWTs. MUST be overridden in prod.
    auth_jwt_secret: str = "dev-insecure-change-me"
    auth_token_days: int = 30
    otp_ttl_seconds: int = 600       # code valid for 10 minutes
    otp_max_attempts: int = 5        # wrong tries before a code is dead
    otp_resend_seconds: int = 30     # min gap between sends to one number

    model_config = SettingsConfigDict(env_file=".env", extra="ignore")


settings = Settings()
