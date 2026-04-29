#!/usr/bin/env node
/**
 * EI-MOVE-DETECTOR: Catches load-bearing content moved out of skill.md.
 *
 * Companion to compression-safety.test.js, which detects DELETE in compressed
 * output. This test detects MOVE: content that left skill.md entirely (e.g.
 * silently extracted to references/foo.md or _shared/) — a regression vector
 * because the loader reads skill.md only and does not follow links.
 *
 * Compares the current skill.md against test/ei-baseline.json:
 *   1. Every <EXTREMELY_IMPORTANT> block must still be present (normalized match)
 *   2. Every protected section (Hallucination Prevention, Incident Log/Record/
 *      History, References, Failure Modes) must still be present
 *   3. No protected block may shrink by more than 30% of its baseline char count
 *      (i.e., the block must retain at least 70% of its original length)
 *      without a reviewer waiver declared in the PR body (not the commit
 *      message — CI reads EI_WAIVERS from github.event.pull_request.body):
 *      "EI-WAIVER: <skill> -<pct>% — <reason>"
 *
 * Normalization: lowercase, collapse all whitespace runs to single space,
 * strip punctuation. Detects content moved with whitespace/punctuation drift
 * but rejects pure rewrites (different normalized content = MOVE+REWRITE = FAIL).
 *
 * To regenerate the baseline (requires explicit reviewer approval):
 *   node test/ei-move-detector.test.js --update
 *
 * Run: node test/ei-move-detector.test.js
 *
 * Exit 0 = pass, exit 1 = at least one move/shrink detected.
 */
'use strict';

const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
const { stripFrontmatter } = require('../lib/frontmatter');

const SKILLS_DIR = path.join(__dirname, '..', 'skills');
const BASELINE_PATH = path.join(__dirname, 'ei-baseline.json');
const SHRINK_FLOOR = 0.30; // 30% length-floor

const PROTECTED_HEADINGS = [
    'Hallucination Prevention',
    'Incident Log',
    'Incident Record',
    'Incident History',
    'References',
    'Failure Modes',
];

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

function normalize(s) {
    return s
        .toLowerCase()
        .replace(/[\p{P}\p{S}]/gu, ' ')   // strip punctuation/symbols
        .replace(/\s+/g, ' ')
        .trim();
}

function hash(s) {
    return crypto.createHash('sha256').update(s).digest('hex').slice(0, 16);
}

function extractEIBlocks(text) {
    const out = [];
    const re = /<EXTREMELY[_-]IMPORTANT(?:\s+name="([^"]*)")?>\n?([\s\S]*?)<\/EXTREMELY[_-]IMPORTANT>/g;
    let m, idx = 0;
    while ((m = re.exec(text)) !== null) {
        const inner = m[2].trim();
        if (inner) out.push({ kind: 'EI', name: m[1] || `block-${idx}`, content: inner });
        idx++;
    }
    return out;
}

function extractSections(text, heading) {
    const re = new RegExp(`^(#{2,4})\\s+${heading.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')}\\s*$`, 'gm');
    const out = [];
    let m;
    while ((m = re.exec(text)) !== null) {
        const level = m[1].length;
        const start = m.index + m[0].length;
        const nextRe = new RegExp(`^#{1,${level}}\\s`, 'gm');
        nextRe.lastIndex = start;
        const next = nextRe.exec(text);
        const content = text.slice(start, next ? next.index : text.length).trim();
        if (content) out.push({ kind: 'SEC', name: heading, content });
    }
    return out;
}

function extractAllProtectedBlocks(text) {
    const blocks = extractEIBlocks(text);
    for (const h of PROTECTED_HEADINGS) blocks.push(...extractSections(text, h));
    return blocks;
}

// --- Baseline generation ---

function buildBaseline() {
    const baseline = { generated_at: new Date().toISOString(), skills: {} };
    for (const skillPath of findAllSkills(SKILLS_DIR)) {
        const rel = path.relative(SKILLS_DIR, skillPath);
        const raw = stripFrontmatter(fs.readFileSync(skillPath, 'utf8'));
        const blocks = extractAllProtectedBlocks(raw);
        if (blocks.length === 0) continue;
        baseline.skills[rel] = blocks.map((b, i) => ({
            kind: b.kind,
            name: b.name,
            normalized_hash: hash(normalize(b.content)),
            length: b.content.length,
            first_line: (b.content.split('\n').find(l => l.trim().length > 10) || '').trim().slice(0, 120),
        }));
    }
    fs.writeFileSync(BASELINE_PATH, JSON.stringify(baseline, null, 2) + '\n');
    const total = Object.values(baseline.skills).reduce((n, a) => n + a.length, 0);
    console.log(`✅ Baseline written: ${Object.keys(baseline.skills).length} skills, ${total} protected blocks → ${path.relative(process.cwd(), BASELINE_PATH)}`);
}

// --- Waiver parsing ---

function loadWaivers() {
    // Read waivers from environment var EI_WAIVERS (newline-separated) so CI
    // can pass them via PR body extraction. Format:
    //   EI-WAIVER: <skill-rel-path> -<pct>% — <reason>
    const raw = process.env.EI_WAIVERS || '';
    const out = [];
    for (const line of raw.split('\n')) {
        const m = line.match(/EI-WAIVER:\s*(\S+)\s+-(\d+)%/);
        if (m) out.push({ skill: m[1], pct: parseInt(m[2], 10) });
    }
    return out;
}

function isWaived(waivers, skill) {
    return waivers.some(w => w.skill === skill);
}

// --- Detect ---

function detect() {
    if (!fs.existsSync(BASELINE_PATH)) {
        console.error(`❌ No baseline at ${BASELINE_PATH}. Run with --update first.`);
        process.exit(2);
    }
    const baseline = JSON.parse(fs.readFileSync(BASELINE_PATH, 'utf8'));
    const waivers = loadWaivers();
    let failures = [];
    let checked = 0;

    for (const [rel, expected] of Object.entries(baseline.skills)) {
        const skillPath = path.join(SKILLS_DIR, rel);
        if (!fs.existsSync(skillPath)) {
            // Skill file missing — treat as failure. Protected content is gone from the
            // loader's reach regardless of whether the file was deleted or archived.
            // Run --update to explicitly remove the skill from the baseline when
            // a deletion or archival is intentional.
            if (isWaived(waivers, rel)) continue;
            failures.push(
                `  FAIL: ${rel}: skill.md no longer exists. If intentional (deletion/archive), run --update to remove from baseline.`
            );
            continue;
        }
        const raw = stripFrontmatter(fs.readFileSync(skillPath, 'utf8'));
        const current = extractAllProtectedBlocks(raw);

        // Hash consumption map: tracks remaining instances of each hash so that
        // two baseline blocks with identical normalized content each need a surviving
        // counterpart (prevents a single surviving block from satisfying both checks).
        const currentHashCounts = new Map();
        for (const b of current) {
            const h = hash(normalize(b.content));
            currentHashCounts.set(h, (currentHashCounts.get(h) || 0) + 1);
        }

        // Name multimap: collects ALL current blocks per kind::name key so that
        // duplicate-named sections (e.g. two "Failure Modes" headings) are each
        // independently matchable rather than the last silently winning.
        const currentByNameGroups = new Map();
        for (const b of current) {
            const key = `${b.kind}::${b.name}`;
            if (!currentByNameGroups.has(key)) currentByNameGroups.set(key, []);
            currentByNameGroups.get(key).push(b);
        }
        // Per-name occurrence counter (reset per skill).
        const nameOccurrence = {};

        for (const exp of expected) {
            checked++;
            const key = `${exp.kind}::${exp.name}`;

            // Hash match: consume one instance so identical blocks aren't reused.
            const hashCount = currentHashCounts.get(exp.normalized_hash) || 0;
            if (hashCount > 0) {
                currentHashCounts.set(exp.normalized_hash, hashCount - 1);
                // Keep nameOccurrence aligned so that a second same-named block
                // (e.g. two "Failure Modes" headings) uses the correct position
                // index when its turn comes — not always group[0].
                nameOccurrence[key] = (nameOccurrence[key] || 0) + 1;
                continue; // identical normalized content present
            }

            // Name match: pick the occurrence at the same position as in the baseline.
            const occIdx = nameOccurrence[key] || 0;
            nameOccurrence[key] = occIdx + 1;
            const group = currentByNameGroups.get(key) || [];
            const matchByName = group[occIdx] || null;

            if (!matchByName) {
                if (isWaived(waivers, rel)) continue;
                failures.push(
                    `  FAIL: ${rel}: ${exp.kind} block "${exp.name}" disappeared (first line was: "${exp.first_line.slice(0, 60)}...")`
                );
                continue;
            }
            // Same name/position, different normalized content — likely rewrite.
            // Apply length floor.
            const shrink = 1 - matchByName.content.length / exp.length;
            if (shrink > SHRINK_FLOOR) {
                if (isWaived(waivers, rel)) continue;
                failures.push(
                    `  FAIL: ${rel}: ${exp.kind} block "${exp.name}" shrank ${(shrink * 100).toFixed(1)}% ` +
                    `(${exp.length} → ${matchByName.content.length} chars). Threshold ${(SHRINK_FLOOR * 100).toFixed(0)}%. ` +
                    `Add EI-WAIVER: ${rel} -${Math.ceil(shrink * 100)}% — <reason> if intentional.`
                );
            }
            // Within threshold: rewrites under length-floor are tolerated; pair with operative-move-detector.
        }
    }

    console.log(`\nChecked ${checked} protected blocks across ${Object.keys(baseline.skills).length} skills`);
    if (failures.length) {
        console.log(`\n${failures.length} failure(s):`);
        failures.forEach(f => console.log(f));
        process.exit(1);
    }
    console.log('✅ EI-move detector: ALL CHECKS PASSED');
}

// --- Main ---

const args = process.argv.slice(2);
if (args.includes('--update')) buildBaseline();
else detect();
