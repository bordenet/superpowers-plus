#!/usr/bin/env bats
# Unit test for tools/harsh-review.sh CHECK 8b-2 (reviewer prompt file length).
#
# harsh-review.sh is a monolithic, repo-wide script with no function-level
# test seams (all checks run in one pass against the real tree), so this test
# runs the real script against the real repo with a temporary fixture file
# injected under skills/**/reviewers/*.md, rather than a hermetic fresh-repo
# fixture (the pattern used by tools/*-gate.sh tests, which don't need the
# rest of the repo's real content to run cleanly). The fixture is always
# removed in teardown, including on assertion failure.

setup() {
    REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
    HARSH_REVIEW="$REPO_ROOT/tools/harsh-review.sh"
    FIXTURE_DIR="$REPO_ROOT/skills/engineering/code-review-battery/reviewers"
    FIXTURE_FILE="$FIXTURE_DIR/zzz-test-fixture-oversized.md"
}

teardown() {
    rm -f "$FIXTURE_FILE"
}

@test "harsh-review CHECK 8b-2: a reviewers/*.md file over 400 lines fails with the exact file and line count named" {
    i=0
    while [ "$i" -lt 410 ]; do echo "# fixture line $i"; i=$((i + 1)); done > "$FIXTURE_FILE"
    # Confirm the fixture is actually over the 400-line threshold before
    # trusting the assertion below -- a fixture-generation bug must fail
    # loudly here, not produce a false pass/fail on the real check.
    fixture_lines=$(wc -l < "$FIXTURE_FILE" | tr -d ' ')
    [ "$fixture_lines" -gt 400 ]

    cd "$REPO_ROOT"
    run bash "$HARSH_REVIEW"

    [[ "$output" == *"Reviewer prompt file length"* ]]
    [[ "$output" == *"zzz-test-fixture-oversized.md"* ]]
    [[ "$output" == *"${fixture_lines} lines (max 400)"* ]]
}

@test "harsh-review CHECK 8b-2: a reviewers/*.md file at exactly 400 lines does not fail" {
    i=0
    while [ "$i" -lt 400 ]; do echo "# fixture line $i"; i=$((i + 1)); done > "$FIXTURE_FILE"
    fixture_lines=$(wc -l < "$FIXTURE_FILE" | tr -d ' ')
    [ "$fixture_lines" -eq 400 ]

    cd "$REPO_ROOT"
    run bash "$HARSH_REVIEW"

    [[ "$output" != *"zzz-test-fixture-oversized.md"* ]]
}
