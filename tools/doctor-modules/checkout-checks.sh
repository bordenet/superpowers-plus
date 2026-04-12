# shellcheck shell=bash
# doctor-modules/checkout-checks.sh — sourced by doctor-checks.sh
# All global state (CRITICAL, ERRORS, WARNINGS, FIXED, SKILL_*, FIX_MODE, etc.)
# is inherited from the parent script.

_doctor_checkout_checks() {
# --- Check 19: Stale Managed Checkout ---
# Detect when ~/.codex/superpowers-plus is behind origin/main.
# Parallel pre-fetch: kick off both git fetches concurrently to cut network wait in half
_timeout_cmd=""
command -v timeout &>/dev/null && _timeout_cmd="timeout 10"
command -v gtimeout &>/dev/null && _timeout_cmd="gtimeout 10"
declare -A _fetch_ok=()
if command -v git &>/dev/null; then
for managed_entry in "$MANAGED_SPP_DIR:superpowers-plus" "$MANAGED_OBRA_DIR:obra/superpowers"; do
  managed_dir="${managed_entry%%:*}"
  if [[ -d "$managed_dir/.git" ]]; then
    # shellcheck disable=SC2086
    $_timeout_cmd git -C "$managed_dir" fetch origin --quiet 2>/dev/null &
    _fetch_ok[$managed_dir]=$!
  fi
done
# Wait for all fetches to complete
for dir in "${!_fetch_ok[@]}"; do
  if ! wait "${_fetch_ok[$dir]}" 2>/dev/null; then
    _fetch_ok[$dir]="failed"
  else
    _fetch_ok[$dir]="ok"
  fi
done

check_stale_checkout() {
  local dir="$1" label="$2"
  [[ -d "$dir/.git" ]] || return 0
  if [[ "${_fetch_ok[$dir]:-}" == "failed" ]]; then
    echo "🟡 WARNING: $label — could not fetch origin (network issue?)"; ((WARNINGS++))
    return 0
  fi
  local local_head remote_head ahead behind
  local_head=$(git -C "$dir" rev-parse HEAD 2>/dev/null || echo "unknown")
  remote_head=$(git -C "$dir" rev-parse origin/main 2>/dev/null || echo "unknown")
  if [[ "$local_head" == "unknown" || "$remote_head" == "unknown" ]]; then
    return 0  # Can't compare — skip silently
  fi
  if [[ "$local_head" == "$remote_head" ]]; then
    return 0  # Up to date
  fi
  ahead=$(git -C "$dir" rev-list --count origin/main..HEAD 2>/dev/null || echo 0)
  behind=$(git -C "$dir" rev-list --count HEAD..origin/main 2>/dev/null || echo 0)
  local local_short remote_short
  local_short="${local_head:0:10}"
  remote_short="${remote_head:0:10}"
  if [[ "$behind" -gt 0 ]]; then
    echo "🟠 ERROR: $label — ${behind} commits behind origin/main"
    echo "   Local HEAD:  $local_short  Remote HEAD: $remote_short"
    [[ "$ahead" -gt 0 ]] && echo "   Also ${ahead} commits ahead (diverged)"
    ((ERRORS++))
    if can_fix safe && [[ "$ahead" -eq 0 ]]; then
      if git -C "$dir" pull --ff-only origin main --quiet 2>/dev/null; then
        echo "  ✅ FIXED: fast-forwarded $label to origin/main"; ((FIXED++))
      else
        echo "  ⚠️  Could not fast-forward (local changes?). Run: git -C \"$dir\" pull"
      fi
    fi
  elif [[ "$ahead" -gt 0 ]]; then
    # Local commits in the installed copy are always wrong — this is a deployment
    # target, not a working directory. Changes must go through the source repo.
    echo "🔴 CRITICAL: $label — ${ahead} local commit(s) not on origin/main"
    echo "   Installed copies must never be edited directly."
    echo "   Edit source repos, then reinstall."
    git -C "$dir" log --oneline "origin/main..HEAD" 2>/dev/null | head -5 | while IFS= read -r line; do
      echo "   $line"
    done
    echo "   Fix: git -C \"$dir\" reset --hard origin/main"
    ((CRITICAL++))
  fi
}
for managed_entry in "$MANAGED_SPP_DIR:superpowers-plus" "$MANAGED_OBRA_DIR:obra/superpowers"; do
  managed_dir="${managed_entry%%:*}"
  managed_label="${managed_entry##*:}"
  check_stale_checkout "$managed_dir" "$managed_label"
done

# --- Check 20: Dirty Managed Checkout ---
# Detect tracked and untracked changes in managed checkouts.
# Distinguishes safe-to-recreate artifacts from likely user-authored changes.
SAFE_DIRTY_PATTERNS='node_modules/|__pycache__/|\.pyc$|\.pyo$|\.DS_Store$|\.env\.local$|install-state/|modules/'
check_dirty_checkout() {
  local dir="$1" label="$2"
  [[ -d "$dir/.git" ]] || return 0
  local porcelain user_changes safe_changes
  porcelain=$(git -C "$dir" status --porcelain 2>/dev/null || true)
  [[ -z "$porcelain" ]] && return 0  # Clean
  safe_changes=$(echo "$porcelain" | grep -E "$SAFE_DIRTY_PATTERNS" || true)
  user_changes=$(echo "$porcelain" | grep -vE "$SAFE_DIRTY_PATTERNS" || true)
  local safe_count user_count
  safe_count=0; [[ -n "$safe_changes" ]] && safe_count=$(echo "$safe_changes" | wc -l | tr -d ' ')
  user_count=0; [[ -n "$user_changes" ]] && user_count=$(echo "$user_changes" | wc -l | tr -d ' ')
  if [[ "$user_count" -gt 0 ]]; then
    echo "🟠 ERROR: $label — $user_count uncommitted change(s) detected"
    echo "$user_changes" | head -5 | while IFS= read -r line; do
      echo "   $line"
    done
    [[ "$user_count" -gt 5 ]] && echo "   ... and $((user_count - 5)) more"
    ((ERRORS++))
    if can_fix moderate; then
      # Stash user changes with a descriptive message before any destructive action
      local stash_msg
      stash_msg="doctor-backup-$(date +%Y%m%d-%H%M%S)"
      # git stash push requires git 2.13+; fall back to git stash save
      local stash_ok=false
      if git -C "$dir" stash push -m "$stash_msg" --include-untracked 2>/dev/null; then
        stash_ok=true
      elif git -C "$dir" stash save "$stash_msg" 2>/dev/null; then
        stash_ok=true
      fi
      if [[ "$stash_ok" == "true" ]]; then
        echo "  ✅ FIXED: stashed local changes as '$stash_msg'"
        echo "  📦 Recover with: git -C \"$dir\" stash pop"; ((FIXED++))
      else
        echo "  ⚠️  Could not stash changes. Resolve manually."
      fi
    fi
  fi
  if [[ "$safe_count" -gt 0 ]]; then
    echo "🔵 INFO: $label — $safe_count generated/install artifact(s) (safe to clean)"
    if can_fix moderate; then
      # Remove gitignored files first
      git -C "$dir" clean -fdX --quiet 2>/dev/null || true
      # Also remove untracked safe-pattern files/dirs (e.g. modules/) that are not gitignored
      while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        # porcelain lines: "?? path" or "?? dir/" — strip the leading status chars
        artifact="${line#\?\? }"
        artifact="${artifact#"$dir/"}"
        full_path="$dir/$artifact"
        # Strip trailing slash for the path check
        full_path="${full_path%/}"
        [[ -e "$full_path" ]] && rm -rf "$full_path"
      done <<< "$safe_changes"
      echo "  ✅ FIXED: cleaned generated artifacts"; ((FIXED++))
    fi
  fi
}
for managed_entry in "$MANAGED_SPP_DIR:superpowers-plus" "$MANAGED_OBRA_DIR:obra/superpowers"; do
  managed_dir="${managed_entry%%:*}"
  managed_label="${managed_entry##*:}"
  check_dirty_checkout "$managed_dir" "$managed_label"
done
fi  # end: command -v git guard for checks 19/20
# --- Check 21: Git Hook Integrity ---
# Verifies this source checkout has the current pre-commit and pre-push hooks
# installed. Missing or stale hooks disable the local guardrails that should block
# IP leaks before commit/push.
HOOK_INSTALL_SCRIPT="$SCRIPT_DIR/install-hooks.sh"
_doctor_hook_integrity() {
  local hooks_dir hook_name expected installed
  local -a issues=()

  [[ -f "$HOOK_INSTALL_SCRIPT" ]] || return 0
  git -C "$REPO_ROOT" rev-parse --git-dir >/dev/null 2>&1 || return 0
  hooks_dir="$(git -C "$REPO_ROOT" rev-parse --git-path hooks 2>/dev/null || echo "$REPO_ROOT/.git/hooks")"

  if [[ ! -d "$hooks_dir" ]]; then
    issues+=(".git/hooks directory missing")
  fi

  for hook_name in pre-commit pre-push; do
    expected="$SCRIPT_DIR/$hook_name"
    installed="$hooks_dir/$hook_name"
    [[ -f "$expected" ]] || continue
    if [[ ! -f "$installed" ]]; then
      issues+=("$hook_name missing")
      continue
    fi
    [[ -x "$installed" ]] || issues+=("$hook_name is not executable")
    cmp -s "$expected" "$installed" || issues+=("$hook_name differs from tools/$hook_name")
  done

  if [[ ${#issues[@]} -gt 0 ]]; then
    echo "🟠 ERROR: git-hooks — repo hooks missing or stale"
    for issue in "${issues[@]}"; do
      echo "   - $issue"
    done
    echo "   Fix: bash \"$HOOK_INSTALL_SCRIPT\""
    ((ERRORS++))
    if can_fix safe; then
      if bash "$HOOK_INSTALL_SCRIPT" >/dev/null 2>&1; then
        echo "  ✅ FIXED: installed current pre-commit/pre-push hooks"; ((FIXED++))
      else
        echo "  ⚠️  Could not install git hooks automatically"
      fi
    fi
  fi
}
_doctor_hook_integrity

}
