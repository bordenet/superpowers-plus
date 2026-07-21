#!/usr/bin/env bats
# Tests for the pre-push Gate 2 (.code-review-cleared consumer side)'s file
# classification -- _first_code_file() and range_is_docs_only(). Extracts
# both functions from tools/pre-push-code-review-gate.sh and exercises the
# skills/*.md exemption specifically: skills/*.md is owned exclusively by
# the llm-skill-review gate (see test/pre-push-llm-skill-review-gate.bats),
# but any OTHER file under skills/ (scripts, configs) must still count as
# code requiring the cr-battery sentinel.

setup() {
    REPO_ROOT_REAL="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
    WORK="$(mktemp -d)"
    cd "$WORK"
    git init -q --initial-branch=main
    git config user.email "test@test"
    git config user.name "test"

    cat > stub-colors.sh <<'EOF'
RED=$'\033[0;31m'
YELLOW=$'\033[0;33m'
GREEN=$'\033[0;32m'
NC=$'\033[0m'
EOF

    # Extract _first_code_file and range_is_docs_only (range_is_docs_only
    # calls _first_code_file, so both must be present in the harness).
    awk '/^_first_code_file\(\)/,/^}$/' \
        "$REPO_ROOT_REAL/tools/pre-push-code-review-gate.sh" > extracted-fns.sh
    awk '/^range_is_docs_only\(\)/,/^}$/' \
        "$REPO_ROOT_REAL/tools/pre-push-code-review-gate.sh" >> extracted-fns.sh

    cat > harness.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
source ./stub-colors.sh
EOF
    cat extracted-fns.sh >> harness.sh
    cat >> harness.sh <<'EOF'

# Arg: $1=range. Prints "DOCS_ONLY" or "HAS_CODE".
if range_is_docs_only "$1"; then
    echo "DOCS_ONLY"
else
    echo "HAS_CODE"
fi
EOF
    chmod +x harness.sh

    echo "x" > unrelated.txt
    git add unrelated.txt
    git commit -q -m "base"
    BASE_SHA=$(git rev-parse HEAD)
    export BASE_SHA
}

teardown() {
    rm -rf "$WORK"
}

@test "code-review-gate: skills/*.md-only change classifies as DOCS_ONLY" {
    mkdir -p skills/foo
    echo "# a skill" > skills/foo/skill.md
    git add skills/foo/skill.md
    git commit -q -m "add skill"
    HEAD_SHA=$(git rev-parse HEAD)
    run ./harness.sh "${BASE_SHA}..${HEAD_SHA}"
    [ "$status" -eq 0 ]
    [[ "$output" == "DOCS_ONLY" ]]
}

@test "code-review-gate: skills/*.sh (a non-.md file under skills/) still classifies as HAS_CODE" {
    mkdir -p skills/foo
    echo "echo hi" > skills/foo/helper.sh
    git add skills/foo/helper.sh
    git commit -q -m "add skill helper script"
    HEAD_SHA=$(git rev-parse HEAD)
    run ./harness.sh "${BASE_SHA}..${HEAD_SHA}"
    [ "$status" -eq 0 ]
    [[ "$output" == "HAS_CODE" ]]
}

@test "code-review-gate: mixed skills/*.md + skills/*.sh classifies as HAS_CODE (the script still needs review)" {
    mkdir -p skills/foo
    echo "# a skill" > skills/foo/skill.md
    echo "echo hi" > skills/foo/helper.sh
    git add skills/foo/skill.md skills/foo/helper.sh
    git commit -q -m "add skill with helper script"
    HEAD_SHA=$(git rev-parse HEAD)
    run ./harness.sh "${BASE_SHA}..${HEAD_SHA}"
    [ "$status" -eq 0 ]
    [[ "$output" == "HAS_CODE" ]]
}

@test "code-review-gate: non-skills .md change still classifies as DOCS_ONLY (unchanged pre-existing behavior)" {
    echo "# a doc" > README2.md
    git add README2.md
    git commit -q -m "add doc"
    HEAD_SHA=$(git rev-parse HEAD)
    run ./harness.sh "${BASE_SHA}..${HEAD_SHA}"
    [ "$status" -eq 0 ]
    [[ "$output" == "DOCS_ONLY" ]]
}

@test "code-review-gate: a plain code file still classifies as HAS_CODE (unchanged pre-existing behavior)" {
    echo "console.log('hi')" > script.js
    git add script.js
    git commit -q -m "add script"
    HEAD_SHA=$(git rev-parse HEAD)
    run ./harness.sh "${BASE_SHA}..${HEAD_SHA}"
    [ "$status" -eq 0 ]
    [[ "$output" == "HAS_CODE" ]]
}

@test "code-review-gate: AGENTS.md still classifies as HAS_CODE (unchanged pre-existing behavior -- policy file)" {
    echo "# agents" > AGENTS.md
    git add AGENTS.md
    git commit -q -m "add agents"
    HEAD_SHA=$(git rev-parse HEAD)
    run ./harness.sh "${BASE_SHA}..${HEAD_SHA}"
    [ "$status" -eq 0 ]
    [[ "$output" == "HAS_CODE" ]]
}
