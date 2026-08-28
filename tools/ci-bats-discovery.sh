#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# tools/ci-bats-discovery.sh
#
# PURPOSE: Discover and run every bats suite in the repo, so CI coverage cannot
#          drift away from what is actually on disk.
#
# WHY THIS EXISTS (2026-08-26): .github/workflows/test.yml listed every suite by
# hand. An audit found 39 of 70 bats files were never run by CI -- among them
# test/ship.bats (the canonical agent workflow), test/pre-push-code-review-gate.bats,
# test/pre-push-gate4.bats and test/hotfix-charter-check.bats. All 39 passed when
# run manually: they were dark by omission, not by exclusion. A hand-maintained
# list is exactly the "then the human should remember to..." step that CLAUDE.md's
# agent-first principle forbids, so the list is replaced by discovery.
#
# THE CONTRACT: a new .bats file runs in CI with no config edit. Keeping a suite
# out requires an explicit policy line carrying a reason, and --lint fails when a
# policy line names a path that no longer exists -- so the opt-out list cannot
# rot the way the enumeration did.
#
# POLICY FILE (default <root>/tests/ci-bats-policy.txt, optional):
#   # comment
#   exclude <path>              <reason...>
#   env     <path> KEY=VALUE    <reason...>
# $REPO_ROOT inside an env VALUE expands to the repo root. Nothing is eval'd.
# Keys must be UPPER_SNAKE and are refused if they belong to the loader,
# startup-file, or search-path families -- setting those does not configure a
# suite, it replaces the interpreter that runs it.
#
# USAGE:   tools/ci-bats-discovery.sh --list    print the suites CI will run
#          tools/ci-bats-discovery.sh --lint    validate the policy file
#          tools/ci-bats-discovery.sh --run     run every discovered suite
#          tools/ci-bats-discovery.sh --help
#            --root <dir>     tree to scan (default: this script's parent)
#            --policy <file>  policy file (default: <root>/tests/ci-bats-policy.txt)
#
# EXIT:    0 = success (suites passed / policy clean)
#          1 = a suite failed, or the policy is invalid
#          2 = usage error
# -----------------------------------------------------------------------------
set -euo pipefail

MODE=""
ROOT=""
POLICY=""
POLICY_EXPLICIT=0
SCAN_DIRS="test tests skills"

usage() { awk 'NR>1 && /^#/ {sub(/^# ?/,""); print; next} NR>1 {exit}' "$0"; }
die() { echo "ERROR: $*" >&2; exit 2; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    --help|-h) usage; exit 0 ;;
    --list) MODE="list"; shift ;;
    --lint) MODE="lint"; shift ;;
    --run)  MODE="run";  shift ;;
    --root) [[ $# -ge 2 ]] || die "--root requires a directory"; ROOT="$2"; shift 2 ;;
    --root=*) ROOT="${1#*=}"; shift ;;
    --policy) [[ $# -ge 2 ]] || die "--policy requires a file"; POLICY="$2"; POLICY_EXPLICIT=1; shift 2 ;;
    --policy=*) POLICY="${1#*=}"; POLICY_EXPLICIT=1; shift ;;
    *) die "unknown argument '$1' (see --help)" ;;
  esac
done

[[ -n "$MODE" ]] || die "one of --list, --lint, --run is required (see --help)"

if [[ -z "$ROOT" ]]; then
  ROOT="$(cd "$(dirname "$0")/.." && pwd)"
else
  [[ -d "$ROOT" ]] || die "--root is not a directory: $ROOT"
  ROOT="$(cd "$ROOT" && pwd)"
fi
[[ -n "$POLICY" ]] || POLICY="$ROOT/tests/ci-bats-policy.txt"
# An ABSENT default policy is fine (a repo may have no opt-outs at all), but a
# policy path the caller named explicitly and that does not exist is a typo --
# silently treating it as "no policy" would evaporate every env directive.
if [[ "$POLICY_EXPLICIT" -eq 1 && ! -f "$POLICY" ]]; then
  die "--policy file does not exist: $POLICY"
fi

# ---------------------------------------------------------------------------
# Policy parsing. Emits normalised directive/path/assign/reason records joined
# by ASCII US (\037) so every mode reads the policy exactly one way.
#
# US, not TAB: tab is an IFS *whitespace* character, so `read` collapses runs of
# them and drops empty fields -- an exclude line (empty assign) then shifted its
# reason into assign and linted as "no reason". US is non-whitespace, so empty
# fields survive intact.
# ---------------------------------------------------------------------------
parse_policy() {
  [[ -f "$POLICY" ]] || return 0
  awk '
    { sub(/\r$/, "") }
    /^[[:space:]]*(#|$)/ { next }
    {
      directive = $1; path = $2
      assign = ""; reason = ""
      start = 3
      if (directive == "env" && $3 ~ /^[A-Za-z_][A-Za-z0-9_]*=/) { assign = $3; start = 4 }
      for (i = start; i <= NF; i++) reason = reason (reason == "" ? "" : " ") $i
      printf "%s\037%s\037%s\037%s\n", directive, path, assign, reason
    }
  ' "$POLICY"
}

# ---------------------------------------------------------------------------
# lint_policy -- the anti-rot gate. Prints every problem, then exits 1.
# ---------------------------------------------------------------------------
lint_policy() {
  local problems=0 seen="" directive path assign reason
  while IFS=$'\037' read -r directive path assign reason; do
    [[ -n "$directive" ]] || continue
    case "$directive" in
      exclude|env) ;;
      *) echo "policy: unknown directive '$directive' (expected exclude or env)"; problems=$((problems + 1)); continue ;;
    esac
    if [[ -z "$path" ]]; then
      echo "policy: '$directive' line is missing a path"; problems=$((problems + 1)); continue
    fi
    if [[ ! -f "$ROOT/$path" ]]; then
      echo "policy: names a path that does not exist: $path"
      echo "        remove the line, or fix the path -- a stale opt-out silently drops coverage"
      problems=$((problems + 1))
    fi
    # SECURITY: the policy file is repo-committed and agent-editable, and the
    # key is exported into the bats child. Without this check a policy line
    # could set PATH (replacing the test runner, with CI still reporting a
    # pass), BASH_ENV (arbitrary code at shell startup), or the dynamic-loader
    # variables. That is CI code execution, not a misconfiguration.
    if [[ "$directive" == "env" && -n "$assign" ]]; then
      _key="${assign%%=*}"
      if [[ ! "$_key" =~ ^[A-Z][A-Z0-9_]*$ ]]; then
        echo "policy: env key '$_key' for $path is not UPPER_SNAKE -- refused"
        problems=$((problems + 1))
      elif [[ "$_key" == PATH || "$_key" == BASH_ENV || "$_key" == ENV || "$_key" == IFS \
           || "$_key" == SHELL || "$_key" == LD_* || "$_key" == DYLD_* \
           || "$_key" == GIT_CONFIG* || "$_key" == PYTHONPATH || "$_key" == PERL5LIB \
           || "$_key" == NODE_OPTIONS || "$_key" == BATS_* ]]; then
        echo "policy: env key '$_key' for $path can replace the interpreter or runner -- refused"
        echo "        (loader / startup-file / search-path variables are never suite configuration)"
        problems=$((problems + 1))
      fi
    fi
    if [[ "$directive" == "env" && -z "$assign" ]]; then
      echo "policy: env line for $path has no KEY=VALUE assignment"; problems=$((problems + 1))
    fi
    # The grammar reads exactly ONE assignment ($3) and treats the rest as
    # prose, so a second KEY=VALUE would be silently discarded. Refuse it
    # rather than half-apply it. One assignment per line; a suite needing two
    # vars needs a grammar change, not a second line (paths must stay unique).
    if [[ "$directive" == "env" && "$reason" =~ (^|[[:space:]])[A-Za-z_][A-Za-z0-9_]*= ]]; then
      echo "policy: env line for $path carries a second assignment in its reason text"
      echo "        ('${reason}') -- only one KEY=VALUE per line is applied; the rest is silently dropped"
      problems=$((problems + 1))
    fi
    if [[ -z "$reason" ]]; then
      echo "policy: $path has no reason -- every opt-out must say why"; problems=$((problems + 1))
    fi
    case "$seen" in
      *"|$path|"*) echo "policy: duplicate entry for $path"; problems=$((problems + 1)) ;;
      *) seen="$seen|$path|" ;;
    esac
  done < <(parse_policy)

  if [[ "$problems" -gt 0 ]]; then
    echo "policy: $problems problem(s) in $POLICY" >&2
    return 1
  fi
  return 0
}

excluded_paths() { parse_policy | awk -F'\037' '$1 == "exclude" { print $2 }'; }

env_for() {
  parse_policy | awk -F'\037' -v want="$1" '$1 == "env" && $2 == want { print $3 }'
}

# ---------------------------------------------------------------------------
# discover -- every .bats under the scan dirs, repo-relative, sorted, minus
# anything the policy excludes.
# ---------------------------------------------------------------------------
discover() {
  local dirs=() d
  for d in $SCAN_DIRS; do [[ -d "$ROOT/$d" ]] && dirs+=("$ROOT/$d"); done
  [[ "${#dirs[@]}" -gt 0 ]] || return 0

  # Exclusions are filtered inside awk rather than by a `grep -q` per suite:
  # grep -q exits on first match, the upstream printf takes SIGPIPE, and under
  # `set -o pipefail` that pipeline reports failure -- so `||` fired and emitted
  # the suite the policy had just excluded.
  {
    excluded_paths
    echo "---SUITES---"
    find "${dirs[@]}" -type f -name '*.bats' 2>/dev/null \
      | sed "s|^${ROOT}/||" \
      | LC_ALL=C sort
  } | awk '
      /^---SUITES---$/ { in_suites = 1; next }
      !in_suites       { excluded[$0] = 1; next }
      !($0 in excluded) { print }
    '
}

case "$MODE" in
  lint)
    lint_policy || exit 1
    echo "policy OK: $(parse_policy | wc -l | tr -d ' ') entr(ies), $(discover | wc -l | tr -d ' ') suite(s) discovered"
    ;;

  list)
    lint_policy >/dev/null || { lint_policy; exit 1; }
    discover
    ;;

  run)
    if ! lint_policy; then
      echo "refusing to run with an invalid policy" >&2
      exit 1
    fi
    failed=""
    total=0
    while IFS= read -r suite; do
      [[ -n "$suite" ]] || continue
      total=$((total + 1))
      assign="$(env_for "$suite")"
      echo "==> $suite${assign:+  [${assign}]}"
      if [[ -n "$assign" ]]; then
        key="${assign%%=*}"
        val="${assign#*=}"
        val="${val//\$REPO_ROOT/$ROOT}"
        if ! ( export "${key}=${val}"; bats "$ROOT/$suite" ); then
          failed="$failed $suite"
        fi
      else
        if ! bats "$ROOT/$suite"; then
          failed="$failed $suite"
        fi
      fi
    done < <(discover)

    echo ""
    if [[ -n "$failed" ]]; then
      echo "FAILED suites:"
      for s in $failed; do echo "  $s"; done
      exit 1
    fi
    echo "All $total suite(s) passed."
    ;;
esac
