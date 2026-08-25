#!/usr/bin/env bats

# Behavioral tests for skills/engineering/subagent-driven-development/scripts/task-brief.
# Covers the plan-scoped-workspace port: task-brief passes PLAN_FILE through
# to sdd-workspace so its default OUTFILE lands under the plan-scoped dir
# (.superpowers/sdd/<plan-basename>/task-<N>-brief.md) instead of the old
# shared .superpowers/sdd/ dir.
#
# NOTE on the "old 2-arg form" case below: task-brief's own arg-count check
# already requires a minimum of 2 args (PLAN_FILE, TASK_NUMBER) as read from
# the script today, so an old-style 2-arg call (TASK_NUMBER OUTFILE, no
# PLAN_FILE) does NOT trip the "usage: ..." arg-count message -- it still
# satisfies the count check, then fails one step later because the value in
# the PLAN_FILE slot (e.g. a bare task number) is not a real file. Verified
# by direct invocation rather than assumed; see the final report for detail.

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
SCRIPT="$REPO_ROOT/skills/engineering/subagent-driven-development/scripts/task-brief"

setup() {
    # Physical path up front -- see sdd-workspace.bats for why (macOS
    # /var/folders symlink vs `git rev-parse --show-toplevel`'s physical
    # output).
    SANDBOX="$(cd "$BATS_TEST_TMPDIR" && pwd -P)/repo"
    mkdir -p "$SANDBOX"
    cd "$SANDBOX"
    git init -q -b main
    git config user.email "test@example.com"
    git config user.name "Test"

    cat > plan.md <<'EOF'
# Plan

## Task 1
Do the first thing.
More detail.

## Task 2
Do the second thing.
EOF
}

@test "task-brief: old 2-arg form (missing PLAN_FILE) -> exit 2, error names the bad plan-file value" {
    run bash "$SCRIPT" 3 outfile.md
    [ "$status" -eq 2 ]
    [[ "$output" == *"no such plan file: 3"* ]]
}

@test "task-brief: 0 args -> exit 2 with usage message" {
    run bash "$SCRIPT"
    [ "$status" -eq 2 ]
    [[ "$output" == *"usage: task-brief PLAN_FILE TASK_NUMBER"* ]]
}

@test "task-brief: PLAN_FILE N (valid) writes the brief under the plan-scoped dir" {
    run bash "$SCRIPT" plan.md 1
    [ "$status" -eq 0 ]

    expected="$SANDBOX/.superpowers/sdd/plan/task-1-brief.md"
    [[ "$output" == "wrote ${expected}: "*"lines" ]]
    [ -f "$expected" ]
    [[ "$(cat "$expected")" == *"Task 1"* ]]
    [[ "$(cat "$expected")" == *"Do the first thing."* ]]
    [[ "$(cat "$expected")" != *"Task 2"* ]]
}

@test "task-brief: PLAN_FILE N shares the workspace's .gitignore, not a per-task one" {
    run bash "$SCRIPT" plan.md 2
    [ "$status" -eq 0 ]
    [ -f "$SANDBOX/.superpowers/sdd/.gitignore" ]
    [ "$(cat "$SANDBOX/.superpowers/sdd/.gitignore")" = "*" ]
}
