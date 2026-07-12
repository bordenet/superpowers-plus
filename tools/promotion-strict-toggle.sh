#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# Script: promotion-strict-toggle.sh
# PURPOSE: Safe wrapper for temporarily disabling required_status_checks.strict
#          on dev/staging/main during a promotion PR stuck on BEHIND (see
#          .ai-guidance/promotion-strict-behind-runbook.md for the full
#          symptom/root-cause/fix writeup this script implements).
#
#          Unlike a raw `gh api PATCH`, this script verifies the change via
#          read-back before trusting it, and writes a timestamped sentinel on
#          disable so a stale (forgotten) toggle is machine-detectable via the
#          `status` subcommand rather than silently left weakened forever.
#
# USAGE:   tools/promotion-strict-toggle.sh disable <branch>
#          tools/promotion-strict-toggle.sh restore <branch>
#          tools/promotion-strict-toggle.sh status
#
# EXIT:    disable/restore: 0 = confirmed via read-back, 1 = PATCH sent but
#                            read-back didn't confirm (sentinel state matches
#                            reality: NOT written on failed disable, NOT
#                            cleared on failed restore)
#          status:          0 = no active entries, or all within TTL
#                            1 = at least one entry is STALE (past TTL)
# -----------------------------------------------------------------------------
set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || {
  echo "❌ Not inside a git repo" >&2
  exit 1
}
SENTINEL="$REPO_ROOT/.strict-toggle-state"
REPO_SLUG="${PROMOTION_STRICT_TOGGLE_REPO:-bordenet/superpowers-plus}"
TTL_SECONDS="${PROMOTION_STRICT_TOGGLE_TTL_SECONDS:-1800}"
CONTEXT_FLAGS=(-f 'contexts[]=Node.js Tests' -f 'contexts[]=Quality Checks' -f 'contexts[]=Security Scan' -f 'contexts[]=Shell Tests')

usage() {
  cat <<'EOF'
Usage: tools/promotion-strict-toggle.sh disable <branch>
       tools/promotion-strict-toggle.sh restore <branch>
       tools/promotion-strict-toggle.sh status

  disable <branch>   Set required_status_checks.strict=false on <branch>,
                      verify via read-back, write a timestamped sentinel.
                      Refuses to write the sentinel if read-back doesn't
                      confirm false.
  restore <branch>    Set strict=true on <branch>, verify via read-back,
                      remove the sentinel entry for <branch>. Refuses to
                      clear the sentinel if read-back doesn't confirm true.
  status              List active (disabled) entries; flag any older than
                      PROMOTION_STRICT_TOGGLE_TTL_SECONDS (default 1800 = 30
                      min) as STALE. Exit 1 if any STALE entry exists.

<branch> should be the promotion PR's BASE branch (not head) -- see the
scenario table in .ai-guidance/promotion-strict-behind-runbook.md.
EOF
}

read_strict() {
  local branch="$1"
  gh api "repos/$REPO_SLUG/branches/$branch/protection/required_status_checks" --jq '.strict'
}

write_sentinel_entry() {
  local branch="$1" ts="$2"
  local tmp
  tmp="$(mktemp)"
  if [[ -f "$SENTINEL" ]]; then
    grep -v "^v1|${branch}|" "$SENTINEL" > "$tmp" || true
  fi
  echo "v1|${branch}|${REPO_SLUG}|${ts}" >> "$tmp"
  mv "$tmp" "$SENTINEL"
}

remove_sentinel_entry() {
  local branch="$1"
  [[ -f "$SENTINEL" ]] || return 0
  local tmp
  tmp="$(mktemp)"
  grep -v "^v1|${branch}|" "$SENTINEL" > "$tmp" || true
  if [[ -s "$tmp" ]]; then
    mv "$tmp" "$SENTINEL"
  else
    rm -f "$tmp"
    rm -f "$SENTINEL"
  fi
}

cmd_disable() {
  local branch="${1:?branch required}"
  gh api -X PATCH "repos/$REPO_SLUG/branches/$branch/protection/required_status_checks" \
    -F strict=false "${CONTEXT_FLAGS[@]}" >/dev/null

  local confirmed
  confirmed="$(read_strict "$branch")"
  if [[ "$confirmed" != "false" ]]; then
    echo "❌ PATCH sent but read-back shows strict=$confirmed (expected false). Sentinel NOT written." >&2
    exit 1
  fi

  local now
  now="$(date -u +%s)"
  write_sentinel_entry "$branch" "$now"
  echo "✅ strict=false confirmed on $branch. Sentinel written."
  echo "   REMINDER: run 'tools/promotion-strict-toggle.sh restore $branch' as soon as the merge completes."
}

cmd_restore() {
  local branch="${1:?branch required}"
  gh api -X PATCH "repos/$REPO_SLUG/branches/$branch/protection/required_status_checks" \
    -F strict=true "${CONTEXT_FLAGS[@]}" >/dev/null

  local confirmed
  confirmed="$(read_strict "$branch")"
  if [[ "$confirmed" != "true" ]]; then
    echo "❌ PATCH sent but read-back shows strict=$confirmed (expected true). Sentinel NOT cleared -- retry restore." >&2
    exit 1
  fi

  remove_sentinel_entry "$branch"
  echo "✅ strict=true confirmed on $branch. Sentinel cleared."
}

cmd_status() {
  if [[ ! -f "$SENTINEL" || ! -s "$SENTINEL" ]]; then
    echo "No active strict-toggle entries."
    return 0
  fi

  local now stale_found=0
  now="$(date -u +%s)"
  while IFS='|' read -r version branch _repo ts; do
    [[ "$version" == "v1" ]] || continue
    local age=$(( now - ts ))
    if (( age > TTL_SECONDS )); then
      echo "STALE: $branch has had strict=false for ${age}s (>${TTL_SECONDS}s threshold) -- restore immediately: tools/promotion-strict-toggle.sh restore $branch"
      stale_found=1
    else
      echo "active: $branch disabled ${age}s ago (within ${TTL_SECONDS}s threshold)"
    fi
  done < "$SENTINEL"

  (( stale_found == 0 )) || return 1
  return 0
}

case "${1:-}" in
  disable) shift; cmd_disable "$@" ;;
  restore) shift; cmd_restore "$@" ;;
  status)  cmd_status ;;
  -h|--help|"") usage; exit 0 ;;
  *) echo "❌ Unknown subcommand: $1" >&2; usage; exit 1 ;;
esac
