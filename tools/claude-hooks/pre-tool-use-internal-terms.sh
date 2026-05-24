#!/usr/bin/env bash
# pre-tool-use-internal-terms.sh — block git push to github.com when commit
# bodies or unpushed diff contain patterns from ~/.config/claude-hooks/internal-terms.txt
#
# Item 1 of the Claude Code 12-point guardrails plan.
# Exit codes: 0 = allow, 2 = block (stderr shown to model as reason).
#
# Override for testing: CLAUDE_HOOKS_PATTERNS_FILE_OVERRIDE=/path/to/patterns.txt
set -euo pipefail
if [[ "${CLAUDE_HOOKS_BYPASS:-0}" == "1" ]]; then exit 0; fi

LOG="$HOME/.claude/hooks/hook-audit.log"; mkdir -p "$(dirname "$LOG")"
log() { echo "$(date -u +%FT%TZ) internal-terms exit=$1 reason=$2" >> "$LOG"; }

INPUT="$(cat)"
TOOL="$(jq -r '.tool_name // empty' <<<"$INPUT")"
CMD="$(jq -r '.tool_input.command // empty' <<<"$INPUT")"
CWD="$(jq -r '.cwd // empty' <<<"$INPUT")"
[[ "$TOOL" != "Bash" ]] && { log 0 not-bash; exit 0; }
[[ "$CMD" =~ (^|[^A-Za-z0-9_])git[[:space:]]+push([[:space:]]|$) ]] || { log 0 not-push; exit 0; }

cd "$CWD" 2>/dev/null || { log 0 cwd-missing; exit 0; }

REMOTE="$(awk '{for(i=1;i<=NF;i++) if($i!~/^-/ && $i!~/^git$/ && $i!~/^push$/){print $i; exit}}' <<<"$CMD")"
if [[ -z "$REMOTE" ]]; then
  REMOTE="$(git config --get "branch.$(git symbolic-ref --short HEAD 2>/dev/null).remote" 2>/dev/null || echo origin)"
fi
URL="$(git remote get-url "$REMOTE" 2>/dev/null || echo '')"
[[ "$URL" != *github.com* ]] && { log 0 not-github; exit 0; }

PATTERNS="${CLAUDE_HOOKS_PATTERNS_FILE_OVERRIDE:-$HOME/.config/claude-hooks/internal-terms.txt}"
[[ ! -s "$PATTERNS" ]] && { log 0 no-patterns; exit 0; }

# Strip comment lines before passing to grep so '#' prefixed lines are ignored.
# Write lowercased active patterns to a temp file to avoid SC2259 (pipe + herestring conflict).
TMP_PAT="$(mktemp)"
grep -v '^\s*#' "$PATTERNS" | grep -v '^\s*$' | tr '[:upper:]' '[:lower:]' > "$TMP_PAT" || true
if [[ ! -s "$TMP_PAT" ]]; then
  rm -f "$TMP_PAT"; log 0 no-active-patterns; exit 0
fi

# Scan unpushed commit messages + diff for any pattern (case-insensitive, fixed-string).
#
# Upstream-tracking selection:
#   - If the current branch has an upstream (@{u}), scan @{u}..HEAD (only the
#     commits that this push would actually publish).
#   - If no upstream is set (first push of a new branch), @{u}..HEAD fails
#     silently and would produce empty SCAN -> hook would fail open. Fall back
#     to "all local commits not present on any remote" (--not --remotes) plus
#     the working-tree diff, which covers the first-push case correctly.
if git rev-parse --abbrev-ref --symbolic-full-name '@{u}' >/dev/null 2>&1; then
  RANGE_LOG="$(git log '@{u}..HEAD' --format='%B' 2>/dev/null || true)"
  RANGE_DIFF="$(git diff '@{u}..HEAD' 2>/dev/null || true)"
else
  # HEAD --not --remotes = commits reachable from HEAD but not from any
  # remote-tracking ref. The explicit HEAD is required: a bare --not --remotes
  # has no positive ref to start from and prints nothing when refs/remotes/ is
  # empty (e.g. fresh `git remote add origin` with no fetch yet).
  RANGE_LOG="$(git log HEAD --not --remotes --format='%B' 2>/dev/null || true)"
  RANGE_DIFF="$(git diff HEAD 2>/dev/null || true)"
fi
SCAN="$(printf '%s\n%s' "$RANGE_LOG" "$RANGE_DIFF" | tr '[:upper:]' '[:lower:]')"
HITS="$(echo "$SCAN" | grep -i -F -f "$TMP_PAT" | sort -u | head -20 || true)"
rm -f "$TMP_PAT"

if [[ -n "$HITS" ]]; then
  {
    echo "BLOCKED: internal-terms detected in push to $URL"
    echo "Hits:"
    while IFS= read -r hit; do echo "  - $hit"; done <<<"$HITS"
    echo "Scrub the commits, or set CLAUDE_HOOKS_BYPASS=1 to override (see audit log)."
  } >&2
  log 2 hits-found
  exit 2
fi
log 0 clean
exit 0
