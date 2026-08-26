#!/usr/bin/env bash
# tools/ship.sh -- push current branch, open PR, poll checks, merge.
#
# Usage:
#   ship.sh --title "feat(x): do y" \
#           --test-plan "ran tools/test-all.sh --fast; all pass"
#   ship.sh --title "..." --base main                # override default 'dev'
#   ship.sh --title "..." --no-merge                 # push + PR only; skip merge
#   ship.sh --title "..." --body-file FILE           # use caller body verbatim
#
# Agent-native evidence flow:
#   ship.sh reads .code-review-cleared, .llm-skill-review-cleared, and
#   .phr-cleared for the current HEAD SHA and auto-injects the appropriate
#   evidence sections into the PR description. No manual copy-paste required.
#   The evidence lands on the FIRST GitHub Actions run against the PR.
#
# Sentinel format (written by run-battery.sh / run-llm-skill-review.sh / run-phr.sh):
#   v1|<sha>|PASS|<timestamp>|min-score=N.N
#
# Environment:
#   CLAUDE_HOOKS_BYPASS=1   skip the red-autonomy hook (session-less toolchains,
#                           e.g. Augment Agent; audit-logged by the hook)
#
# Adapted for GitHub / gh CLI. Feature branches target 'dev' by default.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Allow test harness to supply REPO_ROOT via environment (SHIP_TESTMODE=1).
: "${REPO_ROOT:="$(cd "$SCRIPT_DIR/.." && pwd)"}"

# When sourced for unit testing, skip arg-parse and main body.
if [[ "${SHIP_TESTMODE:-0}" == "1" ]]; then
  true
else

###############################################################################
# Args
###############################################################################
TITLE=""
TARGET_BRANCH="dev"    # feature branches merge into dev, not main
NO_MERGE=0
PR_BODY_FILE=""
TICKET_URL=""
TEST_PLAN=""
TEST_PLAN_FILE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --title)          TITLE="$2";          shift 2 ;;
    --base|--target-branch)
                      TARGET_BRANCH="$2";  shift 2 ;;
    --body-file)      PR_BODY_FILE="$2";   shift 2 ;;
    --ticket)         TICKET_URL="$2";     shift 2 ;;
    --test-plan)      TEST_PLAN="$2";      shift 2 ;;
    --test-plan-file) TEST_PLAN_FILE="$2"; shift 2 ;;
    --no-merge)       NO_MERGE=1;          shift ;;
    -h|--help)
      grep '^#' "$0" | grep -v '^#!/' | sed 's/^# //'
      exit 0 ;;
    *) echo "Unknown flag: $1" >&2; exit 1 ;;
  esac
done

[[ -n "$TITLE" ]] || { echo "ERROR: --title is required" >&2; exit 1; }

###############################################################################
# Identity guard -- personal-repo default; override with SHIP_EXPECTED_EMAIL.
###############################################################################
ACTUAL_EMAIL=$(git config user.email 2>/dev/null || echo "")
EXPECTED_EMAIL="${SHIP_EXPECTED_EMAIL:-bordenet@users.noreply.github.com}"
if [[ "$ACTUAL_EMAIL" != "$EXPECTED_EMAIL" ]]; then
  echo "ERROR: git identity is '$ACTUAL_EMAIL'; expected '$EXPECTED_EMAIL'" >&2
  echo "  (override via SHIP_EXPECTED_EMAIL env var)" >&2
  exit 1
fi

command -v gh >/dev/null 2>&1 || { echo "ERROR: gh CLI not found on PATH" >&2; exit 1; }

fi  # end SHIP_TESTMODE else block

###############################################################################
# Sentinel reader
#
# Usage: _read_sentinel <file> <head_sha>
# Prints "SCORE VERDICT" if the most-recent line for HEAD SHA has verdict PASS,
# prints nothing otherwise.
###############################################################################
_read_sentinel() {
  local file="$1" head_sha="$2"
  [[ -f "$file" ]] || return 0
  local line
  line=$(grep "^v1|${head_sha}|" "$file" | tail -1) || true
  [[ -n "$line" ]] || return 0
  local verdict score
  verdict=$(echo "$line" | cut -d'|' -f3)
  score=$(echo "$line" | cut -d'|' -f5 | sed 's/min-score=//')
  [[ "$verdict" == "PASS" || "$verdict" == "PASS_WITH_NITS" ]] || return 0
  [[ -n "$score" ]] || return 0
  echo "${score} ${verdict}"
}

###############################################################################
# Auto-generate PR body from sentinels
###############################################################################
_generate_body() {
  local head_sha="$1" test_plan_text="$2" ticket="$3"
  local out=""

  out+="## Summary"$'\n\n'
  [[ -n "$ticket" ]] && out+="Ticket: ${ticket}"$'\n\n'

  local r s v
  r=$(_read_sentinel "${REPO_ROOT}/.code-review-cleared" "$head_sha")
  if [[ -n "$r" ]]; then
    s=$(echo "$r" | awk '{print $1}'); v=$(echo "$r" | awk '{print $2}')
    out+="## cr-battery evidence"$'\n\n'"Min-score: ${s}/10 | verdict: ${v} | sha: ${head_sha:0:8}"$'\n\n'
    echo "[ship] cr-battery evidence: ${s}/10 (${v})" >&2
  fi

  r=$(_read_sentinel "${REPO_ROOT}/.llm-skill-review-cleared" "$head_sha")
  if [[ -n "$r" ]]; then
    s=$(echo "$r" | awk '{print $1}'); v=$(echo "$r" | awk '{print $2}')
    out+="## llm-skill-review evidence"$'\n\n'"Min-score: ${s}/10 | verdict: ${v} | sha: ${head_sha:0:8}"$'\n\n'
    echo "[ship] llm-skill-review evidence: ${s}/10 (${v})" >&2
  fi

  r=$(_read_sentinel "${REPO_ROOT}/.phr-cleared" "$head_sha")
  if [[ -n "$r" ]]; then
    s=$(echo "$r" | awk '{print $1}'); v=$(echo "$r" | awk '{print $2}')
    out+="## PHR evidence"$'\n\n'"Min-score: ${s}/10 | verdict: ${v} | sha: ${head_sha:0:8}"$'\n\n'
    echo "[ship] PHR evidence: ${s}/10 (${v})" >&2
  fi

  out+="## Test Plan"$'\n\n'"${test_plan_text}"$'\n'
  printf '%s' "$out"
}

###############################################################################
# Push (skip when sourced for testing: SHIP_TESTMODE=1)
###############################################################################
[[ "${SHIP_TESTMODE:-0}" == "1" ]] && return 0
BRANCH=$(git rev-parse --abbrev-ref HEAD)
HEAD_SHA=$(git rev-parse HEAD)
if [[ "$BRANCH" == "$TARGET_BRANCH" ]]; then
  echo "ERROR: current branch equals target '$TARGET_BRANCH' -- create a feature branch first." >&2
  exit 1
fi
# Guard: never auto-delete canonical long-lived branches.
case "$BRANCH" in
  dev|staging|main)
    echo "ERROR: refusing to operate on canonical branch '$BRANCH' -- create a feature branch first." >&2
    exit 1
    ;;
esac
echo "[ship] pushing $BRANCH -> origin"
git push --set-upstream origin "$BRANCH"

###############################################################################
# Build PR body
###############################################################################
BODY_TMPFILE=$(mktemp -t ship-pr-body.XXXXXX)
# shellcheck disable=SC2064
trap "rm -f '$BODY_TMPFILE'" EXIT

if [[ -n "$PR_BODY_FILE" ]]; then
  cp "$PR_BODY_FILE" "$BODY_TMPFILE"
  echo "[ship] using caller-supplied body: $PR_BODY_FILE" >&2
else
  if [[ -n "$TEST_PLAN_FILE" ]]; then
    TEST_PLAN="$(cat "$TEST_PLAN_FILE")"
  elif [[ -z "$TEST_PLAN" ]]; then
    TEST_PLAN="(no test plan provided -- update this PR description before review)"
  fi
  _generate_body "$HEAD_SHA" "$TEST_PLAN" "$TICKET_URL" > "$BODY_TMPFILE"
  echo "[ship] auto-generated PR body from sentinel files" >&2
fi

###############################################################################
# Create PR (use --body-file so a body that starts with '-' is not misparsed
# as a flag, and so long bodies do not blow argv limits on any platform).
###############################################################################
echo "[ship] creating PR: $TITLE"
PR_URL=$(gh pr create \
  --base "$TARGET_BRANCH" \
  --head "$BRANCH" \
  --title "$TITLE" \
  --body-file "$BODY_TMPFILE")
echo "[ship] PR: $PR_URL"

# GitHub PR URLs are of the form https://github.com/OWNER/REPO/pull/N
PR_NUMBER="${PR_URL##*/}"
[[ "$PR_NUMBER" =~ ^[0-9]+$ ]] || { echo "ERROR: could not parse PR number from '$PR_URL'" >&2; exit 1; }

###############################################################################
# Merge path
###############################################################################
if [[ "$NO_MERGE" -eq 1 ]]; then
  echo "[ship] --no-merge set; skipping merge."
  echo "[ship] URL: $PR_URL"
  exit 0
fi

# Poll GitHub Actions checks via `gh pr checks`. Output is one line per check
# with tab-separated columns: <name>\t<state>\t<elapsed>\t<url> ...
# We only inspect the <state> column (2nd), which is one of:
#   pass | fail | pending | skipping | queued | in_progress | (empty)
# and reduce to a single aggregate state.
echo "[ship] waiting for GitHub Actions checks to complete on PR #$PR_NUMBER"
_POLL_TIMEOUT=600  # 10 minutes
_POLL_INTERVAL=20
_POLL_ELAPSED=0
while true; do
  # gh pr checks exits non-zero if any check is failing; we swallow that so
  # the state machine below sees the aggregate and decides whether to abort.
  _CHECKS_OUT=$(gh pr checks "$PR_NUMBER" 2>/dev/null || true)
  if [[ -z "$_CHECKS_OUT" ]]; then
    _AGG_STATE="pending"
  else
    # Pure-awk aggregate: avoids grep empty-alternative (ugrep on macOS exits 2
    # for '^(pending|in_progress|queued|)$', causing a false "success" fallthrough).
    # Priority: any terminal failure > any in-flight > all pass.
    _AGG_STATE=$(printf '%s\n' "$_CHECKS_OUT" | awk -F'\t' '
      BEGIN { has_fail=0; has_running=0; has_pass=0 }
      {
        s = $2
        if (s == "fail" || s == "cancelled" || s == "action_required" || s == "timed_out")
          has_fail = 1
        else if (s == "pending" || s == "in_progress" || s == "queued" || s == "")
          has_running = 1
        else if (s == "pass" || s == "skipping" || s == "success")
          has_pass = 1
        else
          has_running = 1   # unknown state: treat conservatively as in-flight
      }
      END {
        if (has_fail)    print "failed"
        else if (has_running) print "running"
        else             print "success"
      }
    ')
  fi

  case "$_AGG_STATE" in
    success)
      echo "[ship] checks succeeded; merging"
      break
      ;;
    failed)
      echo "[ship] checks ended with failure -- aborting merge." >&2
      echo "[ship] PR #$PR_NUMBER is open but NOT merged. Fix the failing check and re-run, or merge manually." >&2
      exit 1
      ;;
    running|pending)
      if [[ $_POLL_ELAPSED -ge $_POLL_TIMEOUT ]]; then
        echo "[ship] timed out waiting for checks after ${_POLL_TIMEOUT}s." >&2
        echo "[ship] PR #$PR_NUMBER is open. Merge manually once checks pass." >&2
        exit 1
      fi
      echo "[ship] checks state: $_AGG_STATE -- retrying in ${_POLL_INTERVAL}s (${_POLL_ELAPSED}s elapsed)"
      sleep "$_POLL_INTERVAL"
      _POLL_ELAPSED=$(( _POLL_ELAPSED + _POLL_INTERVAL ))
      ;;
    *)
      echo "[ship] unrecognised aggregate state '$_AGG_STATE' -- retrying" >&2
      sleep "$_POLL_INTERVAL"
      _POLL_ELAPSED=$(( _POLL_ELAPSED + _POLL_INTERVAL ))
      ;;
  esac
done

# --merge = create a real merge commit (matches GitLab's --squash=false). Use
# --squash if you want a single squashed commit on the target branch instead.
gh pr merge "$PR_NUMBER" --merge --delete-branch
echo "[ship] done. PR #$PR_NUMBER merged."
