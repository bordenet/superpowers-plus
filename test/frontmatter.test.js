#!/usr/bin/env node
/**
 * Unit tests for lib/frontmatter.js — the reference parser.
 * Run: node test/frontmatter.test.js
 */

'use strict';

const { parseFrontmatter, parseInlineArray, extractStringValue, findSkillFile } = require('../lib/frontmatter');
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

// --- extractStringValue ---
console.log('\n--- extractStringValue ---');
eq(extractStringValue('"hello"'), 'hello', 'simple double-quoted');
eq(extractStringValue("'hello'"), 'hello', 'simple single-quoted');
eq(extractStringValue('plain text'), 'plain text', 'unquoted');
eq(extractStringValue('"User says \\"build X\\""'), 'User says "build X"', 'escaped double-quotes');
eq(extractStringValue('"path\\\\to\\\\file"'), 'path\\to\\file', 'escaped backslashes');
eq(extractStringValue(''), '', 'empty string');
eq(extractStringValue('"  spaced  "'), '  spaced  ', 'preserves internal spaces');

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
            if (inFrontmatter) { frontmatterEnded = true; continue; }
            inFrontmatter = true;
            continue;
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

// --- Summary ---
console.log(`\n=== Results: ${pass} passed, ${fail} failed ===`);
process.exit(fail > 0 ? 1 : 0);
