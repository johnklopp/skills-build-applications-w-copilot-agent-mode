#!/usr/bin/env bash
#
# Idempotent environment bootstrap for the OctoFit Tracker course.
#
# Installs the toolchain the exercise depends on (MongoDB) and, when the
# generated application already exists, refreshes its Python and Node
# dependencies. The application itself is created by the learner during the
# course, so every project-specific step is guarded to keep this script a
# no-op on the bare template.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

MONGODB_MAJOR="8.0"
KEYRING="/usr/share/keyrings/mongodb-server-${MONGODB_MAJOR}.gpg"
SOURCES_LIST="/etc/apt/sources.list.d/mongodb-org-${MONGODB_MAJOR}.list"

install_mongodb() {
  if command -v mongod >/dev/null 2>&1; then
    echo "==> MongoDB already installed: $(mongod --version | head -n1)"
    return
  fi

  echo "==> Installing MongoDB ${MONGODB_MAJOR} from the official repository"
  # shellcheck disable=SC1091
  . /etc/os-release

  curl -fsSL "https://pgp.mongodb.com/server-${MONGODB_MAJOR}.asc" \
    | sudo gpg --dearmor --yes -o "$KEYRING"

  echo "deb [ arch=amd64,arm64 signed-by=${KEYRING} ] https://repo.mongodb.org/apt/ubuntu ${VERSION_CODENAME}/mongodb-org/${MONGODB_MAJOR} multiverse" \
    | sudo tee "$SOURCES_LIST" >/dev/null

  sudo apt-get update
  sudo apt-get install -y mongodb-org

  echo "==> Installed $(mongod --version | head -n1)"
}

setup_backend() {
  local backend_dir="octofit-tracker/backend"
  if [ ! -f "${backend_dir}/requirements.txt" ]; then
    echo "==> Skipping backend setup (no ${backend_dir}/requirements.txt yet)"
    return
  fi

  echo "==> Setting up Django backend virtual environment"
  if [ ! -d "${backend_dir}/venv" ]; then
    python3 -m venv "${backend_dir}/venv"
  fi
  "${backend_dir}/venv/bin/python" -m pip install --upgrade pip
  "${backend_dir}/venv/bin/pip" install -r "${backend_dir}/requirements.txt"
}

setup_frontend() {
  local frontend_dir="octofit-tracker/frontend"
  if [ ! -f "${frontend_dir}/package.json" ]; then
    echo "==> Skipping frontend setup (no ${frontend_dir}/package.json yet)"
    return
  fi

  echo "==> Installing React frontend dependencies"
  if [ -f "${frontend_dir}/package-lock.json" ]; then
    (cd "${frontend_dir}" && npm ci)
  else
    (cd "${frontend_dir}" && npm install)
  fi
}

install_mongodb
setup_backend
setup_frontend

echo "==> Environment install complete"
