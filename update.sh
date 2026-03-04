#!/usr/bin/env bash
set -euo pipefail

# Always run from repo root (directory of this script)
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

UPSTREAM_URL="https://github.com/VilhelmMagnusLab/DIANA.git"

if [ ! -d .git ]; then
  echo "[update] No git repository found (ZIP install detected)."
  echo "[update] Initializing git and connecting to $UPSTREAM_URL ..."
  git init -q
  git remote add origin "$UPSTREAM_URL"
  git fetch origin --depth=1 -q
  git checkout -q -b main --track origin/main
  echo "[update] Done. Repository initialized. Future updates will be fast."
  echo "[update] Current commit: $(git rev-parse --short HEAD)"
  exit 0
fi

current_branch="$(git rev-parse --abbrev-ref HEAD)"

# Use 'upstream' if it exists, otherwise fall back to 'origin'
if git remote get-url upstream >/dev/null 2>&1; then
  FETCH_REMOTE="upstream"
  existing_url="$(git remote get-url upstream)"
  if [ "$existing_url" != "$UPSTREAM_URL" ]; then
    echo "[update] Updating upstream remote to $UPSTREAM_URL"
    git remote set-url upstream "$UPSTREAM_URL"
  fi
else
  FETCH_REMOTE="origin"
fi

echo "[update] Fetching latest changes from $FETCH_REMOTE (shallow fetch for speed)..."
git fetch "$FETCH_REMOTE" --depth=1 --tags --prune

# Detect default branch (fallback to main)
upstream_default_branch="$(git symbolic-ref -q --short refs/remotes/${FETCH_REMOTE}/HEAD 2>/dev/null | cut -d'/' -f2 || true)"
if [ -z "${upstream_default_branch:-}" ]; then
  upstream_default_branch="main"
fi

stashed=0
if ! git diff-index --quiet HEAD --; then
  stashed=1
  msg="auto-update-$(date +%Y%m%d_%H%M%S)"
  echo "[update] Local changes detected. Stashing (name: $msg)..."
  git stash push -u -m "$msg" >/dev/null
fi

echo "[update] Pulling latest changes from '$FETCH_REMOTE/$upstream_default_branch'..."
git pull --ff-only "$FETCH_REMOTE" "$upstream_default_branch"

if [ "$stashed" -eq 1 ]; then
  echo "[update] Restoring stashed changes..."
  set +e
  git stash pop
  pop_rc=$?
  set -e
  if [ $pop_rc -ne 0 ]; then
    echo "[update] Stash pop reported conflicts. Please resolve and commit:" >&2
    echo "        git status" >&2
    exit 2
  fi
fi

echo "[update] Update complete. Current commit: $(git rev-parse --short HEAD)"
if [ -x ./validate_setup.sh ]; then
  echo "[update] Tip: run ./validate_setup.sh to verify containers and tooling."
fi


