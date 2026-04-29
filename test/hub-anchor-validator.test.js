#!/usr/bin/env node
/**
 * HUB-ANCHOR-VALIDATOR: Catches silent renumbering breakage when hub skills
 * reference other skills' Step/Stage/Phase/§/G anchors.
 *
 * Failure shape: hub skill text says "see foo Step 3" but foo's "## Step 3"
 * has been renumbered to 3a/3b. Compression-safety + ei-move-detector won't
 * catch it (the heading still exists in foo, just renumbered). This test will.
 *
 * Approach:
 *   1. Identify hub skills (think-twice, debate, debug-conductor + any with
 *      composition.uses[] declared in frontmatter — auto-discovery).
 *   2. For each hub, scan its skill.md for cross-references of the form:
 *        - "skill-name Step N" / "skill-name Stage N" / "skill-name Phase N"
 *        - "skill-name §N" / "skill-name GN"
 *        - "<X> step N" inside [link](other-skill) blocks
 *      OR linked references in markdown like [Step N](#h-step-n) inside a
 *      section that names another skill.
 *   3. For each reference, open the target skill.md and assert the referenced
 *      anchor exists (heading "## Step N" or anchor "#h-step-n").
 *
 * Required for Phase 4 HUB merges (per plan P0.4b).
 *
 * Run: node test/hub-anchor-validator.test.js
 *
 * Exit 0 = pass, exit 1 = at least one anchor missing.
 */
'use strict';

const fs = require('fs');
const path = require('path');
const { stripFrontmatter } = require('../lib/frontmatter');

const SKILLS_DIR = path.join(__dirname, '..', 'skills');

// Canonical hubs from the plan + any skill declaring composition.uses[].
const CANONICAL_HUBS = new Set(['think-twice', 'debate', 'debug-conductor']);

let pass = 0, fail = 0, warnings = 0;
const failures = [];

function findAllSkills(dir) {
    const out = [];
    for (const e of fs.readdirSync(dir, { withFileTypes: true })) {
        const full = path.join(dir, e.name);
        if (e.isDirectory()) out.push(...findAllSkills(full));
        else if (e.name === 'skill.md') out.push(full);
    }
    return out;
}

function getSkillName(skillPath) {
    return path.basename(path.dirname(skillPath));
}

function readBody(skillPath) {
    return stripFrontmatter(fs.readFileSync(skillPath, 'utf8'));
}

function hasCompositionUses(skillPath) {
    const raw = fs.readFileSync(skillPath, 'utf8');
    const m = raw.match(/^---\n([\s\S]*?)\n---/);
    if (!m) return false;
    const fm = m[1];
    // Extract the composition/coordination block using indentation-based matching
    // (blank-line-tolerant) so we only look for uses:/next: within that block,
    // not in any sibling top-level key. Pattern mirrors parseCompositionUses().
    const compBlock = fm.match(/^composition:\n((?:(?:[ \t][^\n]*)?\n)*)/m);
    const coordBlock = fm.match(/^coordination:\n((?:(?:[ \t][^\n]*)?\n)*)/m);
    return (compBlock && /^\s*uses:/m.test(compBlock[1])) ||
        (coordBlock && /^\s*next:/m.test(coordBlock[1]));
}

function discoverHubs(allSkills) {
    const hubs = new Map();
    for (const sp of allSkills) {
        const name = getSkillName(sp);
        if (CANONICAL_HUBS.has(name) || hasCompositionUses(sp)) {
            hubs.set(name, sp);
        }
    }
    return hubs;
}

function buildSkillIndex(allSkills) {
    const idx = new Map();
    for (const sp of allSkills) idx.set(getSkillName(sp), sp);
    return idx;
}

function findAnchorPatterns(text, allSkillNames) {
    const refs = [];
    // Pattern 1: "<skill-name> Step N" / Stage N / Phase N / §N / GN
    const skillAlt = allSkillNames.map(s => s.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')).join('|');
    if (!skillAlt) return refs;
    const stepRe = new RegExp(
        `\\b(${skillAlt})\\b[\\s,:.-]*?(Step|Stage|Phase)\\s+(\\d+[a-z]?)`,
        'gi'
    );
    let m;
    while ((m = stepRe.exec(text)) !== null) {
        refs.push({
            target: m[1].toLowerCase(),
            kind: m[2],
            num: m[3],
            raw: m[0],
        });
    }
    const symRe = new RegExp(
        `\\b(${skillAlt})\\b[\\s,:.-]*?[§G](\\d+)`,
        'gi'
    );
    while ((m = symRe.exec(text)) !== null) {
        refs.push({
            target: m[1].toLowerCase(),
            kind: m[0].includes('§') ? 'Section' : 'Gate',
            num: m[2],
            raw: m[0],
        });
    }
    return refs;
}

function targetHasAnchor(targetText, kind, num) {
    // Heading patterns
    const heading = new RegExp(
        `^#{2,6}\\s+(?:\\d+\\.\\s+)?(${kind})\\s+${num}\\b`,
        'mi'
    );
    if (heading.test(targetText)) return true;
    // Bold inline patterns
    const bold = new RegExp(
        `\\*\\*\\s*${kind}\\s+${num}\\b`,
        'i'
    );
    if (bold.test(targetText)) return true;
    // Anchor link
    const anchorSlug = `#h-${kind.toLowerCase()}-${num}`;
    if (targetText.toLowerCase().includes(anchorSlug)) return true;
    return false;
}

// --- Main ---

const allSkills = findAllSkills(SKILLS_DIR);
const hubs = discoverHubs(allSkills);
const index = buildSkillIndex(allSkills);
const allNames = [...index.keys()].sort((a, b) => b.length - a.length); // longest-first to avoid prefix collisions

console.log(`Hub-anchor-validator: ${hubs.size} hub(s) discovered, ${index.size} skills total\n`);

for (const [hubName, hubPath] of hubs.entries()) {
    const body = readBody(hubPath);
    const refs = findAnchorPatterns(body, allNames);
    if (refs.length === 0) {
        console.log(`  ${hubName}: no cross-skill step anchors — OK`);
        continue;
    }
    console.log(`  ${hubName}: ${refs.length} cross-skill anchor reference(s)`);
    for (const ref of refs) {
        if (ref.target === hubName) continue; // self-reference, not cross
        const targetPath = index.get(ref.target);
        if (!targetPath) {
            // Skill not in index — could be a false positive (common word matching
            // a skill name) OR a renamed/deleted skill. Emit a warning but do not
            // count as pass so the pass count reflects only verified anchors.
            warnings++;
            console.log(`  ⚠️  ${hubName} → ${ref.target}: skill not in index (false positive or renamed skill — review manually)`);
            continue;
        }
        const targetText = readBody(targetPath);
        if (targetHasAnchor(targetText, ref.kind, ref.num)) {
            pass++;
        } else {
            fail++;
            failures.push(
                `  FAIL: ${hubName} → ${ref.target}: "${ref.raw}" has no matching ${ref.kind} ${ref.num} anchor in target`
            );
        }
    }
}

console.log(`\n${pass} passed, ${fail} failed, ${warnings} unresolvable (review manually)`);
if (fail > 0) {
    console.log('\nFailures:');
    failures.forEach(f => console.log(f));
    process.exit(1);
}
console.log('✅ Hub-anchor-validator: ALL CHECKS PASSED');
