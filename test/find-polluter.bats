#!/usr/bin/env bats

# Behavioral tests for skills/engineering/systematic-debugging/find-polluter.sh.
# Covers the ./-prefix bug fix: the test-finder pattern (positional arg 2,
# e.g. 'src/**/*.test.ts') must actually match files, both nested under an
# extra directory level and directly at the base dir (the '**/'-collapsed
# fix), and must report a true zero -- not an always-empty-then-miscounted-
# as-1 result -- when nothing matches.
#
# CLI interface (confirmed by reading the script): positional args, not env
# vars -- `find-polluter.sh <file_or_dir_to_check> <test_pattern>`.

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
SCRIPT="$REPO_ROOT/skills/engineering/systematic-debugging/find-polluter.sh"

setup() {
    WORK="$BATS_TEST_TMPDIR/work"
    mkdir -p "$WORK"
    cd "$WORK"
    # A path that will never exist and never get created (the script's own
    # `npm test` calls are suppressed/best-effort and irrelevant here) --
    # this keeps every iteration running to completion so we can assert on
    # the "Found N" line and the per-file listing rather than an early exit.
    NEVER="$WORK/never-created.marker"
}

@test "find-polluter: nested test file (src/sub/foo.test.ts) matching src/**/*.test.ts is found and named in output" {
    mkdir -p src/sub
    echo "test('x', () => {})" > src/sub/foo.test.ts

    run bash "$SCRIPT" "$NEVER" 'src/**/*.test.ts'
    [ "$status" -eq 0 ]
    [[ "$output" == *"Found 1 test files"* ]]
    [[ "$output" == *"src/sub/foo.test.ts"* ]]
}

@test "find-polluter: top-level test file (src/top.test.ts) matching src/**/*.test.ts is also found (the **/-collapsed fix)" {
    mkdir -p src
    echo "test('x', () => {})" > src/top.test.ts

    run bash "$SCRIPT" "$NEVER" 'src/**/*.test.ts'
    [ "$status" -eq 0 ]
    [[ "$output" == *"Found 1 test files"* ]]
    [[ "$output" == *"src/top.test.ts"* ]]
}

@test "find-polluter: no matching files at all reports 0, not a miscounted 1" {
    mkdir -p src
    # deliberately no files matching the pattern anywhere
    run bash "$SCRIPT" "$NEVER" 'nomatch/**/*.test.ts'
    [ "$status" -eq 0 ]
    [[ "$output" == *"Found 0 test files"* ]]
    [[ "$output" != *"Found 1 test files"* ]]
}

@test "find-polluter: nested + top-level together are both counted once each, no double count from the two alternated patterns" {
    mkdir -p src/sub
    echo "test('x', () => {})" > src/sub/foo.test.ts
    echo "test('x', () => {})" > src/top.test.ts

    run bash "$SCRIPT" "$NEVER" 'src/**/*.test.ts'
    [ "$status" -eq 0 ]
    [[ "$output" == *"Found 2 test files"* ]]
    [[ "$output" == *"src/sub/foo.test.ts"* ]]
    [[ "$output" == *"src/top.test.ts"* ]]
}
