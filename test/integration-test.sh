#!/usr/bin/env bash
# Integration test: verifies skill discovery, deployment, and MCP server
# Run from repo root: bash test/integration-test.sh

set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$SCRIPT_DIR" || exit 1

# Semi-hermetic: deploy repo skills to a temp dir, use that as personal skills dir
HERMETIC_DIR=$(mktemp -d)
export PERSONAL_SKILLS_DIR="$HERMETIC_DIR"
HERMETIC_EMPTY=$(mktemp -d)
export SUPERPOWERS_SKILLS_DIR="$HERMETIC_EMPTY"
MCP_BOOTSTRAP_ATTEMPTED=false
MCP_NODE_MODULES_PREEXISTED=false
if [[ -d "$SCRIPT_DIR/mcp/node_modules" ]]; then
    MCP_NODE_MODULES_PREEXISTED=true
fi
cleanup() {
    rm -rf "${HERMETIC_DIR:?}" "${HERMETIC_EMPTY:?}"
    if [[ "$MCP_BOOTSTRAP_ATTEMPTED" == "true" && "$MCP_NODE_MODULES_PREEXISTED" != "true" ]]; then
        rm -rf "$SCRIPT_DIR/mcp/node_modules"
    fi
}
trap cleanup EXIT

# Deploy repo skills to flat layout (mimics install.sh behavior)
for domain_dir in "$SCRIPT_DIR/skills/"*/; do
    [[ ! -d "$domain_dir" ]] && continue
    dname=$(basename "$domain_dir")
    [[ "$dname" == _* ]] && continue
    # Check if domain dir IS a skill
    if [[ -f "$domain_dir/skill.md" ]] || [[ -f "$domain_dir/SKILL.md" ]]; then
        cp -R "$domain_dir" "$HERMETIC_DIR/$dname"
    else
        # Nested: domain/skill/skill.md
        for skill_dir in "$domain_dir"*/; do
            [[ ! -d "$skill_dir" ]] && continue
            sname=$(basename "$skill_dir")
            [[ "$sname" == _* ]] && continue
            if [[ -f "$skill_dir/skill.md" ]] || [[ -f "$skill_dir/SKILL.md" ]]; then
                cp -R "$skill_dir" "$HERMETIC_DIR/$sname"
            fi
        done
    fi
done

PASS=0
FAIL=0

pass() { echo "  ✅ $1"; PASS=$((PASS + 1)); }
fail() { echo "  ❌ $1"; FAIL=$((FAIL + 1)); }

echo "=== Integration Tests (hermetic) ==="

MCP_READY=true
if [[ ! -d "$SCRIPT_DIR/mcp/node_modules/@modelcontextprotocol/sdk" ]]; then
    echo ""
    echo "--- MCP dependency bootstrap ---"
    if [[ -d "$SCRIPT_DIR/mcp/node_modules" ]]; then
        MCP_READY=false
        fail "MCP dependencies missing from existing mcp/node_modules (run 'cd mcp && npm ci')"
    else
        MCP_BOOTSTRAP_ATTEMPTED=true
        if (cd "$SCRIPT_DIR/mcp" && npm ci --silent >/dev/null 2>&1); then
            pass "MCP dependencies installed"
        else
            MCP_READY=false
            fail "MCP dependencies install failed"
        fi
    fi
fi

# 1. Smoke test
echo ""
echo "--- MCP Smoke Test ---"
if [[ "$MCP_READY" == "true" ]]; then
    output=$(node mcp/smoke-test.js 2>&1)
    if echo "$output" | grep -q "All skills passed"; then
        pass "MCP smoke test"
    else
        fail "MCP smoke test: $output"
    fi
else
    fail "MCP smoke test skipped because MCP dependencies are unavailable"
fi

# 2. find-skills discovers skills (cache output for reuse)
echo ""
echo "--- find-skills Discovery ---"
find_output=$(timeout 30 node superpowers-augment.js find-skills 2>&1) || true
# Parse actual skill total from Summary line (e.g., "Summary: N superpowers, M explicit skills, T total")
skill_count=$(echo "$find_output" | grep '^Summary:' | grep -oE '[0-9]+ total' | head -1 | grep -oE '[0-9]+' || echo "0")
if [[ "$skill_count" -ge 50 ]]; then
    pass "find-skills found $skill_count total skills (≥50)"
else
    fail "find-skills found only $skill_count total skills (expected ≥50)"
fi

# 2b. No broken descriptions (folded scalar leak)
broken_desc=$(echo "$find_output" | grep -cE "^\s+>$" || true)
if [[ "$broken_desc" -eq 0 ]]; then
    pass "No broken '>' descriptions in find-skills output"
else
    fail "Found $broken_desc broken '>' descriptions in find-skills output"
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
schema_count=$(find skills/_shared -name "multi-agent-*-schema.md" -o -name "incident-packet-schema.md" 2>/dev/null | wc -l | tr -d ' ')
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

# 9. install-augment-superpowers.sh syntax check
echo ""
echo "--- install-augment syntax ---"
if bash -n install-augment-superpowers.sh 2>/dev/null; then
    pass "install-augment-superpowers.sh syntax OK"
else
    fail "install-augment-superpowers.sh syntax error"
fi

# 10. stripFrontmatter CRLF normalization in all 3 consumers
echo ""
echo "--- stripFrontmatter CRLF parity ---"
for f in superpowers-augment.js mcp/superpowers-mcp.js install-augment-superpowers.sh; do
    if grep -q 'function stripFrontmatter' "$f"; then
        # Extract the first line of the function body — must contain CRLF normalization
        body=$(sed -n '/function stripFrontmatter/,/^}/p' "$f" | head -5)
        if echo "$body" | grep -qF 'replace(/'; then
            pass "stripFrontmatter CRLF: $f"
        else
            fail "stripFrontmatter missing CRLF normalization: $f"

        fi
    fi
done

# 11. harsh-review passes (honor exit code, not grep patterns)
echo ""
echo "--- harsh-review ---"
if bash tools/harsh-review.sh >/dev/null 2>&1; then
    pass "harsh-review: exit 0"
else
    fail "harsh-review: exit non-zero (run 'bash tools/harsh-review.sh' for details)"
fi

# 12. public-repo-ip-check targeted coverage
echo ""
echo "--- public-repo-ip-check ---"
if bash test/public-repo-ip-check.test.sh >/dev/null 2>&1; then
    pass "public-repo-ip-check targeted tests"
else
    fail "public-repo-ip-check targeted tests failed (run 'bash test/public-repo-ip-check.test.sh')"
fi

echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
[[ "$FAIL" -eq 0 ]] && exit 0 || exit 1
