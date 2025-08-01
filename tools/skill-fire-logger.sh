#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# Script: skill-fire-logger.sh
# PURPOSE: Log skill invocations for observability and metrics analysis.
#          Records skill fires, misses, and session boundaries to JSONL files.
# USAGE: ./skill-fire-logger.sh <command> [args]
#        fire <skill-name> <trigger-reason>     Log skill invocation
#        miss <skill-name> <user-phrase> <why>  Log missed trigger opportunity
#        session-start                          Mark session beginning
#        session-end <fired-csv> <missed-csv>   Mark session end with summary
# PLATFORM: macOS, Linux, WSL (POSIX-compatible)
# VERSION: 1.0.0
# -----------------------------------------------------------------------------
set -euo pipefail

METRICS_DIR="${SUPERPOWERS_DIR:-$(dirname "$0")/..}/.skill-metrics"
mkdir -p "$METRICS_DIR"

FIRED_LOG="$METRICS_DIR/fired.jsonl"
MISSED_LOG="$METRICS_DIR/missed.jsonl"
SESSIONS_LOG="$METRICS_DIR/sessions.jsonl"

TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)

case "${1:-help}" in
    fire)
        SKILL="${2:-unknown}"
        TRIGGER="${3:-manual}"
        echo "{\"timestamp\":\"$TIMESTAMP\",\"skill\":\"$SKILL\",\"trigger\":\"$TRIGGER\"}" >> "$FIRED_LOG"
        echo "✓ Logged: $SKILL fired ($TRIGGER)"
        ;;
    miss)
        SKILL="${2:-unknown}"
        USER_PHRASE="${3:-}"
        REASON="${4:-detected post-hoc}"
        echo "{\"timestamp\":\"$TIMESTAMP\",\"skill\":\"$SKILL\",\"user_phrase\":\"$USER_PHRASE\",\"reason\":\"$REASON\"}" >> "$MISSED_LOG"
        echo "⚠ Logged miss: $SKILL should have fired ($REASON)"
        ;;
    session-start)
        SESSION_ID=$(uuidgen 2>/dev/null || cat /proc/sys/kernel/random/uuid 2>/dev/null || echo "session-$$")
        echo "{\"session\":\"$SESSION_ID\",\"started\":\"$TIMESTAMP\",\"status\":\"active\"}" >> "$SESSIONS_LOG"
        echo "Session started: $SESSION_ID"
        ;;
    session-end)
        FIRED_CSV="${2:-}"
        MISSED_CSV="${3:-}"
        # Mark latest session as ended
        echo "{\"ended\":\"$TIMESTAMP\",\"skills_fired\":\"$FIRED_CSV\",\"skills_missed\":\"$MISSED_CSV\"}" >> "$SESSIONS_LOG"
        echo "Session ended. Fired: $FIRED_CSV | Missed: $MISSED_CSV"
        ;;
    stats)
        TOTAL_FIRED=$(wc -l < "$FIRED_LOG" 2>/dev/null | tr -d ' ' || echo "0")
        TOTAL_MISSED=$(wc -l < "$MISSED_LOG" 2>/dev/null | tr -d ' ' || echo "0")
        echo "Stats: $TOTAL_FIRED fires, $TOTAL_MISSED misses"
        ;;
    help|*)
        echo "Usage:"
        echo "  $0 fire <skill-name> <trigger-reason>"
        echo "  $0 miss <skill-name> <user-phrase> <reason>"
        echo "  $0 session-start"
        echo "  $0 session-end <fired-csv> <missed-csv>"
        echo "  $0 stats"
        ;;
esac

