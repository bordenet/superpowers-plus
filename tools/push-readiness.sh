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
# USAGE:   tools/push-readiness.sh [--target <ref>] [--remote <name>]
#          [--destination <branch>] [--source <promotion-branch>] [--json]
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
DESTINATION=""
DESTINATION_EXPLICIT=0
PROMOTION_SOURCE=""
JSON=0

usage() { awk 'NR>1 && /^#/ {sub(/^# ?/,""); print; next} NR>1 {exit}' "$0"; }
die() { echo "ERROR: $*" >&2; exit 2; }
shell_quote() { printf '%q' "$1"; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    --help|-h) usage; exit 0 ;;
    --json) JSON=1; shift ;;
    --target) [[ $# -ge 2 ]] || die "--target requires a ref"; TARGET="$2"; shift 2 ;;
    --target=*) TARGET="${1#*=}"; shift ;;
    --remote) [[ $# -ge 2 ]] || die "--remote requires a name"; REMOTE="$2"; shift 2 ;;
    --remote=*) REMOTE="${1#*=}"; shift ;;
    --destination) [[ $# -ge 2 ]] || die "--destination requires a branch"; DESTINATION="$2"; DESTINATION_EXPLICIT=1; shift 2 ;;
    --destination=*) DESTINATION="${1#*=}"; DESTINATION_EXPLICIT=1; shift ;;
    --source) [[ $# -ge 2 ]] || die "--source requires a branch"; PROMOTION_SOURCE="$2"; shift 2 ;;
    --source=*) PROMOTION_SOURCE="${1#*=}"; shift ;;
    *) die "unknown argument '$1' (see --help)" ;;
  esac
done

git rev-parse --git-dir >/dev/null 2>&1 || die "not a git repository"
REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "$REPO_ROOT" || die "cannot cd to repo root"

BRANCH="$(git branch --show-current 2>/dev/null || true)"
[[ -n "$BRANCH" ]] || die "detached HEAD -- check out a branch first"
HEAD_SHA="$(git rev-parse HEAD)"
DESTINATION="${DESTINATION#refs/heads/}"
[[ -n "$DESTINATION" ]] || DESTINATION="$BRANCH"
git check-ref-format "refs/heads/$DESTINATION" >/dev/null 2>&1 || die "invalid destination branch '$DESTINATION'"
if [[ -n "$PROMOTION_SOURCE" ]]; then
  PROMOTION_SOURCE="${PROMOTION_SOURCE#refs/heads/}"
  git check-ref-format "refs/heads/$PROMOTION_SOURCE" >/dev/null 2>&1 || die "invalid promotion source '$PROMOTION_SOURCE'"
fi
case "$DESTINATION" in
  dev|staging|main)
    if [[ -z "$PROMOTION_SOURCE" ]]; then
      case "$BRANCH" in dev|staging|main) ;; *) PROMOTION_SOURCE="$BRANCH" ;; esac
    fi
    ;;
esac

# Shared with Gate 2 so readiness cannot accept a code-review sentinel that
# the real pre-push consumer rejects (or vice versa).
# shellcheck source=tools/lib/code-review-sentinel.sh
source "$REPO_ROOT/tools/lib/code-review-sentinel.sh"

# Resolve what this push would be compared against, mirroring how the gates
# derive their range: the branch's own upstream if it has one, else the
# canonical integration branch.
DIRECT_TARGET=0
if [[ -z "$TARGET" && "$DESTINATION_EXPLICIT" -eq 1 ]] && \
   git rev-parse --verify --quiet "$REMOTE/$DESTINATION" >/dev/null 2>&1; then
  # An existing destination gives Git's pre-push hook a concrete remote SHA;
  # Gate 2 compares that endpoint directly with the pushed SHA. Do the same,
  # rather than diffing the current branch's (possibly unrelated) upstream.
  TARGET="$REMOTE/$DESTINATION"
  DIRECT_TARGET=1
fi
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

if [[ "$DIRECT_TARGET" -eq 1 ]]; then
  RANGE_BASE="$(git rev-parse --verify "$TARGET" 2>/dev/null || true)"
else
  RANGE_BASE="$(git merge-base "$TARGET" HEAD 2>/dev/null || true)"
fi

# STALE-TARGET GUARD: if TARGET is a local branch whose remote counterpart has
# moved ahead, the merge-base is older than reality, the diff is wider than the
# push, and files already merged upstream get routed to gates they do not need.
# Observed: `--target dev` against a local dev a month behind origin/dev
# reported 24 changed files instead of 6 and three blockers instead of one.
# The tool cannot know which base the caller meant, so it must not guess --
# it says so and names the remedy.
STALE_TARGET_NOTE=""
if git show-ref --verify --quiet "refs/heads/$TARGET"; then
  _remote_ref="refs/remotes/$REMOTE/$TARGET"
  if git rev-parse --verify --quiet "$_remote_ref" >/dev/null 2>&1; then
    _behind="$(git rev-list --count "$TARGET..$_remote_ref" 2>/dev/null || echo 0)"
    if [[ "$_behind" -gt 0 ]]; then
      STALE_TARGET_NOTE="WARNING: local '$TARGET' is $_behind commit(s) behind $REMOTE/$TARGET.
  The range below is measured from the STALE local branch, so it may list files
  already merged upstream and blockers this push does not actually need.
  Re-run with: $(shell_quote "$(basename "$0")") --target $(shell_quote "$REMOTE/$TARGET") --remote $(shell_quote "$REMOTE")"
    fi
  fi
fi
# NOT mapfile: that is bash 4+, and stock macOS /bin/bash is 3.2, where this
# aborts with exit 127 -- a code this script's own exit table does not define,
# so an agent cannot tell "not ready" from "interpreter too old".
CHANGED_RAW=""
if [[ -n "$RANGE_BASE" ]]; then
  CHANGED_RAW="$(git diff --name-only "$RANGE_BASE..HEAD" 2>/dev/null)" \
    || die "could not enumerate changed files for $RANGE_BASE..HEAD"
else
  # Match the gates' NEW_BRANCH_NO_BASE policy: when histories are unrelated,
  # enumerate every file touched anywhere in the pushed branch. A tip-only
  # diff would miss code introduced in an earlier orphan commit.
  CHANGED_RAW="$(git log --name-only -m --format='' HEAD 2>/dev/null)" \
    || die "could not enumerate changed files in no-common-ancestor history"
  CHANGED_RAW="$(printf '%s\n' "$CHANGED_RAW" | awk 'NF' | LC_ALL=C sort -u)"
fi
CHANGED=()
while IFS= read -r _f; do
  [[ -n "$_f" ]] && CHANGED+=("$_f")
done <<< "$CHANGED_RAW"

# Uncommitted work is NOT part of what gets pushed, and sentinels bind to a
# commit SHA -- so a dirty tree means this report describes a state that does
# not yet exist. Say so loudly rather than letting an agent read "ready" and
# then be rejected for the commit it is about to make.
DIRTY_COUNT="$(git status --porcelain --untracked-files=no | wc -l | tr -d ' ')"

BLOCKERS=0
declare -a REPORT=()
declare -a WARNINGS=()

note() { REPORT+=("$1"); }
warn() { WARNINGS+=("$1"); }

if [[ -n "$STALE_TARGET_NOTE" ]]; then
  warn "$STALE_TARGET_NOTE"
fi
if [[ "$DIRTY_COUNT" -gt 0 ]]; then
  warn "WARNING: ${DIRTY_COUNT} uncommitted change(s). This report describes HEAD (${HEAD_SHA:0:8}), not the commit that would include the working tree."
fi

# Parse and validate a review sentinel exactly as its owning pre-push gate does.
# Outputs are returned through SENTINEL_SHA, SENTINEL_VERDICT and
# SENTINEL_ERROR so the caller can keep report formatting in one place.
validate_review_sentinel() {
  local sentinel="$1" base line line_count field_count
  local ver sha verdict ts f5 f6 f7
  base="${sentinel##*/}"
  line_count="$(awk 'NF{c++} END{print c+0}' "$sentinel" 2>/dev/null || echo 0)"
  line="$(head -n1 "$sentinel" 2>/dev/null || true)"
  field_count="$(awk -F'|' '{print NF; exit}' <<< "$line")"
  IFS='|' read -r ver sha verdict ts f5 f6 f7 <<< "$line"

  SENTINEL_SHA="$sha"
  SENTINEL_VERDICT="$verdict"
  SENTINEL_ERROR=""

  if [[ "$line_count" -gt 1 ]]; then
    SENTINEL_ERROR="malformed (${line_count} non-blank lines; must be exactly 1)"
    return
  fi

  case "$base" in
    .code-review-cleared)
      parse_code_review_sentinel "$sentinel" || true
      SENTINEL_SHA="$CODE_REVIEW_SENTINEL_SHA"
      SENTINEL_VERDICT="$CODE_REVIEW_SENTINEL_VERDICT"
      SENTINEL_ERROR="$CODE_REVIEW_SENTINEL_ERROR"
      ;;
    .phr-cleared)
      if [[ "$ver" != "v1" || "$field_count" -ne 5 || -z "$sha" || -z "$verdict" || -z "$ts" || -z "$f5" ]]; then
        SENTINEL_ERROR="format unrecognized (expected v1|SHA|VERDICT|TIMESTAMP|min-score=N)"
      elif [[ ! "$f5" =~ ^min-score=[0-9]+(\.[0-9]+)?$ ]]; then
        SENTINEL_ERROR="format unrecognized (malformed min-score field '$f5')"
      fi
      ;;
    .llm-skill-review-cleared)
      if [[ "$ver" != "v2" || "$field_count" -ne 7 || -z "$sha" || -z "$verdict" || -z "$ts" || -z "$f5" || -z "$f6" || -z "$f7" ]]; then
        SENTINEL_ERROR="format unrecognized (expected v2|SHA|VERDICT|TIMESTAMP|mean=N|unresolved_s0_s1=0|evidence_replay=ok)"
      elif [[ ! "$f5" =~ ^mean=[0-9]+(\.[0-9]+)?$ ]]; then
        SENTINEL_ERROR="format unrecognized (malformed mean field '$f5')"
      elif [[ "$f6" != "unresolved_s0_s1=0" ]]; then
        SENTINEL_ERROR="unresolved_s0_s1 is not 0 (got '$f6')"
      elif [[ "$f7" != "evidence_replay=ok" && "$f7" != "evidence_replay=bypassed" ]]; then
        SENTINEL_ERROR="format unrecognized (malformed evidence_replay field '$f7')"
      elif [[ "$f7" == "evidence_replay=bypassed" && "$verdict" != "PASS" ]]; then
        SENTINEL_ERROR="evidence_replay=bypassed requires verdict PASS"
      fi
      ;;
    *)
      SENTINEL_ERROR="unknown sentinel type '$base'"
      ;;
  esac
}

# Gate 4 applies to the branch being pushed, not the comparison target used to
# calculate the review range. Inspect its single-use receipt without consuming
# it; this tool's read-only contract leaves consumption to the real push hook.
check_branch_flow_readiness() {
  case "$DESTINATION" in
    dev|staging|main) ;;
    *) return ;;
  esac
  [[ -f tools/branch-flow-preflight.sh ]] || return

  local sentinel=".branch-flow-cleared" line line_count field_count
  local ver sha source target ts
  local fix_source="$PROMOTION_SOURCE" fix
  branch_flow_fix() {
    local candidate_source="$1"
    if [[ -n "$candidate_source" ]]; then
      printf 'tools/branch-flow-preflight.sh %q %q --sha %q' "$candidate_source" "$DESTINATION" "$HEAD_SHA"
    else
      printf 'rerun %q --target %q --remote %q --destination %q with --source set to the actual promotion branch' \
        "$(basename "$0")" "$TARGET" "$REMOTE" "$DESTINATION"
    fi
  }
  fix="$(branch_flow_fix "$fix_source")"
  if [[ ! -f "$sentinel" ]]; then
    note "BLOCKED|$sentinel missing for destination '$DESTINATION'|$fix"
    BLOCKERS=$((BLOCKERS + 1))
    return
  fi

  line_count="$(awk 'NF{c++} END{print c+0}' "$sentinel" 2>/dev/null || echo 0)"
  line="$(head -n1 "$sentinel" 2>/dev/null || true)"
  field_count="$(awk -F'|' '{print NF; exit}' <<< "$line")"
  IFS='|' read -r ver sha source target ts <<< "$line"
  if [[ "$ver" != "v1" || "$field_count" -ne 5 || "$line_count" -gt 1 || -z "$sha" || -z "$source" || -z "$target" || -z "$ts" ]]; then
    note "BLOCKED|$sentinel format unrecognized|$fix"
    BLOCKERS=$((BLOCKERS + 1))
  elif [[ "$target" != "$DESTINATION" ]]; then
    note "BLOCKED|$sentinel target '$target' does not match destination '$DESTINATION'|$(branch_flow_fix "${fix_source:-$source}")"
    BLOCKERS=$((BLOCKERS + 1))
  elif [[ "$sha" != "$HEAD_SHA" ]]; then
    note "BLOCKED|$sentinel STALE (cleared ${sha:0:8}, HEAD is ${HEAD_SHA:0:8})|$(branch_flow_fix "${fix_source:-$source}")"
    BLOCKERS=$((BLOCKERS + 1))
  else
    note "OK|$sentinel valid for ${HEAD_SHA:0:8} ($source -> $target)|"
  fi
}

if [[ ${#CHANGED[@]} -eq 0 ]]; then
  note "OK|no files changed vs $TARGET|nothing to review"
else
  # Ask the ROUTER which sentinel each changed file needs. review.sh route
  # wraps which-gate.sh, which extracts the real detection logic from the gate
  # scripts themselves -- so this never drifts from what pre-push enforces.
  ROUTE_RC=0
  ROUTE_OUT="$(tools/review.sh route "${CHANGED[@]}" 2>&1)" || ROUTE_RC=$?

  if [[ "$ROUTE_RC" -ne 0 ]]; then
    note "BLOCKED|review route failed (exit $ROUTE_RC); requirements are incomplete|inspect: tools/review.sh route ${CHANGED[*]}"
    BLOCKERS=$((BLOCKERS + 1))
    printf '%s\n' "$ROUTE_OUT" | sed 's/^/    router: /' >&2
  fi

  # FAIL CLOSED on a broken router. Without this, a router error produced zero
  # SENTINEL lines, the loop below found nothing, and the tool printed "no
  # blockers" -- reporting READY precisely when it had learned nothing. A
  # readiness check that cannot determine requirements must say so, never
  # default to "looks fine". (Caught by its own test harness, where a partial
  # tools/ tree made which-gate.sh exit 2.)
  # NOT `printf | grep -q`: grep -q exits at the first match, printf takes
  # SIGPIPE, and pipefail surfaces 141 -- which `!` inverts into the fail-closed
  # branch even though the line matched. Reachable once router output exceeds
  # the 64KiB pipe buffer (~1300 changed files), exactly the stale-base case
  # this script warns about above. Same `case` form used for verdicts below.
  if [[ "$ROUTE_RC" -eq 0 ]] && ! case $'\n'"$ROUTE_OUT" in
      *$'\n'"SENTINEL: "*|*$'\n'"EXEMPT: "*) true ;;
      *) false ;;
    esac; then
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
      validate_review_sentinel "$sentinel"
      s_sha="$SENTINEL_SHA"
      s_verdict="$SENTINEL_VERDICT"
      if [[ -n "$SENTINEL_ERROR" ]]; then
        note "BLOCKED|$sentinel $SENTINEL_ERROR|$runner"
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

check_branch_flow_readiness

json_escape() {
  local value="$1"
  value="${value//\\/\\\\}"
  value="${value//\"/\\\"}"
  value="${value//$'\b'/\\b}"
  value="${value//$'\f'/\\f}"
  value="${value//$'\n'/\\n}"
  value="${value//$'\r'/\\r}"
  value="${value//$'\t'/\\t}"
  printf '%s' "$value"
}

if [[ "$JSON" -eq 1 ]]; then
  printf '{"branch":"%s","head":"%s","target":"%s","destination":"%s","source":"%s","blockers":%d,"warnings":[' \
    "$(json_escape "$BRANCH")" "$(json_escape "$HEAD_SHA")" "$(json_escape "$TARGET")" \
    "$(json_escape "$DESTINATION")" "$(json_escape "$PROMOTION_SOURCE")" "$BLOCKERS"
  sep=""
  if [[ "${#WARNINGS[@]}" -gt 0 ]]; then
    for warning in "${WARNINGS[@]}"; do
      printf '%s"%s"' "$sep" "$(json_escape "$warning")"
      sep=","
    done
  fi
  printf '],"items":['
  sep=""
  for r in "${REPORT[@]}"; do
    st="${r%%|*}"; rest="${r#*|}"; msg="${rest%%|*}"; fix="${rest#*|}"
    printf '%s{"status":"%s","detail":"%s","remediation":"%s"}' \
      "$sep" "$(json_escape "$st")" "$(json_escape "$msg")" "$(json_escape "$fix")"
    sep=","
  done
  printf ']}\n'
  exit $(( BLOCKERS > 0 ? 1 : 0 ))
fi

echo "push-readiness: $BRANCH @ ${HEAD_SHA:0:8}  ->  $REMOTE/$DESTINATION"
echo "comparison target: $TARGET"
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
