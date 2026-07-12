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
#          The sentinel read-modify-write is protected by a mkdir-based lock
#          (portable, no `flock` dependency) so concurrent disable/restore
#          calls on different branches can't silently clobber each other.
#
# USAGE:   tools/promotion-strict-toggle.sh disable <branch>
#          tools/promotion-strict-toggle.sh restore <branch>
#          tools/promotion-strict-toggle.sh status [--porcelain]
#
#          <branch> must be one of: dev, staging, main (enforced -- this
#          script only ever operates on this repo's three promotion branches).
#
# EXIT:    disable/restore: 0 = confirmed via read-back, 1 = PATCH sent but
#                            read-back didn't confirm (sentinel state matches
#                            reality: NOT written on failed disable, NOT
#                            cleared on failed restore)
#          status:          0 = no active entries, or all within TTL
#                            1 = at least one entry is STALE or CORRUPT
#
# KNOWN LIMITATIONS (see runbook "Known gaps" for the full list):
#  - Lock is not held across a SIGKILL; a killed process can leave a stale
#    lock directory. The acquire loop times out after ~10s with a message
#    telling the operator how to remove it manually.
#  - Sentinel is local/gitignored by design: it tracks "did *this machine*
#    run disable", not "is strict actually false right now" (that's always
#    re-verified live against the GitHub API by disable/restore themselves).
# -----------------------------------------------------------------------------
set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || {
  echo "❌ Not inside a git repo" >&2
  exit 1
}
SENTINEL="$REPO_ROOT/.strict-toggle-state"
LOCKDIR="$SENTINEL.lock"
REPO_SLUG="bordenet/superpowers-plus"
TTL_SECONDS="${PROMOTION_STRICT_TOGGLE_TTL_SECONDS:-1800}"
CONTEXT_FLAGS=(-f 'contexts[]=Node.js Tests' -f 'contexts[]=Quality Checks' -f 'contexts[]=Security Scan' -f 'contexts[]=Shell Tests')

usage() {
  cat <<'EOF'
Usage: tools/promotion-strict-toggle.sh disable <branch>
       tools/promotion-strict-toggle.sh restore <branch>
       tools/promotion-strict-toggle.sh status [--porcelain]

  disable <branch>   Set required_status_checks.strict=false on <branch>,
                      verify via read-back, write a timestamped sentinel.
                      Refuses to write the sentinel if read-back doesn't
                      confirm false. <branch> must be dev, staging, or main.
  restore <branch>    Set strict=true on <branch>, verify via read-back,
                      remove the sentinel entry for <branch>. Refuses to
                      clear the sentinel if read-back doesn't confirm true.
                      <branch> must be dev, staging, or main.
  status              List active (disabled) entries; flag any older than
                      PROMOTION_STRICT_TOGGLE_TTL_SECONDS (default 1800 = 30
                      min) as STALE, and any entry with an unparsable
                      timestamp as CORRUPT. Exit 1 if any STALE or CORRUPT
                      entry exists. --porcelain emits "branch|state|age_secs"
                      lines instead of prose, for scripted callers.

<branch> should be the promotion PR's BASE branch (not head) -- see the
scenario table in .ai-guidance/promotion-strict-behind-runbook.md.

Env: PROMOTION_STRICT_TOGGLE_TTL_SECONDS overrides the staleness threshold.
EOF
}

validate_branch() {
  case "$1" in
    dev|staging|main) return 0 ;;
    *)
      echo "❌ Unsupported branch '$1' -- this script only operates on dev, staging, or main." >&2
      exit 1
      ;;
  esac
}

read_strict() {
  local branch="$1"
  gh api "repos/$REPO_SLUG/branches/$branch/protection/required_status_checks" --jq '.strict'
}

LOCK_HELD=0

_lock_acquire() {
  local waited=0
  while ! mkdir "$LOCKDIR" 2>/dev/null; do
    sleep 0.1
    waited=$(( waited + 1 ))
    if (( waited > 100 )); then
      echo "❌ Could not acquire sentinel lock ($LOCKDIR) after 10s. If no other instance of this script is running, this is a stale lock from a crashed process -- remove it manually: rmdir $LOCKDIR" >&2
      exit 1
    fi
  done
  LOCK_HELD=1
}

_lock_release() {
  if [[ "$LOCK_HELD" == "1" ]]; then
    rmdir "$LOCKDIR" 2>/dev/null || true
    LOCK_HELD=0
  fi
}
trap _lock_release EXIT

# Sentinel entries are plain lines "v1|<branch>|<repo>|<epoch>". Since
# <branch> is allowlisted to dev/staging/main (validate_branch above), it
# can never contain a regex metacharacter, so the unescaped `grep` pattern
# below is safe -- no need for -F/escaping.
write_sentinel_entry() {
  local branch="$1" ts="$2"
  _lock_acquire
  local tmp
  tmp="$(mktemp "${SENTINEL}.XXXXXX")"
  if [[ -f "$SENTINEL" ]]; then
    grep -v "^v1|${branch}|" "$SENTINEL" > "$tmp" || true
  fi
  echo "v1|${branch}|${REPO_SLUG}|${ts}" >> "$tmp"
  mv "$tmp" "$SENTINEL"
  _lock_release
}

remove_sentinel_entry() {
  local branch="$1"
  _lock_acquire
  if [[ ! -f "$SENTINEL" ]]; then
    _lock_release
    return 0
  fi
  local tmp
  tmp="$(mktemp "${SENTINEL}.XXXXXX")"
  grep -v "^v1|${branch}|" "$SENTINEL" > "$tmp" || true
  if [[ -s "$tmp" ]]; then
    mv "$tmp" "$SENTINEL"
  else
    rm -f "$tmp"
    rm -f "$SENTINEL"
  fi
  _lock_release
}

cmd_toggle() {
  local branch="$1" desired="$2"   # desired: "false" (disable) or "true" (restore)
  validate_branch "$branch"

  gh api -X PATCH "repos/$REPO_SLUG/branches/$branch/protection/required_status_checks" \
    -F "strict=$desired" "${CONTEXT_FLAGS[@]}" >/dev/null

  local confirmed
  confirmed="$(read_strict "$branch")"
  if [[ "$confirmed" != "$desired" ]]; then
    if [[ "$desired" == "false" ]]; then
      echo "❌ PATCH sent but read-back shows strict=$confirmed (expected false). Sentinel NOT written." >&2
    else
      echo "❌ PATCH sent but read-back shows strict=$confirmed (expected true). Sentinel NOT cleared -- retry restore." >&2
    fi
    exit 1
  fi

  if [[ "$desired" == "false" ]]; then
    local now
    now="$(date -u +%s)"
    write_sentinel_entry "$branch" "$now"
    echo "✅ strict=false confirmed on $branch. Sentinel written."
    echo "   REMINDER: run 'tools/promotion-strict-toggle.sh restore $branch' as soon as the merge completes."
  else
    remove_sentinel_entry "$branch"
    echo "✅ strict=true confirmed on $branch. Sentinel cleared."
  fi
}

cmd_disable() { cmd_toggle "${1:?branch required}" "false"; }
cmd_restore() { cmd_toggle "${1:?branch required}" "true"; }

cmd_status() {
  local porcelain=0
  [[ "${1:-}" == "--porcelain" ]] && porcelain=1

  if [[ ! -f "$SENTINEL" || ! -s "$SENTINEL" ]]; then
    (( porcelain )) || echo "No active strict-toggle entries."
    return 0
  fi

  local now bad_found=0
  now="$(date -u +%s)"
  while IFS='|' read -r version branch _repo ts; do
    [[ "$version" == "v1" ]] || continue

    if [[ ! "$ts" =~ ^[0-9]+$ ]]; then
      if (( porcelain )); then
        echo "${branch}|CORRUPT|-"
      else
        echo "CORRUPT: sentinel entry for '$branch' has an unparsable timestamp -- inspect $SENTINEL manually (e.g. 'tools/promotion-strict-toggle.sh restore $branch' to clear it, or edit the file directly)"
      fi
      bad_found=1
      continue
    fi

    local age=$(( now - ts ))
    if (( age > TTL_SECONDS )); then
      if (( porcelain )); then
        echo "${branch}|STALE|${age}"
      else
        echo "STALE: $branch has had strict=false for ${age}s (>${TTL_SECONDS}s threshold) -- restore immediately: tools/promotion-strict-toggle.sh restore $branch"
      fi
      bad_found=1
    else
      if (( porcelain )); then
        echo "${branch}|active|${age}"
      else
        echo "active: $branch disabled ${age}s ago (within ${TTL_SECONDS}s threshold)"
      fi
    fi
  done < "$SENTINEL"

  (( bad_found == 0 )) || return 1
  return 0
}

case "${1:-}" in
  disable) shift; cmd_disable "$@" ;;
  restore) shift; cmd_restore "$@" ;;
  status)  shift; cmd_status "$@" ;;
  -h|--help|"") usage; exit 0 ;;
  *) echo "❌ Unknown subcommand: $1" >&2; usage; exit 1 ;;
esac
