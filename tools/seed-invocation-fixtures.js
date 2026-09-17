#!/usr/bin/env node
/**
 * Refresh trigger phrases in test/skill-invocation-fixtures.json from
 * frontmatter without changing the independently reviewed body assertions.
 *
 * For each in-scope skill, pulls:
 *   - expected_substrings[] : reviewer-owned literal assertions. This tool
 *     validates but never derives or updates them from live/compressed output.
 *   - triggers[] : up to 3 trigger phrases from frontmatter `triggers:` list,
 *     preferring multi-word phrases (more specific = better top-3 ranking).
 *
 * The operative assertions are an independent oracle. A missing assertion,
 * auto-seeded provenance, or malformed review date fails closed before the
 * file can be updated.
 *
 * Run: node tools/seed-invocation-fixtures.js
 */
'use strict';

const fs = require('fs');
const path = require('path');
const ROOT = path.resolve(__dirname, '..');
const FIXTURES = path.join(ROOT, 'test', 'skill-invocation-fixtures.json');
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

function validateReviewedFixture(name, fixture) {
    const assertions = fixture.expected_substrings;
    if (!Array.isArray(assertions) || assertions.length === 0) {
        throw new Error(`${name}: at least one independently reviewed operative assertion is required`);
    }
    if (assertions.some(value => typeof value !== 'string' || value.trim() === '')) {
        throw new Error(`${name}: operative assertions must be non-empty strings`);
    }
    if (new Set(assertions).size !== assertions.length) {
        throw new Error(`${name}: operative assertions must be unique`);
    }
    if (typeof fixture.verified_by !== 'string' || fixture.verified_by.trim() === ''
        || /auto[- ]?(seed|resync)|compressed output/i.test(fixture.verified_by)) {
        throw new Error(`${name}: expected_substrings require independent review provenance`);
    }
    if (typeof fixture.verified_at !== 'string' || !/^\d{4}-\d{2}-\d{2}$/.test(fixture.verified_at)) {
        throw new Error(`${name}: verified_at must be YYYY-MM-DD`);
    }
}

function refreshTriggers(fixture, triggers) {
    return { ...fixture, triggers };
}

// Export parseFrontmatterTriggers so the smoke test unit block can import the
// actual implementation rather than maintaining a divergence-prone copy.
module.exports = { parseFrontmatterTriggers, refreshTriggers, validateReviewedFixture };

// Guard: only run the main seeding logic when executed directly, not when
// require()'d by a test importing parseFrontmatterTriggers.
if (require.main === module) {
    const fixtures = JSON.parse(fs.readFileSync(FIXTURES, 'utf8'));
    const today = new Date().toISOString().slice(0, 10);
    let refreshed = 0;

    for (const [name, fixture] of Object.entries(fixtures.skills)) {
        try {
            validateReviewedFixture(name, fixture);
        } catch (error) {
            console.error(`❌ ${error.message}`);
            process.exit(1);
        }
    }

    for (const name of Object.keys(fixtures.skills)) {
        const sf = findSkillFile(name);
        if (!sf) {
            console.log(`  ⏭️  ${name}: skill.md not found`);
            continue;
        }
        const trigs = parseFrontmatterTriggers(fs.readFileSync(sf, 'utf8'))
            .filter(t => t.length >= 4 && t.split(' ').length >= 2)
            .slice(0, 3);
        fixtures.skills[name] = refreshTriggers(fixtures.skills[name], trigs);
        refreshed++;
        console.log(`  ✅ ${name}: kept ${fixtures.skills[name].expected_substrings.length} reviewed assertions, refreshed ${trigs.length} triggers`);
    }

    fixtures._status = `Trigger metadata refreshed ${today}; reviewed operative assertions preserved`;
    fs.writeFileSync(FIXTURES, JSON.stringify(fixtures, null, 4) + '\n');
    console.log(`\n✅ ${refreshed} skill trigger fixtures refreshed → ${path.relative(process.cwd(), FIXTURES)}`);
}
