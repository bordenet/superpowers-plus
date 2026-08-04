#!/usr/bin/env bats

# Behavioral tests for skills/engineering/subagent-driven-development/scripts/sdd-workspace.
# Covers the plan-scoped-workspace port: requires exactly one arg (PLAN_FILE),
# errors on missing/nonexistent plan file, derives a slug via `basename $plan
# .md`, creates .superpowers/sdd/<slug>/, and writes the shared .gitignore at
# the parent .superpowers/sdd/ level (not inside the per-plan dir).

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
SCRIPT="$REPO_ROOT/skills/engineering/subagent-driven-development/scripts/sdd-workspace"

setup() {
    # Resolve to the physical (symlink-free) path up front: on macOS
    # $BATS_TEST_TMPDIR lives under /var/folders, itself a symlink to
    # /private/var/folders, and `git rev-parse --show-toplevel` (used
    # internally by sdd-workspace) returns the physical path -- so asserting
    # against the logical $BATS_TEST_TMPDIR form would spuriously mismatch.
    SANDBOX="$(cd "$BATS_TEST_TMPDIR" && pwd -P)/repo"
    mkdir -p "$SANDBOX"
    cd "$SANDBOX"
    git init -q -b main
    git config user.email "test@example.com"
    git config user.name "Test"
}

# ------------------------------- usage errors -------------------------------

@test "sdd-workspace: 0 args -> exit 2 with usage message" {
    run bash "$SCRIPT"
    [ "$status" -eq 2 ]
    [[ "$output" == *"usage: sdd-workspace PLAN_FILE"* ]]
}

@test "sdd-workspace: 2+ args -> exit 2 with usage message" {
    run bash "$SCRIPT" a.md b.md
    [ "$status" -eq 2 ]
    [[ "$output" == *"usage: sdd-workspace PLAN_FILE"* ]]
}

@test "sdd-workspace: nonexistent plan file -> exit 2, error mentions the path" {
    run bash "$SCRIPT" "foo/bar/nope.md"
    [ "$status" -eq 2 ]
    [[ "$output" == *"foo/bar/nope.md"* ]]
}

# --------------------------- real-plan resolution ---------------------------

@test "sdd-workspace: real plan file creates and prints <repo>/.superpowers/sdd/<slug>" {
    mkdir -p foo/bar
    echo "# plan" > foo/bar/my-plan.md

    run bash "$SCRIPT" foo/bar/my-plan.md
    [ "$status" -eq 0 ]
    [ "$output" = "$SANDBOX/.superpowers/sdd/my-plan" ]
    [ -d "$SANDBOX/.superpowers/sdd/my-plan" ]
}

@test "sdd-workspace: same-basename plans in different dirs collide onto the same slug dir (accepted, matches upstream)" {
    # This is documented, accepted behavior -- not a bug to fix. If a future
    # change disambiguates by directory, this test should be updated
    # deliberately, not silently broken.
    mkdir -p dir-a dir-b
    echo "a" > dir-a/plan.md
    echo "b" > dir-b/plan.md

    run bash "$SCRIPT" dir-a/plan.md
    [ "$status" -eq 0 ]
    out_a="$output"

    run bash "$SCRIPT" dir-b/plan.md
    [ "$status" -eq 0 ]
    out_b="$output"

    [ "$out_a" = "$out_b" ]
    [ "$out_a" = "$SANDBOX/.superpowers/sdd/plan" ]
}

@test "sdd-workspace: .gitignore (content '*') lands at .superpowers/sdd/.gitignore, not inside the per-plan dir" {
    mkdir -p foo
    echo "# plan" > foo/my-plan.md

    run bash "$SCRIPT" foo/my-plan.md
    [ "$status" -eq 0 ]

    [ -f "$SANDBOX/.superpowers/sdd/.gitignore" ]
    [ "$(cat "$SANDBOX/.superpowers/sdd/.gitignore")" = "*" ]
    [ ! -f "$SANDBOX/.superpowers/sdd/my-plan/.gitignore" ]
}
