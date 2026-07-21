#!/usr/bin/env bats
# Tests for tools/pre-commit's staged_has_code() -- the opt-in
# (REQUIRE_CODE_REVIEW_SENTINEL=true, default false) commit-time twin of
# tools/pre-push-code-review-gate.sh's _first_code_file(). Both classifiers
# must agree on the llm-skill-review ownership boundary (skills/*.md,
# .ai-guidance/*.md, AGENTS.md-family) or the dormant gate will silently
# diverge from the live one the moment someone flips the env var on.

setup() {
    REPO_ROOT_REAL="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
    WORK="$(mktemp -d)"
    cd "$WORK"
    git init -q --initial-branch=main
    git config user.email "test@test"
    git config user.name "test"
    echo "x" > unrelated.txt
    git add unrelated.txt
    git commit -q -m "base"

    # Extract just staged_has_code() from the real tools/pre-commit.
    awk '/^staged_has_code\(\)/,/^}$/' "$REPO_ROOT_REAL/tools/pre-commit" > extracted-fn.sh

    cat > harness.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
EOF
    cat extracted-fn.sh >> harness.sh
    cat >> harness.sh <<'EOF'

if staged_has_code; then
    echo "HAS_CODE"
else
    echo "DOCS_ONLY"
fi
EOF
    chmod +x harness.sh
}

teardown() {
    rm -rf "$WORK"
}

@test "staged_has_code: AGENTS.md is DOCS_ONLY (owned by llm-skill-review)" {
    echo "# agents" > AGENTS.md
    git add AGENTS.md
    run ./harness.sh
    [ "$status" -eq 0 ]
    [[ "$output" == "DOCS_ONLY" ]]
}

@test "staged_has_code: CLAUDE.md is DOCS_ONLY" {
    echo "# claude" > CLAUDE.md
    git add CLAUDE.md
    run ./harness.sh
    [ "$status" -eq 0 ]
    [[ "$output" == "DOCS_ONLY" ]]
}

@test "staged_has_code: nested guidance/AGENTS.md is DOCS_ONLY" {
    mkdir -p guidance
    echo "# agents" > guidance/AGENTS.md
    git add guidance/AGENTS.md
    run ./harness.sh
    [ "$status" -eq 0 ]
    [[ "$output" == "DOCS_ONLY" ]]
}

@test "staged_has_code: .ai-guidance/*.md is DOCS_ONLY" {
    mkdir -p .ai-guidance
    echo "# invariants" > .ai-guidance/invariants.md
    git add .ai-guidance/invariants.md
    run ./harness.sh
    [ "$status" -eq 0 ]
    [[ "$output" == "DOCS_ONLY" ]]
}

@test "staged_has_code: skills/*.md is DOCS_ONLY" {
    mkdir -p skills/foo
    echo "# a skill" > skills/foo/skill.md
    git add skills/foo/skill.md
    run ./harness.sh
    [ "$status" -eq 0 ]
    [[ "$output" == "DOCS_ONLY" ]]
}

@test "staged_has_code: skills/*.sh (non-.md under skills/) is HAS_CODE" {
    mkdir -p skills/foo
    echo "echo hi" > skills/foo/helper.sh
    git add skills/foo/helper.sh
    run ./harness.sh
    [ "$status" -eq 0 ]
    [[ "$output" == "HAS_CODE" ]]
}

@test "staged_has_code: a plain code file is HAS_CODE" {
    echo "console.log('hi')" > script.js
    git add script.js
    run ./harness.sh
    [ "$status" -eq 0 ]
    [[ "$output" == "HAS_CODE" ]]
}

@test "staged_has_code: a design doc (non-agent uppercase root .md) is DOCS_ONLY" {
    echo "# design" > DESIGN.md
    git add DESIGN.md
    run ./harness.sh
    [ "$status" -eq 0 ]
    [[ "$output" == "DOCS_ONLY" ]]
}

@test "staged_has_code: no staged files is DOCS_ONLY" {
    run ./harness.sh
    [ "$status" -eq 0 ]
    [[ "$output" == "DOCS_ONLY" ]]
}
