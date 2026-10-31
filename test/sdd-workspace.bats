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

@test "sdd-workspace: same-basename plans have separate stable owned workspaces" {
    mkdir -p dir-a dir-b
    echo "a" > dir-a/plan.md
    echo "b" > dir-b/plan.md
    run bash "$SCRIPT" dir-a/plan.md
    [ "$status" -eq 0 ]; out_a="$output"
    run bash "$SCRIPT" dir-b/plan.md
    [ "$status" -eq 0 ]; out_b="$output"
    [ "$out_a" != "$out_b" ]
    [ "$(cat "$out_a/plan-path")" = "dir-a/plan.md" ]
    [ "$(cat "$out_b/plan-path")" = "dir-b/plan.md" ]
    run bash "$SCRIPT" "$SANDBOX/dir-b/../dir-b/plan.md"
    [ "$status" -eq 0 ]; [ "$output" = "$out_b" ]
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

@test "sdd-workspace: preserves an existing shared ignore policy" {
    echo "# plan" > plan.md
    mkdir -p .superpowers/sdd
    printf '*\n!progress.md\n' > .superpowers/sdd/.gitignore
    cp .superpowers/sdd/.gitignore expected-ignore
    run bash "$SCRIPT" plan.md
    [ "$status" -eq 0 ]
    cmp expected-ignore .superpowers/sdd/.gitignore
}

@test "sdd-workspace: disambiguates repeated parent names without overwriting artifacts" {
    mkdir -p one/shared two/shared three/shared
    for parent in one two three; do
        echo "# plan" > "$parent/shared/plan.md"
        run bash "$SCRIPT" "$parent/shared/plan.md"
        [ "$status" -eq 0 ]
        printf '%s\n' "$parent" > "$output/artifact"
    done
    run bash "$SCRIPT" one/shared/plan.md
    [ "$(cat "$output/artifact")" = one ]
    run bash "$SCRIPT" two/shared/plan.md
    [ "$(cat "$output/artifact")" = two ]
    run bash "$SCRIPT" three/shared/plan.md
    [ "$(cat "$output/artifact")" = three ]
}

@test "sdd-workspace: blocked parent fails promptly rather than looping on collisions" {
    echo "# plan" > plan.md
    touch .superpowers
    run timeout 2 bash "$SCRIPT" plan.md
    [ "$status" -eq 1 ]
    [[ "$output" == *"cannot create workspace"* ]]
}

@test "sdd-workspace: simultaneous colliding plans cannot claim one workspace" {
    mkdir -p a b
    for n in $(seq 1 12); do
        echo "# a" > "a/plan-$n.md"
        echo "# b" > "b/plan-$n.md"
        bash "$SCRIPT" "a/plan-$n.md" > first & first=$!
        bash "$SCRIPT" "b/plan-$n.md" > second & second=$!
        wait "$first"; wait "$second"
        [ "$(cat first)" != "$(cat second)" ]
        [ "$(cat "$(cat first)/plan-path")" = "a/plan-$n.md" ]
        [ "$(cat "$(cat second)/plan-path")" = "b/plan-$n.md" ]
    done
}

@test "sdd-workspace: concurrent callers for one plan all resolve successfully" {
    echo "# plan" > plan.md
    pids=()
    for n in $(seq 1 12); do
        bash "$SCRIPT" plan.md > "out-$n" & pids+=("$!")
    done
    for pid in "${pids[@]}"; do wait "$pid"; done
    for n in $(seq 2 12); do cmp out-1 "out-$n"; done
    [ "$(cat "$(cat out-1)/plan-path")" = plan.md ]
}

@test "sdd-workspace: a file at the lock path fails fast as an obstruction" {
    echo "# plan" > plan.md
    mkdir -p .superpowers/sdd
    : > .superpowers/sdd/.workspace-lock
    run timeout 8 bash "$SCRIPT" plan.md
    [ "$status" -eq 1 ]
    [[ "$output" == *"cannot create workspace lock"* ]]
}

# A lock released between two separate stats (`-e` then `! -d`) looked like a
# file obstruction and failed a waiting caller; it flaked CI under load. Widen
# that window on purpose: insert a sleep before the obstruction check's last
# test. The single-stat-per-test check stays correct; the old pair failed ~10%
# of callers here.
@test "sdd-workspace: a lock released mid-check is retried, not reported as an obstruction" {
    echo "# plan" > plan.md
    slow="$BATS_TEST_TMPDIR/sdd-workspace-slow"
    sed 's/^  if \(.*\) || \[ -S "\$lock" \]; then$/  if \1 || { sleep 0.02; [ -S "$lock" ]; }; then/' "$SCRIPT" > "$slow"
    grep -q 'sleep 0.02' "$slow"
    for round in 1 2 3; do
        pids=()
        for n in $(seq 1 12); do
            bash "$slow" plan.md > "out-$round-$n" 2>> err & pids+=("$!")
        done
        for pid in "${pids[@]}"; do wait "$pid"; done
    done
    [ ! -s err ] || { cat err; false; }
}

@test "sdd-workspace: stale lock fails with a recovery message within a bounded wait" {
    echo "# plan" > plan.md
    mkdir -p .superpowers/sdd/.workspace-lock
    run timeout 8 bash "$SCRIPT" plan.md
    [ "$status" -eq 1 ]
    [[ "$output" == *"workspace lock busy"* ]]
    [ -d .superpowers/sdd/.workspace-lock ]
}

@test "sdd-workspace: outside a git work tree -> exit 2 with a named reason, nothing written" {
    outside="$(cd "$BATS_TEST_TMPDIR" && pwd -P)/outside"
    mkdir -p "$outside"
    printf '# Plan\n' > "$outside/plan.md"
    cd "$outside"
    GIT_CEILING_DIRECTORIES="$outside" run bash "$SCRIPT" plan.md
    [ "$status" -eq 2 ]
    [[ "$output" == *"not inside a git work tree"* ]]
    [ ! -e "$outside/.superpowers" ]
}
