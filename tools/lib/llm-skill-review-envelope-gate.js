#!/usr/bin/env node
/**
 * ADR-003 envelope gate for llm-skill-review sentinel writes.
 *
 * Usage: node tools/lib/llm-skill-review-envelope-gate.js <envelope.json> \
 *          --head-sha <sha> [--allow-s0-waiver]
 *
 * --head-sha is REQUIRED and is compared against the envelope's own head_sha.
 * The envelope FILENAME also carries a SHA, but a filename is not an assertion:
 * `cp <reviewed-sha>.json <unreviewed-sha>.json` is enough to replay a clean
 * review onto code nobody looked at, and Gate 6 only checks that the resulting
 * sentinel names the commit being pushed -- which a replayed envelope satisfies.
 * Binding inside the body means forging it requires writing a false statement
 * rather than copying a file.
 *
 * Exit 0: envelope OK for sentinel write (prints unresolved_s0_s1=0 summary line)
 * Exit 1: refuse (prints ERROR reason on stderr)
 */
'use strict';

const fs = require('fs');

function fail(msg) {
  process.stderr.write('ERROR: ' + msg + '\n');
  process.exit(1);
}

const args = process.argv.slice(2);
if (args.length < 1) {
  fail(
    'usage: llm-skill-review-envelope-gate.js <envelope.json> --head-sha <sha> [--allow-s0-waiver]'
  );
}

let allowS0 = false;
let headSha = '';
let path = '';

for (let i = 0; i < args.length; i++) {
  const a = args[i];
  if (a === '--allow-s0-waiver') {
    allowS0 = true;
  } else if (a === '--head-sha') {
    headSha = args[++i] || '';
  } else if (a.startsWith('--head-sha=')) {
    headSha = a.slice('--head-sha='.length);
  } else if (a.startsWith('--')) {
    fail("unknown flag '" + a + "'");
  } else if (!path) {
    path = a;
  } else {
    fail("unexpected extra argument '" + a + "'");
  }
}

if (!path) fail('envelope path required');
if (!headSha.trim()) {
  fail(
    '--head-sha <sha> is required. Without it the envelope is bound to nothing ' +
      'but its filename, and a filename can be copied (ADR-003 §2).'
  );
}

let env;
try {
  env = JSON.parse(fs.readFileSync(path, 'utf8'));
} catch (e) {
  fail('cannot parse envelope JSON: ' + e.message);
}

if (!env || typeof env !== 'object') fail('envelope must be a JSON object');

if (typeof env.head_sha !== 'string' || !env.head_sha.trim()) {
  fail(
    'envelope.head_sha missing: the envelope must name the commit it reviewed. ' +
      'Add "head_sha": "<sha>" (ADR-003 §2)'
  );
}
if (env.head_sha.trim() !== headSha.trim()) {
  const abbreviated =
    headSha.trim().startsWith(env.head_sha.trim()) && env.head_sha.trim().length < 40;
  fail(
    'envelope.head_sha (' + env.head_sha.trim() + ') does not match the commit ' +
      'being cleared (' + headSha.trim() + '). ' +
      (abbreviated
        ? 'It looks abbreviated -- use the full 40-character `git rev-parse HEAD`.'
        : 'This envelope reviewed different code; re-review at HEAD rather than ' +
          'reusing it') +
      ' (ADR-003 §2)'
  );
}

const findings = Array.isArray(env.findings) ? env.findings : null;
const clean = Array.isArray(env.clean_dimensions) ? env.clean_dimensions : null;
if (!findings) fail('envelope.findings must be an array');
if (!clean) fail('envelope.clean_dimensions must be an array');

// ADR-003 §4 requires clean_dimensions "with replayable evidence covering at
// least one scored axis" -- a non-empty array is not that. A bare string, or a
// set where every entry is verifiable:false, asserts cleanliness without ever
// having checked anything, which is the exact posture the ADR exists to reject.
const replayableClean = clean.filter(
  (d) =>
    d &&
    typeof d === 'object' &&
    !Array.isArray(d) &&
    d.evidence &&
    typeof d.evidence === 'object' &&
    d.evidence.verifiable === true &&
    typeof d.evidence.command === 'string' &&
    d.evidence.command.trim() !== ''
);

if (replayableClean.length < 1) {
  fail(
    'non-vacuous review proof required: at least one clean_dimensions entry must ' +
      'carry replayable evidence ({"evidence":{"command":"...","verifiable":true}}). ' +
      'Got ' + clean.length + ' entry/entries, none replayable. Bare strings and ' +
      'all-unverifiable sets are not proof of review (ADR-003 §4)'
  );
}

const SEV = new Set(['S0', 'S1', 'S2', 'S3']);
let unresolved = 0;

for (let i = 0; i < findings.length; i++) {
  const f = findings[i];
  if (!f || typeof f !== 'object') fail('findings[' + i + '] must be an object');
  const sev = f.severity;
  if (typeof sev !== 'string' || !SEV.has(sev)) {
    fail(
      'findings[' + i + '] missing or invalid severity (required: S0|S1|S2|S3); ' +
        'refusing rather than silently excluding from the S0/S1 count (ADR-003)'
    );
  }

  const waiver = f.waiver;
  const hasWaiver = waiver && typeof waiver === 'object';

  if (sev === 'S0' || sev === 'S1') {
    if (!hasWaiver) {
      unresolved++;
      continue;
    }
    if (sev === 'S0') {
      if (!allowS0) {
        fail(
          'findings[' + i + '] is S0 with a waiver but --allow-s0-waiver was not passed; ' +
            'S0 is non-waivable via envelope alone (ADR-003)'
        );
      }
      if (typeof waiver.ref !== 'string' || !waiver.ref.trim()) {
        fail('findings[' + i + '] S0 waiver requires non-empty waiver.ref (PR comment URL)');
      }
      if (typeof waiver.rationale !== 'string' || !waiver.rationale.trim()) {
        fail('findings[' + i + '] S0 waiver requires non-empty waiver.rationale');
      }
    } else if (sev === 'S1') {
      if (typeof waiver.rationale !== 'string' || !waiver.rationale.trim()) {
        fail('findings[' + i + '] S1 waiver requires non-empty waiver.rationale');
      }
    }
  }
}

if (unresolved > 0) {
  fail('unresolved S0/S1 findings remain (' + unresolved + '); fix or waive before sentinel write');
}

process.stdout.write(
  'envelope-gate: ok unresolved_s0_s1=0 clean_dimensions=' + clean.length +
    ' replayable=' + replayableClean.length +
    ' head_sha=' + env.head_sha.trim().slice(0, 8) + '\n'
);
process.exit(0);
