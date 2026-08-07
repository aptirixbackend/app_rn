"""Run every SQL file in supabase/migrations against DATABASE_URL.

DATABASE_URL is read from backend/.env (git-ignored). Safe to re-run: the
migrations use `create table if not exists` / `add column if not exists`.

Usage (from repo root):
    backend/.venv/Scripts/python.exe backend/scripts/run_migrations.py
"""
import os
import sys
from pathlib import Path

import psycopg2
from dotenv import load_dotenv

ROOT = Path(__file__).resolve().parents[2]  # repo root
load_dotenv(ROOT / "backend" / ".env")

db_url = os.environ.get("DATABASE_URL", "").strip()
if not db_url:
    sys.exit("DATABASE_URL is not set in backend/.env")

files = sorted((ROOT / "supabase" / "migrations").glob("*.sql"))
if not files:
    sys.exit("No migration files found.")

conn = psycopg2.connect(db_url, sslmode="require")
conn.autocommit = True
cur = conn.cursor()

failed = False
for f in files:
    print(f"-> {f.name} ...", end=" ", flush=True)
    try:
        cur.execute(f.read_text(encoding="utf-8"))
        print("ok")
    except Exception as e:  # noqa: BLE001
        failed = True
        print("ERROR")
        print(f"   {type(e).__name__}: {e}")

cur.close()
conn.close()
print("done." if not failed else "done (with errors above).")
sys.exit(1 if failed else 0)
