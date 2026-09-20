#!/usr/bin/env bats
# Unit test for tools/harsh-review.sh CHECK 8b-2 (reviewer prompt file length).
#
# harsh-review.sh is a monolithic, repo-wide script with no function-level
# test seams (all checks run in one pass against the real tree), so this test
# runs the real script against the real repo with temporary fixture files
# injected under skills/**/reviewers/*.md, rather than a hermetic fresh-repo
# fixture (the pattern used by tools/*-gate.sh tests, which don't need the
# rest of the repo's real content to run cleanly). Fixtures are always
# removed in teardown, including on assertion failure.
#
# Both scenarios (over-400 fails, exactly-400 does not) are asserted from a
# SINGLE harsh-review.sh run, not two -- this script takes several minutes
# per invocation over the whole repo, and running it twice to check one
# check's two boundary cases was itself the single largest cost in the full
# test suite (diet.md W1 Cause C, 2026-09-20). Two distinct fixture files in
# the same run exercise both boundaries without doubling the scan cost.

setup() {
    REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
    HARSH_REVIEW="$REPO_ROOT/tools/harsh-review.sh"
    FIXTURE_DIR="$REPO_ROOT/skills/engineering/code-review-battery/reviewers"
    OVER_FIXTURE="$FIXTURE_DIR/zzz-test-fixture-oversized.md"
    EXACT_FIXTURE="$FIXTURE_DIR/zzz-test-fixture-exact.md"
}

teardown() {
    rm -f "$OVER_FIXTURE" "$EXACT_FIXTURE"
}

@test "harsh-review CHECK 8b-2: over-400 fails named with count, exactly-400 does not fail, from one run" {
    i=0
    while [ "$i" -lt 410 ]; do echo "# fixture line $i"; i=$((i + 1)); done > "$OVER_FIXTURE"
    over_lines=$(wc -l < "$OVER_FIXTURE" | tr -d ' ')
    [ "$over_lines" -gt 400 ]

    i=0
    while [ "$i" -lt 400 ]; do echo "# fixture line $i"; i=$((i + 1)); done > "$EXACT_FIXTURE"
    exact_lines=$(wc -l < "$EXACT_FIXTURE" | tr -d ' ')
    [ "$exact_lines" -eq 400 ]

    cd "$REPO_ROOT"
    run bash "$HARSH_REVIEW"

    # Over-400 case: named with its exact line count.
    [[ "$output" == *"Reviewer prompt file length"* ]]
    [[ "$output" == *"zzz-test-fixture-oversized.md"* ]]
    [[ "$output" == *"${over_lines} lines (max 400)"* ]]

    # Exactly-400 case: NOT flagged by CHECK 8b-2. A bare filename match is
    # too broad -- 400 repeated "# fixture line N" headers are real markdown
    # content, so this fixture also legitimately trips the separate,
    # unrelated markdownlint check earlier in the script's output ("[WARN]
    # .../zzz-test-fixture-exact.md: markdownlint issues") -- found via
    # code-review-battery, reproduced by running harsh-review.sh directly
    # against this exact fixture. Assert against CHECK 8b-2's own specific
    # log_fail format instead of the bare filename, so this only cares about
    # the check it's named for.
    [[ "$output" != *"zzz-test-fixture-exact.md: ${exact_lines} lines (max 400)"* ]]
}
