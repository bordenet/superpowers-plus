#!/usr/bin/env bats
# Tests for tools/which-gate.sh
# Exit-code contract (default mode): 0=ran, 1=usage error, 2=extraction/dependency error
# Exit-code contract (--any mode): 0=match, 1=no match, 2=usage/extraction error

REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
SCRIPT="$REPO_ROOT/tools/which-gate.sh"

@test "--help exits 0 and describes exit codes" {
    run bash "$SCRIPT" --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"EXIT CODES"* ]]
}

@test "no args exits 1" {
    run bash "$SCRIPT"
    [ "$status" -eq 1 ]
}

@test "skills/**/skill.md requires llm-skill-review only" {
    cd "$REPO_ROOT"
    run bash "$SCRIPT" skills/engineering/progressive-harsh-review/skill.md
    [ "$status" -eq 0 ]
    [[ "$output" == *"llm-skill-review gate: REQUIRED"* ]]
    [[ "$output" != *"PHR gate: REQUIRED"* ]]
    [[ "$output" != *"cr-battery gate: REQUIRED"* ]]
}

@test "docs/*.md requires PHR only" {
    cd "$REPO_ROOT"
    run bash "$SCRIPT" docs/ARCHITECTURE.md
    [ "$status" -eq 0 ]
    [[ "$output" == *"PHR gate: REQUIRED"* ]]
    [[ "$output" != *"llm-skill-review gate: REQUIRED"* ]]
}

@test "tools/*.sh requires cr-battery only" {
    cd "$REPO_ROOT"
    run bash "$SCRIPT" tools/pre-push-loc-gate.sh
    [ "$status" -eq 0 ]
    [[ "$output" == *"cr-battery gate: REQUIRED"* ]]
    [[ "$output" != *"llm-skill-review gate: REQUIRED"* ]]
    [[ "$output" != *"PHR gate: REQUIRED"* ]]
}

@test "executable CI bats policy requires cr-battery despite its .txt suffix" {
    cd "$REPO_ROOT"
    run bash "$SCRIPT" tests/ci-bats-policy.txt
    [ "$status" -eq 0 ]
    [[ "$output" == *"cr-battery gate: REQUIRED"* ]]
}

@test "root README.md has no gate coverage" {
    cd "$REPO_ROOT"
    run bash "$SCRIPT" README.md
    [ "$status" -eq 0 ]
    [[ "$output" == *"no gate currently covers this file"* ]]
}

@test "--any=explicit-exempt identifies every Gate-2 docs-only path" {
    cd "$REPO_ROOT"
    run bash "$SCRIPT" --any=explicit-exempt README.md
    [ "$status" -eq 0 ]
    run bash "$SCRIPT" --any=explicit-exempt notes.txt
    [ "$status" -eq 0 ]
}

@test "--help prints its complete fail-closed contract without a line-number range" {
    run bash "$SCRIPT" --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"never silently reports"* ]]
    run grep -nE "sed -n '[0-9]+,[0-9]+p'" "$REPO_ROOT/tools/which-gate.sh"
    [ "$status" -ne 0 ]
}

@test "--any=llm-skill-review matches a skills/**/skill.md path" {
    cd "$REPO_ROOT"
    run bash "$SCRIPT" --any=llm-skill-review skills/engineering/progressive-harsh-review/skill.md
    [ "$status" -eq 0 ]
}

@test "--any=cr-battery does not match a skills/**/skill.md path" {
    cd "$REPO_ROOT"
    run bash "$SCRIPT" --any=cr-battery skills/engineering/progressive-harsh-review/skill.md
    [ "$status" -eq 1 ]
}

@test "--any with an invalid gate name exits 2" {
    cd "$REPO_ROOT"
    run bash "$SCRIPT" --any=bogus-gate README.md
    [ "$status" -eq 2 ]
    [[ "$output" == *"invalid"* ]]
}

@test "--any with no paths exits 2" {
    cd "$REPO_ROOT"
    run bash "$SCRIPT" --any=phr
    [ "$status" -eq 2 ]
}

# ---------------------------------------------------------------------------
# Regression: --any=explicit-exempt's docstring says "root metadata path",
# and every existing test above uses a bare root-level filename. The
# implementation's /\.(md|txt|rst)$/ match has no path anchor, so it silently
# exempts ANY .md/.txt/.rst file at ANY depth from every review gate --
# cr-battery, PHR, and llm-skill-review. Before this session, an unmatched
# nested prose/generated file caused review.sh to exit 3 (fail-closed,
# "agent must resolve"); this widens that into a silent pass repo-wide,
# which is a real narrowing of the router's stated safety property, not the
# root-metadata carve-out the function claims to implement.
# ---------------------------------------------------------------------------
@test "--any=explicit-exempt does NOT match a nested prose/generated file" {
    cd "$REPO_ROOT"
    run bash "$SCRIPT" --any=explicit-exempt some/nested/path/notes.txt
    [ "$status" -eq 1 ]
    run bash "$SCRIPT" --any=explicit-exempt test/golden-compression/x.golden.txt
    [ "$status" -eq 1 ]
    run bash "$SCRIPT" --any=explicit-exempt skills/engineering/some-skill/reference.md
    [ "$status" -eq 1 ]
}
