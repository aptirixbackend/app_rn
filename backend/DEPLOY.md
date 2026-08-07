# Deploy the FastAPI backend to GCP Cloud Run (via Docker + GitHub)

The container listens on `$PORT` (Cloud Run sets it), reads config from **environment
variables** (no `.env` needed in the cloud), and exposes `/health`.

## One-time GCP setup (run locally with the `gcloud` CLI)

```bash
# 0) pick your project + region
gcloud config set project YOUR_PROJECT_ID
export REGION=asia-south1

# 1) enable the APIs
gcloud services enable run.googleapis.com artifactregistry.googleapis.com \
  cloudbuild.googleapis.com secretmanager.googleapis.com

# 2) Artifact Registry repo to hold the image
gcloud artifacts repositories create homevista \
  --repository-format=docker --location=$REGION

# 3) store the Supabase secrets in Secret Manager (paste values when prompted)
printf '%s' 'YOUR_SUPABASE_SERVICE_KEY' | gcloud secrets create SUPABASE_SERVICE_KEY --data-file=-
printf '%s' 'YOUR_SUPABASE_JWT_SECRET' | gcloud secrets create SUPABASE_JWT_SECRET --data-file=-

# 4) let Cloud Run's runtime service account read those secrets
PROJ_NUM=$(gcloud projects describe YOUR_PROJECT_ID --format='value(projectNumber)')
gcloud secrets add-iam-policy-binding SUPABASE_SERVICE_KEY \
  --member="serviceAccount:${PROJ_NUM}-compute@developer.gserviceaccount.com" \
  --role=roles/secretmanager.secretAccessor
gcloud secrets add-iam-policy-binding SUPABASE_JWT_SECRET \
  --member="serviceAccount:${PROJ_NUM}-compute@developer.gserviceaccount.com" \
  --role=roles/secretmanager.secretAccessor
```

## Deploy-from-GitHub service account (for the Actions workflow)

```bash
# a CI service account with permission to build + deploy
gcloud iam service-accounts create gh-deployer --display-name="GitHub deployer"
SA="gh-deployer@YOUR_PROJECT_ID.iam.gserviceaccount.com"
for ROLE in roles/run.admin roles/artifactregistry.writer roles/iam.serviceAccountUser roles/secretmanager.secretAccessor; do
  gcloud projects add-iam-policy-binding YOUR_PROJECT_ID --member="serviceAccount:$SA" --role="$ROLE"
done
gcloud iam service-accounts keys create key.json --iam-account="$SA"   # <-- upload contents as the GCP_SA_KEY secret, then delete key.json
```

## GitHub repo secrets (Settings → Secrets and variables → Actions)

| Secret | Value |
|---|---|
| `GCP_PROJECT_ID` | your GCP project id |
| `GCP_SA_KEY` | the entire contents of `key.json` above |
| `SUPABASE_URL` | `https://<ref>.supabase.co` |

(The Supabase **service key** and **JWT secret** live in Secret Manager, not GitHub.)

Push to `main` → the [`deploy-backend.yml`](../.github/workflows/deploy-backend.yml)
workflow builds the image, pushes it to Artifact Registry, and deploys to Cloud Run.
The run's last step prints the service URL (e.g. `https://homevista-api-xxxx.a.run.app`).

> Simpler alternative (no GitHub secrets): in the Cloud Run console → **Create service →
> Continuously deploy from a repository** → connect this GitHub repo, set the build source
> to `/backend` with the Dockerfile. Cloud Build then rebuilds on every push. You still set
> the env vars/secrets on the service once.

## Point the app at the deployed backend

In `mobile/env.json` set:

```json
"API_BASE_URL": "https://homevista-api-xxxx.a.run.app"
```

Rebuild the app. It now uses Cloud Run as the **primary**, with the direct-Supabase
fallback still automatic if the API is ever unreachable.

## At real-auth go-live

- Set `ALLOW_DEMO_AUTH=false` (env var on the service) and make sure
  `SUPABASE_JWT_SECRET` is filled — then only verified Supabase tokens are accepted.
- Tighten `CORS_ORIGINS` from `*` to your web app's origin(s).
