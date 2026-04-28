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
        step_headings: (text.match(/^#{2,4}\s+(Step|Stage|Phase)\s+\d+/gim) || []).length,
        stop_markers: (text.match(/⛔/g) || []).length,
        hard_gate_table: (text.match(/^\|.*\b(HARD\s*GATE|BLOCK|MUST)\b.*\|/gim) || []).length,
        code_fences: Math.floor((text.match(/^```/gm) || []).length / 2), // pairs
    };
}

function loadWaivers() {
    const raw = process.env.OP_WAIVERS || '';
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
            console.warn(`  ⚠️  ${rel}: skill.md missing`);
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
