#!/usr/bin/env bash
# Integration test: verifies skill discovery, deployment, and MCP server
# Run from repo root: bash test/integration-test.sh

set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$SCRIPT_DIR"

PASS=0
FAIL=0

pass() { echo "  ✅ $1"; ((PASS++)); }
fail() { echo "  ❌ $1"; ((FAIL++)); }

echo "=== Integration Tests ==="

# 1. Smoke test
echo ""
echo "--- MCP Smoke Test ---"
output=$(node mcp/smoke-test.js 2>&1)
if echo "$output" | grep -q "All skills passed"; then
    pass "MCP smoke test"
else
    fail "MCP smoke test: $output"
fi

# 2. find-skills discovers skills (cache output for reuse)
echo ""
echo "--- find-skills Discovery ---"
find_output=$(timeout 30 node superpowers-augment.js find-skills 2>&1) || true
skill_count=$(echo "$find_output" | grep -c "^  " || true)
if [[ "$skill_count" -ge 50 ]]; then
    pass "find-skills found $skill_count skills (≥50)"
else
    fail "find-skills found only $skill_count skills (expected ≥50)"
fi

# 3. _shared not listed as a skill (reuse cached output)
echo ""
echo "--- _shared exclusion ---"
shared_hits=$(echo "$find_output" | grep -c "_shared" || true)
if [[ "$shared_hits" -eq 0 ]]; then
    pass "_shared not listed as skill"
else
    fail "_shared appears in find-skills output ($shared_hits times)"
fi

# 4. match-skills returns results
echo ""
echo "--- match-skills ---"
match_output=$(timeout 15 node superpowers-augment.js match-skills "fix a bug" 2>&1) || true
if echo "$match_output" | grep -qi "debug\|systematic"; then
    pass "match-skills routes 'fix a bug' correctly"
else
    fail "match-skills did not route 'fix a bug': $match_output"
fi

# 5. No folded-scalar descriptions in source
echo ""
echo "--- Description format ---"
folded=$(grep -rn "^description: [>|]$" skills/ 2>/dev/null | wc -l | tr -d ' ')
if [[ "$folded" -eq 0 ]]; then
    pass "No folded-scalar descriptions in source"
else
    fail "$folded skills still use folded-scalar description"
fi

# 6. _shared/ exists and has schema files
echo ""
echo "--- _shared schemas ---"
schema_count=$(ls skills/_shared/multi-agent-*-schema.md skills/_shared/incident-packet-schema.md 2>/dev/null | wc -l | tr -d ' ')
if [[ "$schema_count" -ge 4 ]]; then
    pass "$schema_count schema files in _shared/"
else
    fail "Expected ≥4 schema files in _shared/, found $schema_count"
fi

# 7. JS syntax check
echo ""
echo "--- JS syntax ---"
for f in superpowers-augment.js mcp/superpowers-mcp.js lib/skill-router.js lib/frontmatter.js; do
    if node -c "$f" 2>/dev/null; then
        pass "$f syntax OK"
    else
        fail "$f syntax error"
    fi
done

# 8. Shell syntax check
echo ""
echo "--- Shell syntax ---"
for f in install.sh lib/install/deploy.sh lib/install/migrate.sh; do
    if bash -n "$f" 2>/dev/null; then
        pass "$f syntax OK"
    else
        fail "$f syntax error"
    fi
done

# 9. harsh-review passes
echo ""
echo "--- harsh-review ---"
hr_output=$(bash tools/harsh-review.sh 2>&1)
errors=$(echo "$hr_output" | grep -c "\[ERROR\]" || true)
warns=$(echo "$hr_output" | grep -c "\[WARN\]" || true)
if [[ "$errors" -eq 0 && "$warns" -eq 0 ]]; then
    pass "harsh-review: 0 errors, 0 warnings"
else
    fail "harsh-review: $errors errors, $warns warnings"
fi

echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
[[ "$FAIL" -eq 0 ]] && exit 0 || exit 1
