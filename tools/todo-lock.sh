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

# --- Resolve TODO path (shared utility) ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=resolve-env-path.sh
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
# hostname -s strips domain; fall back to full hostname if -s unsupported
HOSTNAME_SHORT=$(hostname -s 2>/dev/null || hostname | cut -d. -f1)
# Use PPID (parent process) — the calling agent's shell survives after this script exits.
# Using $$ would store this script's PID, which dies immediately, making every lock look stale.
MY_PID=${PPID:-$$}

# --- Helpers ---
_log() { echo "[todo-lock] $1"; }
_err() { echo "[todo-lock] ERROR: $1" >&2; }

_write_meta() {
  local now
  now=$(date +%s)
  # Write atomically: write to temp file then move (avoids partial reads)
  local tmp="${LOCK_META}.tmp.$$"
  printf '{"hostname":"%s","pid":%s,"epoch":%s,"agent":"%s"}\n' \
    "$HOSTNAME_SHORT" "$MY_PID" "$now" "${AGENT_ID:-unknown}" > "$tmp"
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
    # Lock directory exists but no metadata — orphaned lock, treat as stale
    echo "999999"
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

_is_stale() {
  local ttl="${1:-$DEFAULT_TTL}"
  local age
  age=$(_lock_age)

  # Check TTL
  if [[ "$age" -gt "$ttl" ]]; then
    return 0  # stale
  fi

  # Check if holder is on this machine and PID is dead
  local lock_host
  lock_host=$(_lock_hostname)
  if [[ "$lock_host" == "$HOSTNAME_SHORT" ]]; then
    local lock_pid
    lock_pid=$(_lock_pid)
    if [[ "$lock_pid" -gt 0 ]] && ! kill -0 "$lock_pid" 2>/dev/null; then
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
      _write_meta
      trap - INT TERM EXIT  # clear all traps after metadata is written
      _log "ACQUIRED lock (host=${HOSTNAME_SHORT} pid=${MY_PID} ttl=${ttl}s)"
      echo "LOCK_ACQUIRED=true"
      echo "LOCK_DIR=$LOCK_DIR"
      return 0
    fi

    # Lock exists — check if stale
    if _is_stale "$ttl"; then
      _log "Stealing stale lock (age=$(_lock_age)s, holder=$(_lock_hostname):$(_lock_pid))"
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

  if _is_stale "$DEFAULT_TTL"; then
    echo "LOCK_STALE=true"
    _log "Lock is STALE (age=${age}s, holder=${holder_host}:${holder_pid})"
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
