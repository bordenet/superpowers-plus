#!/usr/bin/env bats
# Regression test for a real defect: code-review-battery's dispatch cap was
# bumped (6 -> 7) when ShellRuntimeAuditor was added, but the reconciliation
# missed README.md, docs/WORKFLOW.md, and requesting-code-review/skill.md --
# leaving stale counts that directly contradicted the files that WERE fixed.
# This test makes the "up to N" figure mechanically single-sourced instead of
# manually reconciled, per tools/review.sh's own stated philosophy (don't let
# hand-written prose drift out of sync with the thing it describes).
#
# Every per-file test below asserts a non-empty match count BEFORE comparing
# values -- an empty match set (e.g. a rewording that no longer fits the
# regex) must fail loudly, not silently pass via a zero-iteration while loop.

REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
SKILL_MD="$REPO_ROOT/skills/engineering/code-review-battery/skill.md"

canonical_count() {
    grep -oE 'Dispatch(es)? up to [0-9]+' "$SKILL_MD" | head -1 | grep -oE '[0-9]+'
}

# assert_all_match FILE PATTERN...  -- each PATTERN is a separate grep -oiE
# extraction (one per known phrasing); every extracted number across all
# patterns combined must equal the canonical count, and at least one match
# must be found in total.
assert_all_match() {
    local file="$1"; shift
    local n found_any=0 nums pat
    n="$(canonical_count)"
    for pat in "$@"; do
        nums="$(grep -oiE "$pat" "$file" | grep -oE '[0-9]+' || true)"
        [ -z "$nums" ] && continue
        while read -r found; do
            [ -z "$found" ] && continue
            found_any=1
            if [ "$found" -ne "$n" ]; then
                echo "$file has stale count $found, canonical is $n (pattern: $pat)" >&2
                return 1
            fi
        done <<< "$nums"
    done
    if [ "$found_any" -eq 0 ]; then
        echo "no reviewer-count mention matched in $file -- pattern(s) may be stale after a rewording" >&2
        return 1
    fi
    return 0
}

@test "canonical reviewer count is extractable from code-review-battery/skill.md" {
    local n
    n="$(canonical_count)"
    [ -n "$n" ]
    [ "$n" -gt 0 ]
}

@test "README.md's first reviewer-count mention matches the canonical count" {
    # Split into one assert_all_match call per distinct phrasing -- a single
    # call given 2+ genuinely different patterns only requires the UNION to
    # match at least once, so a vanished first mention would go undetected
    # as long as the second still matched. Each phrasing gets its own call.
    assert_all_match "$REPO_ROOT/README.md" \
        'dispatches (up to )?[0-9]+ parallel reviewers'
}

@test "README.md's second reviewer-count mention matches the canonical count" {
    assert_all_match "$REPO_ROOT/README.md" \
        'dispatches (up to )?[0-9]+ specialist reviewers in parallel'
}

@test "docs/WORKFLOW.md's table-row reviewer-count mention matches the canonical count" {
    # Bounded to the gate-chain table row specifically -- a single combined
    # pattern covering both of this file's mentions would let this row go
    # missing undetected as long as the diagram mention (next test) still
    # matched, since assert_all_match only requires the UNION to match once.
    assert_all_match "$REPO_ROOT/docs/WORKFLOW.md" \
        '\| up to [0-9]+ parallel specialist reviewers \|'
}

@test "docs/WORKFLOW.md's gate-diagram reviewer-count mention matches the canonical count" {
    assert_all_match "$REPO_ROOT/docs/WORKFLOW.md" \
        '\(up to [0-9]+ parallel reviewers\)'
}

@test "requesting-code-review/skill.md's reviewer-count mention matches the canonical count" {
    assert_all_match "$REPO_ROOT/skills/engineering/requesting-code-review/skill.md" \
        'dispatches (up to )?[0-9]+ specialist reviewers'
}

@test "docs/SKILLS.md's reviewer-count mention matches the canonical count" {
    assert_all_match "$REPO_ROOT/docs/SKILLS.md" \
        'dispatches (up to )?[0-9]+ parallel specialist reviewers'
}

@test "docs/SKILL_TAXONOMY.md's reviewer-count mention matches the canonical count" {
    assert_all_match "$REPO_ROOT/docs/SKILL_TAXONOMY.md" \
        '\(up to [0-9]+ parallel specialist reviewers\)'
}
