#!/usr/bin/env node
/**
 * Unit tests for lib/compress.js — skill content compression.
 * Run: node test/compress.test.js
 *
 * Tests two things:
 *   1. Compression rules work correctly (unit tests)
 *   2. Golden-file regression: compressed output of top-5 skills matches snapshots
 */
'use strict';

const fs = require('fs');
const path = require('path');
const { compressSkillContent, STRIP_SECTIONS, DENSITY_RULES, protectCodeBlocks } = require('../lib/compress');

let pass = 0;
let fail = 0;

function assert(condition, msg) {
    if (condition) { pass++; console.log(`  ✅ ${msg}`); }
    else { fail++; console.log(`  ❌ ${msg}`); }
}
function eq(a, b, msg) { assert(a === b, `${msg} (got: ${JSON.stringify(a).substring(0, 80)}, want: ${JSON.stringify(b).substring(0, 80)})`); }

// --- Phase 1: Structural stripping ---
console.log('\n--- Phase 1: Section stripping ---');

assert(compressSkillContent('## When to Use\nsome text\n\n## Procedure\nreal content').includes('real content'),
    'strips "When to Use" section');
assert(!compressSkillContent('## When to Use\nsome text\n\n## Procedure\nreal content').includes('some text'),
    'removes "When to Use" content');

assert(!compressSkillContent('## Example\nsome example\n\n## Procedure\nreal').includes('some example'),
    'strips Example sections');
assert(!compressSkillContent('## Anti-Patterns\nsome patterns\n\n## Procedure\nreal').includes('some patterns'),
    'strips Anti-Patterns sections');
assert(!compressSkillContent('## Rationalizations to Reject\n| a | b |\n\n## Procedure\nreal').includes('Reject'),
    'strips Rationalizations to Reject');
assert(!compressSkillContent('## References\n- link1\n- link2\n\n## Procedure\nreal').includes('link1'),
    'strips References sections');
assert(!compressSkillContent('## Reference: Shell Guide\ncontent\n\n## Procedure\nreal').includes('Shell Guide'),
    'strips Reference: variant sections');

// Preserved sections
assert(compressSkillContent('## Failure Modes\n| a | b |\n\n## Other\ntext').includes('Failure Modes'),
    'preserves Failure Modes sections');
assert(compressSkillContent('## Procedure\ncritical steps\n\n## Other\ntext').includes('critical steps'),
    'preserves Procedure sections');

// --- Phase 1: Other structural ---
console.log('\n--- Phase 1: DOT/frontmatter/comments ---');
eq(compressSkillContent('```dot\ndigraph { a -> b }\n```\nreal'), 'real', 'strips DOT graphs');
assert(!compressSkillContent('---\ntitle: test\n---\ncontent').includes('title:'), 'strips YAML frontmatter');
eq(compressSkillContent('<!-- comment -->\ncontent'), 'content', 'strips HTML comments');

// --- Phase 2: Density rules ---
console.log('\n--- Phase 2: Density rules ---');

assert(!compressSkillContent('**Announce at start:** "I\'m using debate."\n\ncontent').includes('Announce'),
    'strips announce-at-start lines');
assert(compressSkillContent('**Exit gate:** all checks pass').includes('Exit gate:'),
    'debolds Exit gate labels');
assert(!compressSkillContent('**Exit gate:** all checks pass').includes('**Exit gate:**'),
    'removes bold markers from Exit gate');

// Code block protection
console.log('\n--- Code block protection ---');
const withCode = '## Heading\n\n```bash\n**Exit gate:** preserved\n```\n\ncontent';
const compressed = compressSkillContent(withCode);
assert(compressed.includes('**Exit gate:** preserved'), 'preserves bold inside code blocks');

// HARD-GATE preservation
console.log('\n--- HARD-GATE preservation ---');
assert(compressSkillContent('⛔ **HARD GATE:** do not skip\n\ncontent').includes('HARD GATE'),
    'preserves HARD-GATE content');
assert(compressSkillContent('⛔ **HARD GATE:** do not skip\n\ncontent').includes('do not skip'),
    'preserves HARD-GATE text');

// Whitespace tightening
console.log('\n--- Whitespace tightening ---');
assert(!compressSkillContent('## Heading\n\n\n\ncontent').includes('\n\n\n'), 'collapses 3+ blank lines');
assert(!compressSkillContent('content   \nnext').includes('   '), 'strips trailing whitespace');

// --- Golden file regression ---
console.log('\n--- Golden file regression ---');
const goldenDir = path.join(__dirname, 'golden-compression');
const { stripFrontmatter } = require('../lib/frontmatter');
const skills = ['plan-and-execute', 'code-review-battery', 'verification-before-completion',
                'todo-management', 'pre-push-quality-gate'];

for (const skill of skills) {
    const goldenPath = path.join(goldenDir, `${skill}.golden.txt`);
    if (!fs.existsSync(goldenPath)) {
        console.log(`  ⏭️  ${skill}: golden file not found (run with --update to create)`);
        continue;
    }
    const skillFile = findSkillFile(skill);
    if (!skillFile) { console.log(`  ⏭️  ${skill}: skill.md not found`); continue; }

    const raw = fs.readFileSync(skillFile, 'utf8');
    const compressed = compressSkillContent(stripFrontmatter(raw));
    const golden = fs.readFileSync(goldenPath, 'utf8');

    // Compare content after the "# Skill: name" header (golden includes it, compressed doesn't)
    const goldenBody = golden.replace(/^# Skill: [^\n]+\n\n/, '');
    eq(compressed, goldenBody.trim(), `golden regression: ${skill}`);
}

function findSkillFile(name) {
    const skillsDir = path.join(__dirname, '..', 'skills');
    for (const domain of fs.readdirSync(skillsDir)) {
        const p = path.join(skillsDir, domain, name, 'skill.md');
        if (fs.existsSync(p)) return p;
    }
    return null;
}

// --- Summary ---
console.log(`\n${pass} passed, ${fail} failed`);
process.exit(fail > 0 ? 1 : 0);
