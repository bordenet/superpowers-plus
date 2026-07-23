#!/usr/bin/env bats
# Verifies the shell-runtime-auditor persona port: registered in the roster
# doc AND the ported file itself is well-formed, not just present. A
# count-only check would pass even on a truncated/malformed file.

REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
SKILL_MD="$REPO_ROOT/skills/engineering/code-review-battery/skill.md"
REVIEWERS_DIR="$REPO_ROOT/skills/engineering/code-review-battery/reviewers"
PERSONA_FILE="$REVIEWERS_DIR/shell-runtime-auditor.md"

@test "reviewers/ directory file count matches the roster table's row count" {
    # The "up to N" prose figure deliberately excludes BugPath Verifier
    # (mode-exclusive) and Monolith (on-demand-only), so it undercounts the
    # actual file total by design -- count table rows instead, scoped to the
    # Reviewer/Focus/Activate-When table specifically (not the separate
    # signal-driven dispatch table further down, which has its own bolded rows).
    local table_count actual_count
    table_count=$(sed -n '/^| Reviewer | Focus | Activate When |$/,/^$/p' "$SKILL_MD" | grep -cE '^\| \*\*')
    actual_count=$(find "$REVIEWERS_DIR" -maxdepth 1 -name '*.md' -type f | wc -l | tr -d ' ')
    [ "$table_count" -gt 0 ]
    [ "$table_count" -eq "$actual_count" ]
}

@test "shell-runtime-auditor.md is registered in the persona roster table" {
    grep -q 'ShellRuntimeAuditor' "$SKILL_MD"
}

@test "shell-runtime-auditor.md exists and is non-empty" {
    [ -s "$PERSONA_FILE" ]
}

@test "shell-runtime-auditor.md is above a minimum line-count floor (not truncated)" {
    local lines
    lines=$(wc -l < "$PERSONA_FILE" | tr -d ' ')
    [ "$lines" -gt 100 ]
}

@test "shell-runtime-auditor.md follows the shared persona section-heading convention" {
    grep -q '^## Your Role' "$PERSONA_FILE"
}

@test "shell-runtime-auditor.md passes the repo's own IP audit (regression check)" {
    # Delegates to the single source of truth (tools/public-repo-ip-check.sh)
    # rather than hand-copying a pattern list here -- a hand-copied literal
    # here would itself trip the same scanner when THIS test file is scanned.
    run bash -c "cat '$PERSONA_FILE' | '$REPO_ROOT/tools/public-repo-ip-check.sh' --stdin --stdin-label shell-runtime-auditor.md"
    [ "$status" -eq 0 ]
}
