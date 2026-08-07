from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from .config import settings
from .routers import auth, properties, users

app = FastAPI(title="AI Real Estate API", version="0.1.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=[o.strip() for o in settings.cors_origins.split(",")],
    # Auth is a Bearer token (not cookies), so credentials aren't needed — and
    # keeping this false lets the "*" origin work for the Flutter web client.
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.get("/health", tags=["health"])
def health():
    return {"status": "ok"}


app.include_router(auth.router)
app.include_router(users.router)
app.include_router(properties.router)
