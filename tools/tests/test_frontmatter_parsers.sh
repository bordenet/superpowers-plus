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

run_malformed_bracket_check() {
    local label="$1"
    local source_file="$2"

    if PARSER_SOURCE="$source_file" MALFORMED_SKILL="$MALFORMED_SKILL" node <<'NODE'
const assert = require('assert');
const fs = require('fs');
const vm = require('vm');

const sourcePath = process.env.PARSER_SOURCE;
const testSkill = process.env.MALFORMED_SKILL;
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
// Guarded parser: description placed AFTER unclosed triggers bracket must survive.
// Both augment and installer parse `triggers` via triggerAccum — this is the real
// discriminating field. Old parser swallows description; guarded parser preserves it.
assert.strictEqual(meta.description, 'payload correctly parsed',
  `description should be preserved; got: "${meta.description}"`);
// Triggers must be empty — bracket never closed, accumulation abandoned
const trigs = Array.from(meta.triggers || []);
assert.deepStrictEqual(trigs, [],
  `triggers should be empty after guard abandonment; got: ${JSON.stringify(trigs)}`);
NODE
    then
        pass "$label malformed-bracket guard preserves subsequent fields (triggerAccum)"
    else
        fail "$label malformed-bracket guard: description was swallowed or triggers non-empty"
    fi
}

echo "── Frontmatter Parser Smoke Tests ──"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "${TMP_DIR:?}"' EXIT
TEST_SKILL="$TMP_DIR/skill.md"
MALFORMED_SKILL="$TMP_DIR/malformed-skill.md"

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

# Malformed-bracket guard: description appears AFTER an unclosed triggers bracket.
# Both augment and installer have triggerAccum — using `triggers:` as the malformed field
# makes the test discriminating for both consumers.
# Old parser (no guard): swallows description line into triggerAccum → description empty.
# Guarded parser: abandons accumulation on new YAML key → description preserved.
cat > "$MALFORMED_SKILL" <<'EOF'
---
name: malformed-bracket-guard-test
anti_triggers: ["known", "good"]
triggers: ["unclosed
description: "payload correctly parsed"
---
Body.
EOF

run_malformed_bracket_check "superpowers-augment" "$ROOT_DIR/superpowers-augment.js"
run_malformed_bracket_check "install-augment-superpowers" "$ROOT_DIR/install-augment-superpowers.sh"

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
