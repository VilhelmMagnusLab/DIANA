#!/usr/bin/env bash
set -euo pipefail

# Always run from repo root (directory of this script)
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

if [ ! -d .git ]; then
  echo "[update] This directory is not a git clone." >&2
  echo "[update] To enable one-command updates, clone the repo with git:" >&2
  echo "        git clone <REPO_URL> && cd <repo>" >&2
  echo "[update] Or re-download the latest ZIP from GitHub." >&2
  exit 1
fi

current_branch="$(git rev-parse --abbrev-ref HEAD)"

# Always define public upstream for end users
UPSTREAM_URL="https://github.com/VilhelmMagnusLab/nWGS_pipeline.git"
if git remote get-url upstream >/dev/null 2>&1; then
  existing_upstream_url="$(git remote get-url upstream)"
  if [ "$existing_upstream_url" != "$UPSTREAM_URL" ]; then
    echo "[update] Setting upstream to $UPSTREAM_URL"
    git remote set-url upstream "$UPSTREAM_URL"
  fi
else
  echo "[update] Adding upstream $UPSTREAM_URL"
  git remote add upstream "$UPSTREAM_URL"
fi

echo "[update] Fetching latest changes (including upstream)..."
git fetch --all --tags --prune >/dev/null

# Detect upstream default branch (fallback to main)
upstream_default_branch="$(git symbolic-ref -q --short refs/remotes/upstream/HEAD 2>/dev/null | cut -d'/' -f2 || true)"
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

echo "[update] Rebasing '$current_branch' onto 'upstream/$upstream_default_branch'..."
if ! git pull --rebase upstream "$upstream_default_branch"; then
  echo "[update] Rebase failed. Attempting to abort rebase and merge instead..."
  git rebase --abort >/dev/null 2>&1 || true
  git pull upstream "$upstream_default_branch"
fi

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


