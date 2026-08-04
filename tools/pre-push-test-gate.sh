#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# pre-push-test-gate.sh
#
# Gate 1 of the pre-push composer: runs tools/test-all.sh --fast (local fast
# test suite) before every push. Without this, catching stale test fixtures
# (golden-compression snapshots, EI-move baselines) was purely a CI
# round-trip: push, wait for CI to fail, fix locally, push again.
#
# Skipped entirely when the push contains ONLY branch deletions (every ref's
# local SHA is all-zero): a deletion carries no content to test, and running
# the full suite anyway wasted minutes of local time (and, chained through a
# code-review-battery re-run, real reviewer-agent cost) for a no-op ref
# removal.
#
# Invoked by tools/pre-push (the composer), which captures git's stdin ref
# list into a temp file and replays it fresh to each gate script. This gate
# can also be invoked directly (as its own tests do), in which case stdin is
# whatever the caller provides.
#
# EXIT: 0 = suite passed, or skipped (no content in the push, or missing
#           prerequisites -- not this repo's concern to enforce)
#       1 = suite failed; push blocked
# -----------------------------------------------------------------------------
set -euo pipefail

# Git sets GIT_DIR (and GIT_PREFIX) in the hook subprocess environment under a
# linked worktree; left set, it overrides `-C`/cwd discovery for ANY nested
# git invocation, silently redirecting this gate's own `test-all.sh` -> bats
# fixture tree onto the wrong repo. The composer already unsets these before
# invoking any gate, but this script re-unsets independently so it stays
# correct when invoked standalone (as its own tests do), not only through
# the composer.
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_PREFIX

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || true)"
if [[ -z "$REPO_ROOT" ]]; then
    REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fi

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

# Classify the push: does any ref carry real content (non-zero local SHA)?
# A pure branch-deletion push has nothing for the local suite to test.
HAS_CONTENT_PUSH=false
while IFS= read -r _push_line; do
    read -r _ _push_local_sha _ _ <<< "$_push_line"
    if [[ "$_push_local_sha" != "0000000000000000000000000000000000000000" ]]; then
        HAS_CONTENT_PUSH=true
        break
    fi
done

if [[ "$HAS_CONTENT_PUSH" == "false" ]]; then
    echo "  [test-gate] (skipped — push contains only branch deletions, nothing to test)"
    exit 0
fi

if [[ ! -f "$REPO_ROOT/tools/test-all.sh" ]] || [[ ! -d "$REPO_ROOT/test" ]]; then
    # This gate is also copied standalone into minimal/derived repo layouts
    # that don't carry the full tools/+test/ tree. A missing prerequisite
    # means "not applicable here", not "block the push" -- same reasoning as
    # the other gates' own missing-helper handling.
    echo "  [test-gate] (skipped — tools/test-all.sh and/or test/ not present)"
    exit 0
fi

# This gate tests the checked-out working tree, not the specific commits
# being pushed (computing that would mean checking out each pushed ref into
# an isolated worktree, real added complexity for a local hook). Make that
# scope gap visible rather than silently testing the wrong thing.
if [[ -n "$(git status --porcelain 2>/dev/null)" ]]; then
    echo "  ⚠️  Working tree has uncommitted changes -- this gate tests what's on disk, not necessarily the exact commits being pushed."
fi

# Prefer GNU coreutils timeout/gtimeout if present; without one, a hung test
# would stall `git push` indefinitely with no built-in escape besides Ctrl-C.
TEST_TIMEOUT_BIN=""
for _cand in timeout gtimeout; do
    if command -v "$_cand" >/dev/null 2>&1; then
        TEST_TIMEOUT_BIN="$_cand"
        break
    fi
done

if [[ -n "$TEST_TIMEOUT_BIN" ]]; then
    test_cmd=("$TEST_TIMEOUT_BIN" "300" bash "$REPO_ROOT/tools/test-all.sh" --fast)
else
    test_cmd=(bash "$REPO_ROOT/tools/test-all.sh" --fast)
fi

# < /dev/null: the HAS_CONTENT_PUSH loop above reads only as much of stdin as
# it needs to decide (it `break`s on the first content-bearing ref, so stdin
# may not be at EOF yet); this redirect is what actually guarantees test-all.sh
# (or anything it invokes) can't read a stray line from stdin instead of /dev/null.
if ! "${test_cmd[@]}" < /dev/null; then
    echo -e "  ${RED}❌ Local test suite failed. Fix the findings above before pushing.${NC}"
    exit 1
fi

echo -e "  ${GREEN}✓ Local fast test suite passed${NC}"
exit 0
