#!/usr/bin/env node
/**
 * Tests for lib/skill-discovery.js
 * Uses temp directories to test flat and domain-grouped layouts.
 */
'use strict';

const fs = require('fs');
const path = require('path');
const os = require('os');
const assert = require('assert');

const { findSkillsInDir, deduplicateSkills, findAllSkills } = require('../lib/skill-discovery');

let pass = 0, fail = 0;
function test(name, fn) {
    try { fn(); pass++; console.log(`  ok: ${name}`); }
    catch (e) { fail++; console.log(`  FAIL: ${name}: ${e.message}`); }
}

// Create temp dirs
const tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), 'sd-test-'));
const flatDir = path.join(tmpDir, 'flat');
const domainDir = path.join(tmpDir, 'domain');
const emptyDir = path.join(tmpDir, 'empty');

// Set up flat layout: flat/{skill-name}/skill.md
fs.mkdirSync(path.join(flatDir, 'alpha'), { recursive: true });
fs.writeFileSync(path.join(flatDir, 'alpha', 'skill.md'), `---
name: alpha
description: Alpha skill
triggers:
  - alpha trigger
---
# Alpha
Alpha content.
`);

fs.mkdirSync(path.join(flatDir, 'beta'), { recursive: true });
fs.writeFileSync(path.join(flatDir, 'beta', 'skill.md'), `---
name: beta
description: Beta skill
composition:
  produces:
    - beta-artifact
  consumes:
    - user-intent
---
# Beta
Beta content.
`);

// Overlay-style skill with coordination + source + overrides + summary
fs.mkdirSync(path.join(flatDir, 'overlay-skill'), { recursive: true });
fs.writeFileSync(path.join(flatDir, 'overlay-skill', 'skill.md'), `---
name: overlay-skill
description: An overlay skill
source: superpowers-overlay
overrides: superpowers-plus/base-skill
summary: "Use when: overlaying."
triggers:
  - overlay trigger
coordination:
  group: linear
  order: 2
  requires: []
  enables:
    - other-skill
  internal: false
---
# Overlay
Overlay content.
`);

// Set up domain-grouped layout: domain/{engineering}/{gamma}/skill.md
fs.mkdirSync(path.join(domainDir, 'engineering', 'gamma'), { recursive: true });
fs.writeFileSync(path.join(domainDir, 'engineering', 'gamma', 'skill.md'), `---
name: gamma
description: Gamma skill
---
# Gamma
`);

fs.mkdirSync(path.join(domainDir, 'productivity', 'delta'), { recursive: true });
fs.writeFileSync(path.join(domainDir, 'productivity', 'delta', 'skill.md'), `---
name: delta
description: Delta skill
triggers:
  - delta trigger
---
# Delta
`);

// Set up empty dir
fs.mkdirSync(emptyDir, { recursive: true });

// Hidden and underscore dirs (should be skipped)
fs.mkdirSync(path.join(flatDir, '_archive', 'hidden-skill'), { recursive: true });
fs.writeFileSync(path.join(flatDir, '_archive', 'hidden-skill', 'skill.md'), '---\nname: hidden\n---\n');
fs.mkdirSync(path.join(flatDir, '.git'), { recursive: true });

// ---- Tests ----

test('findSkillsInDir finds flat skills', () => {
    const skills = findSkillsInDir(flatDir, 'personal');
    assert(skills.length === 3, `Expected 3 skills, got ${skills.length}`);
});

test('findSkillsInDir returns correct metadata', () => {
    const skills = findSkillsInDir(flatDir, 'personal');
    const alpha = skills.find(s => s.name === 'alpha');
    assert(alpha, 'alpha not found');
    assert(alpha.description === 'Alpha skill', `description: ${alpha.description}`);
    assert(alpha.isSuperpower === true, 'alpha should be a superpower (has triggers)');
    assert(alpha.sourceType === 'personal', `sourceType: ${alpha.sourceType}`);
    assert(alpha.tokens > 0, `tokens: ${alpha.tokens}`);
});

test('findSkillsInDir handles composition metadata', () => {
    const skills = findSkillsInDir(flatDir, 'personal');
    const beta = skills.find(s => s.name === 'beta');
    assert(beta, 'beta not found');
    assert(beta.composition, 'beta should have composition');
    assert(beta.composition.produces.includes('beta-artifact'), 'should produce beta-artifact');
});

test('findSkillsInDir propagates overlay fields (coordination, source, overrides, summary)', () => {
    const skills = findSkillsInDir(flatDir, 'personal');
    const overlay = skills.find(s => s.name === 'overlay-skill');
    assert(overlay, 'overlay-skill not found');
    assert.strictEqual(overlay.source, 'superpowers-overlay', 'source propagated');
    assert.strictEqual(overlay.overrides, 'superpowers-plus/base-skill', 'overrides propagated');
    assert.strictEqual(overlay.summary, 'Use when: overlaying.', 'summary propagated');
    assert(overlay.coordination !== null, 'coordination propagated');
    assert.strictEqual(overlay.coordination.group, 'linear', 'coordination.group');
    assert.strictEqual(overlay.coordination.order, 2, 'coordination.order');
    assert.deepStrictEqual(overlay.coordination.enables, ['other-skill'], 'coordination.enables');
    assert.strictEqual(overlay.coordination.internal, false, 'coordination.internal');
});

test('findSkillsInDir returns empty defaults for skills without overlay fields', () => {
    const skills = findSkillsInDir(flatDir, 'personal');
    const alpha = skills.find(s => s.name === 'alpha');
    assert(alpha, 'alpha not found');
    assert.strictEqual(alpha.source, '', 'source defaults to empty');
    assert.strictEqual(alpha.overrides, '', 'overrides defaults to empty');
    assert.strictEqual(alpha.summary, '', 'summary defaults to empty');
    assert.strictEqual(alpha.coordination, null, 'coordination defaults to null');
});

test('findSkillsInDir discovers domain-grouped skills', () => {
    const skills = findSkillsInDir(domainDir, 'superpowers');
    assert(skills.length === 2, `Expected 2, got ${skills.length}`);
    const names = skills.map(s => s.name).sort();
    assert.deepStrictEqual(names, ['delta', 'gamma']);
});

test('findSkillsInDir skips _ prefixed dirs', () => {
    const skills = findSkillsInDir(flatDir, 'personal');
    const hidden = skills.find(s => s.name === 'hidden');
    assert(!hidden, 'should not find _archive skills');
});

test('findSkillsInDir skips . prefixed dirs', () => {
    const skills = findSkillsInDir(flatDir, 'personal');
    assert(!skills.find(s => s.dirName === '.git'));
});

test('findSkillsInDir returns empty for empty dir', () => {
    assert.deepStrictEqual(findSkillsInDir(emptyDir, 'personal'), []);
});

test('findSkillsInDir returns empty for nonexistent dir', () => {
    assert.deepStrictEqual(findSkillsInDir('/nonexistent/path', 'personal'), []);
});

test('deduplicateSkills removes duplicates by name', () => {
    const skills = [
        { name: 'alpha', sourceType: 'personal' },
        { name: 'alpha', sourceType: 'superpowers' },
        { name: 'beta', sourceType: 'personal' },
    ];
    const result = deduplicateSkills(skills);
    assert(result.length === 2, `Expected 2, got ${result.length}`);
    assert(result[0].sourceType === 'personal', 'first occurrence wins');
});

test('findAllSkills merges and deduplicates', () => {
    const skills = findAllSkills(flatDir, domainDir);
    assert(skills.length === 5, `Expected 5, got ${skills.length}`);
});

test('findAllSkills personal overrides superpowers', () => {
    // Create a superpowers dir with same skill name as personal
    const spDir = path.join(tmpDir, 'sp-override');
    fs.mkdirSync(path.join(spDir, 'alpha'), { recursive: true });
    fs.writeFileSync(path.join(spDir, 'alpha', 'skill.md'), '---\nname: alpha\ndescription: SP Alpha\n---\n');
    const skills = findAllSkills(flatDir, spDir);
    const alpha = skills.find(s => s.name === 'alpha');
    assert(alpha.sourceType === 'personal', 'personal should override superpowers');
    assert(alpha.description === 'Alpha skill', 'personal version description wins');
});

// Cleanup
try { fs.rmSync(tmpDir, { recursive: true }); } catch { /* ignore */ }

console.log('');
console.log(`=== Results: ${pass} passed, ${fail} failed ===`);
process.exit(fail > 0 ? 1 : 0);
