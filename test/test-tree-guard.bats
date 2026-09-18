#!/usr/bin/env bats
# Behavioral tests for tools/test-tree-guard.sh.
#
# The guard is itself a gate, so it needs its own regressions: a guard that
# silently stops detecting pollution is worse than no guard, because the suite
# then reports green while leaking fixtures into the working tree.
#
# Every case runs against a throwaway git repo in "$BATS_TEST_TMPDIR" -- these
# tests must not write into the real tree, which is the very thing they police.

setup() {
    GUARD="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)/tools/test-tree-guard.sh"
    REPO="$BATS_TEST_TMPDIR/repo"
    mkdir -p "$REPO/tools" "$REPO/test" "$REPO/skills"
    cp "$GUARD" "$REPO/tools/test-tree-guard.sh"
    chmod +x "$REPO/tools/test-tree-guard.sh"
    cd "$REPO"
    git init -q .
    git config user.email t@example.com
    git config user.name t
    echo seed > skills/seed.md
    git add -A
    git -c commit.gpgsign=false commit -qm seed
    printf 'skills/declared-fixture.md\n' > test/.test-artifacts
    git add -A
    git -c commit.gpgsign=false commit -qm manifest
}

@test "guard: sweep removes a declared artifact left by a crashed run" {
    echo leaked > "$REPO/skills/declared-fixture.md"
    run "$REPO/tools/test-tree-guard.sh" sweep
    [ "$status" -eq 0 ]
    [ ! -e "$REPO/skills/declared-fixture.md" ]
    [[ "$output" == *"swept leftover artifact"* ]]
}

@test "guard: sweep is silent and succeeds on an already-clean tree" {
    run "$REPO/tools/test-tree-guard.sh" sweep
    [ "$status" -eq 0 ]
    [[ "$output" != *"swept leftover artifact"* ]]
}

@test "guard: verify passes when the suite created nothing" {
    run "$REPO/tools/test-tree-guard.sh" snapshot "$BATS_TEST_TMPDIR/state"
    [ "$status" -eq 0 ]
    run "$REPO/tools/test-tree-guard.sh" verify "$BATS_TEST_TMPDIR/state"
    [ "$status" -eq 0 ]
}

@test "guard: verify FAILS and names an undeclared file created during the run" {
    "$REPO/tools/test-tree-guard.sh" snapshot "$BATS_TEST_TMPDIR/state"
    echo junk > "$REPO/skills/undeclared-junk.md"
    run "$REPO/tools/test-tree-guard.sh" verify "$BATS_TEST_TMPDIR/state"
    [ "$status" -eq 1 ]
    [[ "$output" == *"UNDECLARED test pollution"* ]]
    [[ "$output" == *"skills/undeclared-junk.md"* ]]
}

@test "guard: verify FAILS on an undeclared MODIFICATION to a tracked file" {
    "$REPO/tools/test-tree-guard.sh" snapshot "$BATS_TEST_TMPDIR/state"
    echo mutated >> "$REPO/skills/seed.md"
    run "$REPO/tools/test-tree-guard.sh" verify "$BATS_TEST_TMPDIR/state"
    [ "$status" -eq 1 ]
    [[ "$output" == *"skills/seed.md"* ]]
}

@test "guard: a DECLARED artifact left behind is reported but does not fail" {
    "$REPO/tools/test-tree-guard.sh" snapshot "$BATS_TEST_TMPDIR/state"
    echo leaked > "$REPO/skills/declared-fixture.md"
    run "$REPO/tools/test-tree-guard.sh" verify "$BATS_TEST_TMPDIR/state"
    [ "$status" -eq 0 ]
    [[ "$output" == *"declared artifact still present"* ]]
}

@test "guard: pre-existing dirt is baselined, not blamed on the suite" {
    echo preexisting > "$REPO/skills/already-dirty.md"
    "$REPO/tools/test-tree-guard.sh" snapshot "$BATS_TEST_TMPDIR/state"
    run "$REPO/tools/test-tree-guard.sh" verify "$BATS_TEST_TMPDIR/state"
    [ "$status" -eq 0 ]
}

# --- containment regressions -------------------------------------------
# sweep runs `rm -rf` on every test-all.sh invocation, including the pre-push
# gate. A `../x` manifest line was confirmed to escape the repo and delete
# files in $HOME. These pin every escape route shut.

@test "guard: sweep REFUSES a parent-traversal pattern and deletes nothing outside" {
    mkdir -p "$BATS_TEST_TMPDIR/outside"
    echo precious > "$BATS_TEST_TMPDIR/outside/victim.txt"
    printf '../outside/*\n' > "$REPO/test/.test-artifacts"
    run "$REPO/tools/test-tree-guard.sh" sweep
    [ "$status" -eq 1 ]
    [[ "$output" == *"REFUSED parent-traversal"* ]]
    [ -f "$BATS_TEST_TMPDIR/outside/victim.txt" ]
}

@test "guard: sweep REFUSES an absolute pattern" {
    printf '/etc/*\n' > "$REPO/test/.test-artifacts"
    run "$REPO/tools/test-tree-guard.sh" sweep
    [ "$status" -eq 1 ]
    [[ "$output" == *"REFUSED absolute pattern"* ]]
    [ -f /etc/hosts ]
}

@test "guard: sweep REFUSES a tilde pattern" {
    printf '~/*\n' > "$REPO/test/.test-artifacts"
    run "$REPO/tools/test-tree-guard.sh" sweep
    [ "$status" -eq 1 ]
    [[ "$output" == *"REFUSED absolute pattern"* ]]
}

@test "guard: sweep unlinks an in-repo symlink instead of deleting its target" {
    mkdir -p "$BATS_TEST_TMPDIR/target"
    echo keepme > "$BATS_TEST_TMPDIR/target/outside.txt"
    ln -s "$BATS_TEST_TMPDIR/target" "$REPO/skills/linkdir"
    printf 'skills/linkdir\n' > "$REPO/test/.test-artifacts"
    run "$REPO/tools/test-tree-guard.sh" sweep
    [ "$status" -eq 0 ]
    [ ! -L "$REPO/skills/linkdir" ]
    # The link is gone; what it pointed at must be untouched.
    [ -f "$BATS_TEST_TMPDIR/target/outside.txt" ]
}

@test "guard: a declared artifact inside a NEW untracked directory is not misreported" {
    # git status collapses an untracked tree to the directory unless
    # --untracked-files=all is passed, which made a DECLARED artifact in a new
    # directory report as UNDECLARED pollution and fail the run.
    printf 'skills/brandnew/fixture.md\n' > "$REPO/test/.test-artifacts"
    "$REPO/tools/test-tree-guard.sh" snapshot "$BATS_TEST_TMPDIR/state"
    mkdir -p "$REPO/skills/brandnew"
    echo fixture > "$REPO/skills/brandnew/fixture.md"
    run "$REPO/tools/test-tree-guard.sh" verify "$BATS_TEST_TMPDIR/state"
    [ "$status" -eq 0 ]
    [[ "$output" == *"declared artifact still present"* ]]
    [[ "$output" != *"UNDECLARED"* ]]
}

@test "guard: verify refuses to pass when the snapshot is missing" {
    run "$REPO/tools/test-tree-guard.sh" verify "$BATS_TEST_TMPDIR/absent-state"
    [ "$status" -eq 1 ]
    [[ "$output" == *"missing snapshot"* ]]
}

@test "guard: sweep REFUSES a bare * that would wipe the working tree" {
    # `*` is inside the repo, so the traversal and absolute checks both pass it.
    # It matched every top-level entry and rm -rf'd the working tree, reporting
    # "tree healed" with exit 0, on every test-all.sh run including pre-push.
    echo keep > "$REPO/toplevel.txt"
    printf '*\n' > "$REPO/test/.test-artifacts"
    run "$REPO/tools/test-tree-guard.sh" sweep
    [ "$status" -eq 1 ]
    [[ "$output" == *"glob in its first path component"* ]]
    [ -f "$REPO/toplevel.txt" ]
    [ -d "$REPO/skills" ]
    [ -d "$REPO/tools" ]
}

@test "guard: sweep REFUSES ** but still allows a scoped glob" {
    printf '**\n' > "$REPO/test/.test-artifacts"
    run "$REPO/tools/test-tree-guard.sh" sweep
    [ "$status" -eq 1 ]
    [ -d "$REPO/skills" ]
    # A legitimate declaration names its directory and must keep working.
    mkdir -p "$REPO/skills/sub"
    echo leak > "$REPO/skills/sub/leak.md"
    printf 'skills/*/leak.md\n' > "$REPO/test/.test-artifacts"
    run "$REPO/tools/test-tree-guard.sh" sweep
    [ "$status" -eq 0 ]
    [ ! -e "$REPO/skills/sub/leak.md" ]
}
