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
ADVISORIES=()

# (a) augment rules dir — check for dangling symlinks, empty dir, or missing dir.
# A MISSING directory means Augment isn't installed/configured on THIS
# machine at all -- a normal, valid state for a Claude-Code-only contributor,
# fork, or CI runner, not a corruption signal, so it's advisory (non-
# blocking) rather than a PROBLEM. DANGLING symlinks or an existing dir
# EMPTIED of *.md files both imply an Augment setup existed here and broke,
# which stays blocking regardless of which agent is running Claude Code
# (llm-skill-review, 2026-07-17, S1: this hook previously hard-blocked every
# Claude-Code-only session start on a directory that belongs to a different
# agent entirely).
#
# SEEN_MARKER: "missing" and "existed here, then got wiped entirely" are
# bitwise-identical filesystem states, but very different signals -- the
# latter is the easiest, most complete way to strip this guardrail, and
# doing so via `rm -rf` requires zero approval from red-autonomy (confirmed
# by code-review-battery, 2026-07-17: Guardian + AttackerPersona, both
# converging on this independently). The marker is written only once the
# dir is observed healthy (present with >=1 *.md file); its later absence
# with the marker present is treated as tampering (PROBLEMS), not
# "never configured" (ADVISORIES). A machine that genuinely uninstalls
# Augment gets one hard block, then quiets down once the marker is removed
# too -- an accepted, bounded one-time friction cost for the detection value.
RULES_DIR="$HOME/.augment/rules"
SEEN_MARKER="$HOME/.claude/hooks/.augment-rules-seen"
if [[ ! -d "$RULES_DIR" ]]; then
  if [[ -f "$SEEN_MARKER" ]]; then
    PROBLEMS+=("MISSING: $RULES_DIR existed on this machine before (marker: $SEEN_MARKER) and is now gone entirely -- this looks like deletion/tampering, not 'never installed'. If Augment was deliberately uninstalled, remove $SEEN_MARKER to acknowledge and silence this.")
  else
    ADVISORIES+=("$RULES_DIR does not exist -- skipping Augment rules-parity check (not blocking; this machine may not use Augment)")
  fi
elif compgen -G "$RULES_DIR/*.md" >/dev/null 2>&1; then
  for f in "$RULES_DIR"/*.md; do
    [[ -f "$f" ]] || PROBLEMS+=("DANGLING: $f")
  done
  if (( ${#PROBLEMS[@]} == 0 )); then
    mkdir -p "$(dirname "$SEEN_MARKER")"
    touch "$SEEN_MARKER"
  fi
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

# (c) promotion strict-toggle staleness — catches a forgotten
# tools/promotion-strict-toggle.sh disable left un-restored (see
# .ai-guidance/promotion-strict-behind-runbook.md). Skips silently if this
# repo doesn't have the script (not every repo uses this workflow).
TOGGLE_SCRIPT="${TOPLEVEL:+$TOPLEVEL/tools/promotion-strict-toggle.sh}"
if [[ -n "$TOGGLE_SCRIPT" && -x "$TOGGLE_SCRIPT" ]]; then
  TOGGLE_EXIT=0
  # cd into TOPLEVEL first: the script resolves its own repo root via its
  # process cwd (`git rev-parse --show-toplevel`), which is NOT necessarily
  # the same as this hook's own process cwd. --porcelain gives a
  # machine-parsable "branch|state|age" line per entry instead of prose, so
  # we can tell a genuine STALE/CORRUPT report apart from the script itself
  # crashing (e.g. a bug introduced later) -- the two must not look identical.
  TOGGLE_OUTPUT="$(cd "$TOPLEVEL" && bash "$TOGGLE_SCRIPT" status --porcelain 2>&1)" || TOGGLE_EXIT=$?
  if [[ "$TOGGLE_EXIT" != "0" ]]; then
    if [[ "$TOGGLE_OUTPUT" =~ \|(STALE|CORRUPT)\| ]]; then
      PROBLEMS+=("strict-toggle: branch protection left weakened or sentinel corrupt -- $TOGGLE_OUTPUT")
    else
      PROBLEMS+=("strict-toggle status check itself failed unexpectedly (possible bug in the script, not necessarily a stale toggle -- investigate tools/promotion-strict-toggle.sh): $TOGGLE_OUTPUT")
    fi
  fi
fi

if (( ${#PROBLEMS[@]} > 0 )); then
  echo "[claude-hooks/SessionStart] integrity FAILURES — halt and alert user:"
  printf '  - %s\n' "${PROBLEMS[@]}"
  echo "  (bypass: set CLAUDE_HOOKS_BYPASS=1 to skip this check if you've confirmed it's safe to proceed)"
  log 2 "${#PROBLEMS[@]}-failures"
  exit 2
fi

if (( ${#ADVISORIES[@]} > 0 )); then
  echo "[claude-hooks/SessionStart] advisories (non-blocking):"
  printf '  - %s\n' "${ADVISORIES[@]}"
fi

echo "[claude-hooks/SessionStart] rules-file integrity OK; invariants at $INV"
log 0 ok
exit 0
