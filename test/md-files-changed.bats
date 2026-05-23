#!/usr/bin/env bats

# Behavioral tests for tools/md-files-changed.sh.
# Covers: regex matching, README/CHANGELOG exclusion, exit codes,
# --files filter mode, --base override, NO_BASE_FOUND on orphan repos.

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
SCRIPT="$REPO_ROOT/tools/md-files-changed.sh"

# ---------------------------------------------------------------------------
# --files mode: pure regex test, no git interaction required
# ---------------------------------------------------------------------------

@test "md-files-changed: skills/*.md is reported" {
    run bash "$SCRIPT" --files "skills/foo/skill.md"
    [ "$status" -eq 0 ]
    [[ "$output" == "skills/foo/skill.md" ]]
}

@test "md-files-changed: docs/*.md is reported" {
    run bash "$SCRIPT" --files "docs/architecture.md"
    [ "$status" -eq 0 ]
    [[ "$output" == "docs/architecture.md" ]]
}

@test "md-files-changed: root AGENTS.md is reported" {
    run bash "$SCRIPT" --files "AGENTS.md"
    [ "$status" -eq 0 ]
    [[ "$output" == "AGENTS.md" ]]
}

@test "md-files-changed: root README.md is EXCLUDED" {
    run bash "$SCRIPT" --files "README.md"
    [ "$status" -eq 1 ]
    [[ -z "$output" ]]
}

@test "md-files-changed: root CHANGELOG.md is EXCLUDED" {
    run bash "$SCRIPT" --files "CHANGELOG.md"
    [ "$status" -eq 1 ]
    [[ -z "$output" ]]
}

@test "md-files-changed: lowercase root *.md is NOT reported" {
    run bash "$SCRIPT" --files "notes.md"
    [ "$status" -eq 1 ]
}

@test "md-files-changed: non-md files are NOT reported" {
    run bash "$SCRIPT" --files $'tools/run-battery.sh\nlib/compress.js'
    [ "$status" -eq 1 ]
}

@test "md-files-changed: mixed list reports only matching paths" {
    local input
    input=$'README.md\nskills/foo/skill.md\nCHANGELOG.md\ndocs/x.md\ntools/y.sh\nAGENTS.md'
    run bash "$SCRIPT" --files "$input"
    [ "$status" -eq 0 ]
    [[ "$output" == *"skills/foo/skill.md"* ]]
    [[ "$output" == *"docs/x.md"* ]]
    [[ "$output" == *"AGENTS.md"* ]]
    [[ "$output" != *"README.md"* ]]
    [[ "$output" != *"CHANGELOG.md"* ]]
    [[ "$output" != *"tools/y.sh"* ]]
}

# ---------------------------------------------------------------------------
# Diff mode (no --files): exercises git interaction in a throwaway repo
# ---------------------------------------------------------------------------

setup() {
    SANDBOX="$BATS_TEST_TMPDIR/repo"
    mkdir -p "$SANDBOX"
    cd "$SANDBOX"
    git init -q -b main >/dev/null
    git config user.email "test@example.com"
    git config user.name "Test"
    echo seed > seed.txt
    git add seed.txt
    git commit -qm "seed"
}

@test "md-files-changed: diff-mode reports a new skill .md" {
    mkdir -p skills/foo
    echo "# foo" > skills/foo/skill.md
    git add skills/foo/skill.md
    git commit -qm "add skill"
    run bash "$SCRIPT" --base HEAD~1
    [ "$status" -eq 0 ]
    [[ "$output" == "skills/foo/skill.md" ]]
}

@test "md-files-changed: diff-mode ignores README changes" {
    echo "# readme" > README.md
    git add README.md
    git commit -qm "add readme"
    run bash "$SCRIPT" --base HEAD~1
    [ "$status" -eq 1 ]
}

@test "md-files-changed: --print-base resolves merge base" {
    echo a > a.txt && git add a.txt && git commit -qm "a"
    run bash "$SCRIPT" --print-base
    [ "$status" -eq 0 ]
    [[ "${#output}" -eq 40 ]]   # SHA-1
}

@test "md-files-changed: returns 2 (NO_BASE_FOUND) on orphan branch" {
    git checkout -q --orphan lonely
    git rm -rfq .
    echo orphan > o.txt && git add o.txt && git commit -qm "orphan root"
    # No main, no master, and no HEAD^ → exit 2.
    run bash "$SCRIPT"
    [ "$status" -eq 2 ]
}

@test "md-files-changed: --print-base on orphan emits NO_BASE_FOUND" {
    git checkout -q --orphan lonely
    git rm -rfq .
    echo orphan > o.txt && git add o.txt && git commit -qm "orphan root"
    run bash "$SCRIPT" --print-base
    [ "$status" -eq 2 ]
    [[ "$output" == "NO_BASE_FOUND" ]]
}

@test "md-files-changed: master fallback is used when main is absent" {
    git branch -m main master
    git checkout -qb work
    mkdir -p docs && echo x > docs/x.md
    git add docs/x.md && git commit -qm "add doc"
    run bash "$SCRIPT"
    [ "$status" -eq 0 ]
    [[ "$output" == "docs/x.md" ]]
}

@test "md-files-changed: rejects unknown flag" {
    run bash "$SCRIPT" --bogus
    [ "$status" -eq 3 ]
}
