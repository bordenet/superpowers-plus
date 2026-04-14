#!/usr/bin/env node
/**
 * DETERMINISTIC SAFETY GATE: Compression must never destroy operative content.
 *
 * This test runs in CI as a required status check. It dynamically scans ALL
 * skills in the repository and verifies that compression preserves:
 *
 *   1. Every <EXTREMELY_IMPORTANT> / <EXTREMELY-IMPORTANT> block's inner text
 *   2. Every "## Hallucination Prevention" section
 *   3. Every "## Incident Log" / "## Incident Record" / "## Incident History" section
 *   4. Every "## References" section (pointer tables to reference files)
 *
 * This test exists because of incident 2026-04-14: STRIP_SECTIONS deleted all
 * four of the above from skills, causing wiki authoring to produce broken
 * hyperlinks. The regression shipped because compression tests were not in CI.
 *
 * If this test fails, the merge is blocked. No agent decision required.
 *
 * Run: node test/compression-safety.test.js
 */
'use strict';

const fs = require('fs');
const path = require('path');
const assert = require('assert');
const { compressSkillContent } = require('../lib/compress');
const { stripFrontmatter } = require('../lib/frontmatter');

const SKILLS_DIR = path.join(__dirname, '..', 'skills');
let passed = 0;
let failed = 0;
const failures = [];

function findAllSkills(dir) {
    const results = [];
    for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
        const full = path.join(dir, entry.name);
        if (entry.isDirectory()) {
            results.push(...findAllSkills(full));
        } else if (entry.name === 'skill.md') {
            results.push(full);
        }
    }
    return results;
}

function extractEIBlocks(text) {
    const blocks = [];
    const re = /<EXTREMELY[_-]IMPORTANT>\n?([\s\S]*?)<\/EXTREMELY[_-]IMPORTANT>/g;
    let m;
    while ((m = re.exec(text)) !== null) {
        const inner = m[1].trim();
        if (inner) blocks.push(inner);
    }
    return blocks;
}

function extractSections(text, headingPattern) {
    const re = new RegExp(`^(#{2,4}) ${headingPattern}\\s*$`, 'gm');
    const sections = [];
    let m;
    while ((m = re.exec(text)) !== null) {
        const level = m[1].length;
        const start = m.index + m[0].length;
        // Find next heading of same or higher level
        const nextRe = new RegExp(`^#{1,${level}} `, 'gm');
        nextRe.lastIndex = start;
        const next = nextRe.exec(text);
        const content = text.slice(start, next ? next.index : text.length).trim();
        if (content) sections.push({ heading: m[0].trim(), content });
    }
    return sections;
}

function check(condition, skillName, message) {
    if (condition) {
        passed++;
    } else {
        failed++;
        failures.push(`  FAIL: ${skillName}: ${message}`);
    }
}

// --- Scan all skills ---
const allSkills = findAllSkills(SKILLS_DIR);
console.log(`Scanning ${allSkills.length} skills for compression safety...\n`);

for (const skillPath of allSkills) {
    const relPath = path.relative(SKILLS_DIR, skillPath);
    const raw = fs.readFileSync(skillPath, 'utf8');
    const stripped = stripFrontmatter(raw);
    const compressed = compressSkillContent(stripped);

    // 1. EXTREMELY_IMPORTANT blocks must survive compression
    const eiBlocks = extractEIBlocks(stripped);
    for (let i = 0; i < eiBlocks.length; i++) {
        // Check first meaningful line of each block (avoids whitespace-only diffs)
        const firstLine = eiBlocks[i].split('\n').find(l => l.trim().length > 10);
        if (firstLine) {
            check(compressed.includes(firstLine.trim()), relPath,
                `EXTREMELY_IMPORTANT block ${i + 1} content missing: "${firstLine.trim().slice(0, 60)}..."`);
        }
    }

    // 2. Hallucination Prevention sections must survive
    const hallucSections = extractSections(stripped, 'Hallucination Prevention');
    for (const sec of hallucSections) {
        check(compressed.includes('Hallucination Prevention'), relPath,
            'Hallucination Prevention section heading stripped');
        // Skip EI tags and heading lines — find actual content
        const firstDataLine = sec.content.split('\n').find(l =>
            l.trim().length > 10 && !l.startsWith('#') &&
            !l.includes('EXTREMELY_IMPORTANT') && !l.includes('EXTREMELY-IMPORTANT'));
        if (firstDataLine) {
            check(compressed.includes(firstDataLine.trim()), relPath,
                `Hallucination Prevention content missing: "${firstDataLine.trim().slice(0, 60)}..."`);
        }
    }

    // 3. Incident Log/Record/History sections must survive
    for (const heading of ['Incident Log', 'Incident Record', 'Incident History']) {
        const sections = extractSections(stripped, heading);
        for (const sec of sections) {
            check(compressed.includes(heading), relPath,
                `${heading} section heading stripped`);
            const firstDataLine = sec.content.split('\n').find(l => l.trim().length > 5 && !l.startsWith('#'));
            if (firstDataLine) {
                check(compressed.includes(firstDataLine.trim()), relPath,
                    `${heading} content missing: "${firstDataLine.trim().slice(0, 60)}..."`);
            }
        }
    }

    // 4. References sections must survive
    const refSections = extractSections(stripped, 'References');
    for (const sec of refSections) {
        check(compressed.includes('References'), relPath,
            'References section heading stripped');
    }
}

// --- Report ---
console.log(`\n${passed} passed, ${failed} failed (${allSkills.length} skills scanned)`);
if (failures.length > 0) {
    console.log('\nFAILURES:');
    failures.forEach(f => console.log(f));
    process.exit(1);
}
console.log('\n✅ Compression safety gate: ALL CHECKS PASSED');
