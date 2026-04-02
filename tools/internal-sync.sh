#!/usr/bin/env bash
set -euo pipefail

# INTERNAL SYNC — CONFIDENTIAL
# Syncs ~/.codex/superpowers-plus main, dev, and staging from upstream public
# source to internal GitLab fork (origin).
# This is an INTERNAL-ONLY operation. Never expose to public repos.
# Always use internal CI/CD or manual trigger only.

PUBLIC_SOURCE="https://github.com/bordenet/superpowers-plus.git"

# Resolve repo path: SPP_SOURCE_DIR in ~/.codex/.env takes priority over the
# default, so behaviour is identical across machines that share config via
# OneDrive or similar. Mirrors the resolve_managed_dir() logic in sp-update.sh.
_resolve_repo_path() {
  if [[ -f "$HOME/.codex/.env" ]]; then
    local env_val
    env_val=$(bash -c 'set +u; source "$1" 2>/dev/null; printf "%s" "${SPP_SOURCE_DIR:-}"' \
      -- "$HOME/.codex/.env") || true
    if [[ -n "$env_val" && -d "$env_val/.git" ]]; then
      printf '%s' "$env_val"
      return 0
    fi
  fi
  printf '%s' "$HOME/.codex/superpowers-plus"
}

REPO_PATH="${1:-$(_resolve_repo_path)}"
INTERNAL_REMOTE="public-source"  # Hidden remote name
BRANCHES=(main dev staging)

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

# Fetch all branches from public source
git fetch "$INTERNAL_REMOTE" "${BRANCHES[@]}" --quiet 2>/dev/null || true

# Sync main: reset local branch then push to GitLab
git reset --hard "${INTERNAL_REMOTE}/main"
git push origin main --force --quiet
echo "[OK] Synced main"

# Sync dev and staging: push directly from remote tracking ref (no checkout needed)
for branch in dev staging; do
  if git push origin "refs/remotes/${INTERNAL_REMOTE}/${branch}:refs/heads/${branch}" --force --quiet 2>/dev/null; then
    echo "[OK] Synced ${branch}"
  else
    echo "[WARN] Could not sync ${branch} — may not exist on public source" >&2
  fi
done

echo "[OK] All branches synced from public source"
