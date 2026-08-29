#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# tools/ci-bats-discovery.sh
#
# PURPOSE: Discover and run every bats suite in the repo, so CI coverage cannot
#          drift away from what is actually on disk.
#
# WHY THIS EXISTS (2026-08-26): .github/workflows/test.yml listed every suite by
# hand. An audit found 39 of 67 bats files were never run by CI -- among them
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
# Keys must be UPPER_SNAKE and must appear in ALLOWED_ENV_KEYS. This is an
# allowlist: an env var that changes where a subprocess finds code, config or
# trust roots is never suite configuration, and that set is unbounded.
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

# Suite-config env keys a policy line may set. ALLOWLIST -- see lint_policy.
ALLOWED_ENV_KEYS="PERSONAL_SKILLS_DIR SUPERPOWERS_SKILLS_DIR BUDGET_MODE"

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
  local _ALL_SUITES
  _ALL_SUITES="$(discover_all)"
  while IFS=$'\037' read -r directive path assign reason; do
    [[ -n "$directive" ]] || continue
    case "$directive" in
      exclude|env) ;;
      *) echo "policy: unknown directive '$directive' (expected exclude or env)"; problems=$((problems + 1)); continue ;;
    esac
    if [[ -z "$path" ]]; then
      echo "policy: '$directive' line is missing a path"; problems=$((problems + 1)); continue
    fi
    # Validate against what discovery can actually MATCH, not merely against the
    # filesystem. `./test/a.bats`, `test/../test/a.bats` and a non-.bats file all
    # pass an -f test while matching no suite, so the opt-out silently no-ops and
    # the quarantined suite keeps running under a clean lint.
    if ! grep -qxF "$path" <<< "$_ALL_SUITES"; then
      if [[ -f "$ROOT/$path" ]]; then
        echo "policy: '$path' exists but matches no discovered suite"
        echo "        paths must match --list exactly (repo-relative, no ./ prefix, no .. segments, must be a .bats file)"
      else
        echo "policy: names a path that does not exist: $path"
        echo "        remove the line, or fix the path -- a stale opt-out silently drops coverage"
      fi
      problems=$((problems + 1))
    fi
    # SECURITY: the policy file is repo-committed and agent-editable, and the
    # key is exported into the bats child. This is an ALLOWLIST, deliberately.
    # A denylist was tried first and failed: it closed the loader family
    # (PATH/BASH_ENV/LD_*/DYLD_*) and left the external-command family wide
    # open. Two independent adversarial reviews probed 41 and 46 keys and found
    # GIT_EXTERNAL_DIFF, GIT_SSH_COMMAND, GIT_ASKPASS, GIT_DIR, HOME, CDPATH,
    # PERL5OPT, NODE_PATH, PS4 and more all accepted, each giving code
    # execution in the CI job through a lint-clean, run-green policy line.
    # The denied set grows with every tool installed on the runner; the
    # ALLOWED set is three keys. Adding another is a deliberate edit to this
    # script, reviewed as code.
    if [[ "$directive" == "env" && -n "$assign" ]]; then
      _key="${assign%%=*}"
      if [[ ! "$_key" =~ ^[A-Z][A-Z0-9_]*$ ]]; then
        echo "policy: env key '$_key' for $path is not UPPER_SNAKE -- refused"
        problems=$((problems + 1))
      elif [[ " $ALLOWED_ENV_KEYS " != *" $_key "* ]]; then
        echo "policy: env key '$_key' for $path is not on the suite-config allowlist -- refused"
        echo "        allowed: $ALLOWED_ENV_KEYS"
        echo "        (adding a key means editing ALLOWED_ENV_KEYS in $(basename "$0"), reviewed as code --"
        echo "         an env var that changes where a subprocess finds code is never suite configuration)"
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
    if [[ "$directive" == "env" && "$reason" =~ (^|[[:space:]])[A-Z][A-Z0-9_]*= ]]; then
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
discover_all() {
  local dirs=() d
  for d in $SCAN_DIRS; do [[ -d "$ROOT/$d" ]] && dirs+=("$d"); done
  [[ "${#dirs[@]}" -gt 0 ]] || return 0
  ( cd "$ROOT" && find "${dirs[@]}" -type f -name '*.bats' ) \
    | LC_ALL=C sort
}

discover() {
  local dirs=() d
  for d in $SCAN_DIRS; do [[ -d "$ROOT/$d" ]] && dirs+=("$d"); done
  [[ "${#dirs[@]}" -gt 0 ]] || return 0

  # Exclusions are filtered inside awk rather than by a `grep -q` per suite:
  # grep -q exits on first match, the upstream printf takes SIGPIPE, and under
  # `set -o pipefail` that pipeline reports failure -- so `||` fired and emitted
  # the suite the policy had just excluded.
  {
    excluded_paths
    echo "---SUITES---"
    ( cd "$ROOT" && find "${dirs[@]}" -type f -name '*.bats' ) \
      | LC_ALL=C sort
  } | awk '
      /^---SUITES---$/ { in_suites = 1; next }
      !in_suites       { excluded[$0] = 1; next }
      !($0 in excluded) { print }
    '
}

# ---------------------------------------------------------------------------
# preflight -- discovery status and a coverage floor, shared by every mode.
# `--run` previously reported "All 0 suite(s) passed." on an empty tree, and
# discarded discover()'s status through process substitution, so a `find`
# traversal error silently shrank the suite set and CI went green with a
# FAILING suite never executed. This script is now the only thing running bats
# in CI, so a coverage collapse must fail loudly rather than pass quietly.
# ---------------------------------------------------------------------------
MIN_SUITES="${CI_BATS_MIN_SUITES:-1}"
if [[ ! "$MIN_SUITES" =~ ^[1-9][0-9]*$ ]]; then
  echo "ERROR: CI_BATS_MIN_SUITES must be a positive integer (got '$MIN_SUITES')." >&2
  exit 1
fi
if ! SUITES="$(discover)"; then
  echo "ERROR: suite discovery failed (find or policy error) -- refusing to report a result" >&2
  exit 1
fi
SUITE_COUNT="$(printf '%s\n' "$SUITES" | grep -c '[^[:space:]]' || true)"
if [[ "$SUITE_COUNT" -lt "$MIN_SUITES" ]]; then
  echo "ERROR: discovered $SUITE_COUNT suite(s), expected at least $MIN_SUITES." >&2
  echo "       A coverage collapse is not a pass. Set CI_BATS_MIN_SUITES to change the floor." >&2
  exit 1
fi

case "$MODE" in
  lint)
    lint_policy || exit 1
    echo "policy OK: $(parse_policy | wc -l | tr -d ' ') entr(ies), ${SUITE_COUNT} suite(s) discovered"
    ;;

  list)
    # Capture once: calling lint_policy twice duplicated every diagnostic,
    # because its summary goes to stderr and escaped the >/dev/null.
    if ! _lint_out="$(lint_policy 2>&1)"; then
      printf '%s\n' "$_lint_out" >&2
      exit 1
    fi
    printf '%s\n' "$SUITES"
    ;;

  run)
    if ! lint_policy; then
      echo "refusing to run with an invalid policy" >&2
      exit 1
    fi
    # A nested Bats run prepends its internal libexec directory to PATH. Under
    # GNU parallel, exported helper functions are not preserved, so invoking
    # that internal `bats` entry point directly fails before any test runs.
    # The public wrapper records the caller's original PATH in BATS_SAVED_PATH;
    # prefer the wrapper from there when present.
    BATS_BIN="$(command -v bats 2>/dev/null || true)"
    if [[ -n "${BATS_SAVED_PATH:-}" && -n "${BATS_LIBEXEC:-}" && "$BATS_BIN" == "$BATS_LIBEXEC/bats" ]]; then
      _saved_bats="$(PATH="$BATS_SAVED_PATH" command -v bats 2>/dev/null || true)"
      [[ -n "$_saved_bats" ]] && BATS_BIN="$_saved_bats"
    fi
    # One actionable error beats 69 "command not found" lines, and a skip would
    # reintroduce the fail-open above.
    if [[ -z "$BATS_BIN" ]]; then
      echo "ERROR: bats is not installed -- cannot run any suite." >&2
      echo "       install: brew install bats-core   (CI: see .github/workflows/test.yml)" >&2
      exit 1
    fi
    failed=()
    total=0
    while IFS= read -r suite; do
      [[ -n "$suite" ]] || continue
      total=$((total + 1))
      assign="$(env_for "$suite")"
      if [[ -n "$assign" ]]; then
        key="${assign%%=*}"
        val="${assign#*=}"
        val="${val//\$REPO_ROOT/$ROOT}"
        # Log the EXPANDED value: the CI log must show what the suite actually ran with.
        echo "==> $suite  [${key}=${val}]"
        if ! ( export "${key}=${val}"; "$BATS_BIN" "$ROOT/$suite" ); then
          failed+=("$suite")
        fi
      else
        echo "==> $suite"
        if ! "$BATS_BIN" "$ROOT/$suite"; then
          failed+=("$suite")
        fi
      fi
    done <<EOF_SUITES
$SUITES
EOF_SUITES

    echo ""
    if [[ "${#failed[@]}" -gt 0 ]]; then
      echo "FAILED suites:"
      for s in "${failed[@]}"; do echo "  $s"; done
      echo ""
      echo "${#failed[@]} of $total suite(s) failed."
      exit 1
    fi
    echo "All $total suite(s) passed."
    ;;
esac
