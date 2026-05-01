#!/usr/bin/env bash
# pre-compact-reinject.sh — item 9 of the Claude Code guardrails plan.
# Fires on PreCompact. Re-injects the top 50 lines of the nearest CLAUDE.md
# and any active task scope file so the compaction summary retains key context.
# Exit codes: 0 = ok (always; non-fatal).
set -euo pipefail
if [[ "${CLAUDE_HOOKS_BYPASS:-0}" == "1" ]]; then exit 0; fi

LOG="$HOME/.claude/hooks/hook-audit.log"; mkdir -p "$(dirname "$LOG")"
log() { echo "$(date -u +%FT%TZ) pre-compact-reinject exit=$1 reason=$2" >> "$LOG"; }

INPUT="$(cat)"
CWD="$(jq -r '.cwd // empty' <<<"$INPUT")"
SESSION_ID="$(jq -r '.session_id // empty' <<<"$INPUT")"
[[ -z "$CWD" ]] && CWD="$PWD"

# (1) Locate the nearest CLAUDE.md by walking up from cwd
_find_claude_md() {
  local dir="$1"
  while [[ "$dir" != "/" ]]; do
    [[ -f "$dir/CLAUDE.md" ]] && { echo "$dir/CLAUDE.md"; return 0; }
    dir="$(dirname "$dir")"
  done
  [[ -f "$HOME/git/CLAUDE.md" ]] && { echo "$HOME/git/CLAUDE.md"; return 0; }
  return 1
}

CLAUDE_MD=""
CLAUDE_MD="$(_find_claude_md "$CWD")" || true

echo "[PreCompact re-inject] CLAUDE.md (top 50 lines):"
if [[ -n "$CLAUDE_MD" && -r "$CLAUDE_MD" ]]; then
  head -50 "$CLAUDE_MD"
else
  echo "  (no CLAUDE.md found from $CWD)"
fi

# (2) Active task scope file
SCOPE_FILE=""
if [[ -n "$SESSION_ID" ]]; then
  # Sanitize session_id to prevent path traversal
  _safe_sid="$(printf '%s' "$SESSION_ID" | tr -cd 'a-zA-Z0-9_-' | cut -c1-128)"
  SCOPE_FILE="$HOME/.claude/session-env/${_safe_sid}.scope.txt"
fi

echo "[PreCompact re-inject] Active task scope:"
if [[ -n "$SCOPE_FILE" && -r "$SCOPE_FILE" ]]; then
  cat "$SCOPE_FILE"
else
  echo "  (no active scope file)"
fi

log 0 ok
exit 0
