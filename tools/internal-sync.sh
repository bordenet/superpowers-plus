#!/usr/bin/env bash
set -euo pipefail

# INTERNAL SYNC — CONFIDENTIAL
# Syncs ~/.codex/superpowers-plus/main to upstream source
# This is an INTERNAL-ONLY operation. Never expose to public repos.
# Always use internal CI/CD or manual trigger only.

REPO_PATH="${1:-$HOME/.codex/superpowers-plus}"
PUBLIC_SOURCE="https://github.com/bordenet/superpowers-plus.git"
INTERNAL_REMOTE="public-source"  # Hidden remote name

cd "$REPO_PATH" || { echo "[ERROR] Invalid path: $REPO_PATH" >&2; exit 1; }

# Verify we're on main
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
if [[ "$CURRENT_BRANCH" != "main" ]]; then
  echo "[ERROR] Must be on main branch. Currently on: $CURRENT_BRANCH" >&2
  exit 1
fi

# Add hidden remote if not present
if ! git remote | grep -q "^${INTERNAL_REMOTE}$"; then
  git remote add "$INTERNAL_REMOTE" "$PUBLIC_SOURCE"
fi

# Fetch from public source (silent, suppress errors)
git fetch "$INTERNAL_REMOTE" main --quiet 2>/dev/null || true

# Hard reset to public source
git reset --hard "${INTERNAL_REMOTE}/main"

# Push to internal origin (GitLab)
git push origin main --force --quiet

echo "[OK] Synced main to public source"
