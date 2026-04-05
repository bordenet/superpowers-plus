#!/usr/bin/env node
/**
 * Unit tests for lib/frontmatter.js — the reference parser.
 * Run: node test/frontmatter.test.js
 */

'use strict';

const { parseFrontmatter, parseInlineArray, unquoteYaml, findSkillFile, validateFrontmatter, extractFrontmatter, stripFrontmatter } = require('../lib/frontmatter');
const fs = require('fs');
const path = require('path');

let pass = 0;
let fail = 0;

function assert(condition, msg) {
    if (condition) { pass++; console.log(`  ✅ ${msg}`); }
    else { fail++; console.log(`  ❌ ${msg}`); }
}
function eq(a, b, msg) { assert(a === b, `${msg} (got: ${JSON.stringify(a)}, want: ${JSON.stringify(b)})`); }
function arrEq(a, b, msg) { assert(JSON.stringify(a) === JSON.stringify(b), `${msg} (got: ${JSON.stringify(a)}, want: ${JSON.stringify(b)})`); }

// --- parseInlineArray ---
console.log('\n--- parseInlineArray ---');
arrEq(parseInlineArray('["a", "b", "c"]'), ['a', 'b', 'c'], 'simple quoted array');
arrEq(parseInlineArray("['a', 'b']"), ['a', 'b'], 'single-quoted array');
arrEq(parseInlineArray('["a\\"b", "c"]'), ['a"b', 'c'], 'escaped quotes in array');
arrEq(parseInlineArray('[]'), [], 'empty array');
arrEq(parseInlineArray('[unquoted, values]'), ['unquoted', 'values'], 'unquoted values');
arrEq(parseInlineArray('["a\\\\b"]'), ['a\\b'], 'escaped backslash in array');

// --- unquoteYaml ---
console.log('\n--- unquoteYaml ---');
eq(unquoteYaml('"hello"'), 'hello', 'simple double-quoted');
eq(unquoteYaml("'hello'"), 'hello', 'simple single-quoted');
eq(unquoteYaml('plain text'), 'plain text', 'unquoted');
eq(unquoteYaml('"User says \\"build X\\""'), 'User says "build X"', 'escaped double-quotes');
eq(unquoteYaml('"path\\\\to\\\\file"'), 'path\\to\\file', 'escaped backslashes');
eq(unquoteYaml(''), '', 'empty string');
eq(unquoteYaml('"  spaced  "'), '  spaced  ', 'preserves internal spaces');

// --- parseFrontmatter: basic ---
console.log('\n--- parseFrontmatter: basic ---');
const basicSkill = `---
name: my-skill
description: "A simple skill"
triggers: ["a", "b", "c"]
anti_triggers: ["x", "y"]
---
# Body`;
const basic = parseFrontmatter(basicSkill);
eq(basic.name, 'my-skill', 'name parsed');
eq(basic.description, 'A simple skill', 'description parsed');
arrEq(basic.triggers, ['a', 'b', 'c'], 'inline triggers parsed');
arrEq(basic.anti_triggers, ['x', 'y'], 'inline anti_triggers parsed');

// --- parseFrontmatter: escaped quotes in description ---
console.log('\n--- parseFrontmatter: escaped quotes ---');
const quotedSkill = `---
name: tricky
description: "User says \\"build X\\" and we comply"
---
# Body`;
const quoted = parseFrontmatter(quotedSkill);
eq(quoted.description, 'User says "build X" and we comply', 'escaped quotes in description');

// --- parseFrontmatter: multiline triggers ---
console.log('\n--- parseFrontmatter: multiline ---');
const multilineSkill = `---
name: multi
description: "Multi skill"
triggers:
  - "alpha"
  - "beta"
  - gamma
anti_triggers:
  - no-this
---
# Body`;
const multi = parseFrontmatter(multilineSkill);
arrEq(multi.triggers, ['alpha', 'beta', 'gamma'], 'multiline triggers parsed');
arrEq(multi.anti_triggers, ['no-this'], 'multiline anti_triggers parsed');

// --- parseFrontmatter: unquoted description ---
console.log('\n--- parseFrontmatter: unquoted ---');
const unquotedSkill = `---
name: bare
description: A bare description without quotes
---
# Body`;
const unquoted = parseFrontmatter(unquotedSkill);
eq(unquoted.description, 'A bare description without quotes', 'unquoted description');

// --- parseFrontmatter: compress flag ---
console.log('\n--- parseFrontmatter: compress ---');
const noCompressSkill = `---
name: nocomp
description: "No compress"
compress: false
---
# Body`;
const nocomp = parseFrontmatter(noCompressSkill);
assert(nocomp.compress === false, 'compress: false parsed');
assert(parseFrontmatter('---\nname: x\n---\n').compress === true, 'compress defaults true');

// --- parseFrontmatter: CRLF line endings ---
console.log('\n--- parseFrontmatter: CRLF ---');
const crlfSkill = "---\r\nname: crlf-skill\r\ndescription: \"CRLF test\"\r\ntriggers: [\"a\", \"b\"]\r\n---\r\n# Body\r\n";
const crlf = parseFrontmatter(crlfSkill);
eq(crlf.name, 'crlf-skill', 'CRLF: name parsed');
eq(crlf.description, 'CRLF test', 'CRLF: description parsed');
arrEq(crlf.triggers, ['a', 'b'], 'CRLF: triggers parsed');

// --- parseFrontmatter: no frontmatter ---
console.log('\n--- parseFrontmatter: no frontmatter ---');
const noFM = parseFrontmatter('# Just a heading\nNo frontmatter here.');
eq(noFM.name, '', 'no frontmatter returns empty name');

// --- parseFrontmatter: malformed bracket (unclosed [) ---
console.log('\n--- parseFrontmatter: malformed bracket ---');
// lib/frontmatter.js uses regex-based matching (/^field:\s*(\[.+\])\s*$/) so an
// unclosed bracket simply does not match and the field is silently left empty.
// This is safe: no later fields are swallowed (unlike accumulator-based parsers
// without a top-level-key guard).
const malformedBracket = `---
name: malformed
anti_triggers: ["a", "b"
description: "should still be parsed"
---
# Body`;
const malformed = parseFrontmatter(malformedBracket);
arrEq(malformed.anti_triggers, [], 'malformed unclosed bracket → empty anti_triggers (safe fallback)');
eq(malformed.description, 'should still be parsed', 'field after malformed bracket still parsed correctly');

// --- parseFrontmatter: bracket-multiline ---
console.log('\n--- parseFrontmatter: bracket-multiline ---');
// lib/frontmatter.js uses accumulator-based parsing for bracket-multiline arrays.
// Opening [ on one line, closing ] on another — fully supported.
const bracketMultiline = `---
name: bmulti
anti_triggers: ["first",
  "second"]
---
# Body`;
const bmulti = parseFrontmatter(bracketMultiline);
arrEq(bmulti.anti_triggers, ['first', 'second'], 'bracket-multiline array parsed correctly');

// --- findSkillFile ---
console.log('\n--- findSkillFile ---');
const testDir = path.join(__dirname, '..', 'skills', 'productivity', 'superpowers-help');
const found = findSkillFile(testDir);
assert(found !== null, 'findSkillFile finds skill.md in known dir');
assert(found.endsWith('skill.md') || found.endsWith('SKILL.md'), 'findSkillFile returns correct filename');
assert(findSkillFile('/nonexistent/path') === null, 'findSkillFile returns null for missing dir');

// --- Real skill files ---
console.log('\n--- Real skill parsing ---');
const skillsDir = path.join(__dirname, '..', 'skills');
let realCount = 0;
let emptyDesc = 0;
function walkDir(dir) {
    for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
        if (entry.name.startsWith('_') || entry.name.startsWith('.')) continue;
        const full = path.join(dir, entry.name);
        if (entry.isDirectory()) {
            const sf = findSkillFile(full);
            if (sf) {
                const content = fs.readFileSync(sf, 'utf-8');
                const parsed = parseFrontmatter(content);
                realCount++;
                if (!parsed.description || parsed.description === '>') emptyDesc++;
            }
            walkDir(full);
        }
    }
}
walkDir(skillsDir);
assert(realCount >= 50, `Parsed ${realCount} real skills (≥50)`);
eq(emptyDesc, 0, `No empty/broken descriptions in ${realCount} skills`);

// --- stripFrontmatter parity (using production export from lib/frontmatter.js) ---
console.log('\n--- stripFrontmatter CRLF parity ---');
// CRLF
eq(stripFrontmatter("---\r\nname: x\r\n---\r\nBody\r\nLine2"), 'Body\nLine2', 'stripFrontmatter: CRLF');
// CR-only
eq(stripFrontmatter("---\rname: x\r---\rBody\rLine2"), 'Body\nLine2', 'stripFrontmatter: CR-only');
// Mixed endings
eq(stripFrontmatter("---\r\nname: x\n---\rBody\nLine2"), 'Body\nLine2', 'stripFrontmatter: mixed');
// No frontmatter
eq(stripFrontmatter("Just body text"), 'Just body text', 'stripFrontmatter: no frontmatter');
// No trailing newline
eq(stripFrontmatter("---\nname: x\n---\nBody"), 'Body', 'stripFrontmatter: no trailing newline');
// Body contains --- horizontal rule (regression: was silently dropped)
eq(stripFrontmatter("---\nname: x\n---\nBefore\n---\nAfter"), 'Before\n---\nAfter', 'stripFrontmatter: body --- preserved');

// --- Error path tests ---
console.log('\n-- Error paths --');

// extractFrontmatter with nonexistent file returns defaults
const efResult = extractFrontmatter('/nonexistent/skill.md');
eq(efResult.name, '', 'extractFrontmatter: nonexistent file returns empty name');
assert(Array.isArray(efResult.triggers) && efResult.triggers.length === 0,
    'extractFrontmatter: nonexistent file returns empty triggers array');

// Empty frontmatter block
const emptyFm = parseFrontmatter('');
eq(emptyFm.name, '', 'parseFrontmatter: empty string returns empty name');

// Malformed YAML (missing closing ---) — parser is lenient, still extracts fields
const malformedResult = parseFrontmatter('---\nname: test\nno closing fence');
eq(malformedResult.name, 'test', 'parseFrontmatter: lenient — extracts name without closing ---');

// Completely empty file returns defaults
const emptyFile = parseFrontmatter('\n\n\n');
eq(emptyFile.name, '', 'parseFrontmatter: whitespace-only returns empty name');
assert(Array.isArray(emptyFile.triggers), 'parseFrontmatter: whitespace-only returns triggers array');

// extractFrontmatter with file containing no frontmatter
const os = require('os');
const tmpNoFm = path.join(os.tmpdir(), 'no-fm-test.md');
fs.writeFileSync(tmpNoFm, '# Just a header\nSome content\n');
const noFmResult = extractFrontmatter(tmpNoFm);
eq(noFmResult.name, '', 'extractFrontmatter: file without frontmatter returns empty name');
fs.unlinkSync(tmpNoFm);

// Composition multiline YAML list parsing
const tmpComp = path.join(os.tmpdir(), 'comp-test.md');
fs.writeFileSync(tmpComp, '---\nname: comp-test\ncomposition:\n  produces:\n    - artifact-a\n    - artifact-b\n  consumes:\n    - input-x\n  priority: 10\n  optional: true\n---\n');
const compResult = extractFrontmatter(tmpComp);
assert(compResult.composition !== null, 'composition: parsed from multiline YAML');
assert(Array.isArray(compResult.composition.produces), 'composition: produces is array');
eq(compResult.composition.produces.length, 2, 'composition: 2 produces');
eq(compResult.composition.produces[0], 'artifact-a', 'composition: first produce');
eq(compResult.composition.consumes[0], 'input-x', 'composition: first consume');
eq(compResult.composition.priority, 10, 'composition: priority parsed as number');
eq(compResult.composition.optional, true, 'composition: optional parsed as boolean');
fs.unlinkSync(tmpComp);

// --- Coordination block parsing ---
console.log('\n--- parseFrontmatter: coordination ---');
const coordSkill = `---
name: domain-build
source: superpowers-overlay
summary: "Use when: building skills from a completed domain-design output."
overrides: superpowers-plus/update-superpowers
coordination:
  group: overlay
  order: 1
  requires: []
  enables:
    - linear-comment-debunker
  escalates_to: []
  internal: false
---
# Body`;
const coord = parseFrontmatter(coordSkill);
eq(coord.source, 'superpowers-overlay', 'source: parsed');
eq(coord.summary, 'Use when: building skills from a completed domain-design output.', 'summary: parsed');
eq(coord.overrides, 'superpowers-plus/update-superpowers', 'overrides: parsed');
assert(coord.coordination !== null, 'coordination: parsed');
eq(coord.coordination.group, 'overlay', 'coordination: group parsed as string');
eq(coord.coordination.order, 1, 'coordination: order parsed as integer');
assert(Array.isArray(coord.coordination.requires), 'coordination: requires is array');
eq(coord.coordination.requires.length, 0, 'coordination: empty inline array');
arrEq(coord.coordination.enables, ['linear-comment-debunker'], 'coordination: multiline list parsed');
eq(coord.coordination.internal, false, 'coordination: boolean false parsed');

// --- Coordination + composition coexistence ---
console.log('\n--- parseFrontmatter: coordination + composition coexist ---');
const bothBlocks = `---
name: both-blocks
coordination:
  group: linear
  order: 2
composition:
  produces:
    - output-a
  priority: 50
---
# Body`;
const both = parseFrontmatter(bothBlocks);
assert(both.coordination !== null, 'coordination present when both blocks exist');
assert(both.composition !== null, 'composition present when both blocks exist');
eq(both.coordination.group, 'linear', 'coordination.group correct with both');
eq(both.composition.priority, 50, 'composition.priority correct with both');
arrEq(both.composition.produces, ['output-a'], 'composition.produces correct with both');

// --- Default/error path: new fields have correct defaults ---
console.log('\n--- parseFrontmatter: new field defaults ---');
const emptyDefaults = parseFrontmatter('');
assert(emptyDefaults.coordination === null, 'default: coordination is null');
eq(emptyDefaults.source, '', 'default: source is empty string');
eq(emptyDefaults.overrides, '', 'default: overrides is empty string');
eq(emptyDefaults.summary, '', 'default: summary is empty string');

const efDefaults = extractFrontmatter('/nonexistent/path/skill.md');
assert(efDefaults.coordination === null, 'error-path: coordination is null');
eq(efDefaults.source, '', 'error-path: source is empty string');
eq(efDefaults.overrides, '', 'error-path: overrides is empty string');
eq(efDefaults.summary, '', 'error-path: summary is empty string');

// --- Defaults stay in sync (parse vs error-path) ---
console.log('\n--- parseFrontmatter: defaults sync check ---');
const parseDefKeys = Object.keys(parseFrontmatter('')).sort();
const errorDefKeys = Object.keys(extractFrontmatter('/nonexistent/x.md')).sort();
arrEq(parseDefKeys, errorDefKeys, 'parse defaults and error-path defaults have same keys');

// --- validateFrontmatter ---
console.log('\n--- validateFrontmatter: valid skill ---');
{
    const fm = parseFrontmatter(`---
name: test-skill
description: A test skill
triggers: ["a", "b"]
anti_triggers: ["c"]
compress: true
---
# Body`);
    const warnings = validateFrontmatter(fm);
    eq(warnings.length, 0, 'valid frontmatter produces no warnings');
}

console.log('\n--- validateFrontmatter: missing name ---');
{
    const fm = parseFrontmatter('---\ndescription: test\n---');
    const warnings = validateFrontmatter(fm, 'test.md');
    assert(warnings.length > 0, 'missing name produces warnings');
    assert(warnings[0].includes('name'), 'warning mentions name');
    assert(warnings[0].includes('test.md'), 'warning includes source');
}

console.log('\n--- validateFrontmatter: valid composition ---');
{
    const fm = parseFrontmatter(`---
name: composable-skill
triggers: ["x"]
composition:
  produces: ["artifact-a"]
  consumes: ["user-intent"]
  capabilities: ["cap-1"]
  priority: 10
  optional: false
  requires_all: true
---`);
    const warnings = validateFrontmatter(fm);
    eq(warnings.length, 0, 'valid composition produces no warnings');
}

console.log('\n--- validateFrontmatter: unknown composition key (DEBUG-gated) ---');
{
    const fm = parseFrontmatter(`---
name: bad-comp
triggers: []
composition:
  produces: ["x"]
  typo_key: true
---`);
    // Unknown keys are only flagged when DEBUG is set
    const oldDebug = process.env.DEBUG;
    process.env.DEBUG = '1';
    const warnings = validateFrontmatter(fm);
    assert(warnings.some(w => w.includes('typo_key')), 'unknown composition key flagged with DEBUG');
    if (oldDebug !== undefined) process.env.DEBUG = oldDebug;
    else delete process.env.DEBUG;
}

console.log('\n--- validateFrontmatter: valid coordination ---');
{
    const fm = parseFrontmatter(`---
name: coordinated-skill
triggers: ["y"]
coordination:
  group: commit-gates
  order: 1
  requires: ["pre-commit-gate"]
  enables: ["post-commit"]
  escalates_to: ["think-twice"]
  internal: false
---`);
    const warnings = validateFrontmatter(fm);
    eq(warnings.length, 0, 'valid coordination produces no warnings');
}

console.log('\n--- validateFrontmatter: unknown coordination key (DEBUG-gated) ---');
{
    const fm = parseFrontmatter(`---
name: bad-coord
triggers: []
coordination:
  group: test
  unknown_field: value
---`);
    // Unknown keys are only flagged when DEBUG is set
    const oldDebug = process.env.DEBUG;
    process.env.DEBUG = '1';
    const warnings = validateFrontmatter(fm);
    assert(warnings.some(w => w.includes('unknown_field')), 'unknown coordination key flagged with DEBUG');
    if (oldDebug !== undefined) process.env.DEBUG = oldDebug;
    else delete process.env.DEBUG;
}

// --- validateFrontmatter: type coercion edge cases ---
console.log('\n--- validateFrontmatter: non-string array elements ---');
{
    // Manually construct a frontmatter object with wrong element types
    const fm = {
        name: 'test-skill',
        triggers: [1, null, 'valid'],
        anti_triggers: ['ok'],
        aliases: [],
        requires_mcp: [],
        compress: true,
    };
    const warnings = validateFrontmatter(fm);
    assert(warnings.some(w => w.includes('triggers[0]') && w.includes('number')),
        'non-string trigger element flagged (number)');
    assert(warnings.some(w => w.includes('triggers[1]') && w.includes('object')),
        'non-string trigger element flagged (null→object)');
}

console.log('\n--- validateFrontmatter: compress as string ---');
{
    const fm = {
        name: 'test-skill',
        triggers: [],
        anti_triggers: [],
        aliases: [],
        requires_mcp: [],
        compress: 'true',
    };
    const warnings = validateFrontmatter(fm);
    assert(warnings.some(w => w.includes('compress') && w.includes('string')),
        'string "true" for compress is flagged');
}

console.log('\n--- validateFrontmatter: composition nested array with non-string ---');
{
    const fm = {
        name: 'test-skill',
        triggers: [],
        anti_triggers: [],
        aliases: [],
        requires_mcp: [],
        compress: true,
        composition: { produces: [42, 'valid'], consumes: [], capabilities: [], priority: 10 },
    };
    const warnings = validateFrontmatter(fm);
    assert(warnings.some(w => w.includes('composition.produces[0]') && w.includes('number')),
        'non-string composition.produces element flagged');
}

// --- validateFrontmatter: null/undefined guard (I1 fix) ---
console.log('\n--- validateFrontmatter: null/undefined guard ---');
{
    const w1 = validateFrontmatter(null);
    assert(w1.length === 1 && w1[0].includes('null'), 'null input returns warning');
    const w2 = validateFrontmatter(undefined);
    assert(w2.length === 1 && w2[0].includes('undefined'), 'undefined input returns warning');
    const w3 = validateFrontmatter([]);
    assert(w3.length === 1 && w3[0].includes('object'), 'array input returns warning');
    const w4 = validateFrontmatter('string');
    assert(w4.length === 1 && w4[0].includes('string'), 'string input returns warning');
}

// --- validateFrontmatter: NaN/Infinity numeric validation (I2 fix) ---
console.log('\n--- validateFrontmatter: NaN/Infinity rejection ---');
{
    const base = { name: 'test', triggers: [], anti_triggers: [], aliases: [],
        requires_mcp: [], compress: true };
    const w1 = validateFrontmatter({ ...base, composition: { priority: NaN } });
    assert(w1.some(w => w.includes('composition.priority') && w.includes('finite')),
        'NaN composition.priority flagged');
    const w2 = validateFrontmatter({ ...base, composition: { priority: Infinity } });
    assert(w2.some(w => w.includes('composition.priority') && w.includes('finite')),
        'Infinity composition.priority flagged');
    const w3 = validateFrontmatter({ ...base, coordination: { order: NaN } });
    assert(w3.some(w => w.includes('coordination.order') && w.includes('finite')),
        'NaN coordination.order flagged');
    // Valid number passes
    const w4 = validateFrontmatter({ ...base, composition: { priority: 50 } });
    assert(!w4.some(w => w.includes('priority')), 'valid priority accepted');
}

// --- validateFrontmatter: unknown keys behind DEBUG (I3 fix) ---
console.log('\n--- validateFrontmatter: unknown keys behind DEBUG ---');
{
    const base = { name: 'test', triggers: [], anti_triggers: [], aliases: [],
        requires_mcp: [], compress: true };
    // Unknown keys should NOT produce warnings in non-DEBUG mode
    const oldDebug = process.env.DEBUG;
    delete process.env.DEBUG;
    const w1 = validateFrontmatter({ ...base, composition: { collision_group: 'foo' } });
    assert(!w1.some(w => w.includes('collision_group')),
        'unknown composition key silent without DEBUG');
    // x_ prefixed keys always silent
    const w2 = validateFrontmatter({ ...base, coordination: { x_custom: 'bar' } });
    assert(!w2.some(w => w.includes('x_custom')),
        'x_-prefixed coordination key always silent');
    // With DEBUG, unknown keys DO warn
    process.env.DEBUG = '1';
    const w3 = validateFrontmatter({ ...base, composition: { collision_group: 'foo' } });
    assert(w3.some(w => w.includes('collision_group')),
        'unknown composition key warns with DEBUG');
    if (oldDebug !== undefined) process.env.DEBUG = oldDebug;
    else delete process.env.DEBUG;
}

// --- compressSkillContent contract tests (I4 fix) ---
console.log('\n--- compressSkillContent contract tests ---');
{
    const { compressSkillContent } = require('../lib/compress');
    // Strips DOT graphs
    eq(compressSkillContent('Before\n```dot\ndigraph{}\n```\nAfter'), 'Before\n\nAfter',
        'compress: strips DOT graphs');
    // Strips YAML frontmatter
    eq(compressSkillContent('---\nname: x\n---\nBody'), 'Body',
        'compress: strips frontmatter');
    // Strips HTML comments
    eq(compressSkillContent('Before <!-- hidden --> After'), 'Before  After',
        'compress: strips HTML comments');
    // Unwraps EXTREMELY-IMPORTANT
    assert(compressSkillContent('<EXTREMELY-IMPORTANT>\nKeep this\n</EXTREMELY-IMPORTANT>').includes('Keep this'),
        'compress: unwraps EXTREMELY-IMPORTANT');
    // Strips boilerplate sections mid-doc
    const midDoc = '## Procedure\nGood\n## When to Use\nBoilerplate\n## Next\nAlso good';
    const compressed = compressSkillContent(midDoc);
    assert(compressed.includes('Good'), 'compress: keeps non-boilerplate');
    assert(!compressed.includes('Boilerplate'), 'compress: strips boilerplate mid-doc');
    // Collapses blank lines
    eq(compressSkillContent('A\n\n\n\nB'), 'A\n\nB',
        'compress: collapses excessive blank lines');
}

// --- Summary ---
console.log(`\n=== Results: ${pass} passed, ${fail} failed ===`);
process.exit(fail > 0 ? 1 : 0);
