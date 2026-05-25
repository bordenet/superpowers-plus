#!/usr/bin/env bats
# Tests for the pre-push Gate 4 (.phr-cleared consumer side).
# Extracts the check_phr_sentinel function from tools/pre-push and
# exercises it across (missing/stale/format-violation/non-passing-verdict/
# md-eligible-skip/clean-pass) plus the helper-missing failsafe.

setup() {
    REPO_ROOT_REAL="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
    WORK="$(mktemp -d)"
    cd "$WORK"
    git init -q --initial-branch=main
    git config user.email "test@test"
    git config user.name "test"

    # Color codes used by the function under test.
    cat > stub-colors.sh <<'EOF'
RED=$'\033[0;31m'
GREEN=$'\033[0;32m'
YELLOW=$'\033[0;33m'
NC=$'\033[0m'
EOF

    # Extract just the check_phr_sentinel function from pre-push.
    awk '/^check_phr_sentinel\(\)/,/^}$/' \
        "$REPO_ROOT_REAL/tools/pre-push" > extracted-fn.sh

    # Use the REAL md-files-changed.sh helper -- a divergent stub silently
    # gives false confidence (PHR-eligible regex must match production exactly,
    # or Gate 4 fires on paths that won't fire in production / vice versa).
    mkdir -p tools
    cp "$REPO_ROOT_REAL/tools/md-files-changed.sh" tools/md-files-changed.sh
    chmod +x tools/md-files-changed.sh

    cat > harness.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
source ./stub-colors.sh
REPO_ROOT="$PWD"
PHR_SENTINEL="$PWD/.phr-cleared"
EOF
    cat extracted-fn.sh >> harness.sh
    cat >> harness.sh <<'EOF'

# Args: $1=range $2=pushed_sha [$3=no_base flag passthrough]
check_phr_sentinel "$1" "$2" "${3:-}"
EOF
    chmod +x harness.sh

    # Build a 2-commit history so we have a real range to diff against.
    echo "x" > unrelated.txt
    git add unrelated.txt
    git commit -q -m "base"
    BASE_SHA=$(git rev-parse HEAD)

    mkdir -p skills/foo
    echo "# skill" > skills/foo/skill.md
    git add skills/foo/skill.md
    git commit -q -m "add skill"
    HEAD_SHA=$(git rev-parse HEAD)

    export BASE_SHA HEAD_SHA
}

teardown() {
    rm -rf "$WORK"
}

# --- Helper-missing failsafe ---

@test "gate4: md-files-changed.sh missing -> skip with audible warning" {
    rm -f tools/md-files-changed.sh
    run ./harness.sh "${BASE_SHA}..${HEAD_SHA}" "$HEAD_SHA"
    [ "$status" -eq 0 ]
    [[ "$output" == *"md-files-changed.sh not present"* ]]
}

# --- No PHR-eligible files: skip ---

@test "gate4: range has no md files -> skip (return 0)" {
    # diff a..a (empty range) -> no files -> skip
    run ./harness.sh "${HEAD_SHA}..${HEAD_SHA}" "$HEAD_SHA"
    [ "$status" -eq 0 ]
}

@test "gate4: range has only non-md files -> skip (return 0) with observability echo" {
    # Add a 3rd commit that touches ONLY a non-md file. Range HEAD_SHA..tip
    # then contains files (so it bypasses the "no files in range" early return)
    # but those files are not PHR-eligible (so it hits the "no PHR-eligible
    # md files in push" observability branch).
    echo "non-md change" > nonmd.txt
    git add nonmd.txt
    git commit -q -m "non-md tip"
    TIP_SHA=$(git rev-parse HEAD)
    run ./harness.sh "${HEAD_SHA}..${TIP_SHA}" "$TIP_SHA"
    [ "$status" -eq 0 ]
    [[ "$output" == *"no PHR-eligible md files"* ]]
}

# --- Missing sentinel ---

@test "gate4: md files in push + no sentinel -> BLOCK (return 1)" {
    run ./harness.sh "${BASE_SHA}..${HEAD_SHA}" "$HEAD_SHA"
    [ "$status" -eq 1 ]
    [[ "$output" == *"PUSH BLOCKED"* ]]
    [[ "$output" == *"sentinel missing"* ]]
    [[ "$output" == *"tools/run-phr.sh"* ]]
}

# --- Valid sentinel passes ---

@test "gate4: md files in push + valid PASS sentinel matching HEAD -> PASS" {
    echo "v1|${HEAD_SHA}|PASS|2026-05-25T00:00:00Z|min-score=9.5" > .phr-cleared
    run ./harness.sh "${BASE_SHA}..${HEAD_SHA}" "$HEAD_SHA"
    [ "$status" -eq 0 ]
    [[ "$output" == *"PHR cleared"* ]]
}

@test "gate4: PASS_WITH_NITS no longer accepted (verdict whitelist aligned)" {
    echo "v1|${HEAD_SHA}|PASS_WITH_NITS|2026-05-25T00:00:00Z|min-score=9.5" > .phr-cleared
    run ./harness.sh "${BASE_SHA}..${HEAD_SHA}" "$HEAD_SHA"
    [ "$status" -eq 1 ]
    [[ "$output" == *"not passing"* ]]
}

@test "gate4: PASS_WITH_FIXES blocked (another round required, not a pass)" {
    echo "v1|${HEAD_SHA}|PASS_WITH_FIXES|2026-05-25T00:00:00Z|min-score=7.5" > .phr-cleared
    run ./harness.sh "${BASE_SHA}..${HEAD_SHA}" "$HEAD_SHA"
    [ "$status" -eq 1 ]
    [[ "$output" == *"not passing"* ]]
}

@test "gate4: multi-line sentinel (corruption/append) -> BLOCK with format error" {
    {
        echo "v1|${HEAD_SHA}|PASS|2026-05-25T00:00:00Z|min-score=9.5"
        echo "GARBAGE_TRAILING_LINE"
    } > .phr-cleared
    run ./harness.sh "${BASE_SHA}..${HEAD_SHA}" "$HEAD_SHA"
    [ "$status" -eq 1 ]
    [[ "$output" == *"format unrecognized"* ]]
}

# --- Stale sentinel (SHA mismatch) ---

@test "gate4: sentinel SHA != pushed SHA -> BLOCK with 'stale'" {
    echo "v1|deadbeef0000000000000000000000000000beef|PASS|2026-05-25T00:00:00Z|min-score=9.5" > .phr-cleared
    run ./harness.sh "${BASE_SHA}..${HEAD_SHA}" "$HEAD_SHA"
    [ "$status" -eq 1 ]
    [[ "$output" == *"stale"* ]]
    [[ "$output" == *"PHR was for"* ]]
}

# --- Non-passing verdict ---

@test "gate4: REJECT verdict -> BLOCK" {
    echo "v1|${HEAD_SHA}|REJECT|2026-05-25T00:00:00Z|min-score=5.0" > .phr-cleared
    run ./harness.sh "${BASE_SHA}..${HEAD_SHA}" "$HEAD_SHA"
    [ "$status" -eq 1 ]
    [[ "$output" == *"not passing"* ]]
}

@test "gate4: FAIL verdict -> BLOCK" {
    echo "v1|${HEAD_SHA}|FAIL|2026-05-25T00:00:00Z|min-score=5.0" > .phr-cleared
    run ./harness.sh "${BASE_SHA}..${HEAD_SHA}" "$HEAD_SHA"
    [ "$status" -eq 1 ]
    [[ "$output" == *"not passing"* ]]
}

# --- Format violations ---

@test "gate4: wrong version prefix (v2) -> BLOCK" {
    echo "v2|${HEAD_SHA}|PASS|2026-05-25T00:00:00Z|min-score=9.5" > .phr-cleared
    run ./harness.sh "${BASE_SHA}..${HEAD_SHA}" "$HEAD_SHA"
    [ "$status" -eq 1 ]
    [[ "$output" == *"format unrecognized"* ]]
}

@test "gate4: too few fields -> BLOCK" {
    echo "v1|${HEAD_SHA}|PASS|2026-05-25T00:00:00Z" > .phr-cleared
    run ./harness.sh "${BASE_SHA}..${HEAD_SHA}" "$HEAD_SHA"
    [ "$status" -eq 1 ]
    [[ "$output" == *"format unrecognized"* ]]
}

@test "gate4: missing min-score field prefix -> BLOCK" {
    echo "v1|${HEAD_SHA}|PASS|2026-05-25T00:00:00Z|9.5" > .phr-cleared
    run ./harness.sh "${BASE_SHA}..${HEAD_SHA}" "$HEAD_SHA"
    [ "$status" -eq 1 ]
    [[ "$output" == *"min-score field malformed"* ]]
}

@test "gate4: empty SHA field -> BLOCK" {
    echo "v1||PASS|2026-05-25T00:00:00Z|min-score=9.5" > .phr-cleared
    run ./harness.sh "${BASE_SHA}..${HEAD_SHA}" "$HEAD_SHA"
    [ "$status" -eq 1 ]
    [[ "$output" == *"format unrecognized"* ]]
}

# --- PHR-eligible file listing ---

@test "gate4: AGENTS.md change triggers gate" {
    echo "# agents" > AGENTS.md
    git add AGENTS.md
    git commit -q -m "agents"
    NEW_SHA=$(git rev-parse HEAD)
    run ./harness.sh "${HEAD_SHA}..${NEW_SHA}" "$NEW_SHA"
    [ "$status" -eq 1 ]
    [[ "$output" == *"PHR-eligible md files"* ]]
    [[ "$output" == *"AGENTS.md"* ]]
}

@test "gate4: prints the offending md file list before blocking" {
    run ./harness.sh "${BASE_SHA}..${HEAD_SHA}" "$HEAD_SHA"
    [ "$status" -eq 1 ]
    [[ "$output" == *"skills/foo/skill.md"* ]]
}

# --- Single-SHA range (new branch / merge commit / root commit) ---

@test "gate4: single-SHA range on merge commit enumerates files (-m flag)" {
    # Build: base -> branch_a (skill change) -> merge into main
    # Then push the merge as a single-SHA range and assert Gate 4 sees the skill.
    git checkout -q -b branch_a "$BASE_SHA"
    mkdir -p skills/bar
    echo "# skill bar" > skills/bar/skill.md
    git add skills/bar/skill.md
    git commit -q -m "add skill bar"
    git checkout -q -B test_main "$BASE_SHA"
    # Force a real merge commit (not fast-forward) so it has 2 parents
    git merge -q --no-ff -m "merge branch_a" branch_a
    MERGE_SHA=$(git rev-parse HEAD)
    # Single-SHA range (simulating new-branch first push) -- no sentinel exists.
    run ./harness.sh "$MERGE_SHA" "$MERGE_SHA"
    [ "$status" -eq 1 ]
    [[ "$output" == *"PHR-eligible md files"* ]]
    [[ "$output" == *"skills/bar/skill.md"* ]]
}

@test "gate4: NEW_BRANCH_NO_BASE enumerates full history, catches skill in non-tip commit" {
    # Reproduce the Defect Finder finding: orphan branch with skill .md in
    # an EARLIER commit and an unrelated change in the tip. Without the
    # no_base flag, Gate 4 would only inspect the tip and miss the skill.
    git checkout -q --orphan orphan_with_skill
    git rm -qrf . 2>/dev/null || true
    rm -f a.txt
    mkdir -p skills/baz
    echo "# orphan skill" > skills/baz/skill.md
    git add skills/baz/skill.md
    git commit -q -m "orphan: add skill in non-tip commit"
    # Tip commit changes ONLY unrelated.txt -- not PHR-eligible
    echo "x" > unrelated.txt
    git add unrelated.txt
    git commit -q -m "orphan: unrelated tip"
    TIP=$(git rev-parse HEAD)
    # WITHOUT no_base: gate would skip (tip has no PHR-eligible files)
    run ./harness.sh "$TIP" "$TIP"
    [ "$status" -eq 0 ]  # silent skip without no_base flag (the buggy R1 behavior)
    # WITH no_base: gate must enumerate full history and BLOCK on missing sentinel
    run ./harness.sh "$TIP" "$TIP" "no_base"
    [ "$status" -eq 1 ]
    [[ "$output" == *"skills/baz/skill.md"* ]]
    [[ "$output" == *"PUSH BLOCKED"* ]]
}

@test "gate4: single-SHA range on root commit enumerates files (--root flag)" {
    # Build a fresh repo with a single root commit that touches a skill.
    WORK2="$(mktemp -d)"
    cd "$WORK2"
    git init -q --initial-branch=main
    git config user.email "test@test"
    git config user.name "test"
    mkdir -p skills/zzz
    echo "# root skill" > skills/zzz/skill.md
    git add skills/zzz/skill.md
    git commit -q -m "root commit with skill"
    ROOT_SHA=$(git rev-parse HEAD)
    # Bring over the harness + helper
    cp "$WORK/stub-colors.sh" .
    cp "$WORK/extracted-fn.sh" .
    mkdir -p tools
    cp "$REPO_ROOT_REAL/tools/md-files-changed.sh" tools/md-files-changed.sh
    chmod +x tools/md-files-changed.sh
    cp "$WORK/harness.sh" .
    chmod +x harness.sh
    run ./harness.sh "$ROOT_SHA" "$ROOT_SHA"
    [ "$status" -eq 1 ]
    [[ "$output" == *"skills/zzz/skill.md"* ]]
    rm -rf "$WORK2"
    cd "$WORK"
}
