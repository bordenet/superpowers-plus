#!/usr/bin/env bash
# user-prompt-submit-context-ferry.sh -- Early-warning context-ferry trigger.
# Fires on every UserPromptSubmit. Primary signal: actual context-window
# usage, read from the last reported `usage` object in the session transcript
# JSONL (Claude Code hooks do not expose context-window usage directly as of
# this writing -- see anthropics/claude-code#27760 -- so this parses the
# transcript, which is Anthropic's own documented workaround). Falls back to
# a raw assistant-turn count ONLY when usage data cannot be extracted (jq
# missing, transcript unreadable, or no usage object found yet), so the
# fallback is a degraded mode, not the primary signal.
#
# Bug this replaces (confirmed 2026-09): the original turn-count-only design
# fired a hard-stop advisory at a fixed 20 assistant turns regardless of how
# much of the context window those turns actually consumed -- a session of
# 20 short turns can leave >95% of the window free, while a session of 5
# turns with large tool output can already be near compaction. Turn count is
# not a reliable proxy for context pressure; actual reported token usage is.
#
# Token threshold: CONTEXT_FERRY_TOKEN_THRESHOLD_PCT (default: 70, i.e. warn
#   at 70% of the context window -- well before the ~95% PreCompact backstop
#   in pre-compact-context-ferry.sh, leaving room to actually run the skill).
# Context window: CONTEXT_FERRY_CONTEXT_WINDOW (default: 200000 tokens).
# Fallback threshold: CONTEXT_FERRY_TURN_THRESHOLD (default: 40 -- raised
#   from the old 20 specifically because this is now a degraded fallback,
#   not the primary signal; a lower bar for a proxy this weak was where the
#   false-early-trigger bug came from).
# Flag file:  ~/.claude/.context-ferry-warned-<session_id>
# Exit: always 0 (never blocks prompt processing).
set -euo pipefail
if [[ "${CLAUDE_HOOKS_BYPASS:-0}" == "1" ]]; then exit 0; fi

CONTEXT_WINDOW="${CONTEXT_FERRY_CONTEXT_WINDOW:-200000}"
[[ "$CONTEXT_WINDOW" =~ ^[0-9]+$ ]] && [[ "$CONTEXT_WINDOW" -gt 0 ]] || CONTEXT_WINDOW=200000

TOKEN_THRESHOLD_PCT="${CONTEXT_FERRY_TOKEN_THRESHOLD_PCT:-70}"
[[ "$TOKEN_THRESHOLD_PCT" =~ ^[0-9]+$ ]] || TOKEN_THRESHOLD_PCT=70

THRESHOLD="${CONTEXT_FERRY_TURN_THRESHOLD:-40}"
# Guard: non-numeric threshold would cause arithmetic comparison to fail under set -e;
# fall back to the default rather than crashing and violating the always-exit-0 contract.
[[ "$THRESHOLD" =~ ^[0-9]+$ ]] || THRESHOLD=40

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

# Primary signal: actual context usage, from the most recent `usage` object
# reported anywhere in the transcript (assistant messages carry Anthropic API
# usage stats: input_tokens + cache_creation_input_tokens + cache_read_input_tokens
# together approximate the full context sent for that turn -- the standard,
# though officially unexposed-via-hooks, proxy for "how full is the window").
# jq processes concatenated JSON values from a JSONL stream natively; `tail -1`
# keeps only the last (most recent) match. A single malformed line earlier in
# the file can abort jq before reaching later lines -- accepted known limit;
# TOKENS_USED simply stays empty and the fallback below takes over.
TOKENS_USED=""
if [[ -f "$TRANSCRIPT_PATH_SAFE" ]] && command -v jq &>/dev/null; then
    TOKENS_USED="$(jq -r '
        (.message.usage // .usage) as $u
        | select($u != null)
        | (($u.input_tokens // 0) + ($u.cache_creation_input_tokens // 0) + ($u.cache_read_input_tokens // 0))
    ' "$TRANSCRIPT_PATH_SAFE" 2>/dev/null | tail -1 || true)"
fi
[[ "$TOKENS_USED" =~ ^[0-9]+$ ]] || TOKENS_USED=""

# Count assistant turns in the JSONL transcript as the fallback proxy, used
# only when token usage could not be determined above.
TURN_COUNT=0
if [[ -f "$TRANSCRIPT_PATH_SAFE" ]]; then
    # grep -c exits 1 on no matches but still writes "0" to stdout; || true preserves that output without failing the assignment.
    raw_count="$(grep -c '"role":"assistant"' "$TRANSCRIPT_PATH_SAFE" 2>/dev/null || true)"
    TURN_COUNT="${raw_count:-0}"
fi

if [[ -n "$TOKENS_USED" ]]; then
    USED_PCT=$(( TOKENS_USED * 100 / CONTEXT_WINDOW ))
    [[ "$USED_PCT" -lt "$TOKEN_THRESHOLD_PCT" ]] && exit 0
    SIGNAL_MSG="context usage has reached ${USED_PCT}% of the ~${CONTEXT_WINDOW}-token window (threshold: ${TOKEN_THRESHOLD_PCT}%, ${TOKENS_USED} tokens)"
else
    [[ "$TURN_COUNT" -lt "$THRESHOLD" ]] && exit 0
    SIGNAL_MSG="session has reached ${TURN_COUNT} assistant turns (threshold: ${THRESHOLD} -- degraded fallback signal, actual token usage was unavailable)"
fi

# Threshold crossed -- write the flag and emit the hard-stop advisory.
mkdir -p "$(dirname "$FLAG_FILE")"
touch "$FLAG_FILE"

cat <<MSG
[context-ferry] WARNING: ${SIGNAL_MSG}.
Context compaction may be approaching. Run context-ferry now while enough context remains.

** HARD STOP: invoke the context-ferry skill (/context-ferry) before responding to the
   user's current prompt. Do not skip this -- running it after compaction fires is too late. **

After context-ferry completes, resume normal processing.
MSG

exit 0
