#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

PASS=0; FAIL=0
fail() { echo "FAIL: $*" >&2; ((FAIL++)) || true; }
pass() { echo "  ok: $1"; ((PASS++)) || true; }

# Verify consumer is wired to lib/frontmatter.js (import check)
check_consumer_wiring() {
    local label="$1"
    local source_file="$2"
    local pattern="$3"
    if grep -q "$pattern" "$source_file"; then
        pass "$label imports extractFrontmatter from lib/frontmatter.js"
    else
        fail "$label: wiring not found — expected '$pattern' in $source_file"
    fi
}

# Behavioral parser check
# - JS consumers: require lib/frontmatter.js directly (single source of truth)
# - Shell consumers (install-augment-superpowers.sh): VM-slice their inline parser
run_parser_check() {
    local label="$1"
    local source_file="$2"
    local expect_requires_mcp="$3"

    # For install-augment-superpowers.sh: VM-slice the inline parser
    if [[ "$source_file" == *.sh ]]; then
        if PARSER_SOURCE="$source_file" TEST_SKILL="$TEST_SKILL" EXPECT_REQUIRES_MCP="$expect_requires_mcp" node <<'NODE'
const assert = require('assert');
const fs = require('fs');
const vm = require('vm');
const sourcePath = process.env.PARSER_SOURCE;
const testSkill = process.env.TEST_SKILL;
const expectRequiresMcp = process.env.EXPECT_REQUIRES_MCP === 'yes';
const source = fs.readFileSync(sourcePath, 'utf8');
let start = source.indexOf('function extractFrontmatter(filePath) {');
let end = source.indexOf('\nfunction findSkillFile(', start);
if (start === -1 || end === -1) throw new Error(`Could not locate parser block in ${sourcePath}`);
const context = { fs, console }; vm.createContext(context);
vm.runInContext(source.slice(start, end), context);
const meta = context.extractFrontmatter(testSkill);
const triggers = Array.from(meta.triggers || []);
assert.deepStrictEqual(triggers, ['first trigger', 'second trigger']);
if (expectRequiresMcp) {
  const requiresMcp = Array.from(meta.requires_mcp || []);
  assert.deepStrictEqual(requiresMcp, ['linear', 'github-api']);
}
NODE
        then
            pass "$label parses multiline frontmatter"
        else
            fail "$label failed multiline frontmatter smoke test"
        fi
        return
    fi

    # For JS consumers: use lib/frontmatter.js directly (they delegate to it)
    if TEST_SKILL="$TEST_SKILL" EXPECT_REQUIRES_MCP="$expect_requires_mcp" ROOT_DIR="$ROOT_DIR" node <<'NODE'
const assert = require('assert');
const { extractFrontmatter } = require(process.env.ROOT_DIR + '/lib/frontmatter');
const testSkill = process.env.TEST_SKILL;
const expectRequiresMcp = process.env.EXPECT_REQUIRES_MCP === 'yes';

const meta = extractFrontmatter(testSkill);
const triggers = Array.from(meta.triggers || []);
assert.deepStrictEqual(triggers, ['first trigger', 'second trigger']);

if (expectRequiresMcp) {
  const requiresMcp = Array.from(meta.requires_mcp || []);
  assert.deepStrictEqual(requiresMcp, ['linear', 'github-api']);
}
NODE
    then
        pass "$label parses multiline frontmatter"
    else
        fail "$label failed multiline frontmatter smoke test"
    fi
}

# Behavioral malformed-bracket guard check using lib/frontmatter.js directly
run_malformed_bracket_check() {
    local label="$1"
    local source_file="$2"

    # For install-augment-superpowers.sh (still has inline parser): use VM-slice approach
    if [[ "$source_file" == *.sh ]]; then
        if PARSER_SOURCE="$source_file" MALFORMED_SKILL="$MALFORMED_SKILL" node <<'NODE'
const assert = require('assert');
const fs = require('fs');
const vm = require('vm');
const sourcePath = process.env.PARSER_SOURCE;
const testSkill = process.env.MALFORMED_SKILL;
const source = fs.readFileSync(sourcePath, 'utf8');
let start = source.indexOf('function extractFrontmatter(filePath) {');
let end = source.indexOf('\nfunction findSkillFile(', start);
if (start === -1 || end === -1) throw new Error(`Could not locate parser block in ${sourcePath}`);
const context = { fs, console }; vm.createContext(context);
vm.runInContext(source.slice(start, end), context);
const meta = context.extractFrontmatter(testSkill);
assert.strictEqual(meta.description, 'payload correctly parsed', `desc: "${meta.description}"`);
const trigs = Array.from(meta.triggers || []);
assert.deepStrictEqual(trigs, [], `triggers: ${JSON.stringify(trigs)}`);
NODE
        then
            pass "$label malformed-bracket guard preserves subsequent fields (triggerAccum)"
        else
            fail "$label malformed-bracket guard: description was swallowed or triggers non-empty"
        fi
        return
    fi

    # For JS consumers: test behavior via lib/frontmatter.js (single source of truth)
    if MALFORMED_SKILL="$MALFORMED_SKILL" ROOT_DIR="$ROOT_DIR" node <<'NODE'
const assert = require('assert');
const { extractFrontmatter } = require(process.env.ROOT_DIR + '/lib/frontmatter');
const testSkill = process.env.MALFORMED_SKILL;
const meta = extractFrontmatter(testSkill);
// Guarded parser: description placed AFTER unclosed triggers bracket must survive.
assert.strictEqual(meta.description, 'payload correctly parsed', `desc: "${meta.description}"`);
// Triggers must be empty — bracket never closed, accumulation abandoned
const trigs = Array.from(meta.triggers || []);
assert.deepStrictEqual(trigs, [], `triggers: ${JSON.stringify(trigs)}`);
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

# Wiring checks: confirm JS consumers import from lib/frontmatter.js
check_consumer_wiring "superpowers-augment" "$ROOT_DIR/superpowers-augment.js" "require.*lib/frontmatter"
check_consumer_wiring "superpowers-mcp" "$ROOT_DIR/mcp/superpowers-mcp.js" "require.*lib/frontmatter"

# Behavioral parser checks (all JS consumers now delegate to lib/frontmatter.js)
run_parser_check "superpowers-augment" "$ROOT_DIR/superpowers-augment.js" yes
run_parser_check "superpowers-mcp" "$ROOT_DIR/mcp/superpowers-mcp.js" yes
run_parser_check "install-augment-superpowers" "$ROOT_DIR/install-augment-superpowers.sh" yes

# Malformed-bracket guard: description appears AFTER an unclosed triggers bracket.
# Both augment and installer have triggerAccum — using `triggers:` as the malformed field
# makes the test discriminating for both consumers.
# Old parser (no guard): swallows description line into triggerAccum → description empty.
# Guarded parser: abandons accumulation on new YAML key → description preserved.
# Uses no-space form `description:"..."` to prove the guard covers that syntax too
# (the narrower /^\w+:(?:\s|$)/ would NOT detect this; /^\w+:(?:[^/]|$)/ does).
cat > "$MALFORMED_SKILL" <<'EOF'
---
name: malformed-bracket-guard-test
anti_triggers: ["known", "good"]
triggers: ["unclosed
description:"payload correctly parsed"
---
Body.
EOF

run_malformed_bracket_check "superpowers-augment" "$ROOT_DIR/superpowers-augment.js"
run_malformed_bracket_check "install-augment-superpowers" "$ROOT_DIR/install-augment-superpowers.sh"

# antiAccum: malformed anti_triggers bracket; description must survive (via lib/frontmatter.js)
MALFORMED_ANTI_SKILL="$TMP_DIR/malformed-anti-skill.md"
cat > "$MALFORMED_ANTI_SKILL" <<'EOF'
---
name: malformed-anti-guard-test
triggers: ["alpha"]
anti_triggers: ["unclosed
description:"anti-guard payload parsed"
---
Body.
EOF
if MALFORMED_SKILL="$MALFORMED_ANTI_SKILL" ROOT_DIR="$ROOT_DIR" node <<'NODE'
const assert = require('assert');
const { extractFrontmatter } = require(process.env.ROOT_DIR + '/lib/frontmatter');
const meta = extractFrontmatter(process.env.MALFORMED_SKILL);
assert.strictEqual(meta.description, 'anti-guard payload parsed', `desc: "${meta.description}"`);
assert.deepStrictEqual(Array.from(meta.anti_triggers || []), [], `anti: ${JSON.stringify(meta.anti_triggers)}`);
NODE
then pass "lib/frontmatter malformed-bracket guard preserves subsequent fields (antiAccum)"
else fail "lib/frontmatter antiAccum guard: description swallowed or anti_triggers non-empty"; fi

# mcpAccum: malformed requires_mcp bracket; description must survive (via lib/frontmatter.js)
MALFORMED_MCP_AUGMENT="$TMP_DIR/malformed-mcp-augment-skill.md"
cat > "$MALFORMED_MCP_AUGMENT" <<'EOF'
---
name: malformed-mcp-augment-test
triggers: ["alpha"]
requires_mcp: ["unclosed
description:"mcp-augment payload parsed"
---
Body.
EOF
if MALFORMED_SKILL="$MALFORMED_MCP_AUGMENT" ROOT_DIR="$ROOT_DIR" node <<'NODE'
const assert = require('assert');
const { extractFrontmatter } = require(process.env.ROOT_DIR + '/lib/frontmatter');
const meta = extractFrontmatter(process.env.MALFORMED_SKILL);
assert.strictEqual(meta.description, 'mcp-augment payload parsed', `desc: "${meta.description}"`);
assert.deepStrictEqual(Array.from(meta.requires_mcp || []), [], `mcp: ${JSON.stringify(meta.requires_mcp)}`);
NODE
then pass "lib/frontmatter malformed-bracket guard preserves subsequent fields (mcpAccum)"
else fail "lib/frontmatter mcpAccum guard: description swallowed or requires_mcp non-empty"; fi

# Installer mcpAccum path: requires_mcp is the second accumulator unique to the installer.
# Use a malformed requires_mcp bracket to verify the mcpAccum guard.
MALFORMED_MCP_SKILL="$TMP_DIR/malformed-mcp-skill.md"
cat > "$MALFORMED_MCP_SKILL" <<'EOF'
---
name: malformed-mcp-guard-test
triggers: ["alpha"]
requires_mcp: ["unclosed
description:"mcp-guard payload parsed"
---
Body.
EOF

if PARSER_SOURCE="$ROOT_DIR/install-augment-superpowers.sh" MALFORMED_SKILL="$MALFORMED_MCP_SKILL" node <<'NODE'
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
if (start === -1 || end === -1) throw new Error('Could not locate parser block');

const context = { fs, console };
vm.createContext(context);
vm.runInContext(source.slice(start, end), context);

const meta = context.extractFrontmatter(testSkill);
assert.strictEqual(meta.description, 'mcp-guard payload parsed',
  `description should be preserved; got: "${meta.description}"`);
const mcp = Array.from(meta.requires_mcp || []);
assert.deepStrictEqual(mcp, [],
  `requires_mcp should be empty after guard abandonment; got: ${JSON.stringify(mcp)}`);
NODE
then
    pass "install-augment-superpowers malformed-bracket guard preserves subsequent fields (mcpAccum)"
else
    fail "install-augment-superpowers mcpAccum guard: description swallowed or requires_mcp non-empty"
fi

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
