#!/usr/bin/env bats
# Tests for tools/merge-discipline-preflight.sh
# Verifies each lane (legal pairs) and each rejection (illegal pairs).

setup() {
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
    SCRIPT="$REPO_ROOT/tools/merge-discipline-preflight.sh"
    # Use a clean tempdir as a fake git repo so the sentinel is isolated.
    WORK="$(mktemp -d)"
    cd "$WORK"
    git init -q --initial-branch=main
    git config user.email "test@test"; git config user.name "test"
    echo "x" > a.txt; git add a.txt; git commit -q -m init
    # Set up remote refs the script may check (origin/<source>) by branching.
    git branch dev
    git branch staging
    git branch feature/foo
    git branch hotfix/foo
    git branch forward/hotfix-foo
    git branch forward/foo
    git branch revert/abc
    git branch forward/revert-abc
    git remote add origin "$WORK"
    git fetch -q origin
    cp "$SCRIPT" ./preflight.sh
    chmod +x ./preflight.sh
}

teardown() {
    rm -rf "$WORK"
}

# --- Legal pairs (each must PASS) ---

@test "legal: feature/foo -> dev" {
    run ./preflight.sh feature/foo dev
    [ "$status" -eq 0 ]
    [ -f .merge-discipline-cleared ]
    grep -q "v1|.*|feature/foo|dev|" .merge-discipline-cleared
}

@test "legal: fix/bar -> dev" {
    run ./preflight.sh fix/bar dev
    [ "$status" -eq 0 ]
}

@test "legal: forward/foo -> dev" {
    run ./preflight.sh forward/foo dev
    [ "$status" -eq 0 ]
}

@test "legal: revert/abc -> dev (revert on dev)" {
    run ./preflight.sh revert/abc dev
    [ "$status" -eq 0 ]
}

@test "legal: dev -> staging (promotion)" {
    run ./preflight.sh dev staging
    [ "$status" -eq 0 ]
}

@test "legal: revert/abc -> staging" {
    run ./preflight.sh revert/abc staging
    [ "$status" -eq 0 ]
}

@test "legal: staging -> main (promotion)" {
    run ./preflight.sh staging main
    [ "$status" -eq 0 ]
}

@test "legal: hotfix/foo -> main when paired forward/hotfix-foo exists" {
    run ./preflight.sh hotfix/foo main
    [ "$status" -eq 0 ]
}

@test "legal: revert/abc -> main when paired forward/revert-abc exists" {
    run ./preflight.sh revert/abc main
    [ "$status" -eq 0 ]
}

# --- Illegal pairs (each must FAIL) ---

@test "illegal: feature/foo -> main (no direct-to-main)" {
    run ./preflight.sh feature/foo main
    [ "$status" -ne 0 ]
    [[ "$output" == *"main accepts ONLY"* ]]
}

@test "illegal: feature/foo -> staging (no direct-to-staging)" {
    run ./preflight.sh feature/foo staging
    [ "$status" -ne 0 ]
    [[ "$output" == *"staging rejected"* ]]
}

@test "illegal: main -> dev (back-sync direction)" {
    run ./preflight.sh main dev
    [ "$status" -ne 0 ]
}

@test "illegal: dev -> main (skips staging)" {
    run ./preflight.sh dev main
    [ "$status" -ne 0 ]
}

@test "illegal: target=release/v1 (not canonical branch)" {
    run ./preflight.sh feature/foo release/v1
    [ "$status" -ne 0 ]
    [[ "$output" == *"not dev|staging|main"* ]]
}

@test "illegal: branch -v2 suffix (retry pattern)" {
    git branch feature/foo-v2
    run ./preflight.sh feature/foo-v2 dev
    [ "$status" -ne 0 ]
    [[ "$output" == *"retry"* ]]
}

@test "illegal: branch -v10 suffix (retry pattern, double-digit)" {
    git branch feature/foo-v10
    run ./preflight.sh feature/foo-v10 dev
    [ "$status" -ne 0 ]
    [[ "$output" == *"retry"* ]]
}

@test "illegal: chore/back-sync-* (back-sync name)" {
    git branch chore/back-sync-main-to-dev
    run ./preflight.sh chore/back-sync-main-to-dev dev
    [ "$status" -ne 0 ]
    [[ "$output" == *"back-sync"* ]]
}

@test "illegal: sync/* (back-sync name variant)" {
    git branch sync/main-to-dev
    run ./preflight.sh sync/main-to-dev dev
    [ "$status" -ne 0 ]
    [[ "$output" == *"back-sync"* ]]
}

@test "illegal: mirror/* (mirror name)" {
    git branch mirror/upstream
    run ./preflight.sh mirror/upstream dev
    [ "$status" -ne 0 ]
    [[ "$output" == *"back-sync"* ]] || [[ "$output" == *"mirror"* ]]
}

@test "illegal: hotfix/foo -> main when forward branch missing" {
    git branch -D forward/hotfix-foo
    git update-ref -d refs/remotes/origin/forward/hotfix-foo 2>/dev/null || true
    run ./preflight.sh hotfix/foo main
    [ "$status" -ne 0 ]
    [[ "$output" == *"paired forward-port branch"* ]]
    [[ "$output" == *"forward/hotfix-foo"* ]]
}

@test "illegal: revert/abc -> main when forward branch missing" {
    git branch -D forward/revert-abc
    git update-ref -d refs/remotes/origin/forward/revert-abc 2>/dev/null || true
    run ./preflight.sh revert/abc main
    [ "$status" -ne 0 ]
    [[ "$output" == *"paired forward-port branch"* ]]
    [[ "$output" == *"forward/revert-abc"* ]]
}

# --- Identical-error helper ---

@test "identical-check: identical errors -> STOP" {
    run ./preflight.sh --identical-check \
        "HTTP 422 Branch cannot be merged" \
        "HTTP 422 Branch cannot be merged"
    [ "$status" -ne 0 ]
    [[ "$output" == *"Identical error"* ]]
}

@test "identical-check: different errors -> proceed" {
    run ./preflight.sh --identical-check \
        "HTTP 422 Branch cannot be merged" \
        "HTTP 403 Forbidden"
    [ "$status" -eq 0 ]
}

@test "identical-check: differ only by SHA (volatile) -> STOP" {
    run ./preflight.sh --identical-check \
        "Failed at sha abc1234567 in repo X" \
        "Failed at sha def9876543 in repo X"
    [ "$status" -ne 0 ]
    [[ "$output" == *"Identical error"* ]]
}

@test "identical-check: differ only by request-id (volatile) -> STOP" {
    run ./preflight.sh --identical-check \
        "Server hook rejected req_abcXYZ123 details" \
        "Server hook rejected req_qwerasdf987 details"
    [ "$status" -ne 0 ]
    [[ "$output" == *"Identical error"* ]]
}

@test "identical-check: differ only by UUID (volatile) -> STOP" {
    run ./preflight.sh --identical-check \
        "Trace 550e8400-e29b-41d4-a716-446655440000 rejected" \
        "Trace 6ba7b810-9dad-11d1-80b4-00c04fd430c8 rejected"
    [ "$status" -ne 0 ]
    [[ "$output" == *"Identical error"* ]]
}

@test "identical-check: differ only by ISO-8601 timestamp -> STOP" {
    run ./preflight.sh --identical-check \
        "Failed at 2026-05-24T03:14:22Z on api" \
        "Failed at 2026-05-24T03:18:55Z on api"
    [ "$status" -ne 0 ]
    [[ "$output" == *"Identical error"* ]]
}

@test "identical-check: differ only by pod name -> STOP" {
    run ./preflight.sh --identical-check \
        "Error from pod api-deploy-7d4f8b-x9k2m" \
        "Error from pod api-deploy-3a9c2d-mn8pq"
    [ "$status" -ne 0 ]
    [[ "$output" == *"Identical error"* ]]
}

@test "identical-check: differ only by port -> STOP" {
    run ./preflight.sh --identical-check \
        "Connection refused localhost:54321" \
        "Connection refused localhost:54987"
    [ "$status" -ne 0 ]
    [[ "$output" == *"Identical error"* ]]
}

@test "identical-check: differ only by tmp path -> STOP" {
    run ./preflight.sh --identical-check \
        "Build failed in /tmp/build-abc123/step.log" \
        "Build failed in /tmp/build-xyz789/step.log"
    [ "$status" -ne 0 ]
    [[ "$output" == *"Identical error"* ]]
}

# --- Forward-port empty-diff guard ---

@test "illegal: forward/foo -> dev with empty diff vs origin/dev" {
    # forward/foo branch is identical to dev (no cherry-picked content);
    # preflight should refuse to write sentinel.
    git checkout -q forward/foo
    run ./preflight.sh forward/foo dev
    [ "$status" -ne 0 ]
    [[ "$output" == *"EMPTY diff"* ]] || [[ "$output" == *"wrong SHA"* ]]
}

@test "sentinel format: exactly 5 pipe-separated fields, source SHA matches branch tip" {
    git checkout -q feature/foo
    git commit -q --allow-empty -m "tip"
    expected_sha=$(git rev-parse feature/foo)
    run ./preflight.sh feature/foo dev
    [ "$status" -eq 0 ]
    fields=$(awk -F'|' '{print NF}' < .merge-discipline-cleared)
    [ "$fields" -eq 5 ]
    grep -q "v1|${expected_sha}|feature/foo|dev|" .merge-discipline-cleared
}
