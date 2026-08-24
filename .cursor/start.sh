#!/usr/bin/env bash
#
# Per-boot startup for the OctoFit Tracker course.
#
# Brings up the MongoDB daemon that the Django backend connects to. The
# script is idempotent: it does nothing if a server is already listening,
# starts one otherwise, and waits until the database is ready before
# returning so dependent services can rely on it.

set -euo pipefail

DATA_DIR="${OCTOFIT_MONGO_DATA_DIR:-$HOME/.octofit/mongodb}"
LOG_FILE="${OCTOFIT_MONGO_LOG:-$HOME/.octofit/mongod.log}"
PORT="${OCTOFIT_MONGO_PORT:-27017}"

mkdir -p "$DATA_DIR" "$(dirname "$LOG_FILE")"

mongo_ready() {
  mongosh --quiet --port "$PORT" --eval 'db.runCommand({ ping: 1 }).ok' 2>/dev/null | grep -q '^1$'
}

if mongo_ready; then
  echo "==> MongoDB already running on port ${PORT}"
  exit 0
fi

echo "==> Starting MongoDB on port ${PORT} (dbpath: ${DATA_DIR})"
mongod \
  --dbpath "$DATA_DIR" \
  --bind_ip 127.0.0.1 \
  --port "$PORT" \
  --fork \
  --logpath "$LOG_FILE"

for _ in $(seq 1 30); do
  if mongo_ready; then
    echo "==> MongoDB is ready on port ${PORT}"
    exit 0
  fi
  sleep 1
done

echo "!! MongoDB did not become ready within 30s; recent log:" >&2
tail -n 20 "$LOG_FILE" >&2 || true
exit 1
