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

INPUT="$(cat)"
SESSION_ID=""
TRANSCRIPT_PATH=""

if command -v jq &>/dev/null; then
    SESSION_ID="$(jq -r '.session_id // empty'    <<<"$INPUT" 2>/dev/null || true)"
    TRANSCRIPT_PATH="$(jq -r '.transcript_path // empty' <<<"$INPUT" 2>/dev/null || true)"
fi

# Nothing to do without a session ID or transcript path.
[[ -z "$SESSION_ID" || -z "$TRANSCRIPT_PATH" ]] && exit 0

FLAG_FILE="$HOME/.claude/.context-ferry-warned-${SESSION_ID}"

# Prune flag files older than 30 days (one file per qualifying session accumulates otherwise).
find "$HOME/.claude" -maxdepth 1 -name ".context-ferry-warned-*" -mtime +30 -delete 2>/dev/null || true

# Hysteresis: already warned this session -- stay silent.
[[ -f "$FLAG_FILE" ]] && exit 0

# Count assistant turns in the JSONL transcript as a context proxy.
# Each assistant message has "role":"assistant"; one per turn.
TURN_COUNT=0
if [[ -f "$TRANSCRIPT_PATH" ]]; then
    TURN_COUNT="$(grep -c '"role":"assistant"' "$TRANSCRIPT_PATH" 2>/dev/null || echo 0)"
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
