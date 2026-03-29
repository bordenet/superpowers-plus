#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

PASS=0; FAIL=0
fail() { echo "FAIL: $*" >&2; ((FAIL++)) || true; }
pass() { echo "  ok: $1"; ((PASS++)) || true; }

run_parser_check() {
    local label="$1"
    local source_file="$2"
    local expect_requires_mcp="$3"

    if PARSER_SOURCE="$source_file" TEST_SKILL="$TEST_SKILL" EXPECT_REQUIRES_MCP="$expect_requires_mcp" node <<'NODE'
const assert = require('assert');
const fs = require('fs');
const vm = require('vm');

const sourcePath = process.env.PARSER_SOURCE;
const testSkill = process.env.TEST_SKILL;
const expectRequiresMcp = process.env.EXPECT_REQUIRES_MCP === 'yes';
const source = fs.readFileSync(sourcePath, 'utf8');

let start = source.indexOf('function parseInlineArray(value) {');
let end = source.indexOf('\nfunction compressSkillContent(', start);
if (start === -1 || end === -1) {
  start = source.indexOf('function extractFrontmatter(filePath) {');
  end = source.indexOf('\nfunction findSkillFile(', start);
}
if (start === -1 || end === -1) {
  throw new Error(`Could not locate parser block in ${sourcePath}`);
}

const context = { fs, console };
vm.createContext(context);
vm.runInContext(source.slice(start, end), context);

const meta = context.extractFrontmatter(testSkill);
const triggers = Array.from(meta.triggers || []);
assert.deepStrictEqual(triggers, ['first trigger', 'second trigger']);

if (expectRequiresMcp) {
  const requiresMcp = Array.from(meta.requires_mcp || []);
  assert.deepStrictEqual(requiresMcp, ['linear', 'github-api']);
} else {
  assert.ok(!('requires_mcp' in meta));
}
NODE
    then
        pass "$label parses multiline frontmatter"
    else
        fail "$label failed multiline frontmatter smoke test"
    fi
}

echo "── Frontmatter Parser Smoke Tests ──"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "${TMP_DIR:?}"' EXIT
TEST_SKILL="$TMP_DIR/skill.md"

cat > "$TEST_SKILL" <<'EOF'
---
name: parser-smoke
description: Parser smoke test
triggers:
  - "first trigger"
  - 'second trigger'
requires_mcp:
  - linear
  - github-api
---

Body.
EOF

run_parser_check "superpowers-augment" "$ROOT_DIR/superpowers-augment.js" yes
run_parser_check "superpowers-mcp" "$ROOT_DIR/mcp/superpowers-mcp.js" no
run_parser_check "install-augment-superpowers" "$ROOT_DIR/install-augment-superpowers.sh" yes

# --- stripFrontmatter production parity ---
echo ""
echo "── stripFrontmatter CRLF Parity ──"

run_strip_check() {
    local label="$1"
    local source_file="$2"

    if PARSER_SOURCE="$source_file" node <<'STRIP_NODE'
const assert = require('assert');
const fs = require('fs');
const vm = require('vm');

const source = fs.readFileSync(process.env.PARSER_SOURCE, 'utf8');

// Extract stripFrontmatter + its dependencies
let start = source.indexOf('function stripFrontmatter(');
if (start === -1) throw new Error('stripFrontmatter not found');
// Find the closing brace of the function
let depth = 0, end = start;
for (let i = start; i < source.length; i++) {
    if (source[i] === '{') depth++;
    if (source[i] === '}') { depth--; if (depth === 0) { end = i + 1; break; } }
}

const context = { console };
require('vm').createContext(context);
require('vm').runInContext(source.slice(start, end), context);

// CRLF
assert.strictEqual(context.stripFrontmatter("---\r\nname: x\r\n---\r\nBody\r\nLine2"), "Body\nLine2", "CRLF failed");
// CR-only
assert.strictEqual(context.stripFrontmatter("---\rname: x\r---\rBody\rLine2"), "Body\nLine2", "CR-only failed");
// Mixed
assert.strictEqual(context.stripFrontmatter("---\r\nname: x\n---\rBody\nLine2"), "Body\nLine2", "Mixed failed");
// No frontmatter
assert.strictEqual(context.stripFrontmatter("Just body"), "Just body", "No frontmatter failed");
// No trailing newline
assert.strictEqual(context.stripFrontmatter("---\nname: x\n---\nBody"), "Body", "No trailing NL failed");
STRIP_NODE
    then
        pass "$label stripFrontmatter CRLF parity"
    else
        fail "$label stripFrontmatter CRLF parity"
    fi
}

run_strip_check "superpowers-augment" "$ROOT_DIR/superpowers-augment.js"
run_strip_check "superpowers-mcp" "$ROOT_DIR/mcp/superpowers-mcp.js"
run_strip_check "install-augment-superpowers" "$ROOT_DIR/install-augment-superpowers.sh"

if [[ "$(bash "$ROOT_DIR/tools/parse-frontmatter.sh" "$TEST_SKILL" triggers | paste -sd'|' -)" == "first trigger|second trigger" ]]; then
    pass "parse-frontmatter.sh parses multiline triggers"
else
    fail "parse-frontmatter.sh failed multiline trigger extraction"
fi

validator_output="$(bash "$ROOT_DIR/tools/skill-trigger-validator.sh" registry)"
if grep -q 'execute wiki instructions' <<< "$validator_output"; then
    pass "skill-trigger-validator.sh sees multiline trigger skills"
else
    fail "skill-trigger-validator.sh missed multiline trigger skills"
fi

echo ""
echo "── Results: $PASS passed, $FAIL failed ──"
[[ $FAIL -eq 0 ]]
