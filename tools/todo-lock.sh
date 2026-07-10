#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# Script: todo-lock.sh
# PURPOSE: Advisory file locking for TODO.md to prevent concurrent write
#          corruption across multiple AI agent sessions and machines.
# USAGE:   ./todo-lock.sh acquire [--timeout SECS] [--ttl SECS]
#          ./todo-lock.sh release
#          ./todo-lock.sh status
#          ./todo-lock.sh steal
# DESIGN:  Uses mkdir (POSIX-atomic on local FS) + metadata file.
#          Cross-machine safety via TTL + hostname/PID validation.
#          NOT a hard mutex — advisory lock with backup as safety net.
# PLATFORM: macOS, Linux, WSL
# VERSION: 1.0.0
# -----------------------------------------------------------------------------
set -euo pipefail

# --- Bash Guard ---
if [ -z "${BASH_VERSION:-}" ]; then
    echo "ERROR: This script requires bash. Run with: bash $0" >&2
    exit 1
fi

# --- Configuration ---
DEFAULT_TTL=120          # seconds before lock is considered stale
DEFAULT_TIMEOUT=8        # total seconds to wait for lock (retry window)
RETRY_INTERVAL=2         # seconds between retries
LOCK_DIR_NAME=".TODO.md.lock"
MAX_LOCK_TTL_DIGITS=7    # bounds a declared ttl read from lock.json to <=9999999s (~115 days)

# --- Resolve TODO path (shared utility) ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=tools/resolve-env-path.sh
source "$SCRIPT_DIR/resolve-env-path.sh"
resolve_env
TODO_PATH=$(resolve_path "TODO_FILE_PATH" "$HOME/.codex/TODO.md")

TODO_DIR="$(dirname "$TODO_PATH")"
LOCK_DIR="${TODO_DIR}/${LOCK_DIR_NAME}"
LOCK_META="${LOCK_DIR}/lock.json"

# Validate the TODO directory exists
if [[ ! -d "$TODO_DIR" ]]; then
  echo "[todo-lock] ERROR: TODO directory does not exist: $TODO_DIR" >&2
  echo "[todo-lock] Check TODO_FILE_PATH in ~/.codex/.env" >&2
  exit 1
fi

# --- Identity ---
# Chained fallbacks: `hostname -s` isn't universally supported (e.g. some
# BusyBox builds reject the flag), and a plain `hostname` call can itself be
# absent on a minimal container image. `uname -n` is virtually universal
# (POSIX, present even in BusyBox). The final `|| echo` guarantees this
# assignment can never fail and abort the whole script under `set -e` --
# every one of the identity checks below (_is_stale, release ownership)
# degrades gracefully to "just doesn't match" on an unknown host, rather
# than crashing every invocation of this script.
HOSTNAME_SHORT=$(hostname -s 2>/dev/null || hostname 2>/dev/null | cut -d. -f1 || uname -n 2>/dev/null | cut -d. -f1 || echo "unknown-host")
# Use PPID (parent process) — the calling agent's shell survives after this script exits.
# Using $$ would store this script's PID, which dies immediately, making every lock look stale.
MY_PID=${PPID:-$$}

# --- Helpers ---
_log() { echo "[todo-lock] $1"; }
_err() { echo "[todo-lock] ERROR: $1" >&2; }

_write_meta() {
  local ttl_to_write="${1:-$DEFAULT_TTL}"
  local now
  now=$(date +%s)
  # Write atomically: write to temp file then move (avoids partial reads)
  local tmp="${LOCK_META}.tmp.$$"
  printf '{"hostname":"%s","pid":%s,"epoch":%s,"agent":"%s","ttl":%s}\n' \
    "$HOSTNAME_SHORT" "$MY_PID" "$now" "${AGENT_ID:-unknown}" "$ttl_to_write" > "$tmp"
  mv -f "$tmp" "$LOCK_META"
}

_lock_age() {
  if [[ -f "$LOCK_META" ]]; then
    local lock_epoch
    lock_epoch=$(grep -o '"epoch":[0-9]*' "$LOCK_META" 2>/dev/null | grep -o '[0-9]*' || echo "0")
    if [[ "$lock_epoch" -eq 0 ]]; then
      # Metadata file exists but is empty/corrupt — treat as very stale
      echo "999999"
      return
    fi
    local now
    now=$(date +%s)
    echo $(( now - lock_epoch ))
  elif [[ -d "$LOCK_DIR" ]]; then
    # Lock directory exists but metadata hasn't been written yet. This is
    # ambiguous: it's the normal state during the brief mkdir-then-write-meta
    # window of a concurrent acquirer that is legitimately mid-acquisition,
    # not just a process that died before writing metadata. Treating this as
    # instantly "orphaned" (age=999999) let a concurrent waiter steal a lock
    # that was never actually abandoned -- both processes then believe they
    # hold it. Use the lock DIRECTORY's own mtime as the age
    # instead: a genuinely-orphaned dir ages out via the same TTL as any
    # other stale lock; a dir mid-acquisition looks merely "young," not stale.
    local dir_mtime
    # GNU's -c FIRST, not BSD's -f: BSD stat rejects an unrecognized -c
    # cleanly (nonzero exit, falls through as intended), but on GNU coreutils
    # `-f` doesn't mean "custom format string" -- it means "show filesystem
    # info instead of file info", a completely different, valid mode. Trying
    # `-f %m` there doesn't error; it "succeeds" while printing a multi-line
    # filesystem-info dump (starting with "  File: ...") instead of a bare
    # mtime, which then corrupts the arithmetic below. Reversing the order
    # means the ambiguous flag is never reached on a GNU system.
    dir_mtime=$(stat -c %Y "$LOCK_DIR" 2>/dev/null || stat -f %m "$LOCK_DIR" 2>/dev/null || echo "")
    # Validate as a plain integer before ever handing this to arithmetic --
    # any unexpected stat output (a third platform's flag quirk, a future
    # regression) must degrade to "very stale" rather than feeding a
    # non-numeric string into $(( )), which is exactly how this surfaced in
    # CI (a GNU filesystem-info dump caused a bash "unbound variable" crash).
    if [[ -z "$dir_mtime" ]] || ! [[ "$dir_mtime" =~ ^[0-9]+$ ]]; then
      echo "999999"
    else
      local now
      now=$(date +%s)
      echo $(( now - dir_mtime ))
    fi
  else
    echo "0"
  fi
}

_lock_hostname() {
  grep -o '"hostname":"[^"]*"' "$LOCK_META" 2>/dev/null | sed 's/"hostname":"//;s/"//' || echo ""
}

_lock_pid() {
  grep -o '"pid":[0-9]*' "$LOCK_META" 2>/dev/null | grep -o '[0-9]*' || echo "0"
}

_lock_declared_ttl() {
  # $1 is the fallback to use when the metadata file exists but has no
  # "ttl" field (an old-format lock written before this feature existed) --
  # must be the CALLER's own ttl, not a hardcoded constant, to match the
  # backward-compat contract acquire_lock()'s python counterpart uses.
  local fallback_ttl="${1:-$DEFAULT_TTL}"
  local ttl
  ttl=$(grep -o '"ttl":[0-9]*' "$LOCK_META" 2>/dev/null | grep -o '[0-9]*' || echo "")
  # Validate as 1-7 plain digits (no sign) before trusting it: a value with
  # more digits could overflow bash's signed 64-bit `-gt` in _is_stale and
  # wrap negative, and a zero/negative ttl would make age > ttl true almost
  # immediately, force-removing a live lock the moment another process
  # checks it. The digit-only grep above already can't capture a literal
  # minus sign, but validate explicitly rather than rely on that as safety.
  if [[ "$ttl" =~ ^[0-9]{1,${MAX_LOCK_TTL_DIGITS}}$ ]] && [[ "$ttl" -gt 0 ]]; then
    echo "$ttl"
  else
    echo "$fallback_ttl"
  fi
}

_is_stale() {
  # $1 is a fallback used only when the lock has no metadata (yet) to read
  # its own declared ttl from. When metadata exists, staleness is judged
  # against the HOLDER's own declared ttl, not the caller's -- a waiter
  # calling acquire with a short --ttl must not judge a long-running
  # holder's lock stale just because the waiter's own patience is shorter.
  #
  # Sets _STALE_REASON as a side effect ("ttl-expired" or "dead-holder-pid")
  # whenever this returns 0 (stale) -- without it, "stealing stale lock
  # (age=0s)" for a dead-PID-on-this-host steal reads like a bug in the
  # staleness arithmetic to anyone who doesn't already know about the
  # separate dead-PID short-circuit below.
  _STALE_REASON=""
  local fallback_ttl="${1:-$DEFAULT_TTL}"
  local ttl
  if [[ -f "$LOCK_META" ]]; then
    # Must thread the CALLER's fallback through -- calling with no argument
    # here would silently make _lock_declared_ttl() default to the global
    # DEFAULT_TTL for any old-format lock (no "ttl" field yet), discarding
    # whatever ttl this specific caller actually configured. That's the same
    # bug the whole per-lock-ttl feature exists to close, just relocated to
    # this call site instead of inside _lock_declared_ttl() itself.
    ttl=$(_lock_declared_ttl "$fallback_ttl")
  else
    ttl="$fallback_ttl"
  fi
  local age
  age=$(_lock_age)

  # Check TTL
  if [[ "$age" -gt "$ttl" ]]; then
    _STALE_REASON="ttl-expired"
    return 0  # stale
  fi

  # Check if holder is on this machine and PID is dead
  local lock_host
  lock_host=$(_lock_hostname)
  if [[ "$lock_host" == "$HOSTNAME_SHORT" ]]; then
    local lock_pid
    lock_pid=$(_lock_pid)
    if [[ "$lock_pid" -gt 0 ]] && ! kill -0 "$lock_pid" 2>/dev/null; then
      _STALE_REASON="dead-holder-pid"
      return 0  # stale — PID is dead on this machine
    fi
  fi

  return 1  # not stale
}

_force_remove() {
  # Safety: validate LOCK_DIR before rm -rf
  if [[ -z "${LOCK_DIR:-}" ]]; then
    echo "[todo-lock] BUG: LOCK_DIR is empty — refusing rm -rf" >&2
    return 1
  fi
  if [[ "$LOCK_DIR" != */"$LOCK_DIR_NAME" ]]; then
    echo "[todo-lock] BUG: LOCK_DIR doesn't end with $LOCK_DIR_NAME — refusing rm -rf" >&2
    echo "[todo-lock] LOCK_DIR=$LOCK_DIR" >&2
    return 1
  fi
  if [[ ! -d "$LOCK_DIR" ]]; then
    return 0  # nothing to remove
  fi
  rm -rf "${LOCK_DIR:?}" 2>/dev/null || true
}

# --- Commands ---
cmd_acquire() {
  local ttl="$DEFAULT_TTL"
  local timeout="$DEFAULT_TIMEOUT"

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --ttl) ttl="$2"; shift 2 ;;
      --timeout) timeout="$2"; shift 2 ;;
      *) shift ;;
    esac
  done

  local deadline=$(( $(date +%s) + timeout ))

  while true; do
    # Try atomic mkdir
    if mkdir "$LOCK_DIR" 2>/dev/null; then
      # Trap EXIT in addition to INT/TERM: if _write_meta fails under set -euo pipefail
      # bash exits before LOCK_ACQUIRED=true is printed, orphaning the lock dir.
      # EXIT fires on both error-exit and signal-induced exit; _force_remove is idempotent.
      trap '_force_remove' EXIT
      trap '_force_remove; exit 130' INT TERM
      _write_meta "$ttl"
      trap - INT TERM EXIT  # clear all traps after metadata is written
      _log "ACQUIRED lock (host=${HOSTNAME_SHORT} pid=${MY_PID} ttl=${ttl}s)"
      echo "LOCK_ACQUIRED=true"
      echo "LOCK_DIR=$LOCK_DIR"
      return 0
    fi

    # Lock exists — check if stale
    if _is_stale "$ttl"; then
      _log "Stealing stale lock (age=$(_lock_age)s, reason=${_STALE_REASON}, holder=$(_lock_hostname):$(_lock_pid))"
      _force_remove
      continue  # retry mkdir immediately
    fi

    # Lock is held and fresh — check timeout
    local now
    now=$(date +%s)
    if [[ "$now" -ge "$deadline" ]]; then
      _err "Timeout waiting for lock (held by $(_lock_hostname):$(_lock_pid) for $(_lock_age)s)"
      echo "LOCK_ACQUIRED=false"
      echo "LOCK_HOLDER=$(_lock_hostname):$(_lock_pid)"
      echo "LOCK_AGE=$(_lock_age)"
      return 1
    fi

    _log "Lock held by $(_lock_hostname):$(_lock_pid) ($(_lock_age)s old). Retrying in ${RETRY_INTERVAL}s..."
    sleep "$RETRY_INTERVAL"
  done
}

cmd_release() {
  if [[ ! -d "$LOCK_DIR" ]]; then
    _log "No lock to release"
    return 0
  fi
  # Ownership check: without this, release was functionally identical to
  # steal -- any caller could drop a different, currently-live holder's lock
  # with no check at all.
  #
  # Missing metadata is ambiguous the same way it is in _lock_age(): it means
  # either "genuinely orphaned" or "a different process is mid-acquisition
  # right now" (the brief mkdir-then-write-metadata window). Falling through
  # to unconditional removal treated both cases as safe, which can drop a
  # lock a different process just legitimately created. Use the same
  # young/old distinction _lock_age() uses: only remove a metadata-less dir
  # once it's old enough to be genuinely orphaned.
  if [[ -f "$LOCK_META" ]]; then
    local lock_host lock_pid
    lock_host=$(_lock_hostname)
    lock_pid=$(_lock_pid)
    if [[ "$lock_host" != "$HOSTNAME_SHORT" ]] || [[ "$lock_pid" != "$MY_PID" ]]; then
      _err "Refusing to release: lock is held by ${lock_host}:${lock_pid}, not this process (${HOSTNAME_SHORT}:${MY_PID}). Use 'steal' to force."
      echo "LOCK_RELEASED=false"
      return 1
    fi
  else
    local age
    age=$(_lock_age)
    if [[ "$age" -lt "$DEFAULT_TTL" ]]; then
      _err "Refusing to release: lock has no metadata yet and is too young (${age}s) to be sure this isn't a live mid-acquisition. Use 'steal' to force."
      echo "LOCK_RELEASED=false"
      return 1
    fi
  fi
  _force_remove
  _log "RELEASED lock"
  echo "LOCK_RELEASED=true"
}

cmd_status() {
  if [[ ! -d "$LOCK_DIR" ]]; then
    _log "No lock held"
    echo "LOCKED=false"
    return 0
  fi

  local age
  age=$(_lock_age)
  local holder_host
  holder_host=$(_lock_hostname)
  local holder_pid
  holder_pid=$(_lock_pid)

  echo "LOCKED=true"
  echo "LOCK_HOLDER=${holder_host}:${holder_pid}"
  echo "LOCK_AGE=${age}"
  # Expose the actual ttl this lock is being judged against -- without this,
  # an operator has no way to confirm "is this really taking 600s" other than
  # trusting static doc prose, which silently goes stale the moment a new
  # caller declares a different ttl.
  echo "LOCK_TTL=$(_lock_declared_ttl "$DEFAULT_TTL")"

  if _is_stale "$DEFAULT_TTL"; then
    echo "LOCK_STALE=true"
    echo "LOCK_STALE_REASON=${_STALE_REASON}"
    _log "Lock is STALE (age=${age}s, reason=${_STALE_REASON}, holder=${holder_host}:${holder_pid})"
  else
    echo "LOCK_STALE=false"
    _log "Lock is ACTIVE (age=${age}s, holder=${holder_host}:${holder_pid})"
  fi
}

cmd_steal() {
  if [[ ! -d "$LOCK_DIR" ]]; then
    _log "No lock to steal"
    return 0
  fi
  _log "Force-stealing lock from $(_lock_hostname):$(_lock_pid)"
  _force_remove
  _log "Lock stolen. You may now acquire."
  echo "LOCK_STOLEN=true"
}

# --- Main ---
show_help() {
  cat << 'EOF'
Usage: todo-lock.sh <command> [options]

Commands:
  acquire   Acquire the write lock (blocks until available or timeout)
  release   Release the write lock
  status    Show current lock status
  steal     Force-remove a stuck lock (use with caution)

Options (acquire only):
  --ttl SECS      Lock time-to-live before considered stale (default: 120)
  --timeout SECS  Max seconds to wait for lock acquisition (default: 8)

Environment:
  TODO_FILE_PATH  Path to TODO.md (from ~/.codex/.env)
  AGENT_ID        Optional identifier for the acquiring agent

The lock directory is created alongside TODO.md as .TODO.md.lock/
EOF
}

case "${1:-}" in
  acquire) shift; cmd_acquire "$@" ;;
  release) cmd_release ;;
  status)  cmd_status ;;
  steal)   cmd_steal ;;
  -h|--help|help) show_help ;;
  *)
    _err "Unknown command: ${1:-}. Use: acquire, release, status, steal"
    exit 1
    ;;
esac
