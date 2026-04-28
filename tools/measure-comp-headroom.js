#!/usr/bin/env node
/**
 * Paragraph-level COMP-headroom measurement.
 *
 * Section-level classification (classify-skill-blocks.js) tags whole sections
 * as OP/DEC/COMP. But the realistic compression headroom in heavily-operative
 * skills is at the paragraph level: filler words, verbose phrasings, repeated
 * scaffolding inside OP sections. Apr-17 wiki Haiku conversion achieved -37%
 * via paragraph-level filler-trim, not section-level moves.
 *
 * This script measures filler-trim headroom per-skill by counting:
 *   - Filler-word density: instances of common filler phrases
 *   - Long-paragraph candidates: prose paragraphs >40 words (likely tightenable)
 *   - Redundant-phrase signals: "in order to", "you should", "please", etc.
 *
 * Output prints estimated reducible chars per skill and aggregate. Used as
 * input to the P0.7 economics decision gate.
 *
 * Run: node tools/measure-comp-headroom.js
 */
'use strict';

const fs = require('fs');
const path = require('path');
const { stripFrontmatter } = require('../lib/frontmatter');

const SKILLS_DIR = path.join(__dirname, '..', 'skills');
const IN_SCOPE = [
    'readme-authoring', 'debug-conductor', 'code-review-battery',
    'progressive-code-review-gate', 'feature-development',
    'thinking-orchestrator', 'plan-and-execute', 'sp-bughunt',
    'autonomous-chain-controller', 'progressive-harsh-review',
    'investigation-state', 'think-twice', 'debate',
];

const FILLER_PATTERNS = [
    /\bin order to\b/gi, /\byou should\b/gi, /\byou will\b/gi,
    /\bplease\b/gi, /\bbasically\b/gi, /\bin essence\b/gi,
    /\bit is important to\b/gi, /\bnote that\b/gi,
    /\bmake sure to\b/gi, /\bbe sure to\b/gi,
    /\bessentially\b/gi, /\bobviously\b/gi,
    /\bin general\b/gi, /\bgenerally speaking\b/gi,
    /\bwhich means that\b/gi, /\bthis means that\b/gi,
    /\bin terms of\b/gi, /\bas a matter of fact\b/gi,
];
// Average chars saved per filler-phrase removal (conservative)
const CHARS_PER_FILLER = 8;

const LONG_PARA_THRESHOLD = 40; // words
const LONG_PARA_REDUCIBLE = 0.15; // assume 15% reducible from prose paragraphs

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

function measure(body) {
    let fillerHits = 0;
    for (const re of FILLER_PATTERNS) fillerHits += (body.match(re) || []).length;
    const fillerSaving = fillerHits * CHARS_PER_FILLER;

    // Long paragraphs (excluding code blocks, tables, lists)
    const out = [];
    let inCode = false;
    let para = [];
    function flush() {
        if (!para.length) return;
        const t = para.join(' ').trim();
        if (t && t.split(/\s+/).length >= LONG_PARA_THRESHOLD) {
            out.push(t.length);
        }
        para = [];
    }
    for (const ln of body.split('\n')) {
        if (/^```/.test(ln)) { inCode = !inCode; flush(); continue; }
        if (inCode) continue;
        if (!ln.trim()) { flush(); continue; }
        if (/^\s*[-*|#>]/.test(ln)) { flush(); continue; }
        para.push(ln);
    }
    flush();
    const longParaChars = out.reduce((a, b) => a + b, 0);
    const longParaSaving = Math.round(longParaChars * LONG_PARA_REDUCIBLE);

    return {
        total_chars: body.length,
        filler_hits: fillerHits,
        filler_saving: fillerSaving,
        long_paras: out.length,
        long_para_chars: longParaChars,
        long_para_saving: longParaSaving,
        total_saving: fillerSaving + longParaSaving,
    };
}

console.log('skill\ttotal\tfiller_hits\tfiller_save\tlong_paras\tlong_para_chars\tlong_para_save\ttotal_save\tpct');
let aggTotal = 0, aggSave = 0;
for (const name of IN_SCOPE) {
    const sp = findSkill(name);
    if (!sp) { console.log(`${name}\tNOT_FOUND`); continue; }
    const body = stripFrontmatter(fs.readFileSync(sp, 'utf8'));
    const m = measure(body);
    aggTotal += m.total_chars;
    aggSave += m.total_saving;
    const pct = (100 * m.total_saving / m.total_chars).toFixed(1);
    console.log(`${name}\t${m.total_chars}\t${m.filler_hits}\t${m.filler_saving}\t${m.long_paras}\t${m.long_para_chars}\t${m.long_para_saving}\t${m.total_saving}\t${pct}%`);
}
console.log(`\nAggregate: ${aggTotal} chars total, ${aggSave} reducible chars (${(100 * aggSave / aggTotal).toFixed(1)}%)`);
console.log(`Approx tokens: ${Math.round(aggTotal / 4)} total, ${Math.round(aggSave / 4)} reducible (4 chars/token rough)`);
