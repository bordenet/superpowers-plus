#!/usr/bin/env bash
# user-prompt-submit-context-ferry.sh -- Early-warning context-ferry trigger.
# Fires on every UserPromptSubmit. Counts assistant turns in the session
# transcript as a stable proxy for context usage. When turns exceed the
# threshold, emits a hard-stop advisory and sets a per-session flag so the
# advisory fires exactly once (hysteresis).
#
# Uses turn count (not file size) to avoid false positives from large tool
# outputs early in the session.
#
# Threshold: CONTEXT_FERRY_TURN_THRESHOLD (default: 20)
# Flag file:  ~/.claude/.context-ferry-warned-<session_id>
# Exit: always 0 (never blocks prompt processing).
set -euo pipefail
if [[ "${CLAUDE_HOOKS_BYPASS:-0}" == "1" ]]; then exit 0; fi

THRESHOLD="${CONTEXT_FERRY_TURN_THRESHOLD:-20}"
# Guard: non-numeric threshold would cause arithmetic comparison to fail under set -e;
# fall back to the default rather than crashing and violating the always-exit-0 contract.
[[ "$THRESHOLD" =~ ^[0-9]+$ ]] || THRESHOLD=20

INPUT="$(cat)"
SESSION_ID=""
TRANSCRIPT_PATH=""

if command -v jq &>/dev/null; then
    SESSION_ID="$(jq -r '.session_id // empty'    <<<"$INPUT" 2>/dev/null || true)"
    TRANSCRIPT_PATH="$(jq -r '.transcript_path // empty' <<<"$INPUT" 2>/dev/null || true)"
fi

# Nothing to do without a session ID or transcript path.
[[ -z "$SESSION_ID" || -z "$TRANSCRIPT_PATH" ]] && exit 0

# Sanitize session_id before embedding in a file path (path-traversal guard).
SESSION_ID_SAFE="$(printf '%s' "$SESSION_ID" | tr -cd 'a-zA-Z0-9_-' | cut -c1-128)"
[[ -z "$SESSION_ID_SAFE" ]] && exit 0

FLAG_FILE="$HOME/.claude/.context-ferry-warned-${SESSION_ID_SAFE}"

# Hysteresis: already warned this session -- stay silent.
[[ -f "$FLAG_FILE" ]] && exit 0

# Prune flag files older than 30 days only when threshold may be crossed (not on every prompt).
find "$HOME/.claude" -maxdepth 1 -name ".context-ferry-warned-*" -mtime +30 -delete 2>/dev/null || true

# Sanitize transcript path (path-traversal guard before use as a file argument).
TRANSCRIPT_PATH_SAFE="$(printf '%s' "$TRANSCRIPT_PATH" | tr -cd 'a-zA-Z0-9/_.-')"
[[ -z "$TRANSCRIPT_PATH_SAFE" || "$TRANSCRIPT_PATH_SAFE" != /* ]] && exit 0

# Count assistant turns in the JSONL transcript as a context proxy.
# Each assistant message has "role":"assistant"; one per turn.
TURN_COUNT=0
if [[ -f "$TRANSCRIPT_PATH_SAFE" ]]; then
    # grep -c exits 1 on no matches but still writes "0" to stdout; || true preserves that output without failing the assignment.
    raw_count="$(grep -c '"role":"assistant"' "$TRANSCRIPT_PATH_SAFE" 2>/dev/null || true)"
    TURN_COUNT="${raw_count:-0}"
fi

[[ "$TURN_COUNT" -lt "$THRESHOLD" ]] && exit 0

# Threshold crossed -- write the flag and emit the hard-stop advisory.
mkdir -p "$(dirname "$FLAG_FILE")"
touch "$FLAG_FILE"

cat <<MSG
[context-ferry] WARNING: session has reached ${TURN_COUNT} assistant turns (threshold: ${THRESHOLD}).
Context compaction may be approaching. Run context-ferry now while enough context remains.

** HARD STOP: invoke the context-ferry skill (/context-ferry) before responding to the
   user's current prompt. Do not skip this -- running it after compaction fires is too late. **

After context-ferry completes, resume normal processing.
MSG

exit 0
