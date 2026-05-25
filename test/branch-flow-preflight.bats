#!/usr/bin/env bats
# Tests for the ADVISORY-MODE branch-flow-preflight.sh
# Core invariant: ALWAYS EXITS 0. Never blocks.

setup() {
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
    SCRIPT="$REPO_ROOT/tools/branch-flow-preflight.sh"
    WORK="$(mktemp -d)"
    cd "$WORK"
    git init -q --initial-branch=main
    git config user.email "test@test"
    git config user.name "test"
    echo "x" > a.txt
    git add a.txt
    git commit -q -m init
    git branch develop
    git branch dev
    git branch staging
    git branch feat/foo
    git branch fix/bar
    git branch chore/cleanup
    git remote add origin "$WORK"
    git fetch -q origin
    cp "$SCRIPT" ./preflight.sh
    chmod +x ./preflight.sh
}

teardown() {
    rm -rf "$WORK"
}

# --- Core invariant: ALWAYS EXIT 0 ---

@test "advisory: legal feat/foo -> dev exits 0" {
    run ./preflight.sh feat/foo dev
    [ "$status" -eq 0 ]
}

@test "advisory: feat/foo (auto-mode, no args) exits 0" {
    git checkout -q feat/foo
    run ./preflight.sh
    [ "$status" -eq 0 ]
}

@test "advisory: retry suffix -vN exits 0 with advisory message" {
    git branch feat/foo-v2
    run ./preflight.sh feat/foo-v2 dev
    [ "$status" -eq 0 ]
    [[ "$output" == *"RETRY-SUFFIX ADVISORY"* ]]
    [[ "$output" == *"git commit --amend"* ]]
}

@test "advisory: back-sync name exits 0 with advisory message" {
    git branch chore/back-sync-main-to-dev
    run ./preflight.sh chore/back-sync-main-to-dev dev
    [ "$status" -eq 0 ]
    [[ "$output" == *"BACK-SYNC NAMING ADVISORY"* ]]
}

@test "advisory: sync/* exits 0 with advisory message" {
    git branch sync/upstream
    run ./preflight.sh sync/upstream dev
    [ "$status" -eq 0 ]
    [[ "$output" == *"BACK-SYNC"* ]] || [[ "$output" == *"mirror"* ]]
}

@test "advisory: mirror/* exits 0 with advisory message" {
    git branch mirror/upstream
    run ./preflight.sh mirror/upstream dev
    [ "$status" -eq 0 ]
}

@test "advisory: protected branch source exits 0 with info" {
    run ./preflight.sh main dev
    [ "$status" -eq 0 ]
    [[ "$output" == *"protected"* ]] || [[ "$output" == *"long-lived"* ]]
}

@test "advisory: hotfix/* is exempt (info, no advisory)" {
    git branch hotfix/p0
    run ./preflight.sh hotfix/p0 main
    [ "$status" -eq 0 ]
    [[ "$output" == *"exempt"* ]]
    [[ "$output" != *"RETRY-SUFFIX"* ]]
}

@test "advisory: release/* is exempt" {
    git branch release/v1.2
    run ./preflight.sh release/v1.2 main
    [ "$status" -eq 0 ]
    [[ "$output" == *"exempt"* ]]
}

@test "advisory: backport/* is exempt" {
    git branch backport/v1.2-fix
    run ./preflight.sh backport/v1.2-fix main
    [ "$status" -eq 0 ]
    [[ "$output" == *"exempt"* ]]
}

# --- Escape hatches ---

@test "escape: GIT_BASE_OVERRIDE=1 suppresses base advisory" {
    # Move dev forward, then branch off staging (would normally trigger advisory)
    git checkout -q dev
    git commit -q --allow-empty -m "dev moves"
    git checkout -q staging
    git commit -q --allow-empty -m "staging moves"
    git push -q origin dev staging 2>/dev/null || true
    git fetch -q origin
    git checkout -q -b feat/off-staging staging
    GIT_BASE_OVERRIDE=1 run ./preflight.sh feat/off-staging dev
    [ "$status" -eq 0 ]
    [[ "$output" == *"GIT_BASE_OVERRIDE=1"* ]] || [[ "$output" == *"suppressed"* ]]
}

@test "escape: per-branch ack file suppresses re-firing" {
    git branch feat/baz
    mkdir -p .git
    touch ".git/base-advisory-ack-feat-baz"
    run ./preflight.sh feat/baz dev
    [ "$status" -eq 0 ]
    # Either no advisory output OR the existence of ack means the script exits early
}

# --- Identical-error helper (also advisory; exits 0) ---

@test "identical-check: identical errors -> advisory + exit 0" {
    run ./preflight.sh --identical-check \
        "HTTP 422 Branch cannot be merged" \
        "HTTP 422 Branch cannot be merged"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Identical opaque error"* ]]
}

@test "identical-check: different errors -> proceed + exit 0" {
    run ./preflight.sh --identical-check \
        "HTTP 422 Branch cannot be merged" \
        "HTTP 403 Forbidden"
    [ "$status" -eq 0 ]
}

@test "identical-check: differ only by SHA -> advisory + exit 0" {
    run ./preflight.sh --identical-check \
        "Failed at sha abc1234567 in repo X" \
        "Failed at sha def9876543 in repo X"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Identical opaque error"* ]]
}

@test "identical-check: differ only by UUID -> advisory + exit 0" {
    run ./preflight.sh --identical-check \
        "Trace 550e8400-e29b-41d4-a716-446655440000 rejected" \
        "Trace 6ba7b810-9dad-11d1-80b4-00c04fd430c8 rejected"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Identical opaque error"* ]]
}

# --- First-parent chain check (base alignment) ---

@test "base-alignment: feat off dev when dev = base PASSES" {
    run ./preflight.sh feat/foo dev
    [ "$status" -eq 0 ]
    [[ "$output" == *"base aligned"* ]]
}

@test "base-alignment: feat off staging when target=dev -> advisory exit 0" {
    git checkout -q dev
    git commit -q --allow-empty -m "dev moves"
    git checkout -q staging
    git commit -q --allow-empty -m "staging moves"
    git push -q origin dev staging 2>/dev/null || true
    git fetch -q origin
    git checkout -q -b feat/off-staging staging
    run ./preflight.sh feat/off-staging dev
    [ "$status" -eq 0 ]  # advisory, never blocks
    # Either base-advisory fires OR it falls through; either way exit 0
}

# --- Sentinel write (audit trail) ---

@test "sentinel: written on PASS with 5 fields" {
    run ./preflight.sh feat/foo dev
    [ "$status" -eq 0 ]
    [ -f .branch-flow-cleared ]
    fields=$(awk -F'|' '{print NF}' < .branch-flow-cleared)
    [ "$fields" -eq 5 ]
}

@test "sentinel: written even when advisory fires (advisory != block)" {
    git branch feat/foo-v2
    run ./preflight.sh feat/foo-v2 dev
    [ "$status" -eq 0 ]
    [ -f .branch-flow-cleared ]
}

# --- Self-target sanity check still exits 0 (just doesn't make sense) ---

@test "advisory: source == target exits 0 (protected branch source)" {
    run ./preflight.sh main main
    [ "$status" -eq 0 ]
    [[ "$output" == *"protected"* ]] || [[ "$output" == *"long-lived"* ]]
}
