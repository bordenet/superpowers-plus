#!/usr/bin/env node
/**
 * Unit tests for lib/frontmatter.js — the reference parser.
 * Run: node test/frontmatter.test.js
 */

'use strict';

const { parseFrontmatter, parseInlineArray, unquoteYaml, findSkillFile } = require('../lib/frontmatter');
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

// --- stripFrontmatter parity (inline implementation matching all 3 consumers) ---
console.log('\n--- stripFrontmatter CRLF parity ---');
// Replicate the shared stripFrontmatter logic used by augment.js, MCP, and install-augment
function stripFrontmatter(content) {
    const lines = content.replace(/\r\n/g, '\n').replace(/\r/g, '\n').split('\n');
    let inFrontmatter = false;
    let frontmatterEnded = false;
    const result = [];
    for (const line of lines) {
        if (line.trim() === '---') {
            if (inFrontmatter && !frontmatterEnded) { frontmatterEnded = true; continue; }
            if (!frontmatterEnded) { inFrontmatter = true; continue; }
            // frontmatterEnded=true: body '---' — fall through to push
        }
        if (frontmatterEnded || !inFrontmatter) result.push(line);
    }
    return result.join('\n').trim();
}
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
const { extractFrontmatter } = require('../lib/frontmatter');
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

// --- Summary ---
console.log(`\n=== Results: ${pass} passed, ${fail} failed ===`);
process.exit(fail > 0 ? 1 : 0);
