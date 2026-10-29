#!/usr/bin/env bash
set -eu

# Start MinIO + Qdrant
if command -v docker >/dev/null 2>&1; then
  docker compose up -d || docker-compose up -d
elif command -v docker-compose >/dev/null 2>&1; then
  docker-compose up -d
else
  echo "Docker Desktop or docker-compose is required to start MinIO and Qdrant." >&2
  exit 1
fi

# Create a virtual environment
if [ ! -d .venv ]; then
  python -m venv .venv
fi

# Activate virtualenv (works in bash on macOS/Linux and Git Bash on Windows)
if [ -f .venv/Scripts/activate ]; then
  . .venv/Scripts/activate
elif [ -f .venv/bin/activate ]; then
  . .venv/bin/activate
else
  echo "The virtual environment was not created correctly." >&2
  exit 1
fi

# Install dependencies
python -m pip install --upgrade pip
python -m pip install -r requirements.txt

# Optional: put PDF/TXT/MD files into documents/ and push them to the MinIO bucket
# python -m app.storage

# Start the API, then POST /ingest and POST /retrieve
exec python -m uvicorn app.api:app --reload
