#!/usr/bin/env bash
# session-start-rules-integrity.sh — item 3 of the Claude Code guardrails plan.
# Fires on SessionStart. Checks ~/.augment/rules/*.md for dangling symlinks and
# verifies .ai-guidance/invariants.md is readable from the session's cwd.
# Emits a one-line status banner (stdout becomes additionalContext).
# Exit codes: 0 = ok, 2 = block (integrity failure).
set -euo pipefail
if [[ "${CLAUDE_HOOKS_BYPASS:-0}" == "1" ]]; then exit 0; fi

LOG="$HOME/.claude/hooks/hook-audit.log"; mkdir -p "$(dirname "$LOG")"
log() { echo "$(date -u +%FT%TZ) session-start-integrity exit=$1 reason=$2" >> "$LOG"; }

INPUT="$(cat)"
CWD="$(jq -r '.cwd // empty' <<<"$INPUT")"
[[ -z "$CWD" ]] && CWD="$PWD"

PROBLEMS=()

# (a) augment rules dir — check for dangling symlinks, empty dir, or missing dir
RULES_DIR="$HOME/.augment/rules"
if [[ ! -d "$RULES_DIR" ]]; then
  PROBLEMS+=("MISSING: $RULES_DIR does not exist — all rules absent")
elif compgen -G "$RULES_DIR/*.md" >/dev/null 2>&1; then
  for f in "$RULES_DIR"/*.md; do
    [[ -f "$f" ]] || PROBLEMS+=("DANGLING: $f")
  done
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

if (( ${#PROBLEMS[@]} > 0 )); then
  echo "[claude-hooks/SessionStart] integrity FAILURES — halt and alert user:"
  printf '  - %s\n' "${PROBLEMS[@]}"
  log 2 "${#PROBLEMS[@]}-failures"
  exit 2
fi

echo "[claude-hooks/SessionStart] rules-file integrity OK; invariants at $INV"
log 0 ok
exit 0
