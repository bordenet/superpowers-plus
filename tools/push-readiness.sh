#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# tools/push-readiness.sh
#
# PURPOSE: Answer "what do I need to do before this branch can be pushed?"
#          BEFORE attempting a push -- read-only, in seconds, with the exact
#          remediation command for every unmet requirement.
#
# WHY THIS EXISTS (agent DX, 2026-08-26): the only way to learn a push would be
# rejected was to attempt one. `tools/pre-push` Gate 1 runs the full fast suite
# (600+ bats tests, minutes), and an agent's shell commonly caps a foreground
# command at 120s -- so the attempt is SIGKILLed mid-gate with no verdict at
# all. Two pushes died that way in one session before Gate 6's requirement was
# discovered, and a third reported a fabricated failure because a killed run is
# indistinguishable from a failed one in the log. Each cycle cost a full
# round-trip. `which-gate.sh` answers "which gate covers THIS FILE"; nothing
# answered "what blocks THIS PUSH".
#
# READ-ONLY BY CONSTRUCTION: this script never invokes the gates. It cannot --
# tools/pre-push-branch-flow-gate.sh CONSUMES its sentinel on a successful run,
# so a dry-run that called the gates would destroy the very clearance the real
# push then needs. Requirements are derived from tools/review.sh route (which
# extracts the gates' own detection logic) and sentinel files are inspected,
# never written, moved, or consumed.
#
# USAGE:   tools/push-readiness.sh [--target <ref>] [--remote <name>] [--json]
#          tools/push-readiness.sh --help
#
# EXIT:    0 = every sentinel requirement is satisfied; push should clear
#              (Gate 1 tests and Gate 3 IP scan still run at push time)
#          1 = at least one requirement unmet; remediation printed
#          2 = usage error or not a git repository
# -----------------------------------------------------------------------------
set -euo pipefail

TARGET=""
REMOTE="origin"
JSON=0

usage() { sed -n '2,33p' "$0" | sed 's/^# \{0,1\}//'; }
die() { echo "ERROR: $*" >&2; exit 2; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    --help|-h) usage; exit 0 ;;
    --json) JSON=1; shift ;;
    --target) [[ $# -ge 2 ]] || die "--target requires a ref"; TARGET="$2"; shift 2 ;;
    --target=*) TARGET="${1#*=}"; shift ;;
    --remote) [[ $# -ge 2 ]] || die "--remote requires a name"; REMOTE="$2"; shift 2 ;;
    --remote=*) REMOTE="${1#*=}"; shift ;;
    *) die "unknown argument '$1' (see --help)" ;;
  esac
done

git rev-parse --git-dir >/dev/null 2>&1 || die "not a git repository"
REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "$REPO_ROOT" || die "cannot cd to repo root"

BRANCH="$(git branch --show-current 2>/dev/null || true)"
[[ -n "$BRANCH" ]] || die "detached HEAD -- check out a branch first"
HEAD_SHA="$(git rev-parse HEAD)"

# Resolve what this push would be compared against, mirroring how the gates
# derive their range: the branch's own upstream if it has one, else the
# canonical integration branch.
if [[ -z "$TARGET" ]]; then
  TARGET="$(git rev-parse --abbrev-ref --symbolic-full-name '@{upstream}' 2>/dev/null || true)"
fi
if [[ -z "$TARGET" ]]; then
  for c in "$REMOTE/dev" "$REMOTE/main" "$REMOTE/master"; do
    if git rev-parse --verify --quiet "$c" >/dev/null 2>&1; then TARGET="$c"; break; fi
  done
fi
[[ -n "$TARGET" ]] || die "could not resolve a comparison ref; pass --target"
git rev-parse --verify --quiet "$TARGET" >/dev/null 2>&1 || die "ref '$TARGET' does not exist"

RANGE_BASE="$(git merge-base "$TARGET" HEAD 2>/dev/null || true)"

# STALE-TARGET GUARD: if TARGET is a local branch whose remote counterpart has
# moved ahead, the merge-base is older than reality, the diff is wider than the
# push, and files already merged upstream get routed to gates they do not need.
# Observed: `--target dev` against a local dev a month behind origin/dev
# reported 24 changed files instead of 6 and three blockers instead of one.
# The tool cannot know which base the caller meant, so it must not guess --
# it says so and names the remedy.
STALE_TARGET_NOTE=""
if [[ "$TARGET" != */* ]] && git rev-parse --verify --quiet "$TARGET" >/dev/null 2>&1; then
  _remote_ref="refs/remotes/origin/$TARGET"
  if git rev-parse --verify --quiet "$_remote_ref" >/dev/null 2>&1; then
    _behind="$(git rev-list --count "$TARGET..$_remote_ref" 2>/dev/null || echo 0)"
    if [[ "$_behind" -gt 0 ]]; then
      STALE_TARGET_NOTE="WARNING: local '$TARGET' is $_behind commit(s) behind origin/$TARGET.
  The range below is measured from the STALE local branch, so it may list files
  already merged upstream and blockers this push does not actually need.
  Re-run with: $(basename "$0") --target origin/$TARGET"
    fi
  fi
fi
[[ -n "$RANGE_BASE" ]] || die "no merge base between HEAD and $TARGET"

mapfile -t CHANGED < <(git diff --name-only "$RANGE_BASE..HEAD" 2>/dev/null || true)

# Uncommitted work is NOT part of what gets pushed, and sentinels bind to a
# commit SHA -- so a dirty tree means this report describes a state that does
# not yet exist. Say so loudly rather than letting an agent read "ready" and
# then be rejected for the commit it is about to make.
DIRTY_COUNT="$(git status --porcelain --untracked-files=no | wc -l | tr -d ' ')"

BLOCKERS=0
declare -a REPORT=()

note() { REPORT+=("$1"); }

if [[ ${#CHANGED[@]} -eq 0 ]]; then
  note "OK|no files changed vs $TARGET|nothing to review"
else
  # Ask the ROUTER which sentinel each changed file needs. review.sh route
  # wraps which-gate.sh, which extracts the real detection logic from the gate
  # scripts themselves -- so this never drifts from what pre-push enforces.
  ROUTE_OUT="$(tools/review.sh route "${CHANGED[@]}" 2>&1 || true)"

  # FAIL CLOSED on a broken router. Without this, a router error produced zero
  # SENTINEL lines, the loop below found nothing, and the tool printed "no
  # blockers" -- reporting READY precisely when it had learned nothing. A
  # readiness check that cannot determine requirements must say so, never
  # default to "looks fine". (Caught by its own test harness, where a partial
  # tools/ tree made which-gate.sh exit 2.)
  if ! printf '%s' "$ROUTE_OUT" | grep -q '^SENTINEL: '; then
    note "BLOCKED|cannot determine review requirements -- tools/review.sh route produced no SENTINEL lines|inspect: tools/review.sh route ${CHANGED[*]}"
    BLOCKERS=$((BLOCKERS + 1))
    printf '%s\n' "$ROUTE_OUT" | sed 's/^/    router: /' >&2
  fi

  # Parse "SENTINEL: <file>" / "RUNNER: <cmd>" pairs out of the route report.
  sentinel=""; runner=""
  while IFS= read -r line; do
    case "$line" in
      "RUNNER: "*)   runner="${line#RUNNER: }" ;;
      "SENTINEL: "*) sentinel="${line#SENTINEL: }" ;;
    esac
    [[ -n "$sentinel" ]] || continue

    # Validate the sentinel WITHOUT touching it: must exist, be single-line,
    # name the exact SHA being pushed, and carry a clearing verdict.
    if [[ ! -f "$sentinel" ]]; then
      note "BLOCKED|$sentinel missing|$runner"
      BLOCKERS=$((BLOCKERS + 1))
    else
      lines="$(wc -l < "$sentinel" | tr -d ' ')"
      last="$(tail -1 "$sentinel")"
      s_sha="$(printf '%s' "$last" | cut -d'|' -f2)"
      s_verdict="$(printf '%s' "$last" | cut -d'|' -f3)"
      if [[ "$lines" -gt 1 ]]; then
        note "BLOCKED|$sentinel malformed (${lines} lines; must be exactly 1)|$runner"
        BLOCKERS=$((BLOCKERS + 1))
      elif [[ "$s_sha" != "$HEAD_SHA" ]]; then
        note "BLOCKED|$sentinel STALE (cleared ${s_sha:0:8}, HEAD is ${HEAD_SHA:0:8})|$runner"
        BLOCKERS=$((BLOCKERS + 1))
      else
        # Each gate accepts a DIFFERENT verdict set. A single union set here
        # produces a false READY for the strictest gate -- costing exactly the
        # push round-trip this tool exists to prevent. Keyed on the sentinel the
        # router named, so it stays in step with the gate scripts:
        #   .code-review-cleared      PASS, PASS_WITH_NITS   pre-push-code-review-gate.sh
        #   .llm-skill-review-cleared PASS, PASS_WITH_RISKS  pre-push-llm-skill-review-gate.sh
        #   .phr-cleared              PASS only              pre-push-phr-gate.sh
        # Unknown sentinels fail closed to PASS-only, matching the tool's
        # fail-closed contract elsewhere.
        case "${sentinel##*/}" in
          .code-review-cleared)      accepted="PASS PASS_WITH_NITS" ;;
          .llm-skill-review-cleared) accepted="PASS PASS_WITH_RISKS" ;;
          *)                         accepted="PASS" ;;
        esac
        # Word-match via case, NOT `printf | grep -q`: under `set -o pipefail`
        # grep -q exits early, the upstream printf takes SIGPIPE, and the
        # pipeline reports failure regardless of whether the word matched.
        case " $accepted " in
          *" $s_verdict "*)
            note "OK|$sentinel valid for ${HEAD_SHA:0:8} ($s_verdict)|" ;;
          *)
            note "BLOCKED|$sentinel verdict '$s_verdict' does not clear (accepts: ${accepted// /, })|$runner"
            BLOCKERS=$((BLOCKERS + 1)) ;;
        esac
      fi
    fi
    sentinel=""; runner=""
  done <<< "$ROUTE_OUT"
fi

if [[ "$JSON" -eq 1 ]]; then
  printf '{"branch":"%s","head":"%s","target":"%s","blockers":%d,"items":[' \
    "$BRANCH" "$HEAD_SHA" "$TARGET" "$BLOCKERS"
  sep=""
  for r in "${REPORT[@]}"; do
    st="${r%%|*}"; rest="${r#*|}"; msg="${rest%%|*}"; fix="${rest#*|}"
    printf '%s{"status":"%s","detail":"%s","remediation":"%s"}' \
      "$sep" "$st" "${msg//\"/\\\"}" "${fix//\"/\\\"}"
    sep=","
  done
  printf ']}\n'
  exit $(( BLOCKERS > 0 ? 1 : 0 ))
fi

echo "push-readiness: $BRANCH @ ${HEAD_SHA:0:8}  ->  $TARGET"
echo "changed files vs $TARGET: ${#CHANGED[@]}"
if [[ -n "$STALE_TARGET_NOTE" ]]; then
  echo ""
  echo "  $STALE_TARGET_NOTE"
fi
if [[ "$DIRTY_COUNT" -gt 0 ]]; then
  echo ""
  echo "  WARNING: ${DIRTY_COUNT} uncommitted change(s). This report describes"
  echo "  HEAD (${HEAD_SHA:0:8}), NOT what you are about to commit. Sentinels bind"
  echo "  to a commit SHA, so committing will invalidate every 'ready' below."
fi
echo ""
for r in "${REPORT[@]}"; do
  st="${r%%|*}"; rest="${r#*|}"; msg="${rest%%|*}"; fix="${rest#*|}"
  if [[ "$st" == "OK" ]]; then
    echo "  [ready]   $msg"
  else
    echo "  [BLOCKED] $msg"
    [[ -n "$fix" ]] && echo "            fix: $fix"
  fi
done
echo ""
echo "  Not checked here (they run at push time, and are not sentinel-gated):"
echo "    Gate 1 local fast test suite  -> tools/test-all.sh --fast"
echo "    Gate 3 proprietary IP scan"
echo "    Gate 7 per-commit LOC advisory"
echo ""
if [[ "$BLOCKERS" -gt 0 ]]; then
  echo "  $BLOCKERS blocker(s). Push WILL be rejected until each is resolved."
  exit 1
fi
echo "  No sentinel blockers. Push should clear the sentinel gates."
exit 0
