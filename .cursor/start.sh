#!/usr/bin/env bash
#
# Per-boot startup for the OctoFit Tracker course.
#
# Brings up the MongoDB daemon that the Django backend connects to. On boot
# this command is launched detached and nothing waits on it, so MongoDB is
# run in the foreground (non-daemonizing) and stays attached for the lifetime
# of the environment. The script is idempotent: if a server is already
# listening it exits immediately instead of starting a duplicate.

set -euo pipefail

DATA_DIR="${OCTOFIT_MONGO_DATA_DIR:-$HOME/.octofit/mongodb}"
PORT="${OCTOFIT_MONGO_PORT:-27017}"

mkdir -p "$DATA_DIR"

mongo_ready() {
  mongosh --quiet --port "$PORT" --eval 'db.runCommand({ ping: 1 }).ok' 2>/dev/null | grep -q '^1$'
}

if mongo_ready; then
  echo "==> MongoDB already running on port ${PORT}; nothing to do"
  exit 0
fi

# A stale lock file from a previous, non-clean shutdown blocks startup.
rm -f "${DATA_DIR}/mongod.lock" 2>/dev/null || true

echo "==> Starting MongoDB (foreground) on port ${PORT} (dbpath: ${DATA_DIR})"
exec mongod --dbpath "$DATA_DIR" --bind_ip 127.0.0.1 --port "$PORT"
