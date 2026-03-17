#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# Script: skill-fire-logger.sh
# PURPOSE: Log skill invocations for observability and metrics analysis.
#          Delegates to learning-state.js for unified storage in
#          ~/.codex/.learning-state.json (single source of truth).
# USAGE: ./skill-fire-logger.sh <command> [args]
#        fire <skill-name> <trigger-reason>     Log skill invocation
#        miss <skill-name> <user-phrase> <why>  Log missed trigger opportunity
#        session-start                          Mark session beginning
#        session-end <fired-csv> <missed-csv>   Mark session end with summary
#        stats                                  Show fire/outcome counts
# PLATFORM: macOS, Linux, WSL (POSIX-compatible)
# VERSION: 2.0.0 — unified storage via learning-state.json
# -----------------------------------------------------------------------------
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SUPERPOWERS_AUGMENT="${SCRIPT_DIR}/../superpowers-augment.js"

# Legacy JSONL location (kept for migration reference)
METRICS_DIR="${SUPERPOWERS_DIR:-$(dirname "$0")/..}/.skill-metrics"

case "${1:-help}" in
    fire)
        SKILL="${2:-unknown}"
        TRIGGER="${3:-manual}"
        # Use the unified learning-state.js via superpowers-augment CLI
        node "$SUPERPOWERS_AUGMENT" record-fire "$SKILL" "$TRIGGER" 2>/dev/null \
            || echo "⚠ Failed to log fire for $SKILL (node unavailable?)"
        echo "✓ Logged: $SKILL fired ($TRIGGER)"
        ;;
    miss)
        SKILL="${2:-unknown}"
        USER_PHRASE="${3:-}"
        REASON="${4:-detected post-hoc}"
        # Record as a suggestion for trigger improvement
        node "$SUPERPOWERS_AUGMENT" suggest-trigger "$SKILL" "$USER_PHRASE" 2>/dev/null \
            || echo "⚠ Failed to log miss for $SKILL (node unavailable?)"
        echo "⚠ Logged miss: $SKILL should have fired ($REASON)"
        ;;
    session-start)
        SESSION_ID=$(uuidgen 2>/dev/null || cat /proc/sys/kernel/random/uuid 2>/dev/null || echo "session-$$")
        echo "Session started: $SESSION_ID"
        ;;
    session-end)
        FIRED_CSV="${2:-}"
        MISSED_CSV="${3:-}"
        echo "Session ended. Fired: $FIRED_CSV | Missed: $MISSED_CSV"
        ;;
    stats)
        node "$SUPERPOWERS_AUGMENT" learning-status 2>/dev/null \
            || echo "⚠ Could not read learning state (node unavailable?)"
        ;;
    help|*)
        echo "Usage:"
        echo "  $0 fire <skill-name> <trigger-reason>"
        echo "  $0 miss <skill-name> <user-phrase> <reason>"
        echo "  $0 session-start"
        echo "  $0 session-end <fired-csv> <missed-csv>"
        echo "  $0 stats"
        echo ""
        echo "Data stored in: ~/.codex/.learning-state.json (unified)"
        ;;
esac
