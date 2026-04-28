#!/usr/bin/env node
/**
 * Tokenize every skill.md under a target repo using tiktoken (cl100k_base —
 * closest public proxy for Anthropic's tokenizer). Emits a TSV inventory:
 *
 *   repo \t skill \t path \t chars \t tokens \t tokenizer
 *
 * Falls back to a chars/4 heuristic if tiktoken is unavailable; the
 * "tokenizer" column flags which estimator was used.
 *
 * Usage:
 *   node tools/tokenize-skills.js <repo-root>
 */
'use strict';

const fs = require('fs');
const path = require('path');

let encoder = null;
let tokenizerName = 'chars-fallback';
try {
    const { get_encoding } = require('tiktoken');
    encoder = get_encoding('cl100k_base');
    tokenizerName = 'tiktoken-cl100k_base';
} catch (e) {
    // Loud, unmissable warning. The fallback is a 4× ratio approximation —
    // tolerable for relative ranking, NOT for accurate token-budget claims.
    process.stderr.write(
        '\n' +
        '═══════════════════════════════════════════════════════════════════════\n' +
        '⚠️  tokenize-skills: tiktoken unavailable — falling back to chars/4 heuristic.\n' +
        '   Numbers in the output TSV will be approximate (typically off by 1.5×–2×).\n' +
        '   To get accurate counts:  npm install --no-save tiktoken\n' +
        `   (load error: ${e && e.code ? e.code : e && e.message ? e.message : 'unknown'})\n` +
        '═══════════════════════════════════════════════════════════════════════\n\n'
    );
    // Honor a strict-mode env var so CI can fail-loud instead of silently falling back.
    if (process.env.TOKENIZE_REQUIRE_TIKTOKEN === '1') {
        process.stderr.write('TOKENIZE_REQUIRE_TIKTOKEN=1 set — aborting rather than using fallback.\n');
        process.exit(2);
    }
}

function tokensFor(text) {
    if (encoder) return encoder.encode(text).length;
    return Math.ceil(text.length / 4);
}

function findAllSkills(dir) {
    const out = [];
    if (!fs.existsSync(dir)) return out;
    for (const e of fs.readdirSync(dir, { withFileTypes: true })) {
        if (e.name.startsWith('.')) continue;
        if (e.name === 'node_modules') continue;
        const full = path.join(dir, e.name);
        if (e.isDirectory()) out.push(...findAllSkills(full));
        else if (e.name === 'skill.md') out.push(full);
    }
    return out;
}

function detectSkillsRoot(repoRoot) {
    // Repo layout varies. Default: ./skills/. Otherwise, treat the repo root
    // itself as a skills directory and recurse — works for repos that put
    // skills at top-level. Override-able via --root argv (future).
    const skillsDir = path.join(repoRoot, 'skills');
    return fs.existsSync(skillsDir) ? [skillsDir] : [repoRoot];
}

function main() {
    const repoRoot = process.argv[2];
    if (!repoRoot) {
        console.error('Usage: node tools/tokenize-skills.js <repo-root>');
        process.exit(1);
    }
    const repoName = path.basename(repoRoot.replace(/\/$/, ''));
    const roots = detectSkillsRoot(repoRoot);
    const seen = new Set();
    const skills = [];
    for (const root of roots) {
        for (const sp of findAllSkills(root)) {
            // Skip _* prefixed paths (loader-skipped — already archived)
            const rel = path.relative(repoRoot, sp);
            if (rel.split(path.sep).some(seg => seg.startsWith('_'))) continue;
            if (seen.has(sp)) continue;
            seen.add(sp);
            skills.push(sp);
        }
    }

    // Header
    process.stdout.write(['repo','skill','path','chars','tokens','tokenizer'].join('\t') + '\n');

    let totalChars = 0, totalTokens = 0;
    for (const sp of skills) {
        const text = fs.readFileSync(sp, 'utf8');
        const skillName = path.basename(path.dirname(sp));
        const rel = path.relative(repoRoot, sp);
        const chars = text.length;
        const tokens = tokensFor(text);
        totalChars += chars;
        totalTokens += tokens;
        process.stdout.write([repoName, skillName, rel, chars, tokens, tokenizerName].join('\t') + '\n');
    }
    process.stdout.write(['#TOTAL', repoName, skills.length + ' skills', totalChars, totalTokens, tokenizerName].join('\t') + '\n');
    if (encoder) encoder.free();
}

main();
