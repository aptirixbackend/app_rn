# Backend — FastAPI

## Run locally
```bash
python -m venv .venv
.venv\Scripts\activate          # Windows PowerShell: .venv\Scripts\Activate.ps1
pip install -r requirements.txt
copy .env.example .env           # fill in Supabase keys
uvicorn app.main:app --reload
```

- Swagger UI: http://localhost:8000/docs
- Health check: http://localhost:8000/health

## Structure
```
app/
├── main.py          FastAPI app + CORS + router wiring
├── config.py        env settings
├── database.py      Supabase (service-role) client
├── auth.py          verify Supabase JWT -> current user
├── models/          Pydantic request/response schemas
└── routers/         endpoint groups (auth, users, ...)
```

## Auth model
The Flutter app logs in via Supabase (Google). It sends the Supabase access token as
`Authorization: Bearer <token>`. The backend verifies it with `SUPABASE_JWT_SECRET`
and identifies the user from the token's `sub` claim.
