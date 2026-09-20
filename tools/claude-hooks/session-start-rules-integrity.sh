#!/usr/bin/env bash
# session-start-rules-integrity.sh — item 3 of the Claude Code guardrails plan.
# Fires on SessionStart. Checks ~/.augment/rules/*.md for dangling symlinks and
# verifies .ai-guidance/invariants.md is readable from the session's cwd.
# Emits a one-line status banner (stdout becomes additionalContext).
# Exit codes: 0 = ok, 2 = block (integrity failure).
set -euo pipefail
if [[ "${CLAUDE_HOOKS_BYPASS:-0}" == "1" ]]; then exit 0; fi

rotate_file() {
  local file="$1" max_bytes="$2" generations="$3" size

  rotation_lock_is_owned || return 0

  # Avoid following symlinks or touching non-regular entries. Rotation is
  # best-effort because housekeeping must never prevent a session from opening.
  [[ -f "$file" && ! -L "$file" && -r "$file" ]] || return 0
  size="$(wc -c 2>/dev/null < "$file")" || return 0
  size="${size//[[:space:]]/}"
  [[ "$size" =~ ^[0-9]+$ ]] || return 0
  (( size > max_bytes )) || return 0

  case "$generations" in
    1|2) ;;
    *) return 0 ;;
  esac
  if [[ -e "$file.1" || -L "$file.1" ]]; then
    [[ -f "$file.1" || -L "$file.1" ]] || return 0
  fi
  if [[ "$generations" == "2" && ( -e "$file.2" || -L "$file.2" ) ]]; then
    [[ -f "$file.2" || -L "$file.2" ]] || return 0
  fi

  case "$generations" in
    2)
      if [[ -e "$file.2" || -L "$file.2" ]]; then
        rotation_lock_is_owned || return 0
        rm -f "$file.2" || return 0
      fi
      if [[ -e "$file.1" || -L "$file.1" ]]; then
        rotation_lock_is_owned || return 0
        mv "$file.1" "$file.2" || return 0
      fi
      ;;
    1)
      if [[ -e "$file.1" || -L "$file.1" ]]; then
        rotation_lock_is_owned || return 0
        rm -f "$file.1" || return 0
      fi
      ;;
  esac

  rotation_lock_is_owned || return 0
  mv "$file" "$file.1" || return 0
}

HOOKS_DIR="$HOME/.claude/hooks"
METRICS_FILE="${CLAUDE_SKILL_ROUTER_METRICS:-$HOOKS_DIR/skill-router-metrics.jsonl}"
ROTATION_LOCK="$HOOKS_DIR/.log-rotation.lock"
ROTATION_RECLAIM_CLAIM="$HOOKS_DIR/.log-rotation.reclaim"
# Separate from ROTATION_RECLAIM_CLAIM on purpose: lockf(1)/flock(1) create
# their lock-target path if it is missing, so serializing on the claim path
# itself recreates it as a plain file the instant recover_legacy_reclaim_
# directory() has just rmdir'd it -- observed on Linux CI (flock creates
# missing lock targets by default; neither lockf(1) nor flock(1) exist on
# macOS, so this path was never exercised locally). A dedicated, always-ok-
# to-recreate lock file keeps that OS-level serialization primitive from
# fighting the application-level "is a reclaim in progress" marker.
ROTATION_RECLAIM_LOCKFILE="$HOOKS_DIR/.log-rotation.reclaim.lock"
ROTATION_LOCK_HELD=0
ROTATION_LOCK_OWNER_RECORD=""
ROTATION_INCOMPLETE_LOCK_STALE_SECONDS=300

rotation_lock_contains_only_pid() (
  local -a entries=()

  shopt -s dotglob nullglob
  entries=("$ROTATION_LOCK"/*)
  [[ "${#entries[@]}" -eq 1 && "${entries[0]}" == "$ROTATION_LOCK/pid" ]]
)

rotation_lock_is_empty() (
  local -a entries=()

  shopt -s dotglob nullglob
  entries=("$ROTATION_LOCK"/*)
  [[ "${#entries[@]}" -eq 0 ]]
)

path_age_seconds() {
  local path="$1" path_mtime now

  path_mtime="$(stat -c %Y "$path" 2>/dev/null || stat -f %m "$path" 2>/dev/null || true)"
  [[ "$path_mtime" =~ ^[0-9]+$ ]] || return 1
  now="$(date +%s 2>/dev/null)" || return 1
  [[ "$now" =~ ^[0-9]+$ ]] || return 1
  (( now >= path_mtime )) || return 1
  printf '%s\n' "$((now - path_mtime))"
}

rotation_lock_age_seconds() {
  path_age_seconds "$ROTATION_LOCK"
}

directory_is_empty() (
  local path="$1"
  local -a entries=()

  shopt -s dotglob nullglob
  entries=("$path"/*)
  [[ "${#entries[@]}" -eq 0 ]]
)

write_owner_without_overwrite() (
  local path="$1" owner_record="$2"

  set -o noclobber
  printf '%s\n' "$owner_record" > "$path"
)

rotation_lock_is_owned() {
  local current_owner=""

  [[ "$ROTATION_LOCK_HELD" == "1" ]] || return 1
  [[ -d "$ROTATION_LOCK" && ! -L "$ROTATION_LOCK" ]] || return 1
  rotation_lock_contains_only_pid || return 1
  [[ -f "$ROTATION_LOCK/pid" && ! -L "$ROTATION_LOCK/pid" && -r "$ROTATION_LOCK/pid" ]] || return 1
  current_owner="$(< "$ROTATION_LOCK/pid")" || return 1
  [[ -n "$ROTATION_LOCK_OWNER_RECORD" && "$current_owner" == "$ROTATION_LOCK_OWNER_RECORD" ]]
}

reclaim_stale_rotation_lock() {
  local holder_record="" holder_pid="" lock_age=""

  [[ "${ROTATION_RECLAIM_GUARD:-0}" == "1" ]] || return 1
  [[ -d "$ROTATION_LOCK" && ! -L "$ROTATION_LOCK" ]] || return 1

  if rotation_lock_contains_only_pid; then
    [[ -f "$ROTATION_LOCK/pid" && ! -L "$ROTATION_LOCK/pid" && -r "$ROTATION_LOCK/pid" ]] || return 1

    if [[ ! -s "$ROTATION_LOCK/pid" ]]; then
      lock_age="$(rotation_lock_age_seconds)" || return 1
      (( lock_age > ROTATION_INCOMPLETE_LOCK_STALE_SECONDS )) || return 1
      [[ ! -s "$ROTATION_LOCK/pid" ]] || return 1
    else
      holder_record="$(< "$ROTATION_LOCK/pid")" || return 1
      [[ "$holder_record" =~ ^([1-9][0-9]*)(:[0-9]+)?$ ]] || return 1
      holder_pid="${BASH_REMATCH[1]}"
      kill -0 "$holder_pid" 2>/dev/null && return 1
    fi

    rm -f "$ROTATION_LOCK/pid" 2>/dev/null || return 1
    rmdir "$ROTATION_LOCK" 2>/dev/null || return 1
  elif rotation_lock_is_empty; then
    lock_age="$(rotation_lock_age_seconds)" || return 1
    (( lock_age > ROTATION_INCOMPLETE_LOCK_STALE_SECONDS )) || return 1
    rmdir "$ROTATION_LOCK" 2>/dev/null || return 1
  else
    return 1
  fi
}

initialize_rotation_lock_owner() {
  ROTATION_LOCK_OWNER_RECORD="$$:${RANDOM}${RANDOM}"
  if ! write_owner_without_overwrite "$ROTATION_LOCK/pid" "$ROTATION_LOCK_OWNER_RECORD" 2>/dev/null; then
    ROTATION_LOCK_OWNER_RECORD=""
    return 1
  fi

  ROTATION_LOCK_HELD=1
  if ! rotation_lock_is_owned; then
    ROTATION_LOCK_HELD=0
    ROTATION_LOCK_OWNER_RECORD=""
    return 1
  fi
}

acquire_fresh_rotation_lock() {
  mkdir "$ROTATION_LOCK" 2>/dev/null || return 1
  initialize_rotation_lock_owner
}

recover_legacy_reclaim_directory() {
  local claim_age=""

  [[ -d "$ROTATION_RECLAIM_CLAIM" && ! -L "$ROTATION_RECLAIM_CLAIM" ]] || return 1
  directory_is_empty "$ROTATION_RECLAIM_CLAIM" || return 1
  claim_age="$(path_age_seconds "$ROTATION_RECLAIM_CLAIM")" || return 1
  (( claim_age > ROTATION_INCOMPLETE_LOCK_STALE_SECONDS )) || return 1
  directory_is_empty "$ROTATION_RECLAIM_CLAIM" || return 1
  rmdir "$ROTATION_RECLAIM_CLAIM" 2>/dev/null
}

release_rotation_lock() {
  if [[ "$ROTATION_LOCK_HELD" == "1" ]]; then
    rotation_lock_is_owned || {
      ROTATION_LOCK_HELD=0
      ROTATION_LOCK_OWNER_RECORD=""
      return 0
    }
    rm -f "$ROTATION_LOCK/pid" 2>/dev/null || return 0
    rmdir "$ROTATION_LOCK" 2>/dev/null || true
    ROTATION_LOCK_HELD=0
    ROTATION_LOCK_OWNER_RECORD=""
  fi
}

rotate_logs_while_owned() {
  rotation_lock_is_owned || return 0
  trap release_rotation_lock EXIT
  if rotation_lock_is_owned; then
    rotate_file "$HOOKS_DIR/hook-audit.log" 1048576 2 || true
  fi
  if rotation_lock_is_owned; then
    rotate_file "$METRICS_FILE" 5242880 1 || true
  fi
  release_rotation_lock
  trap - EXIT
}

reclaim_and_rotate_logs() {
  [[ "${ROTATION_RECLAIM_GUARD:-0}" == "1" ]] || return 0

  if acquire_fresh_rotation_lock; then
    rotate_logs_while_owned
    return 0
  fi

  reclaim_stale_rotation_lock || return 0
  mkdir "$ROTATION_LOCK" 2>/dev/null || return 0
  initialize_rotation_lock_owner || return 0
  rotate_logs_while_owned
}

prepare_reclaim_claim_file() {
  if [[ -L "$ROTATION_RECLAIM_CLAIM" ]]; then
    return 1
  fi
  if [[ -d "$ROTATION_RECLAIM_CLAIM" ]]; then
    recover_legacy_reclaim_directory || return 1
  elif [[ -e "$ROTATION_RECLAIM_CLAIM" ]]; then
    [[ -f "$ROTATION_RECLAIM_CLAIM" && ! -L "$ROTATION_RECLAIM_CLAIM" ]] || return 1
  fi
}

run_reclaim_attempt_under_advisory_lock() {
  local lock_tool="" hook_script="${BASH_SOURCE[0]}"

  prepare_reclaim_claim_file || return 0
  if lock_tool="$(command -v lockf 2>/dev/null)" && [[ -n "$lock_tool" ]]; then
    ROTATION_RECLAIM_GUARD=1 "$lock_tool" -t 0 "$ROTATION_RECLAIM_LOCKFILE" \
      /bin/bash "$hook_script" --reclaim-and-rotate || true
  elif lock_tool="$(command -v flock 2>/dev/null)" && [[ -n "$lock_tool" ]]; then
    ROTATION_RECLAIM_GUARD=1 "$lock_tool" -n "$ROTATION_RECLAIM_LOCKFILE" \
      /bin/bash "$hook_script" --reclaim-and-rotate || true
  fi
}

mkdir -p "$HOOKS_DIR" 2>/dev/null || true
if [[ "${1:-}" == "--reclaim-and-rotate" ]]; then
  reclaim_and_rotate_logs
  exit 0
fi

# Fresh acquisition stays in-process. Stale reclamation is serialized by an
# OS advisory lock, which is released by the kernel even if its owner exits.
if acquire_fresh_rotation_lock; then
  rotate_logs_while_owned
else
  run_reclaim_attempt_under_advisory_lock
fi

LOG="$HOOKS_DIR/hook-audit.log"
log() { echo "$(date -u +%FT%TZ) session-start-integrity exit=$1 reason=$2" 2>/dev/null >> "$LOG" || true; }

INPUT="$(cat)"
CWD="$(jq -r '.cwd // empty' <<<"$INPUT")"
[[ -z "$CWD" ]] && CWD="$PWD"

PROBLEMS=()
ADVISORIES=()

# (a) augment rules dir — check for dangling symlinks, empty dir, or missing dir.
# A MISSING directory means Augment isn't installed/configured on THIS
# machine at all -- a normal, valid state for a Claude-Code-only contributor,
# fork, or CI runner, not a corruption signal, so it's advisory (non-
# blocking) rather than a PROBLEM. DANGLING symlinks or an existing dir
# EMPTIED of *.md files both imply an Augment setup existed here and broke,
# which stays blocking regardless of which agent is running Claude Code
# (llm-skill-review, 2026-07-17, S1: this hook previously hard-blocked every
# Claude-Code-only session start on a directory that belongs to a different
# agent entirely).
#
# SEEN_MARKER: "missing" and "existed here, then got wiped entirely" are
# bitwise-identical filesystem states, but very different signals -- the
# latter is the easiest, most complete way to strip this guardrail, and
# doing so via `rm -rf` requires zero approval from red-autonomy (confirmed
# by code-review-battery, 2026-07-17: Guardian + AttackerPersona, both
# converging on this independently). The marker is written only once the
# dir is observed healthy (present with >=1 *.md file); its later absence
# with the marker present is treated as tampering (PROBLEMS), not
# "never configured" (ADVISORIES). A machine that genuinely uninstalls
# Augment gets one hard block, then quiets down once the marker is removed
# too -- an accepted, bounded one-time friction cost for the detection value.
RULES_DIR="$HOME/.augment/rules"
SEEN_MARKER="$HOME/.claude/hooks/.augment-rules-seen"
if [[ ! -d "$RULES_DIR" ]]; then
  if [[ -f "$SEEN_MARKER" ]]; then
    PROBLEMS+=("MISSING: $RULES_DIR existed on this machine before (marker: $SEEN_MARKER) and is now gone entirely -- this looks like deletion/tampering, not 'never installed'. If Augment was deliberately uninstalled, remove $SEEN_MARKER to acknowledge and silence this.")
  else
    ADVISORIES+=("$RULES_DIR does not exist -- skipping Augment rules-parity check (not blocking; this machine may not use Augment)")
  fi
elif compgen -G "$RULES_DIR/*.md" >/dev/null 2>&1; then
  for f in "$RULES_DIR"/*.md; do
    [[ -f "$f" ]] || PROBLEMS+=("DANGLING: $f")
  done
  if (( ${#PROBLEMS[@]} == 0 )); then
    mkdir -p "$(dirname "$SEEN_MARKER")"
    touch "$SEEN_MARKER"
  fi
else
  PROBLEMS+=("WARNING: $RULES_DIR exists but contains no *.md files — all rules may be absent")
fi

# (b) invariants.md — walk up from cwd's git toplevel, fallback to ~/git
TOPLEVEL=""
TOPLEVEL="$(git -C "$CWD" rev-parse --show-toplevel 2>/dev/null)" || true
INV_PRIMARY="${TOPLEVEL:+$TOPLEVEL/.ai-guidance/invariants.md}"
INV_FALLBACK="$HOME/git/.ai-guidance/invariants.md"
INV=""
[[ -n "$INV_PRIMARY" && -r "$INV_PRIMARY" ]] && INV="$INV_PRIMARY"
[[ -z "$INV" && -r "$INV_FALLBACK" ]] && INV="$INV_FALLBACK"
if [[ -z "$INV" ]]; then
  PROBLEMS+=("invariants.md unreadable from $CWD (checked: ${INV_PRIMARY:-<no git toplevel>} and $INV_FALLBACK)")
fi

# (c) promotion strict-toggle staleness — catches a forgotten
# tools/promotion-strict-toggle.sh disable left un-restored (see
# .ai-guidance/promotion-strict-behind-runbook.md). Skips silently if this
# repo doesn't have the script (not every repo uses this workflow).
TOGGLE_SCRIPT="${TOPLEVEL:+$TOPLEVEL/tools/promotion-strict-toggle.sh}"
if [[ -n "$TOGGLE_SCRIPT" && -x "$TOGGLE_SCRIPT" ]]; then
  TOGGLE_EXIT=0
  # cd into TOPLEVEL first: the script resolves its own repo root via its
  # process cwd (`git rev-parse --show-toplevel`), which is NOT necessarily
  # the same as this hook's own process cwd. --porcelain gives a
  # machine-parsable "branch|state|age" line per entry instead of prose, so
  # we can tell a genuine STALE/CORRUPT report apart from the script itself
  # crashing (e.g. a bug introduced later) -- the two must not look identical.
  TOGGLE_OUTPUT="$(cd "$TOPLEVEL" && bash "$TOGGLE_SCRIPT" status --porcelain 2>&1)" || TOGGLE_EXIT=$?
  if [[ "$TOGGLE_EXIT" != "0" ]]; then
    if [[ "$TOGGLE_OUTPUT" =~ \|(STALE|CORRUPT)\| ]]; then
      PROBLEMS+=("strict-toggle: branch protection left weakened or sentinel corrupt -- $TOGGLE_OUTPUT")
    else
      PROBLEMS+=("strict-toggle status check itself failed unexpectedly (possible bug in the script, not necessarily a stale toggle -- investigate tools/promotion-strict-toggle.sh): $TOGGLE_OUTPUT")
    fi
  fi
fi

if (( ${#PROBLEMS[@]} > 0 )); then
  echo "[claude-hooks/SessionStart] integrity FAILURES — halt and alert user:"
  printf '  - %s\n' "${PROBLEMS[@]}"
  echo "  (bypass: set CLAUDE_HOOKS_BYPASS=1 to skip this check if you've confirmed it's safe to proceed)"
  log 2 "${#PROBLEMS[@]}-failures"
  exit 2
fi

if (( ${#ADVISORIES[@]} > 0 )); then
  echo "[claude-hooks/SessionStart] advisories (non-blocking):"
  printf '  - %s\n' "${ADVISORIES[@]}"
fi

echo "[claude-hooks/SessionStart] rules-file integrity OK; invariants at $INV"
log 0 ok
exit 0
