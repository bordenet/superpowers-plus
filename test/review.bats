#!/usr/bin/env bats
# Tests for tools/review.sh
# Exit-code contract: 0=routed, 1=usage error, 2=which-gate.sh extraction
# failure, 3=at least one path matched no gate and was not explicitly exempt

REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
SCRIPT="$REPO_ROOT/tools/review.sh"

@test "--help exits 0 and describes usage" {
    run bash "$SCRIPT" --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"tools/review.sh route"* ]]
}

# ShellRuntimeAuditor (2026-08-28): this session migrated 3 sibling scripts
# (ci-bats-discovery.sh, push-readiness.sh, which-gate.sh) off a hardcoded
# `sed -n 'N,Mp'` --help range onto a self-terminating awk pattern, precisely
# because a hand-maintained line range silently truncates or corrupts --help
# output the next time a comment line is added/removed with no syntax error
# and no test catching it. review.sh was edited in this same diff (its EXIT
# CODES section) but not migrated.
@test "--help prints its complete fail-closed contract without a line-number range" {
    run bash "$SCRIPT" --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"EXIT CODES:"* ]]
    run grep -nE "sed -n '[0-9]+,[0-9]+p'" "$SCRIPT"
    [ "$status" -ne 0 ]
}

@test "no args exits 1" {
    run bash "$SCRIPT"
    [ "$status" -eq 1 ]
}

@test "unknown subcommand exits 1" {
    run bash "$SCRIPT" bogus-subcommand somepath.md
    [ "$status" -eq 1 ]
}

@test "'route' with no paths exits 1" {
    run bash "$SCRIPT" route
    [ "$status" -eq 1 ]
}

@test "routes a skills/**/skill.md to llm-skill-review with correct runner+sentinel" {
    cd "$REPO_ROOT"
    run bash "$SCRIPT" route skills/engineering/progressive-harsh-review/skill.md
    [ "$status" -eq 0 ]
    [[ "$output" == *"SKILL: llm-skill-review"* ]]
    [[ "$output" == *"RUNNER: tools/run-llm-skill-review.sh"* ]]
    [[ "$output" == *"SENTINEL: .llm-skill-review-cleared"* ]]
}

@test "routes a docs/*.md to progressive-harsh-review" {
    cd "$REPO_ROOT"
    run bash "$SCRIPT" route docs/ARCHITECTURE.md
    [ "$status" -eq 0 ]
    [[ "$output" == *"SKILL: progressive-harsh-review"* ]]
    [[ "$output" == *"SENTINEL: .phr-cleared"* ]]
}

@test "routes a tools/*.sh to code-review-battery" {
    cd "$REPO_ROOT"
    run bash "$SCRIPT" route tools/pre-push-loc-gate.sh
    [ "$status" -eq 0 ]
    [[ "$output" == *"SKILL: code-review-battery"* ]]
    [[ "$output" == *"SENTINEL: .code-review-cleared"* ]]
}

@test "routes executable CI bats policy to code-review-battery" {
    cd "$REPO_ROOT"
    run bash "$SCRIPT" route tests/ci-bats-policy.txt
    [ "$status" -eq 0 ]
    [[ "$output" == *"SKILL: code-review-battery"* ]]
    [[ "$output" == *"SENTINEL: .code-review-cleared"* ]]
}

@test "mixed paths produce one block per gate class in stable order" {
    cd "$REPO_ROOT"
    run bash "$SCRIPT" route skills/engineering/progressive-harsh-review/skill.md tools/pre-push-loc-gate.sh docs/ARCHITECTURE.md
    [ "$status" -eq 0 ]
    llm_line=$(echo "$output" | grep -n "SKILL: llm-skill-review" | head -1 | cut -d: -f1)
    phr_line=$(echo "$output" | grep -n "SKILL: progressive-harsh-review" | head -1 | cut -d: -f1)
    cr_line=$(echo "$output" | grep -n "SKILL: code-review-battery" | head -1 | cut -d: -f1)
    [ "$llm_line" -lt "$phr_line" ]
    [ "$phr_line" -lt "$cr_line" ]
}

@test "root README is explicitly exempt instead of reported as an unknown gap" {
    cd "$REPO_ROOT"
    run bash "$SCRIPT" route README.md
    [ "$status" -eq 0 ]
    [[ "$output" == *"EXEMPT:"* ]]
    [[ "$output" == *"README.md"* ]]
}

@test "mixed routed code and explicit README exemption succeeds without hiding either class" {
    cd "$REPO_ROOT"
    run bash "$SCRIPT" route tools/pre-push-loc-gate.sh README.md
    [ "$status" -eq 0 ]
    [[ "$output" == *"SENTINEL: .code-review-cleared"* ]]
    [[ "$output" == *"EXEMPT:"* ]]
    [[ "$output" == *"README.md"* ]]
}

@test "generic prose classified docs-only by Gate 2 is explicitly exempt" {
    cd "$REPO_ROOT"
    run bash "$SCRIPT" route notes.txt
    [ "$status" -eq 0 ]
    [[ "$output" == *"EXEMPT:"* ]]
    [[ "$output" == *"notes.txt"* ]]
}

@test "unreadable which-gate.sh dependency fails closed with exit 2" {
    cd "$REPO_ROOT"
    local_copy="$(mktemp -d)"
    cp -r tools "$local_copy/tools"
    chmod 000 "$local_copy/tools/which-gate.sh"
    run bash "$local_copy/tools/review.sh" route README.md
    [ "$status" -eq 2 ]
    chmod 755 "$local_copy/tools/which-gate.sh"
    rm -rf "$local_copy"
}
