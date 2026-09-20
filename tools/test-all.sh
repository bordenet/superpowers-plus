#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# Script: test-all.sh
# PURPOSE: Unified test entry point for superpowers-plus. Runs the full test
#          surface in the order that catches the most failures earliest:
#          static lint, then bats, then node tests. AGENTS.md points here so
#          first-time contributors can not silently miss half the suite.
# USAGE:   tools/test-all.sh [--no-shellcheck] [--no-bats] [--no-node]
#                            [--no-harsh] [--fast]
#            --fast = node + bats only; skip shellcheck and harsh-review.
#                     Intended for tight inner loops; CI must run the full
#                     suite without --fast.
# EXIT:    0 = all selected suites pass
#          1 = one or more suites failed (summary printed at end)
# -----------------------------------------------------------------------------
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_ROOT" || { echo "❌ Could not cd to $REPO_ROOT" >&2; exit 1; }

RUN_SHELLCHECK=1
RUN_BATS=1
RUN_NODE=1
RUN_HARSH=1
RUN_FAST=0

while [[ $# -gt 0 ]]; do
    case "$1" in
        --help|-h)
            sed -n '2,15p' "$0" | sed 's/^# \{0,1\}//'
            exit 0
            ;;
        --no-shellcheck) RUN_SHELLCHECK=0; shift ;;
        --no-bats)       RUN_BATS=0;       shift ;;
        --no-node)       RUN_NODE=0;       shift ;;
        --no-harsh)      RUN_HARSH=0;      shift ;;
        --fast)          RUN_SHELLCHECK=0; RUN_HARSH=0; RUN_FAST=1; shift ;;
        *) echo "❌ Unknown flag: $1" >&2; exit 1 ;;
    esac
done

declare -a FAILED=()
declare -a PASSED=()

# Working-tree guard. A test that writes into the repo leaks its fixture when a
# run dies hard -- teardown does not run on SIGKILL and no trap can make it, so
# the debris silently breaks the NEXT run and reads as a real failure. Sweep
# declared artifacts first (healing a tree a crashed run left dirty), snapshot
# the tree, and verify afterwards that nothing undeclared was created.
TREE_GUARD="$SCRIPT_DIR/test-tree-guard.sh"
TREE_STATE=""
if [[ ! -x "$TREE_GUARD" ]]; then
    # cr-battery 2026-09-19 (ShellRuntimeAuditor, reproduced live): this used
    # to print a warning and continue -- TREE_STATE stayed empty, so the
    # "if [[ -n "$TREE_STATE" ]]" verify call below was silently skipped with
    # no entry in FAILED. A lost executable bit (a plausible checkout/CI slip)
    # defeated the guard's entire "impossible to miss" promise: the suite
    # reported full green while genuine test pollution went undetected.
    echo "❌ working-tree guard missing or not executable: $TREE_GUARD" >&2
    echo "    test pollution will NOT be detected this run." >&2
    FAILED+=("working-tree guard (missing/not executable)")
fi
if [[ -x "$TREE_GUARD" ]]; then
    # M4: a refused manifest pattern is a manifest bug. Surface it instead of
    # discarding the exit code -- `|| true` here defeated the whole point of
    # making sweep fail on a pattern it refused to expand.
    if ! "$TREE_GUARD" sweep; then
        echo "❌ working-tree guard: sweep refused one or more manifest patterns (see above)" >&2
        FAILED+=("working-tree guard (sweep)")
    fi
    TREE_STATE="$(mktemp)"
    "$TREE_GUARD" snapshot "$TREE_STATE" || TREE_STATE=""
fi

run_suite() {
    local label="$1"; shift
    echo ""
    echo "═══════════════════════════════════════════════════════════"
    echo "  ▶ $label"
    echo "═══════════════════════════════════════════════════════════"
    if "$@"; then
        echo "✓ $label passed"
        PASSED+=("$label")
    else
        echo "❌ $label failed"
        FAILED+=("$label")
    fi
}

# shellcheck disable=SC2329  # invoked indirectly via run_suite "label" run_shellcheck
run_shellcheck() {
    if ! command -v shellcheck >/dev/null 2>&1; then
        echo "⚠️  shellcheck not installed; skipping"
        return 0
    fi
    # Match the scope used by tools/harsh-review.sh: every tracked .sh plus
    # extensionless hooks under tools/. Exclude vendored / generated paths.
    local files
    files=$(git ls-files '*.sh' tools/pre-commit tools/pre-push tools/commit-msg 2>/dev/null | sort -u)
    [[ -z "$files" ]] && { echo "no shell files tracked"; return 0; }
    # shellcheck disable=SC2086  # word-splitting intentional
    shellcheck -x $files
}

# shellcheck disable=SC2329  # invoked indirectly via run_suite
#
# --jobs support (requires GNU parallel, `brew install parallel`): every file
# under test/ was checked for shared mutable state before enabling this --
# 25 of 28 write only to a per-test/per-suite isolated temp path (`mktemp`,
# `BATS_TEST_TMPDIR`, or `BATS_SUITE_TMPDIR`); the remaining 3
# (reviewer-count-consistency, shell-runtime-auditor-count, which-gate)
# only read the real repo tree read-only, with no writes to a shared
# non-temp path. Bats forks a separate process per file under GNU parallel,
# so a `cd "$REPO_ROOT"` in one file's process cannot affect another file's
# CWD, and no cross-file shared-state hazard was found. `--no-parallelize-
# within-files` is passed below because within-file parallelism (bats runs
# a file's own tests concurrently too, by default, once --jobs > 1) was NOT
# audited per-file -- e.g. wiki-oneshot.bats's setup_file() starts one
# shared, stateful mock HTTP server used by all tests in that file, and nothing
# guarantees a future test added to a file like that stays order-independent.
# Revisit only after auditing within-file state for every file individually.
_bats_jobs() {
    local n
    n=$(nproc 2>/dev/null || sysctl -n hw.logicalcpu 2>/dev/null || echo 4)
    # Cap at 8 to avoid thrashing on machines with many cores
    [[ "$n" -gt 8 ]] && n=8
    echo "$n"
}

# shellcheck disable=SC2329  # invoked indirectly via run_suite
# Bats targets for this run. Normally the whole test/ directory; in fast mode
# (which the pre-push hook runs under `timeout 300`) the files declared in
# test/.slow-bats are excluded. A single test that outruns the gate's budget
# kills the suite mid-stream with no `not ok` line, so the gate fails
# deterministically and looks like a hang rather than a timeout.
_bats_targets() {
    local slow_list="$REPO_ROOT/test/.slow-bats"
    if [[ "$RUN_FAST" -ne 1 || ! -f "$slow_list" ]]; then
        printf '%s\n' "$REPO_ROOT/test/"
        return 0
    fi
    local -a skip=()
    local line
    while IFS= read -r line; do
        [[ -z "$line" || "$line" == \#* ]] && continue
        skip+=("$line")
    done < "$slow_list"

    local f base s excluded=0
    for f in "$REPO_ROOT"/test/*.bats; do
        [[ -e "$f" ]] || continue
        base="$(basename "$f")"
        for s in ${skip[@]+"${skip[@]}"}; do
            if [[ "$base" == "$s" ]]; then
                base=""
                excluded=$((excluded + 1))
                break
            fi
        done
        [[ -n "$base" ]] && printf '%s\n' "$f"
    done
    if [[ "$excluded" -gt 0 ]]; then
        echo "  [bats] --fast: excluded $excluded slow file(s) per test/.slow-bats (they run in the full suite)" >&2
    fi
}

# shellcheck disable=SC2329  # invoked indirectly via run_suite
run_bats() {
    if ! command -v bats >/dev/null 2>&1; then
        echo "⚠️  bats not installed; skipping"
        return 0
    fi
    local -a targets=()
    while IFS= read -r line; do targets+=("$line"); done < <(_bats_targets)
    # Force git's fsmonitor off for every git invocation the tests spawn. With
    # core.fsmonitor=true in a developer's global ~/.gitconfig, each throwaway
    # test repo starts a detached `git fsmonitor--daemon` that inherits bats'
    # status FD 3 and never closes it -- bats then hangs forever at suite exit.
    if command -v parallel >/dev/null 2>&1; then
        local jobs
        jobs=$(_bats_jobs)
        echo "  [bats] running with --jobs $jobs (GNU parallel found)"
        GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=core.fsmonitor GIT_CONFIG_VALUE_0=false \
            bats --jobs "$jobs" --no-parallelize-within-files ${targets[@]+"${targets[@]}"}
    else
        echo "  [bats] GNU parallel not found -- running serially (brew install parallel for a speedup)"
        GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=core.fsmonitor GIT_CONFIG_VALUE_0=false \
            bats ${targets[@]+"${targets[@]}"}
    fi
}

# shellcheck disable=SC2329  # invoked indirectly via run_suite
#
# The tests/ tree (the R6 guardrail suite, the kernel-split safety suites, the
# commit-gate suite -- file/test counts deliberately not stated here; see the
# stale-"29"/"51"-files incident PHR round 1 caught 2026-09-18, run
# `find tests -name '*.bats' | wc -l` for the live count) was historically
# never run here: run_bats covered test/ only. That two-tier discovery is why
# a red ledger test shipped -- CI runs tests/ via ci-bats-discovery.sh, so a
# developer could go green locally and push into red CI.
#
# It runs SERIALLY and deliberately. The --jobs audit documented above covered
# test/ only; tests/ has never been audited for shared mutable state, and it
# demonstrably has cross-file interference -- commit-gate-test.bats "overlay
# mode scopes token to overlay repo" passes alone (serial AND --jobs 8) and
# fails only when the whole tree runs concurrently. Running it under --jobs
# would import an intermittent failure, which is the single most expensive
# failure shape this repo has. Serial until each file is audited.
run_bats_tests_dir() {
    if ! command -v bats >/dev/null 2>&1; then
        echo "⚠️  bats not installed; skipping"
        return 0
    fi
    [[ -d "$REPO_ROOT/tests" ]] || { echo "no tests/ directory"; return 0; }
    # -r is REQUIRED. `bats <dir>` does not recurse, so the first version of
    # this ran only the 22 top-level files and silently skipped the 7 in
    # subdirectories -- including every kernel-split safety suite -- while
    # reporting 381 tests green. A gate that looks like it covers something
    # and does not is worse than no gate.
    local found
    found=$(find "$REPO_ROOT/tests" -name '*.bats' | wc -l | tr -d ' ')
    echo "  [bats] tests/: $found file(s), serial"
    GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=core.fsmonitor GIT_CONFIG_VALUE_0=false \
        bats -r "$REPO_ROOT/tests/"
}

# shellcheck disable=SC2329  # invoked indirectly via run_suite
run_node_tests() {
    if ! command -v node >/dev/null 2>&1; then
        echo "❌ node not installed; required for JS test suite"
        return 1
    fi
    local rc=0
    # Iterate explicitly so a single failing suite doesn't mask the rest.
    local f
    for f in test/*.test.js; do
        [[ -e "$f" ]] || continue
        echo ""
        echo "── $f ──"
        if ! node "$f"; then
            rc=1
            echo "✗ $f"
        fi
    done
    # The .test.sh files are independent shell harnesses.
    for f in test/*.test.sh; do
        [[ -e "$f" ]] || continue
        echo ""
        echo "── $f ──"
        if ! bash "$f"; then
            rc=1
            echo "✗ $f"
        fi
    done
    return "$rc"
}

# shellcheck disable=SC2329  # invoked indirectly via run_suite
run_harsh_review() {
    bash "$SCRIPT_DIR/harsh-review.sh"
}

[[ "$RUN_SHELLCHECK" -eq 1 ]] && run_suite "shellcheck"      run_shellcheck
[[ "$RUN_HARSH"      -eq 1 ]] && run_suite "harsh-review.sh" run_harsh_review
[[ "$RUN_BATS"       -eq 1 ]] && run_suite "bats test/"      run_bats
[[ "$RUN_NODE"       -eq 1 ]] && run_suite "node test/*"     run_node_tests
# Not in --fast: the pre-push gate runs under `timeout 300` and tests/ is slow.
# CI runs it via ci-bats-discovery.sh regardless.
[[ "$RUN_BATS" -eq 1 && "$RUN_FAST" -ne 1 ]] && run_suite "bats tests/ (serial)" run_bats_tests_dir

# Undeclared in-tree writes fail the run and are named. A declared artifact
# left behind is reported but not fatal -- the next sweep heals it.
if [[ -n "$TREE_STATE" ]]; then
    run_suite "working-tree guard" "$TREE_GUARD" verify "$TREE_STATE"
    rm -f "$TREE_STATE"
fi

echo ""
echo "═══════════════════════════════════════════════════════════"
echo "  SUMMARY"
echo "═══════════════════════════════════════════════════════════"
for s in "${PASSED[@]}"; do echo "  ✓ $s"; done
for s in "${FAILED[@]}"; do echo "  ✗ $s"; done
echo ""
if [[ ${#FAILED[@]} -gt 0 ]]; then
    echo "❌ ${#FAILED[@]} suite(s) failed."
    exit 1
fi
echo "✅ All ${#PASSED[@]} suite(s) passed."
exit 0
