#!/usr/bin/env node
/**
 * Programmatic first-pass classifier for OP/DEC/COMP content blocks.
 *
 * Reads each in-scope skill, walks heading-by-heading, assigns a default tag:
 *   - OP   : operative — procedure, gate, trigger, failure mode, EI block,
 *            hallucination prev, incident log/record, references, checklists
 *   - DEC  : decoration — long rationale, historical context, motivation,
 *            full case study, alternatives-considered
 *   - COMP : compressible-in-place — verbose narrative for an OP block
 *
 * Heuristic rules (best-effort; reviewer must confirm):
 *   - EI blocks → OP
 *   - "## Hallucination Prevention" / "## Incident Log/Record/History" /
 *     "## Failure Modes" / "## References" → OP
 *   - Headings containing: "Step", "Stage", "Phase", "Gate", "Procedure",
 *     "How to", "Checklist", "Run:", "Wire", "Verify" → OP
 *   - Headings containing: "Why", "Background", "History", "Rationale",
 *     "Motivation", "Context" (alone) → DEC candidate
 *   - Other body sections with paragraph-heavy prose, low list density,
 *     low code-fence count → COMP candidate
 *   - Otherwise → OP (conservative default — fail-closed for safety)
 *
 * Output: tools/optimization-classification.tsv (skill, section, lines,
 * tag, line-range, reviewer-status).
 *
 * Run: node tools/classify-skill-blocks.js
 */
'use strict';

const fs = require('fs');
const path = require('path');
const { stripFrontmatter } = require('../lib/frontmatter');

const SKILLS_DIR = path.join(__dirname, '..', 'skills');
const OUT = path.join(__dirname, 'optimization-classification.tsv');

const IN_SCOPE = [
    'readme-authoring', 'debug-conductor', 'code-review-battery',
    'progressive-code-review-gate', 'feature-development',
    'thinking-orchestrator', 'plan-and-execute', 'sp-bughunt',
    'autonomous-chain-controller', 'progressive-harsh-review',
    'investigation-state', 'think-twice', 'debate',
];

const OP_HEADING_KEYWORDS = [
    'hallucination prevention', 'incident log', 'incident record',
    'incident history', 'failure modes', 'references', 'step ', 'stage ',
    'phase ', 'gate', 'procedure', 'how to', 'checklist', 'run:', 'wire',
    'verify', 'verification', 'when to use', 'when not', 'red flags',
    'instructions', 'rules', 'guardrails',
];
const DEC_HEADING_KEYWORDS = [
    'background', 'history', 'rationale', 'motivation', 'why prior',
    'historical', 'alternatives considered', 'design notes',
    'philosophy', 'further reading',
];

function findSkill(name) {
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

function parseSections(body) {
    const lines = body.split('\n');
    const sections = [];
    let cur = null;
    let inEI = false;
    let eiStart = -1;

    for (let i = 0; i < lines.length; i++) {
        const ln = lines[i];

        // Track EI blocks separately (cross heading boundaries)
        if (/<EXTREMELY[_-]IMPORTANT/.test(ln)) {
            inEI = true;
            eiStart = i;
        }
        if (/<\/EXTREMELY[_-]IMPORTANT>/.test(ln) && inEI) {
            sections.push({ heading: 'EI BLOCK', start: eiStart + 1, end: i + 1, level: 0, ei: true });
            inEI = false;
        }

        const h = ln.match(/^(#{2,4})\s+(.+?)\s*$/);
        if (h) {
            if (cur) {
                cur.end = i;
                sections.push(cur);
            }
            cur = { heading: h[2], start: i + 1, level: h[1].length, end: -1, ei: false };
        }
    }
    if (cur) {
        cur.end = lines.length;
        sections.push(cur);
    }
    return sections;
}

function classify(section, sectionText) {
    if (section.ei) return 'OP';
    const h = section.heading.toLowerCase();
    if (OP_HEADING_KEYWORDS.some(k => h.includes(k))) return 'OP';
    if (DEC_HEADING_KEYWORDS.some(k => h.includes(k))) return 'DEC';
    // Density heuristics for unknown headings
    const lines = sectionText.split('\n');
    const bullet = lines.filter(l => /^\s*[-*]\s/.test(l)).length;
    const codeFences = (sectionText.match(/^```/gm) || []).length;
    const tableRow = lines.filter(l => /^\s*\|/.test(l)).length;
    const proseLines = lines.filter(l => l.trim() && !/^\s*[-*|#`>]/.test(l)).length;
    const opSignal = bullet + codeFences + tableRow;
    if (opSignal >= 4) return 'OP';
    if (proseLines >= 8 && opSignal <= 1) return 'COMP'; // verbose prose, candidate for densification
    return 'OP'; // conservative default
}

function blockChars(body, section) {
    return body.split('\n').slice(section.start, section.end).join('\n').length;
}

const rows = ['skill\tsection_heading\tlevel\tline_start\tline_end\ttag\tchars\treviewer_status'];
const summary = {};

for (const name of IN_SCOPE) {
    const sp = findSkill(name);
    if (!sp) {
        rows.push(`${name}\tNOT_FOUND\t0\t0\t0\tERR\t0\tunverified`);
        continue;
    }
    const body = stripFrontmatter(fs.readFileSync(sp, 'utf8'));
    const sections = parseSections(body);
    summary[name] = { OP: 0, DEC: 0, COMP: 0 };
    for (const s of sections) {
        const sText = body.split('\n').slice(s.start, s.end).join('\n');
        const tag = classify(s, sText);
        const chars = blockChars(body, s);
        summary[name][tag] += chars;
        rows.push(
            `${name}\t${s.heading.replace(/\t/g, ' ')}\t${s.level}\t${s.start}\t${s.end}\t${tag}\t${chars}\tunverified`
        );
    }
}

fs.writeFileSync(OUT, rows.join('\n') + '\n');
console.log(`✅ Classification written: ${rows.length - 1} sections → ${path.relative(process.cwd(), OUT)}\n`);

// Aggregate summary
console.log('Per-skill char totals by tag:');
console.log('skill\tOP\tDEC\tCOMP\tDEC+COMP\ttotal');
let totalDC = 0, totalAll = 0;
for (const [name, sums] of Object.entries(summary)) {
    const dc = sums.DEC + sums.COMP;
    const tot = sums.OP + sums.DEC + sums.COMP;
    totalDC += dc;
    totalAll += tot;
    console.log(`${name}\t${sums.OP}\t${sums.DEC}\t${sums.COMP}\t${dc}\t${tot}`);
}
console.log(`\nAggregate: DEC+COMP = ${totalDC} chars, total = ${totalAll} chars (${(100 * totalDC / totalAll).toFixed(1)}%)`);
console.log(`Approx tokens: DEC+COMP ≈ ${Math.round(totalDC / 4)}, total ≈ ${Math.round(totalAll / 4)} (using 4 chars/token rough)`);
