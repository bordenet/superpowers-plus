#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# Script: loop-progress.sh
# PURPOSE: Per-round progress fingerprinting for retry loops. Fingerprints the
#          tuple (HEAD SHA, dirty-tree hash for SCOPE, verdict) and exits non-zero
#          when this round's tuple equals the previous round's (zero delta).
#          Prints the round-history table on every call.
#
# USAGE:
#   tools/loop-progress.sh --loop NAME --round N [--paths SCOPE] --verdict V
#
# EXIT CODES:
#   0  Round recorded; progress detected (or first round).
#   1  Invalid args, malformed ledger, or system error.
#   2  ABORT: zero-delta (tuple identical to previous round).
#      Also fires when tree is unchanged but verdict improved — rescoring
#      identical bytes is the sharpest waste signal available.
#
# LEDGER:
#   $GIT_DIR/loop-progress/NAME.ledger  — keyed by worktree, never shared.
#   Records are append-only. One line per round:
#     round|branch|base_sha|tree_hash|tuple_hash|verdict|timestamp
#   A record that fails to parse causes exit 1 naming the offending line.
#   Records with a base_sha that differs from the current HEAD are expired
#   (silently skipped) — no replay of a stale session.
#
# THRESHOLDS:
#   Tuple identical to previous round         → hard abort (exit 2)
#   Tree identical, verdict changed           → abort (exit 2) — rescored same bytes
#   Verdict unchanged across N rounds (tree   → loud warning, no block (exit 0)
#     changed each time)
# -----------------------------------------------------------------------------
set -euo pipefail

# Verify we're inside a git repo (the show-toplevel call also validates this)
git rev-parse --show-toplevel >/dev/null 2>&1 \
  || { echo "ERROR: not in a git repo" >&2; exit 1; }
GIT_DIR="$(git rev-parse --git-dir 2>/dev/null)" \
  || { echo "ERROR: cannot locate .git dir" >&2; exit 1; }
GIT_DIR="$(cd "$GIT_DIR" && pwd)"

sha256_of() {
  if command -v sha256sum >/dev/null 2>&1; then
    printf '%s' "$1" | sha256sum | awk '{print $1}'
  else
    printf '%s' "$1" | shasum -a 256 | awk '{print $1}'
  fi
}

usage() {
  cat <<'EOF'
Usage: tools/loop-progress.sh --loop NAME --round N [--paths SCOPE] --verdict V

Options:
  --loop    Unique name for this loop (e.g. "cr-battery", "llm-review").
  --round   Current round number (integer).
  --paths   Optional path scope for dirty-tree hash (default: full working tree).
  --verdict Verdict string for this round (e.g. "PASS", "FAIL", "9.2/10").

Exit codes: 0=progress, 1=error, 2=abort (zero delta or rescored same tree).
EOF
}

LOOP_NAME=""; ROUND=""; PATHS=""; VERDICT=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --loop)    LOOP_NAME="$2"; shift 2 ;;
    --round)   ROUND="$2"; shift 2 ;;
    --paths)   PATHS="$2"; shift 2 ;;
    --verdict) VERDICT="$2"; shift 2 ;;
    --help|-h) usage; exit 0 ;;
    *) echo "ERROR: Unknown flag: $1" >&2; usage >&2; exit 1 ;;
  esac
done

[[ -n "$LOOP_NAME" ]] || { echo "ERROR: --loop NAME required" >&2; exit 1; }
[[ -n "$ROUND"     ]] || { echo "ERROR: --round N required" >&2; exit 1; }
[[ -n "$VERDICT"   ]] || { echo "ERROR: --verdict V required" >&2; exit 1; }
[[ "$ROUND" =~ ^[0-9]+$ ]] || { echo "ERROR: --round must be a non-negative integer" >&2; exit 1; }

LEDGER_DIR="${GIT_DIR}/loop-progress"
mkdir -p "$LEDGER_DIR"
LEDGER="${LEDGER_DIR}/${LOOP_NAME}.ledger"

BRANCH="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo detached)"
BASE_SHA="$(git rev-parse HEAD 2>/dev/null)"

if [[ -n "$PATHS" ]]; then
  # shellcheck disable=SC2086  # word-split intentional: PATHS is a space-separated path list arg
  DIRTY_HASH="$(git diff HEAD -- $PATHS | (sha256sum 2>/dev/null || shasum -a 256) | awk '{print $1}')"
else
  DIRTY_HASH="$(git diff HEAD | (sha256sum 2>/dev/null || shasum -a 256) | awk '{print $1}')"
fi

TREE_HASH="$(sha256_of "${BASE_SHA}
${DIRTY_HASH}")"
TUPLE_HASH="$(sha256_of "${TREE_HASH}
${VERDICT}")"
# POSIX date -u '+FORMAT' is portable across GNU/BSD/BusyBox; no useless fallback.
TIMESTAMP="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"

PREV_TUPLE_HASH=""; PREV_TREE_HASH=""
declare -a HISTORY_ROWS=()
declare -a SESSION_VERDICTS=()
LINE_NUM=0

if [[ -f "$LEDGER" ]]; then
  while IFS='|' read -r r_round r_branch r_base_sha r_tree_hash r_tuple_hash r_verdict r_timestamp; do
    LINE_NUM=$((LINE_NUM + 1))
    if [[ -z "$r_round" || -z "$r_base_sha" || -z "$r_tree_hash" || \
          -z "$r_tuple_hash" || -z "$r_verdict" ]]; then
      printf 'ERROR: malformed ledger record at line %d (loop=%s)\n' \
        "$LINE_NUM" "$LOOP_NAME" >&2
      exit 1
    fi
    [[ "$r_base_sha" == "$BASE_SHA" ]] || continue
    PREV_TUPLE_HASH="$r_tuple_hash"
    PREV_TREE_HASH="$r_tree_hash"
    SESSION_VERDICTS+=("$r_verdict")
    HISTORY_ROWS+=("${r_round}|${r_branch}|${r_tuple_hash}|${r_verdict}|${r_timestamp}")
  done < "$LEDGER"
fi

printf '\n'
printf '+-----+--------------------------------------+----------+--------------+\n'
printf '|  loop-progress: %s\n' "$LOOP_NAME"
printf '+-----+--------------------------------------+----------+--------------+\n'
printf '| Rnd | Tuple Hash                           | Verdict  | When         |\n'
printf '+-----+--------------------------------------+----------+--------------+\n'
for row in "${HISTORY_ROWS[@]+"${HISTORY_ROWS[@]}"}"; do
  IFS='|' read -r h_rnd _h_br h_th h_vd h_ts <<< "$row"
  printf '| %-3s | %-36s | %-8s | %-12s |\n' \
    "$h_rnd" "${h_th:0:36}" "${h_vd:0:8}" "${h_ts:0:12}"
done
printf '| %-3s | %-36s | %-8s | %-12s |  <- current\n' \
  "$ROUND" "${TUPLE_HASH:0:36}" "${VERDICT:0:8}" "${TIMESTAMP:0:12}"
printf '+-----+--------------------------------------+----------+--------------+\n\n'

# Write record BEFORE deciding to abort so a FAIL round is still recorded.
printf '%s|%s|%s|%s|%s|%s|%s\n' \
  "$ROUND" "$BRANCH" "$BASE_SHA" "$TREE_HASH" "$TUPLE_HASH" "$VERDICT" "$TIMESTAMP" \
  >> "$LEDGER"

# Condition 1: full tuple identical -> zero delta
if [[ -n "$PREV_TUPLE_HASH" && "$TUPLE_HASH" == "$PREV_TUPLE_HASH" ]]; then
  printf 'ABORT: round %s tuple identical to previous round.\n' "$ROUND" >&2
  printf '  HEAD, dirty tree, and verdict are all unchanged.\n' >&2
  printf '  Loop is stuck. Escalate to the human -- do not start round %s.\n' \
    "$((ROUND + 1))" >&2
  exit 2
fi

# Condition 2: tree identical but verdict changed -> rescored same bytes
if [[ -n "$PREV_TREE_HASH" && "$TREE_HASH" == "$PREV_TREE_HASH" && \
      "$TUPLE_HASH" != "$PREV_TUPLE_HASH" ]]; then
  printf 'ABORT: round %s rescored an unchanged tree (HEAD + dirty tree identical to previous round).\n' \
    "$ROUND" >&2
  printf '  Verdict changed without any code change -- this is the sharpest waste signal.\n' >&2
  printf '  Escalate to the human -- do not start round %s.\n' "$((ROUND + 1))" >&2
  exit 2
fi

# Warning: tree changed but verdict repeated across consecutive rounds.
# Fixes upstream off-by-one: init to 0 so the tail-loop count is honest.
if [[ ${#SESSION_VERDICTS[@]} -gt 0 && "$VERDICT" == "${SESSION_VERDICTS[${#SESSION_VERDICTS[@]}-1]}" ]]; then
  REPEAT_COUNT=0
  for (( i = ${#SESSION_VERDICTS[@]} - 1; i >= 0; i-- )); do
    if [[ "${SESSION_VERDICTS[$i]}" == "$VERDICT" ]]; then
      REPEAT_COUNT=$((REPEAT_COUNT + 1))
    else
      break
    fi
  done
  # +1 for the current round (not yet in SESSION_VERDICTS at scan time)
  REPEAT_COUNT=$((REPEAT_COUNT + 1))
  printf 'WARNING: verdict "%s" has not changed across %d consecutive round(s) despite tree changes.\n' \
    "$VERDICT" "$REPEAT_COUNT" >&2
  printf '  Consider escalating to the human if this pattern continues.\n' >&2
fi

printf 'loop-progress: round %s recorded (loop=%s, branch=%s)\n' \
  "$ROUND" "$LOOP_NAME" "$BRANCH"
exit 0
