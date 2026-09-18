#!/usr/bin/env node
/**
 * OPERATIVE-MOVE-DETECTOR: Catches operative procedure (Step/Stage/⛔/HARD-GATE/
 * code blocks) silently moved out of skill.md.
 *
 * Companion to ei-move-detector.test.js. EI-move handles `<EXTREMELY_IMPORTANT>`
 * and protected sections; this handles non-EI operative content patterns that
 * the loader-can't-follow-links problem also breaks.
 *
 * Patterns scanned (each per-skill counted):
 *   - "## Step N" / "## Stage N" / "## Phase N" headings
 *   - "⛔" markers (hard-gate symbols)
 *   - "HARD GATE" / "BLOCK" / "MUST" inside table rows
 *   - Fenced code blocks (```)
 *
 * Compares per-skill counts against test/operative-baseline.json. A drop is
 * a FAIL unless waived via OP-WAIVER: <skill> <pattern> -<n> — <reason>.
 *
 * To regenerate the baseline (requires explicit reviewer approval):
 *   node test/operative-move-detector.test.js --update
 *
 * Run: node test/operative-move-detector.test.js
 */
'use strict';

const fs = require('fs');
const path = require('path');
const { stripFrontmatter } = require('../lib/frontmatter');

const SKILLS_DIR = path.join(__dirname, '..', 'skills');
const BASELINE_PATH = path.join(__dirname, 'operative-baseline.json');

// --- Helpers ---

function findAllSkills(dir) {
    const out = [];
    for (const e of fs.readdirSync(dir, { withFileTypes: true })) {
        const full = path.join(dir, e.name);
        if (e.isDirectory()) out.push(...findAllSkills(full));
        else if (e.name === 'skill.md') out.push(full);
    }
    return out;
}

function countPatterns(text) {
    return {
        // REVERTED: an earlier version of this also counted bolded ordered-list
        // items, on the theory that a kernel split merely re-encodes "### Step N"
        // as "1. **Step.**" and that widening a count can never mask a drop.
        // Both halves were wrong. Raising the measured value above a STALE
        // baseline IS the masking mechanism: with the broader term, deleting all
        // four real "### Phase N" headings from systematic-debugging still passed,
        // because 21 unrelated bolded list items held the count above its baseline
        // of 4. Measured across 106 skills the broadening granted ~400 units of
        // undetectable deletion budget against an actual need of 13, and a
        // "1. **name**: ..." companion-skills list satisfied it just as well as a
        // real procedure. Legitimate re-encodings get a bounded, per-skill,
        // reviewable OP-WAIVER instead.
        step_headings: (text.match(/^#{2,4}\s+(Step|Stage|Phase)\s+\d+/gim) || []).length,
        stop_markers: (text.match(/⛔/g) || []).length,
        hard_gate_table: (text.match(/^\|.*\b(HARD\s*GATE|BLOCK|MUST)\b.*\|/gim) || []).length,
        code_fences: Math.floor((text.match(/^```/gm) || []).length / 2), // pairs
    };
}

function loadWaivers() {
    // Two sources, same bounded format. CI reads the PR body via OP_WAIVERS so a
    // reviewer sees the justification next to the diff. A committed
    // test/.op-waivers file carries the same entries durably, so the identical
    // check runs locally and at the pre-push gate instead of passing in CI and
    // failing on every developer machine.
    //
    // The format is bounded on all three axes -- skill, pattern, and maximum
    // drop -- so a waiver can never widen into a blanket exemption. That is the
    // whole reason this is preferred over broadening countPatterns: a global
    // regex change granted ~400 units of slack across 57 skills to buy the 12
    // units actually needed here.
    let fileRaw = '';
    try {
        fileRaw = fs.readFileSync(path.join(__dirname, '.op-waivers'), 'utf8');
    } catch { /* absent is normal */ }
    const raw = (process.env.OP_WAIVERS || '') + '\n' + fileRaw;
    const out = [];
    for (const line of raw.split('\n')) {
        const m = line.match(/OP-WAIVER:\s*(\S+)\s+(\S+)\s+-(\d+)/);
        if (m) out.push({ skill: m[1], pattern: m[2], drop: parseInt(m[3], 10) });
    }
    return out;
}

function isWaived(waivers, skill, pattern, drop) {
    return waivers.some(w => w.skill === skill && w.pattern === pattern && drop <= w.drop);
}

// Whole-skill waiver: any OP-WAIVER entry for this skill regardless of pattern/drop.
// Used for the missing-file case where all patterns are effectively gone.
// NOTE: a narrowly-scoped waiver (e.g. -1 on a single pattern) also satisfies this
// check — log a visible warning so reviewers know the waiver scope was broadened.
function isSkillWaived(waivers, skill) {
    const w = waivers.find(e => e.skill === skill);
    if (w) {
        console.log(`  ⚠️  ${skill}: missing-file waived by OP-WAIVER entry (pattern=${w.pattern}, drop=${w.drop})`);
        return true;
    }
    return false;
}

// --- Baseline ---

function buildBaseline() {
    const baseline = { generated_at: new Date().toISOString(), skills: {} };
    for (const sp of findAllSkills(SKILLS_DIR)) {
        const rel = path.relative(SKILLS_DIR, sp);
        const raw = stripFrontmatter(fs.readFileSync(sp, 'utf8'));
        const counts = countPatterns(raw);
        const total = Object.values(counts).reduce((a, b) => a + b, 0);
        if (total > 0) baseline.skills[rel] = counts;
    }
    fs.writeFileSync(BASELINE_PATH, JSON.stringify(baseline, null, 2) + '\n');
    console.log(`✅ Operative baseline: ${Object.keys(baseline.skills).length} skills → ${path.relative(process.cwd(), BASELINE_PATH)}`);
}

// --- Detect ---

function detect() {
    if (!fs.existsSync(BASELINE_PATH)) {
        console.error(`❌ No baseline at ${BASELINE_PATH}. Run with --update first.`);
        process.exit(2);
    }
    const baseline = JSON.parse(fs.readFileSync(BASELINE_PATH, 'utf8'));
    const waivers = loadWaivers();
    const failures = [];
    let totalChecks = 0;

    for (const [rel, expected] of Object.entries(baseline.skills)) {
        const sp = path.join(SKILLS_DIR, rel);
        if (!fs.existsSync(sp)) {
            // Skill file missing — treat as failure unless waived.
            // Archived/deleted skills lose all their operative patterns from the
            // loader's reach. Run --update to explicitly remove from baseline when
            // intentional. Waiver check mirrors ei-move-detector behavior.
            if (!isSkillWaived(waivers, rel)) {
                failures.push(
                    `  FAIL: ${rel}: skill.md no longer exists. If intentional (deletion/archive), run --update to remove from baseline.`
                );
            }
            continue;
        }
        const raw = stripFrontmatter(fs.readFileSync(sp, 'utf8'));
        const current = countPatterns(raw);
        for (const k of Object.keys(expected)) {
            totalChecks++;
            const drop = expected[k] - (current[k] || 0);
            if (drop > 0 && !isWaived(waivers, rel, k, drop)) {
                failures.push(
                    `  FAIL: ${rel}: pattern "${k}" dropped from ${expected[k]} to ${current[k] || 0} (-${drop}). ` +
                    `Add OP-WAIVER: ${rel} ${k} -${drop} — <reason> if intentional.`
                );
            }
        }
    }

    console.log(`\nChecked ${totalChecks} pattern counts across ${Object.keys(baseline.skills).length} skills`);
    if (failures.length) {
        console.log(`\n${failures.length} failure(s):`);
        failures.forEach(f => console.log(f));
        process.exit(1);
    }
    console.log('✅ Operative-move detector: ALL CHECKS PASSED');
}

// --- Main ---

const args = process.argv.slice(2);
if (args.includes('--update')) buildBaseline();
else detect();
