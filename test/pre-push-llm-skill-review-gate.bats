#!/usr/bin/env bats
# Tests for the pre-push Gate 6 (.llm-skill-review-cleared consumer side).
# Extracts the check_llm_skill_review_sentinel function from
# tools/pre-push-llm-skill-review-gate.sh and exercises it across (missing/
# stale/format-violation/non-passing-verdict/md-eligible-skip/clean-pass/
# skills-floor) plus the helper-missing failsafe.
#
# This gate owns skills/*.md, .ai-guidance/*.md, and AGENTS.md-family files
# (AGENTS.md/CLAUDE.md/GEMINI.md/CODEX.md/COPILOT.md/AGENT.md, at any path
# depth) EXCLUSIVELY -- it supersedes, not supplements, both the PHR gate
# (test/pre-push-gate4.bats) and the code-review gate for these file
# classes. Fixtures here use skills/*.md as the primary reviewed file class,
# with dedicated cases below for the other owned classes; a non-owned .md
# change (e.g. docs/*.md) must never trigger this gate at all.

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
NC=$'\033[0m'
EOF

    # Extract just the check_llm_skill_review_sentinel function from its gate script.
    awk '/^check_llm_skill_review_sentinel\(\)/,/^}$/' \
        "$REPO_ROOT_REAL/tools/pre-push-llm-skill-review-gate.sh" > extracted-fn.sh

    # Use the REAL md-files-changed.sh helper -- a divergent stub silently
    # gives false confidence (the PHR-eligible regex must match production
    # exactly, since this gate filters that result down to skills/ paths).
    mkdir -p tools
    cp "$REPO_ROOT_REAL/tools/md-files-changed.sh" tools/md-files-changed.sh
    chmod +x tools/md-files-changed.sh

    cat > harness.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
source ./stub-colors.sh
REPO_ROOT="$PWD"
LLM_SKILL_REVIEW_SENTINEL="$PWD/.llm-skill-review-cleared"
LLM_SKILL_REVIEW_MIN="9.2"
EOF
    cat extracted-fn.sh >> harness.sh
    cat >> harness.sh <<'EOF'

# Args: $1=range $2=pushed_sha [$3=no_base flag passthrough]
check_llm_skill_review_sentinel "$1" "$2" "${3:-}"
EOF
    chmod +x harness.sh

    # Build a 2-commit history so we have a real range to diff against.
    echo "x" > unrelated.txt
    git add unrelated.txt
    git commit -q -m "base"
    BASE_SHA=$(git rev-parse HEAD)

    mkdir -p skills/foo
    echo "# a skill" > skills/foo/skill.md
    git add skills/foo/skill.md
    git commit -q -m "add skill"
    HEAD_SHA=$(git rev-parse HEAD)

    export BASE_SHA HEAD_SHA
}

teardown() {
    rm -rf "$WORK"
}

# --- Helper-missing failsafe ---

@test "gate6: md-files-changed.sh missing -> skip with audible warning" {
    rm -f tools/md-files-changed.sh
    run ./harness.sh "${BASE_SHA}..${HEAD_SHA}" "$HEAD_SHA"
    [ "$status" -eq 0 ]
    [[ "$output" == *"md-files-changed.sh not present"* ]]
}

# --- No skills/*.md files: skip ---

@test "gate6: range has no md files -> skip (return 0)" {
    run ./harness.sh "${HEAD_SHA}..${HEAD_SHA}" "$HEAD_SHA"
    [ "$status" -eq 0 ]
}

@test "gate6: range has only non-md files -> skip (return 0)" {
    echo "non-md change" > nonmd.txt
    git add nonmd.txt
    git commit -q -m "non-md tip"
    TIP_SHA=$(git rev-parse HEAD)
    run ./harness.sh "${HEAD_SHA}..${TIP_SHA}" "$TIP_SHA"
    [ "$status" -eq 0 ]
    [[ "$output" == *"no llm-skill-review-owned files"* ]]
}

@test "gate6: non-skills .md-only push is skipped -- not this gate's concern" {
    # A design doc change alone must never trigger llm-skill-review -- that's
    # the PHR gate's job (test/pre-push-gate4.bats).
    mkdir -p docs
    echo "# a doc" > docs/foo.md
    git add docs/foo.md
    git commit -q -m "add doc"
    DOC_SHA=$(git rev-parse HEAD)
    run ./harness.sh "${HEAD_SHA}..${DOC_SHA}" "$DOC_SHA"
    [ "$status" -eq 0 ]
    [[ "$output" == *"no llm-skill-review-owned files"* ]]
}

@test "gate6: AGENTS.md-only push requires sentinel -- owned exclusively by this gate" {
    echo "# agents" > AGENTS.md
    git add AGENTS.md
    git commit -q -m "add agents"
    AGENTS_SHA=$(git rev-parse HEAD)
    run ./harness.sh "${HEAD_SHA}..${AGENTS_SHA}" "$AGENTS_SHA"
    [ "$status" -eq 1 ]
    [[ "$output" == *"PUSH BLOCKED"* ]]
    [[ "$output" == *"AGENTS.md"* ]]
}

@test "gate6: CLAUDE.md-only push requires sentinel" {
    echo "# claude" > CLAUDE.md
    git add CLAUDE.md
    git commit -q -m "add claude"
    CLAUDE_SHA=$(git rev-parse HEAD)
    run ./harness.sh "${HEAD_SHA}..${CLAUDE_SHA}" "$CLAUDE_SHA"
    [ "$status" -eq 1 ]
    [[ "$output" == *"PUSH BLOCKED"* ]]
    [[ "$output" == *"CLAUDE.md"* ]]
}

@test "gate6: nested guidance/AGENTS.md push requires sentinel" {
    mkdir -p guidance
    echo "# agents" > guidance/AGENTS.md
    git add guidance/AGENTS.md
    git commit -q -m "add nested agents"
    NESTED_SHA=$(git rev-parse HEAD)
    run ./harness.sh "${HEAD_SHA}..${NESTED_SHA}" "$NESTED_SHA"
    [ "$status" -eq 1 ]
    [[ "$output" == *"PUSH BLOCKED"* ]]
    [[ "$output" == *"guidance/AGENTS.md"* ]]
}

@test "gate6: .ai-guidance/*.md push requires sentinel" {
    mkdir -p .ai-guidance
    echo "# invariants" > .ai-guidance/invariants.md
    git add .ai-guidance/invariants.md
    git commit -q -m "add ai-guidance doc"
    AIG_SHA=$(git rev-parse HEAD)
    run ./harness.sh "${HEAD_SHA}..${AIG_SHA}" "$AIG_SHA"
    [ "$status" -eq 1 ]
    [[ "$output" == *"PUSH BLOCKED"* ]]
    [[ "$output" == *".ai-guidance/invariants.md"* ]]
}

@test "gate6: mixed push (AGENTS.md + docs/*.md) requires sentinel only for AGENTS.md" {
    mkdir -p docs
    echo "# a doc" > docs/baz.md
    echo "# agents" > AGENTS.md
    git add docs/baz.md AGENTS.md
    git commit -q -m "mixed doc + agents"
    MIXED_SHA=$(git rev-parse HEAD)
    run ./harness.sh "${HEAD_SHA}..${MIXED_SHA}" "$MIXED_SHA"
    [ "$status" -eq 1 ]
    [[ "$output" == *"PUSH BLOCKED"* ]]
    [[ "$output" == *"AGENTS.md"* ]]
    [[ "$output" != *"docs/baz.md"* ]]
}

@test "gate6: mixed push (skills/*.md + docs/*.md) requires sentinel only for the skill file" {
    mkdir -p docs
    echo "# another doc" > docs/bar.md
    mkdir -p skills/mixed
    echo "# mixed skill" > skills/mixed/skill.md
    git add docs/bar.md skills/mixed/skill.md
    git commit -q -m "mixed doc + skill"
    MIXED_SHA=$(git rev-parse HEAD)
    run ./harness.sh "${HEAD_SHA}..${MIXED_SHA}" "$MIXED_SHA"
    [ "$status" -eq 1 ]
    [[ "$output" == *"PUSH BLOCKED"* ]]
    [[ "$output" == *"skills/mixed/skill.md"* ]]
    [[ "$output" != *"docs/bar.md"* ]]
}

# --- Missing sentinel ---

@test "gate6: skills/*.md in push + no sentinel -> BLOCK (return 1)" {
    run ./harness.sh "${BASE_SHA}..${HEAD_SHA}" "$HEAD_SHA"
    [ "$status" -eq 1 ]
    [[ "$output" == *"PUSH BLOCKED"* ]]
    [[ "$output" == *"sentinel missing"* ]]
    [[ "$output" == *"tools/run-llm-skill-review.sh"* ]]
}

# --- Valid sentinel passes ---

@test "gate6: skills/*.md in push + valid PASS sentinel matching HEAD -> PASS" {
    echo "v1|${HEAD_SHA}|PASS|2026-05-25T00:00:00Z|min-score=9.5" > .llm-skill-review-cleared
    run ./harness.sh "${BASE_SHA}..${HEAD_SHA}" "$HEAD_SHA"
    [ "$status" -eq 0 ]
    [[ "$output" == *"llm-skill-review cleared"* ]]
}

@test "gate6: PASS_WITH_NITS-style verdicts not accepted (only PASS clears)" {
    echo "v1|${HEAD_SHA}|PASS_WITH_RISKS|2026-05-25T00:00:00Z|min-score=9.5" > .llm-skill-review-cleared
    run ./harness.sh "${BASE_SHA}..${HEAD_SHA}" "$HEAD_SHA"
    [ "$status" -eq 1 ]
    [[ "$output" == *"not passing"* ]]
}

@test "gate6: multi-line sentinel (corruption/append) -> BLOCK with format error" {
    {
        echo "v1|${HEAD_SHA}|PASS|2026-05-25T00:00:00Z|min-score=9.5"
        echo "GARBAGE_TRAILING_LINE"
    } > .llm-skill-review-cleared
    run ./harness.sh "${BASE_SHA}..${HEAD_SHA}" "$HEAD_SHA"
    [ "$status" -eq 1 ]
    [[ "$output" == *"format unrecognized"* ]]
}

# --- Stale sentinel (SHA mismatch) ---

@test "gate6: sentinel SHA != pushed SHA -> BLOCK with 'stale'" {
    echo "v1|deadbeef0000000000000000000000000000beef|PASS|2026-05-25T00:00:00Z|min-score=9.5" > .llm-skill-review-cleared
    run ./harness.sh "${BASE_SHA}..${HEAD_SHA}" "$HEAD_SHA"
    [ "$status" -eq 1 ]
    [[ "$output" == *"stale"* ]]
    [[ "$output" == *"Review was for"* ]]
}

# --- Non-passing verdict ---

@test "gate6: REJECT verdict -> BLOCK" {
    echo "v1|${HEAD_SHA}|REJECT|2026-05-25T00:00:00Z|min-score=5.0" > .llm-skill-review-cleared
    run ./harness.sh "${BASE_SHA}..${HEAD_SHA}" "$HEAD_SHA"
    [ "$status" -eq 1 ]
    [[ "$output" == *"not passing"* ]]
}

@test "gate6: MAJOR REVISIONS REQUIRED verdict -> BLOCK" {
    echo "v1|${HEAD_SHA}|MAJOR_REVISIONS_REQUIRED|2026-05-25T00:00:00Z|min-score=5.0" > .llm-skill-review-cleared
    run ./harness.sh "${BASE_SHA}..${HEAD_SHA}" "$HEAD_SHA"
    [ "$status" -eq 1 ]
    [[ "$output" == *"not passing"* ]]
}

# --- Format violations ---

@test "gate6: wrong version prefix (v2) -> BLOCK" {
    echo "v2|${HEAD_SHA}|PASS|2026-05-25T00:00:00Z|min-score=9.5" > .llm-skill-review-cleared
    run ./harness.sh "${BASE_SHA}..${HEAD_SHA}" "$HEAD_SHA"
    [ "$status" -eq 1 ]
    [[ "$output" == *"format unrecognized"* ]]
}

@test "gate6: too few fields -> BLOCK" {
    echo "v1|${HEAD_SHA}|PASS|2026-05-25T00:00:00Z" > .llm-skill-review-cleared
    run ./harness.sh "${BASE_SHA}..${HEAD_SHA}" "$HEAD_SHA"
    [ "$status" -eq 1 ]
    [[ "$output" == *"format unrecognized"* ]]
}

@test "gate6: missing min-score field prefix -> BLOCK" {
    echo "v1|${HEAD_SHA}|PASS|2026-05-25T00:00:00Z|9.5" > .llm-skill-review-cleared
    run ./harness.sh "${BASE_SHA}..${HEAD_SHA}" "$HEAD_SHA"
    [ "$status" -eq 1 ]
    [[ "$output" == *"min-score field malformed"* ]]
}

@test "gate6: empty SHA field -> BLOCK" {
    echo "v1||PASS|2026-05-25T00:00:00Z|min-score=9.5" > .llm-skill-review-cleared
    run ./harness.sh "${BASE_SHA}..${HEAD_SHA}" "$HEAD_SHA"
    [ "$status" -eq 1 ]
    [[ "$output" == *"format unrecognized"* ]]
}

# --- skills/*.md file listing ---

@test "gate6: prints the offending skills/*.md file list before blocking" {
    run ./harness.sh "${BASE_SHA}..${HEAD_SHA}" "$HEAD_SHA"
    [ "$status" -eq 1 ]
    [[ "$output" == *"skills/foo/skill.md"* ]]
}

# --- Single-SHA range (new branch / merge commit / root commit) ---

@test "gate6: single-SHA range on merge commit enumerates files (-m flag)" {
    git checkout -q -b branch_a "$BASE_SHA"
    mkdir -p skills/bar
    echo "# skill bar" > skills/bar/skill.md
    git add skills/bar/skill.md
    git commit -q -m "add skill bar"
    git checkout -q -B test_main "$BASE_SHA"
    git merge -q --no-ff -m "merge branch_a" branch_a
    MERGE_SHA=$(git rev-parse HEAD)
    run ./harness.sh "$MERGE_SHA" "$MERGE_SHA"
    [ "$status" -eq 1 ]
    [[ "$output" == *"skills/bar/skill.md"* ]]
}

@test "gate6: NEW_BRANCH_NO_BASE enumerates full history, catches skill in non-tip commit" {
    git checkout -q --orphan orphan_with_skill
    git rm -qrf . 2>/dev/null || true
    rm -f a.txt
    mkdir -p skills/baz
    echo "# orphan skill" > skills/baz/skill.md
    git add skills/baz/skill.md
    git commit -q -m "orphan: add skill in non-tip commit"
    echo "x" > unrelated.txt
    git add unrelated.txt
    git commit -q -m "orphan: unrelated tip"
    TIP=$(git rev-parse HEAD)
    run ./harness.sh "$TIP" "$TIP"
    [ "$status" -eq 0 ]  # silent skip without no_base flag
    run ./harness.sh "$TIP" "$TIP" "no_base"
    [ "$status" -eq 1 ]
    [[ "$output" == *"skills/baz/skill.md"* ]]
    [[ "$output" == *"PUSH BLOCKED"* ]]
}

@test "gate6: NEW_BRANCH_NO_BASE orphan branch of --allow-empty commits only -> skip, not a false enumeration failure" {
    # Regression guard for the exact bug class fixed in the PHR gate: a
    # pipeline of `git log --name-only ... | grep -v '^$'` exits 1 (via
    # pipefail) when the branch's commits produce zero file lines -- which
    # must NOT be misreported as "could not enumerate" (fail-closed on a
    # git-command failure) when enumeration actually succeeded and just
    # found nothing.
    git checkout -q --orphan orphan_empty_only
    git rm -qrf . 2>/dev/null || true
    git commit -q --allow-empty -m "orphan: allow-empty 1"
    git commit -q --allow-empty -m "orphan: allow-empty 2"
    TIP=$(git rev-parse HEAD)
    run ./harness.sh "$TIP" "$TIP" "no_base"
    [ "$status" -eq 0 ]
    [[ "$output" == *"no files in push range"* ]]
    [[ "$output" != *"enumeration failed"* ]]
}

@test "gate6: single-SHA range on root commit enumerates files (--root flag)" {
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

# --- llm-skill-review skills floor (9.2 minimum) ---

@test "gate6: min-score below 9.2 -> BLOCK with floor message" {
    echo "v1|${HEAD_SHA}|PASS|2026-05-25T00:00:00Z|min-score=8.5" > .llm-skill-review-cleared
    run ./harness.sh "${BASE_SHA}..${HEAD_SHA}" "$HEAD_SHA"
    [ "$status" -eq 1 ]
    [[ "$output" == *"below project minimum"* ]]
    [[ "$output" == *"9.2"* ]]
}

@test "gate6: min-score exactly 9.2 -> PASS" {
    echo "v1|${HEAD_SHA}|PASS|2026-05-25T00:00:00Z|min-score=9.2" > .llm-skill-review-cleared
    run ./harness.sh "${BASE_SHA}..${HEAD_SHA}" "$HEAD_SHA"
    [ "$status" -eq 0 ]
    [[ "$output" == *"llm-skill-review cleared"* ]]
}

@test "gate6: min-score above 9.2 -> PASS" {
    echo "v1|${HEAD_SHA}|PASS|2026-05-25T00:00:00Z|min-score=9.8" > .llm-skill-review-cleared
    run ./harness.sh "${BASE_SHA}..${HEAD_SHA}" "$HEAD_SHA"
    [ "$status" -eq 0 ]
}
