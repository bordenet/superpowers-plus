#!/usr/bin/env node
// Tests for tools/verify-cr-battery-evidence.js
// Exit-code contract: 0=all verified/unverifiable, 1=falsified, 2=usage/IO error

'use strict';

const { spawnSync } = require('child_process');
const fs = require('fs');
const os = require('os');
const path = require('path');

const SCRIPT = path.join(__dirname, '..', 'tools', 'verify-cr-battery-evidence.js');

if (!fs.existsSync(SCRIPT)) {
    console.error(`SKIP: script not found at ${SCRIPT}`);
    process.exit(0);
}

// TMP created after SKIP guard so it is never leaked on a skip-exit
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
    return { ...r, readBack, filePath: f };
}

let pass = 0, fail = 0;
// check(label, cond) — label first, condition second (distinct from assert(cond,msg) elsewhere)
function check(label, cond) {
    if (cond) { console.log(`  ✅ ${label}`); pass++; }
    else { console.error(`  ❌ FAIL: ${label}`); fail++; }
}

console.log('=== verify-cr-battery-evidence tests ===');

// --- Exit 2: usage errors ---
let r = spawnSync(process.execPath, [SCRIPT], { encoding: 'utf8' });
check('no args: exits 2', r.status === 2);

r = spawnSync(process.execPath, [SCRIPT, '/nonexistent/envelope.json'], { encoding: 'utf8' });
check('missing envelope: exits 2', r.status === 2);

r = spawnSync(process.execPath, [SCRIPT, '--cwd', '/nonexistent'], { encoding: 'utf8' });
check('no envelope path (only --cwd flag): exits 2 via usage()', r.status === 2);

// --- Exit 0: empty envelope ---
r = run(envelope());
check('empty envelope: exits 0', r.status === 0);
check('empty envelope: writes verifier_result', (() => {
    const e = r.readBack();
    return e.verifier_result && e.verifier_result.claims_total === 0;
})());

// --- Exit 0: exit_code verified ---
r = run(envelope([finding({ command: 'true', expectation: { type: 'exit_code', value: 0 } })]));
check('exit_code 0 (true): exits 0', r.status === 0);
check('exit_code 0: claims_verified=1', r.readBack().verifier_result.claims_verified === 1);

// --- Exit 1: exit_code falsified ---
r = run(envelope([finding({ command: 'false', expectation: { type: 'exit_code', value: 0 } })]));
check('exit_code 0 with false: exits 1 (falsified)', r.status === 1);
check('exit_code falsified: caps at 5.0', (() => {
    const caps = r.readBack().verifier_result.dimensions_capped;
    return caps.length === 1 && caps[0].cap === 5.0;
})());

// --- Exit 0: count >0 verified ---
r = run(envelope([finding({ command: 'echo hello', expectation: { type: 'count', value: '>0' } })]));
check('count >0 with echo: exits 0', r.status === 0);

// --- Exit 1: count ==0 falsified (echo produces 1 line) ---
r = run(envelope([finding({ command: 'echo hello', expectation: { type: 'count', value: '==0' } })]));
check('count ==0 with echo: exits 1 (falsified)', r.status === 1);

// --- Exit 0: count ==0 verified (true produces no output) ---
r = run(envelope([finding({ command: 'true', expectation: { type: 'count', value: '==0' } })]));
check('count ==0 with true: exits 0 (verified)', r.status === 0);

// --- Exit 0: match expectation verified ---
r = run(envelope([finding({ command: 'echo hello', expectation: { type: 'match', value: 'hello' } })]));
check('match "hello": exits 0', r.status === 0);

// --- Exit 1: match expectation falsified ---
r = run(envelope([finding({ command: 'echo world', expectation: { type: 'match', value: '^hello$' } })]));
check('match "^hello$" on "world": exits 1', r.status === 1);

// --- Exit 0: absent expectation (true produces no output) ---
r = run(envelope([finding({ command: 'true', expectation: { type: 'absent' } })]));
check('absent with true (no output): exits 0', r.status === 0);

// --- Exit 1: absent expectation falsified (echo has output) ---
r = run(envelope([finding({ command: 'echo x', expectation: { type: 'absent' } })]));
check('absent with echo: exits 1 (falsified)', r.status === 1);

// --- Exit 0: verifiable:false → unverifiable, caps at 7.0 ---
r = run(envelope([finding({
    command: 'true',
    expectation: { type: 'exit_code', value: 0 },
    verifiable: false,
    rationale: 'race condition; cannot replay deterministically',
})]));
check('verifiable:false: exits 0', r.status === 0);
check('verifiable:false: caps at 7.0', (() => {
    const caps = r.readBack().verifier_result.dimensions_capped;
    return caps.length === 1 && caps[0].cap === 7.0;
})());
check('verifiable:false: claims_unverifiable=1',
    r.readBack().verifier_result.claims_unverifiable === 1);

// --- Falsified dominates unverifiable (5.0 < 7.0) ---
r = run(envelope([
    finding({ command: 'false', expectation: { type: 'exit_code', value: 0 } }),  // falsified -> 5.0
    finding({ verifiable: false }),  // unverifiable -> 7.0
]));
check('falsified + unverifiable: falsified wins (exits 1)', r.status === 1);
check('falsified + unverifiable: cap is 5.0', (() => {
    const caps = r.readBack().verifier_result.dimensions_capped;
    return caps.some(c => c.cap === 5.0);
})());

// --- exact expectation ---
r = run(envelope([finding({ command: 'printf hello', expectation: { type: 'exact', value: 'hello' } })]));
check('exact "hello": exits 0', r.status === 0);

// --- custom --cwd ---
r = run(envelope([finding({ command: 'pwd', expectation: { type: 'count', value: '>0' } })]),
    ['--cwd', TMP]);
check('--cwd accepted: exits 0', r.status === 0);

// --- rewritten envelope ends with a trailing newline (harsh-review's file-ending
// check flags any tracked file without one; the verifier used to strip it on every
// annotation pass, so the FIRST re-run after a real battery write always failed a
// check that had nothing to do with the envelope's actual content) ---
r = run(envelope([finding({ command: 'true', expectation: { type: 'exit_code', value: 0 } })]));
check('rewritten envelope file ends with exactly one trailing newline', (() => {
    const raw = fs.readFileSync(r.filePath, 'utf8');
    return raw.endsWith('\n') && !raw.endsWith('\n\n');
})());

// --- Authoring traps that used to fail silently (diet2 / 2026-09-20) ---
// Each of these cost real time when hand-building envelopes. They are now
// accepted (bare count, ==N exit code, anchored match vs trailing newline) or
// rejected LOUDLY as 'error' -- never silently falsified.
{
    const { parseExpectation: pe } = require(path.join(__dirname, '..', 'tools', 'verify-cr-battery-evidence.js'));
    check('count: bare integer "2" means ==2', pe('a\nb\n', 0, { type: 'count', value: '2' }).status === 'verified');
    check('count: bare number 2 means ==2', pe('a\nb\n', 0, { type: 'count', value: 2 }).status === 'verified');
    check('count: bare "0" means ==0', pe('', 0, { type: 'count', value: '0' }).status === 'verified');
    check('count: bare "3" falsifies against 2 lines', pe('a\nb\n', 0, { type: 'count', value: '3' }).status === 'falsified');
    check('count: operator forms still work (>=1)', pe('a\n', 0, { type: 'count', value: '>=1' }).status === 'verified');
    check('count: garbage is still an explicit error', pe('a\n', 0, { type: 'count', value: 'lots' }).status === 'error');
    check('exit_code: "0" accepted', pe('', 0, { type: 'exit_code', value: '0' }).status === 'verified');
    check('exit_code: "==0" accepted', pe('', 0, { type: 'exit_code', value: '==0' }).status === 'verified');
    check('exit_code: non-integer is an explicit error, not a silent falsify',
        pe('', 0, { type: 'exit_code', value: 'zero' }).status === 'error');
    check('match: ^ok$ matches output "ok\\n" (trailing newline)', pe('ok\n', 0, { type: 'match', value: '^ok$' }).status === 'verified');
    check('match: only ONE terminal newline is stripped ("ok\\n\\n" is not "ok")', pe('ok\n\n', 0, { type: 'match', value: '^ok$' }).status === 'falsified');
    check('match: trailing-newline structure stays checkable', pe('foo\n', 0, { type: 'match', value: '[^\\n]$' }).status === 'verified'
        && pe('foo\n\n', 0, { type: 'match', value: '[^\\n]$' }).status === 'falsified');
    check('exit_code: empty string is an explicit error, not exit 0', pe('', 0, { type: 'exit_code', value: '' }).status === 'error');
    check('exit_code: whitespace is an explicit error', pe('', 0, { type: 'exit_code', value: '  ' }).status === 'error');
    check('exit_code: null is an explicit error', pe('', 0, { type: 'exit_code', value: null }).status === 'error');
    check('exit_code: 0x0 is an explicit error', pe('', 0, { type: 'exit_code', value: '0x0' }).status === 'error');
    check('match: anchoring still rejects extra content', pe('ok then more\n', 0, { type: 'match', value: '^ok$' }).status === 'falsified');
}

// Cleanup
try { fs.rmSync(TMP, { recursive: true }); } catch (_) {}

console.log(`\nverify-cr-battery-evidence: ${pass} passed, ${fail} failed`);
process.exit(fail > 0 ? 1 : 0);
