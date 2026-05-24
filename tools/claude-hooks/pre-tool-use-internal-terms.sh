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

# Determine the scan range. The invariant: SCAN must reflect every commit
# (message AND patch content) that this push would publish to $REMOTE.
#
# Single expression handles all three scenarios consistently:
#   * upstream-tracked branch pushing to its upstream remote
#   * first push of a new branch (no upstream, no fetch yet)
#   * multi-remote layouts (refs/remotes/gitlab/* covers HEAD but pushing to
#     refs/remotes/origin/* on github -- the prior fix's --not --remotes
#     excluded ANY remote, which was a fail-open in this case)
#
# `--not --remotes="$REMOTE"` (with implicit /* suffix per git-log(1)) excludes
# only commits reachable from refs/remotes/$REMOTE/*. When that ref set is
# empty (fresh `git remote add` with no fetch), the --not clause is empty and
# the scan includes all of HEAD's history -- the conservative behavior we
# want for a security gate. The explicit HEAD positive ref is required: a
# bare `--not --remotes=...` has no anchor and prints nothing when the
# pattern matches no refs.
#
# `-p --pretty=format:%B` produces both commit messages and patches in one
# stream, replacing the prior `git log ... + git diff ...` pair. This closes
# the gap where the no-upstream fallback used `git diff HEAD` (working-tree
# only) and missed secrets committed into files on a clean working tree.
SCAN_LOG_ARGS=(log HEAD --not "--remotes=$REMOTE" -p --pretty=format:'%B')
SCAN="$(git "${SCAN_LOG_ARGS[@]}" 2>/dev/null | tr '[:upper:]' '[:lower:]' || true)"

# Audit-trail discriminator for the no-upstream path -- lets operators tell
# which scan strategy fired without having to re-run the hook.
if ! git rev-parse --abbrev-ref --symbolic-full-name '@{u}' >/dev/null 2>&1; then
  log 0 "no-upstream-fallback-scan (remote=$REMOTE)"
fi
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
