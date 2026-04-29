#!/usr/bin/env node
/**
 * Seed test/skill-invocation-fixtures.json from goldens + frontmatter.
 *
 * For each in-scope skill, pulls:
 *   - expected_substrings[] : 3 distinctive substrings from the compressed
 *     golden body. Selection rule: longest substantive lines that aren't
 *     headings, blockquotes, or boilerplate (avoid "Source: `superpowers-plus`",
 *     "When to use:" stubs, etc).
 *   - triggers[] : up to 3 trigger phrases from frontmatter `triggers:` list,
 *     preferring multi-word phrases (more specific = better top-3 ranking).
 *
 * Per plan P0.6: fixtures are reviewer-verified ("GOLDEN-VERIFIED"). This
 * script provides a defensible auto-seed; reviewer must confirm by setting
 * verified_by and verified_at fields.
 *
 * Run: node tools/seed-invocation-fixtures.js
 */
'use strict';

const fs = require('fs');
const path = require('path');

const ROOT = path.resolve(__dirname, '..');
const FIXTURES = path.join(ROOT, 'test', 'skill-invocation-fixtures.json');
const GOLDEN_DIR = path.join(ROOT, 'test', 'golden-compression');
const SKILLS_DIR = path.join(ROOT, 'skills');

function findSkillFile(name) {
    function walk(dir) {
        for (const e of fs.readdirSync(dir, { withFileTypes: true })) {
            const full = path.join(dir, e.name);
            if (e.isDirectory()) {
                if (e.name === name && fs.existsSync(path.join(full, 'skill.md'))) return path.join(full, 'skill.md');
                const r = walk(full);
                if (r) return r;
            }
        }
        return null;
    }
    return walk(SKILLS_DIR);
}

// parseFrontmatterTriggers accepts raw file content (not a path) so it can be
// imported and unit-tested directly in skill-invocation-smoke.test.js without
// requiring temporary files. The calling site reads the file separately.
function parseFrontmatterTriggers(raw) {
    const m = raw.match(/^---\n([\s\S]*?)\n---/);
    if (!m) return [];
    // The frontmatter regex stops just before the closing \n---, so the last
    // frontmatter line has no trailing \n. Append one so the block regex can
    // match it (the block regex requires each line to end with \n).
    const fm = m[1] + '\n';
    // Match indented lines (including optional blank lines between items).
    // Stops at the first non-blank, non-indented line or EOF.
    const tBlock = fm.match(/^triggers:\n((?:(?:[ \t][^\n]*)?\n)*)/m);
    if (!tBlock) return [];
    const out = [];
    for (const line of tBlock[1].split('\n')) {
        // Use alternation to correctly handle apostrophes inside double-quoted
        // strings (e.g. "when user says 'fix this'") and vice versa.
        const t = line.match(/^\s*-\s*(?:"([^"\n]+)"|'([^'\n]+)'|([^\n'"]+))\s*$/);
        if (t) {
            const v = (t[1] ?? t[2] ?? t[3]).trim();
            if (v) out.push(v); // guard: don't emit empty strings from bare bullets
        }
    }
    return out;
}

function pickExpectedSubstrings(goldenPath) {
    if (!fs.existsSync(goldenPath)) return [];
    const text = fs.readFileSync(goldenPath, 'utf8');
    // Skip the "# Skill: <name>" header line
    const body = text.split('\n').slice(1).join('\n');
    const candidates = [];
    let inCode = false;
    for (const ln of body.split('\n')) {
        if (/^```/.test(ln)) { inCode = !inCode; continue; }
        if (inCode) continue;
        const t = ln.trim();
        if (t.length < 30 || t.length > 100) continue;
        if (/^#/.test(t)) continue;
        if (/^>/.test(t)) continue;
        if (/^[-*|]/.test(t)) continue;
        if (/superpowers-plus/i.test(t)) continue;
        if (/source:|purpose:|when to use|^\*\*/i.test(t)) continue;
        candidates.push(t);
    }
    // Pick 3 spread across the body for resilience
    if (candidates.length === 0) return [];
    if (candidates.length <= 3) return candidates;
    const stride = Math.floor(candidates.length / 3);
    return [candidates[0], candidates[stride], candidates[stride * 2]].slice(0, 3);
}

// Export parseFrontmatterTriggers so the smoke test unit block can import the
// actual implementation rather than maintaining a divergence-prone copy.
module.exports = { parseFrontmatterTriggers };

// Guard: only run the main seeding logic when executed directly, not when
// require()'d by a test importing parseFrontmatterTriggers.
if (require.main === module) {
    const fixtures = JSON.parse(fs.readFileSync(FIXTURES, 'utf8'));
    const today = new Date().toISOString().slice(0, 10);
    let seeded = 0;

    for (const name of Object.keys(fixtures.skills)) {
        const sf = findSkillFile(name);
        if (!sf) {
            console.log(`  ⏭️  ${name}: skill.md not found`);
            continue;
        }
        const subs = pickExpectedSubstrings(path.join(GOLDEN_DIR, `${name}.golden.txt`));
        const trigs = parseFrontmatterTriggers(fs.readFileSync(sf, 'utf8'))
            .filter(t => t.length >= 4 && t.split(' ').length >= 2)
            .slice(0, 3);
        fixtures.skills[name].expected_substrings = subs;
        fixtures.skills[name].triggers = trigs;
        fixtures.skills[name].verified_by = 'auto-seed (P0.6 — reviewer must confirm by replacing this with reviewer name)';
        fixtures.skills[name].verified_at = today;
        seeded++;
        console.log(`  ✅ ${name}: ${subs.length} substrings, ${trigs.length} triggers`);
    }

    fixtures._status = `P0.6 auto-seeded ${today} — reviewer must verify each entry and replace verified_by stub`;
    fs.writeFileSync(FIXTURES, JSON.stringify(fixtures, null, 4) + '\n');
    console.log(`\n✅ ${seeded} skills seeded → ${path.relative(process.cwd(), FIXTURES)}`);
}
