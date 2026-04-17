#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# Script: env-doctor.sh
# PURPOSE: Verify a local ~/.codex/.env symlink still points to a canonical
#          cloud-backed .env (OneDrive / iCloud / Dropbox / a shared NFS path),
#          and self-heal the safe regression where an editor replaced the
#          symlink with a regular file whose content equals the canonical.
#
#          The regression is common: VS Code and other editors save files
#          atomically (write temp → rename), which breaks symlinks. When that
#          happens, the two machines silently diverge. This script runs
#          periodically (e.g. from launchd/cron) to catch and repair.
#
# USAGE:   tools/env-doctor.sh [--check] [--verbose] [--help]
#          --check    report status, never mutate (for read-only cron jobs)
#          --verbose  extra detail on healthy runs
#          --help     this message
#
# CONFIG:  Paths are read from environment variables (with sensible defaults):
#            CODEX_ENV_LINK      default: $HOME/.codex/.env
#            CODEX_ENV_CANONICAL default: first existing of:
#                                  $HOME/Library/CloudStorage/OneDrive-*/ai-config/codex/.env
#                                  $HOME/OneDrive*/ai-config/codex/.env
#                                  $HOME/Dropbox/ai-config/codex/.env
#                                  $HOME/iCloud*/ai-config/codex/.env
#            CODEX_ENV_LOCAL     default: $HOME/.codex/.env.local (optional)
#
# EXIT:    0 = healthy (symlink OK)
#          1 = healed (auto-re-linked safe regression)
#          2 = needs manual intervention (divergent content OR symlink points
#              elsewhere); backups written; diff summary printed
#          3 = canonical target missing (no cloud-backed .env found)
# -----------------------------------------------------------------------------
set -euo pipefail

# --- parse flags ---
MODE=heal
VERBOSE=false
for arg in "$@"; do
    case "$arg" in
        --check)   MODE=check ;;
        --verbose) VERBOSE=true ;;
        --help|-h) sed -n '2,34p' "$0"; exit 0 ;;
        *)         echo "unknown flag: $arg" >&2; exit 2 ;;
    esac
done

# --- resolve paths ---
SYMLINK="${CODEX_ENV_LINK:-$HOME/.codex/.env}"
LOCAL_OVERRIDE="${CODEX_ENV_LOCAL:-$HOME/.codex/.env.local}"

resolve_canonical() {
    if [[ -n "${CODEX_ENV_CANONICAL:-}" ]]; then
        printf '%s\n' "$CODEX_ENV_CANONICAL"
        return 0
    fi
    local candidates=(
        "$HOME"/Library/CloudStorage/OneDrive-*/ai-config/codex/.env
        "$HOME"/OneDrive*/ai-config/codex/.env
        "$HOME"/Dropbox/ai-config/codex/.env
        "$HOME"/Library/Mobile\ Documents/com~apple~CloudDocs/ai-config/codex/.env
    )
    for c in "${candidates[@]}"; do
        [[ -f "$c" ]] && { printf '%s\n' "$c"; return 0; }
    done
    return 1
}

if ! CANONICAL=$(resolve_canonical); then
    echo "[env-doctor] ERROR: no canonical .env found" >&2
    echo "[env-doctor] set CODEX_ENV_CANONICAL or create one at a standard cloud path" >&2
    exit 3
fi

log()  { printf '[env-doctor] %s\n' "$*"; }
vlog() { [[ $VERBOSE == true ]] && printf '[env-doctor] %s\n' "$*" || true; }
err()  { printf '[env-doctor] ERROR: %s\n' "$*" >&2; }

# --- canonical must exist and be readable ---
[[ -f "$CANONICAL" && -r "$CANONICAL" ]] || { err "canonical not readable: $CANONICAL"; exit 3; }

# --- healthy: symlink to canonical ---
if [[ -L "$SYMLINK" ]]; then
    target=$(readlink "$SYMLINK")
    if [[ "$target" == "$CANONICAL" ]]; then
        vlog "OK: $SYMLINK -> $CANONICAL"
        [[ -f "$LOCAL_OVERRIDE" ]] && vlog "OK: override present ($(grep -cE '^[A-Z_]+=' "$LOCAL_OVERRIDE") keys)"
        exit 0
    fi
    err "symlink points to unexpected target: $target"
    err "expected: $CANONICAL"
    err "not auto-fixing a redirected symlink; set CODEX_ENV_CANONICAL if intended"
    exit 2
fi

# --- missing: re-create ---
if [[ ! -e "$SYMLINK" ]]; then
    [[ $MODE == check ]] && { err "$SYMLINK missing"; exit 2; }
    log "missing; creating symlink"
    mkdir -p "$(dirname "$SYMLINK")"
    ln -s "$CANONICAL" "$SYMLINK"
    exit 1
fi

# --- regression: regular file exists where symlink should ---
log "regression: $SYMLINK is a regular file, not a symlink"
log "(likely cause: an editor saved atomically and replaced the symlink inode)"

if cmp -s "$SYMLINK" "$CANONICAL"; then
    log "content identical to canonical — safe to re-link"
    [[ $MODE == check ]] && { log "--check mode: not mutating"; exit 2; }
    ts=$(date +%Y%m%d_%H%M%S)
    cp "$SYMLINK" "$SYMLINK.regression.$ts"
    log "backed up: $SYMLINK.regression.$ts"
    rm "$SYMLINK"
    ln -s "$CANONICAL" "$SYMLINK"
    log "healed: $SYMLINK -> $CANONICAL"
    exit 1
fi

# --- divergent: do not auto-merge ---
err "content DIFFERS from canonical"
err "keys only in local (would be added on merge):"
comm -23 \
    <(grep -oE '^[A-Z_][A-Z0-9_]*=' "$SYMLINK"   | sort -u) \
    <(grep -oE '^[A-Z_][A-Z0-9_]*=' "$CANONICAL" | sort -u) | sed 's/^/    /' >&2
err "keys only in canonical (would be lost if you overwrite):"
comm -13 \
    <(grep -oE '^[A-Z_][A-Z0-9_]*=' "$SYMLINK"   | sort -u) \
    <(grep -oE '^[A-Z_][A-Z0-9_]*=' "$CANONICAL" | sort -u) | sed 's/^/    /' >&2
ts=$(date +%Y%m%d_%H%M%S)
cp "$SYMLINK"   "$SYMLINK.regression.$ts"
cp "$CANONICAL" "$CANONICAL.regression.$ts"
err "manual merge required. backups:"
err "    $SYMLINK.regression.$ts"
err "    $CANONICAL.regression.$ts"
exit 2
