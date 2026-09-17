#!/usr/bin/env bats
# Tests for tools/lib/pre-push-diff-range.sh's already_reviewed_on_trusted_branch(),
# which exempts pre-push Gates 2/5/6 from requiring a fresh review sentinel
# when the pushed SHA already sits on origin/main or origin/staging -- e.g. a
# promotion back-sync branch (chore/sync-dev-with-main, always cut directly
# from main's tip) or a re-push of an already-merged branch. Content already
# on main already passed every gate to get there.

setup() {
    REPO_ROOT_REAL="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
    WORK="$(mktemp -d)"
    cd "$WORK"

    # "origin" is a bare repo so origin/main and origin/staging are real
    # remote-tracking refs, matching how the gates see them in practice.
    git init -q --bare origin.git
    git clone -q origin.git work
    cd work
    git config user.email "test@test"
    git config user.name "test"

    echo base > base.txt
    git add base.txt
    git commit -q -m "base"
    git branch -M main
    git push -q origin main
    MAIN_SHA=$(git rev-parse HEAD)
    export MAIN_SHA

    echo staging-only > staging.txt
    git checkout -q -b staging
    git add staging.txt
    git commit -q -m "staging extra"
    git push -q origin staging
    STAGING_SHA=$(git rev-parse HEAD)
    export STAGING_SHA

    git checkout -q main
    git fetch -q origin
}

teardown() {
    rm -rf "$WORK"
}

run_check() {
    bash -c "
        set -euo pipefail
        source '$REPO_ROOT_REAL/tools/lib/pre-push-diff-range.sh'
        already_reviewed_on_trusted_branch '$1' '$2'
    "
}

@test "already_reviewed_on_trusted_branch: true for origin/main's own tip" {
    run run_check "$MAIN_SHA" origin
    [ "$status" -eq 0 ]
}

@test "already_reviewed_on_trusted_branch: true for a commit that is an ancestor of origin/main" {
    git checkout -q -b tmp
    echo more > more.txt
    git add more.txt
    git commit -q -m "advance main"
    git checkout -q main
    git merge -q --ff-only tmp
    git push -q origin main
    run run_check "$MAIN_SHA" origin
    [ "$status" -eq 0 ]
}

@test "already_reviewed_on_trusted_branch: true for a commit only on origin/staging" {
    run run_check "$STAGING_SHA" origin
    [ "$status" -eq 0 ]
}

@test "already_reviewed_on_trusted_branch: false for an unrelated feature commit" {
    git checkout -q -b feature
    echo new > feature.txt
    git add feature.txt
    git commit -q -m "feature work"
    feature_sha=$(git rev-parse HEAD)
    run run_check "$feature_sha" origin
    [ "$status" -eq 1 ]
}

@test "already_reviewed_on_trusted_branch: false for a hotfix branch with new commits on top of main" {
    git checkout -q -b "hotfix/hf-1" main
    echo fix > fix.txt
    git add fix.txt
    git commit -q -m "hotfix work"
    hotfix_sha=$(git rev-parse HEAD)
    run run_check "$hotfix_sha" origin
    [ "$status" -eq 1 ]
}

@test "already_reviewed_on_trusted_branch: false (not crash) when neither origin/main nor origin/staging exist" {
    cd "$WORK"
    git init -q --bare origin2.git
    git clone -q origin2.git work2
    cd work2
    git config user.email "test@test"
    git config user.name "test"
    echo x > x.txt
    git add x.txt
    git commit -q -m "x"
    git checkout -q -b feature
    sha=$(git rev-parse HEAD)
    run run_check "$sha" origin
    [ "$status" -eq 1 ]
}
