# Root Dockerfile so Cloud Run "deploy from repository" (build context = repo
# root) can find it. Builds the FastAPI backend that lives in ./backend.
FROM python:3.12-slim

ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PIP_NO_CACHE_DIR=1

WORKDIR /app

# Deps first so this layer caches across code-only changes.
COPY backend/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# App code only (no .env, no .venv, no scripts — see .dockerignore).
COPY backend/app ./app

# Cloud Run provides $PORT (defaults to 8080). Shell form so it expands.
EXPOSE 8080
CMD exec uvicorn app.main:app --host 0.0.0.0 --port ${PORT:-8080}
