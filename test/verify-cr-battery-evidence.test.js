#!/usr/bin/env node
// Tests for tools/verify-cr-battery-evidence.js
// Exit-code contract: 0=all verified/unverifiable, 1=falsified, 2=usage/IO error

'use strict';

const { spawnSync } = require('child_process');
const fs = require('fs');
const os = require('os');
const path = require('path');

const SCRIPT = path.join(__dirname, '..', 'tools', 'verify-cr-battery-evidence.js');
const TMP = fs.mkdtempSync(path.join(os.tmpdir(), 'cr-verify-test-'));

function envelope(findings = [], clean_dimensions = []) {
    return { findings, clean_dimensions };
}

function finding(opts) {
    return {
        claim: opts.claim || 'test claim',
        reviewer: opts.reviewer || 'TestReviewer',
        dimension: opts.dimension || 'correctness',
        evidence: {
            command: opts.command || 'true',
            expectation: opts.expectation || { type: 'exit_code', value: 0 },
            verifiable: opts.verifiable !== undefined ? opts.verifiable : true,
            ...(opts.rationale ? { rationale: opts.rationale } : {}),
        },
    };
}

let counter = 0;
function run(env, args = []) {
    const f = path.join(TMP, `env_${counter++}.json`);
    fs.writeFileSync(f, JSON.stringify(env));
    const r = spawnSync(process.execPath, [SCRIPT, f, ...args], {
        encoding: 'utf8', cwd: TMP,
    });
    const readBack = () => JSON.parse(fs.readFileSync(f, 'utf8'));
    return { ...r, readBack };
}

let pass = 0, fail = 0;
function assert(label, cond) {
    if (cond) { console.log(`  ✅ ${label}`); pass++; }
    else { console.error(`  ❌ FAIL: ${label}`); fail++; }
}

console.log('=== verify-cr-battery-evidence tests ===');

// --- Exit 2: usage errors ---
let r = spawnSync(process.execPath, [SCRIPT], { encoding: 'utf8' });
assert('no args: exits 2', r.status === 2);

r = spawnSync(process.execPath, [SCRIPT, '/nonexistent/envelope.json'], { encoding: 'utf8' });
assert('missing envelope: exits 2', r.status === 2);

r = spawnSync(process.execPath, [SCRIPT, '--cwd', '/nonexistent'], { encoding: 'utf8' });
assert('unknown arg (--cwd before envelope): exits 2', r.status === 2);

// --- Exit 0: empty envelope ---
r = run(envelope());
assert('empty envelope: exits 0', r.status === 0);
assert('empty envelope: writes verifier_result', (() => {
    const e = r.readBack();
    return e.verifier_result && e.verifier_result.claims_total === 0;
})());

// --- Exit 0: exit_code verified ---
r = run(envelope([finding({ command: 'true', expectation: { type: 'exit_code', value: 0 } })]));
assert('exit_code 0 (true): exits 0', r.status === 0);
assert('exit_code 0: claims_verified=1', r.readBack().verifier_result.claims_verified === 1);

// --- Exit 1: exit_code falsified ---
r = run(envelope([finding({ command: 'false', expectation: { type: 'exit_code', value: 0 } })]));
assert('exit_code 0 with false: exits 1 (falsified)', r.status === 1);
assert('exit_code falsified: caps at 5.0', (() => {
    const caps = r.readBack().verifier_result.dimensions_capped;
    return caps.length === 1 && caps[0].cap === 5.0;
})());

// --- Exit 0: count >0 verified ---
r = run(envelope([finding({ command: 'echo hello', expectation: { type: 'count', value: '>0' } })]));
assert('count >0 with echo: exits 0', r.status === 0);

// --- Exit 1: count ==0 falsified (echo produces 1 line) ---
r = run(envelope([finding({ command: 'echo hello', expectation: { type: 'count', value: '==0' } })]));
assert('count ==0 with echo: exits 1 (falsified)', r.status === 1);

// --- Exit 0: count ==0 verified (true produces no output) ---
r = run(envelope([finding({ command: 'true', expectation: { type: 'count', value: '==0' } })]));
assert('count ==0 with true: exits 0 (verified)', r.status === 0);

// --- Exit 0: match expectation verified ---
r = run(envelope([finding({ command: 'echo hello', expectation: { type: 'match', value: 'hello' } })]));
assert('match "hello": exits 0', r.status === 0);

// --- Exit 1: match expectation falsified ---
r = run(envelope([finding({ command: 'echo world', expectation: { type: 'match', value: '^hello$' } })]));
assert('match "^hello$" on "world": exits 1', r.status === 1);

// --- Exit 0: absent expectation (true produces no output) ---
r = run(envelope([finding({ command: 'true', expectation: { type: 'absent' } })]));
assert('absent with true (no output): exits 0', r.status === 0);

// --- Exit 1: absent expectation falsified (echo has output) ---
r = run(envelope([finding({ command: 'echo x', expectation: { type: 'absent' } })]));
assert('absent with echo: exits 1 (falsified)', r.status === 1);

// --- Exit 0: verifiable:false → unverifiable, caps at 7.0 ---
r = run(envelope([finding({
    command: 'true',
    expectation: { type: 'exit_code', value: 0 },
    verifiable: false,
    rationale: 'race condition; cannot replay deterministically',
})]));
assert('verifiable:false: exits 0', r.status === 0);
assert('verifiable:false: caps at 7.0', (() => {
    const caps = r.readBack().verifier_result.dimensions_capped;
    return caps.length === 1 && caps[0].cap === 7.0;
})());
assert('verifiable:false: claims_unverifiable=1',
    r.readBack().verifier_result.claims_unverifiable === 1);

// --- Falsified dominates unverifiable (5.0 < 7.0) ---
r = run(envelope([
    finding({ command: 'false', expectation: { type: 'exit_code', value: 0 } }),  // falsified -> 5.0
    finding({ verifiable: false }),  // unverifiable -> 7.0
]));
assert('falsified + unverifiable: falsified wins (exits 1)', r.status === 1);
assert('falsified + unverifiable: cap is 5.0', (() => {
    const caps = r.readBack().verifier_result.dimensions_capped;
    return caps.some(c => c.cap === 5.0);
})());

// --- exact expectation ---
r = run(envelope([finding({ command: 'printf hello', expectation: { type: 'exact', value: 'hello' } })]));
assert('exact "hello": exits 0', r.status === 0);

// --- custom --cwd ---
r = run(envelope([finding({ command: 'pwd', expectation: { type: 'count', value: '>0' } })]),
    ['--cwd', TMP]);
assert('--cwd accepted: exits 0', r.status === 0);

// Cleanup
try { fs.rmSync(TMP, { recursive: true }); } catch (_) {}

console.log(`\nverify-cr-battery-evidence: ${pass} passed, ${fail} failed`);
process.exit(fail > 0 ? 1 : 0);
