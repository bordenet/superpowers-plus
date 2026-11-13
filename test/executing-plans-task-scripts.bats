#!/usr/bin/env bats
# executing-plans task-start/task-done: run from a foreign cwd against an
# installed-style layout (sibling skill dirs), and record a ledger line only
# when the task's test command passes.

setup() {
    REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd -P)"
    SKILLS="$BATS_TEST_TMPDIR/skills"
    mkdir -p "$SKILLS"
    cp -R "$REPO_ROOT/skills/engineering/executing-plans" "$SKILLS/"
    cp -R "$REPO_ROOT/skills/engineering/subagent-driven-development" "$SKILLS/"
    WORK="$BATS_TEST_TMPDIR/work"
    mkdir -p "$WORK/docs"
    cd "$WORK"
    git init -q
    git -c user.name=Fixture -c user.email=fixture@example.invalid commit -q --allow-empty -m base
    printf '# Plan\n\n## Task 1: first\n\nDo one.\n\n## Task 2: second\n\nDo two.\n' > docs/plan.md
    START="$SKILLS/executing-plans/scripts/task-start"
    DONE="$SKILLS/executing-plans/scripts/task-done"
}

@test "task-start prints the brief path and BASE from a foreign cwd" {
    run bash "$START" docs/plan.md 2
    [ "$status" -eq 0 ]
    brief=$(printf '%s\n' "$output" | sed -n 's/^brief: //p')
    base=$(printf '%s\n' "$output" | sed -n 's/^base: //p')
    [ -f "$brief" ]
    grep -q 'Task 2: second' "$brief"
    ! grep -q 'Task 1: first' "$brief"
    [ "$base" = "$(git rev-parse HEAD)" ]
}

@test "task-done records nothing when the test command fails" {
    base=$(git rev-parse HEAD)
    run bash "$DONE" docs/plan.md 1 "$base" -- false
    [ "$status" -ne 0 ]
    ledger="$(bash "$SKILLS/subagent-driven-development/scripts/sdd-workspace" docs/plan.md)/progress.md"
    [ ! -f "$ledger" ] || ! grep -q '^Task 1: complete' "$ledger"
}

@test "task-done appends exactly one completion line when tests pass" {
    base=$(git rev-parse HEAD)
    run bash "$DONE" docs/plan.md 1 "$base" -- true
    [ "$status" -eq 0 ]
    ledger="$(bash "$SKILLS/subagent-driven-development/scripts/sdd-workspace" docs/plan.md)/progress.md"
    head -1 "$ledger" | grep -q '^# SDD ledger — plan: docs/plan.md$'
    [ "$(grep -c '^Task 1: complete (commits ' "$ledger")" -eq 1 ]
}

@test "task-start fails without writing a workspace outside a git repo" {
    outside="$BATS_TEST_TMPDIR/outside"
    mkdir -p "$outside"
    cp docs/plan.md "$outside/plan.md"
    cd "$outside"
    GIT_CEILING_DIRECTORIES="$outside" run bash "$START" plan.md 1
    [ "$status" -ne 0 ]
    [ ! -e "$outside/.superpowers" ]
}

@test "task-done renders quotes as valid shell and does not duplicate on re-run" {
    base=$(git rev-parse HEAD)
    run bash "$DONE" docs/plan.md 1 "$base" -- echo "it's ok"
    [ "$status" -eq 0 ]
    run bash "$DONE" docs/plan.md 1 "$base" -- echo "it's ok"
    [ "$status" -eq 0 ]
    ledger="$(bash "$SKILLS/subagent-driven-development/scripts/sdd-workspace" docs/plan.md)/progress.md"
    [ "$(grep -c '^Task 1: complete ' "$ledger")" -eq 1 ]
    recorded=$(sed -n 's/^Task 1: complete .*tests: \(.*\) → .*/\1/p' "$ledger")
    [ "$(bash -c "$recorded")" = "it's ok" ]
}

@test "task-done rejects a non-integer task number before running tests" {
    base=$(git rev-parse HEAD)
    run bash "$DONE" docs/plan.md 1.5 "$base" -- true
    [ "$status" -eq 2 ]
    [[ "$output" == *"plain integer"* ]]
}

@test "task-start names an empty repository instead of a wrong cwd" {
    empty="$BATS_TEST_TMPDIR/empty"
    mkdir -p "$empty" && cd "$empty" && git init -q
    cp "$WORK/docs/plan.md" plan.md
    run bash "$START" plan.md 1
    [ "$status" -eq 2 ]
    [[ "$output" == *"no commits yet"* ]]
}

@test "task scripts run when the installed copies lost their exec bits" {
    chmod -x "$SKILLS"/executing-plans/scripts/* "$SKILLS"/subagent-driven-development/scripts/*
    run bash "$START" docs/plan.md 1
    [ "$status" -eq 0 ]
    base=$(git rev-parse HEAD)
    run bash "$DONE" docs/plan.md 1 "$base" -- true
    [ "$status" -eq 0 ]
}
