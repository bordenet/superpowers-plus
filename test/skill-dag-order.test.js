#!/usr/bin/env node
/**
 * Regression tests for tools/generate-skill-dag.js coordination.order sorting.
 * Run: node test/skill-dag-order.test.js
 *
 * The bug these lock down: the group sort was `(a.coordination.order || 99)`,
 * which treats the legitimate value 0 as "unset". All 14 hub skills in the
 * corpus declare `order: 0`, so every one of them sorted LAST in its own
 * group instead of first -- visible live in docs/skill-dependency-graph.md,
 * where the Thinking row listed `thinking-orchestrator` (the hub) last.
 *
 * A second, latent bug: the frontmatter parser's `/^\d+$/` numeric test matched
 * neither a negative integer nor a decimal, so `order: -5` (the two push
 * authorization gates) and `order: 2.5` (the wiki pipeline's inserted stages)
 * both parsed to STRINGS. Any typeof-number check would have silently demoted
 * those to the default. The corpus invariant at the bottom of this file is the
 * guard: it fails the moment a declared order stops parsing to a number.
 */

'use strict';

const { compareCoordinationOrder, coordinationOrderOf, parseFrontmatter } = require('../tools/generate-skill-dag.js');
const fs = require('fs');
const path = require('path');

let pass = 0;
let fail = 0;

function assert(condition, msg) {
    if (condition) { pass++; console.log(`  ✅ ${msg}`); }
    else { fail++; console.log(`  ❌ ${msg}`); }
}
function eq(a, b, msg) { assert(a === b, `${msg} (got: ${JSON.stringify(a)}, want: ${JSON.stringify(b)})`); }

function skill(name, order) {
    return { name, coordination: order === undefined ? {} : { order } };
}
function sortedNames(list) {
    return list.slice().sort(compareCoordinationOrder).map(s => s.name);
}

// --- coordinationOrderOf ---
console.log('\n--- coordinationOrderOf ---');
eq(coordinationOrderOf(skill('a', 0)), 0, 'order 0 is a real value, not "unset"');
eq(coordinationOrderOf(skill('a', 1)), 1, 'positive integer order');
eq(coordinationOrderOf(skill('a', -5)), -5, 'negative integer order');
eq(coordinationOrderOf(skill('a', '-5')), -5, 'negative order stored as a string still coerces');
eq(coordinationOrderOf(skill('a', '3')), 3, 'numeric string order coerces');
eq(coordinationOrderOf(skill('a', undefined)), 99, 'absent order defaults to 99 (sorts last)');
eq(coordinationOrderOf(skill('a', '')), 99, 'empty order defaults to 99');
eq(coordinationOrderOf(skill('a', 'abc')), 99, 'non-numeric order defaults to 99');
eq(coordinationOrderOf({ name: 'a' }), 99, 'missing coordination block defaults to 99');

// --- compareCoordinationOrder: the actual regression ---
console.log('\n--- compareCoordinationOrder ---');
eq(
    sortedNames([skill('zeta', 5), skill('hub', 0), skill('alpha', 2)]).join(','),
    'hub,alpha,zeta',
    'REGRESSION: order 0 sorts FIRST, not last'
);
eq(
    sortedNames([skill('normal', 1), skill('gate', -5), skill('hub', 0)]).join(','),
    'gate,hub,normal',
    'negative order sorts ahead of 0 and of the rest of the group'
);
eq(
    sortedNames([skill('normal', 1), skill('gate', '-5'), skill('hub', 0)]).join(','),
    'gate,hub,normal',
    'string-valued negative order sorts correctly too'
);
eq(
    sortedNames([skill('debate', 1), skill('brainstorming', 1)]).join(','),
    'brainstorming,debate',
    'duplicate order resolves alphabetically, per docs/DESIGN.md'
);
eq(
    sortedNames([skill('b', 1), skill('a', 1), skill('c', 1)]).join(','),
    'a,b,c',
    'tie-break is deterministic regardless of input order'
);
eq(
    sortedNames([skill('late', undefined), skill('early', 9)]).join(','),
    'early,late',
    'absent order sorts after an explicit high order'
);
eq(
    sortedNames([skill('after', 3), skill('between', 2.5), skill('before', 2)]).join(','),
    'before,between,after',
    'fractional order slots between two bands (wiki-pipeline uses 0.5/2.5/5.5)'
);

// --- Corpus invariant: every declared order actually parses to a number ---
console.log('\n--- corpus invariant ---');
const SKILLS_DIR = path.join(__dirname, '..', 'skills');
const offenders = [];
let zeroCount = 0;
let negCount = 0;
let checked = 0;

function walk(dir) {
    for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
        const full = path.join(dir, entry.name);
        if (entry.isDirectory()) { walk(full); continue; }
        if (entry.name !== 'skill.md') continue;
        const fm = parseFrontmatter(fs.readFileSync(full, 'utf8'));
        if (!fm || !fm.coordination || fm.coordination.order === undefined) continue;
        checked++;
        const raw = fm.coordination.order;
        if (typeof raw !== 'number') offenders.push(`${path.relative(SKILLS_DIR, full)} -> ${JSON.stringify(raw)}`);
        if (raw === 0) zeroCount++;
        if (Number(raw) < 0) negCount++;
    }
}
walk(SKILLS_DIR);

assert(checked > 100, `scanned the real corpus (${checked} skills declare coordination.order)`);
assert(zeroCount > 0, `corpus actually exercises order: 0 (${zeroCount} skills) -- the regression case is live`);
assert(negCount > 0, `corpus actually exercises a negative order (${negCount} skills)`);
eq(offenders.length, 0, `every declared order parses to a number${offenders.length ? ': ' + offenders.join(', ') : ''}`);

console.log(`\n${pass} passed, ${fail} failed`);
process.exit(fail === 0 ? 0 : 1);
