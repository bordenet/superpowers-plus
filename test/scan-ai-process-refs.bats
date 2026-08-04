#!/usr/bin/env bats
# Tests for slop-dictionary.js's scan-ai-process-refs / seed-ai-process-refs
# commands: catches this toolkit's own process vocabulary (harsh-review,
# cr-battery, PHR, etc.) leaking into a downstream adopter's PR/commit text,
# while exempting superpowers-plus's own repo where naming these skills is
# normal subject matter, not a violation.

REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
SCRIPT="$REPO_ROOT/scripts/slop-dictionary.js"

setup() {
    # Detection (scan-ai-process-refs) must run OUTSIDE superpowers-plus
    # itself to observe real matching -- inside this repo the self-repo
    # exemption correctly and deliberately suppresses every match.
    FAKE_REPO="$(mktemp -d)"
    cd "$FAKE_REPO" || return 1
    git init -q
    git remote add origin git@github.com:someorg/some-product-repo.git
    echo "# Some Product Repo" > AGENTS.md
}

teardown() {
    cd /
    rm -rf "$FAKE_REPO"
}

@test "scan-ai-process-refs: clean text passes" {
    run bash -c "echo 'This PR fixes a null pointer bug in the parser.' | node '$SCRIPT' scan-ai-process-refs -"
    [ "$status" -eq 0 ]
    [[ "$output" == *"No ai-process reference detected"* ]]
}

@test "scan-ai-process-refs: planted self-reference is caught (exit 1)" {
    run bash -c "echo 'Ran a harsh-review pass and got a phr score of 9.2 before this cr-battery run.' | node '$SCRIPT' scan-ai-process-refs -"
    [ "$status" -eq 1 ]
    [[ "$output" == *"AI-PROCESS REFERENCE DETECTED"* ]]
    [[ "$output" == *"harsh-review"* ]]
}

@test "scan-ai-process-refs: multi-word pattern split across a line wrap is still caught" {
    run bash -c "printf 'a phr\nscore of 9\n' | node '$SCRIPT' scan-ai-process-refs -"
    [ "$status" -eq 1 ]
}

@test "scan-ai-process-refs: empty input exits 2, distinct from a clean pass" {
    run bash -c "printf '' | node '$SCRIPT' scan-ai-process-refs -"
    [ "$status" -eq 2 ]
    [[ "$output" == *"input is empty"* ]]
}

@test "scan-ai-process-refs: self-repo exemption fires inside superpowers-plus itself" {
    run bash -c "cd '$REPO_ROOT' && echo 'a harsh-review pass' | node '$SCRIPT' scan-ai-process-refs -"
    [ "$status" -eq 0 ]
    [[ "$output" == *"self-repo exemption"* ]]
}

@test "scan-profanity still works after the shared-helper refactor (regression check)" {
    run bash -c "echo 'clean text here' | node '$SCRIPT' scan-profanity -"
    [ "$status" -eq 0 ]
    [[ "$output" == *"No profanity detected"* ]]
}

@test "list rejects an invalid category" {
    run node "$SCRIPT" list bogus-category-name
    [ "$status" -eq 1 ]
    [[ "$output" == *"Invalid category"* ]]
}
