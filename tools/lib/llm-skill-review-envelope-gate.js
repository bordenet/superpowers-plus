#!/usr/bin/env node
/**
 * ADR-003 envelope gate for llm-skill-review sentinel writes.
 *
 * Usage: node tools/lib/llm-skill-review-envelope-gate.js <envelope.json> [--allow-s0-waiver]
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
  fail('usage: llm-skill-review-envelope-gate.js <envelope.json> [--allow-s0-waiver]');
}

const allowS0 = args.includes('--allow-s0-waiver');
const path = args.find((a) => !a.startsWith('--'));
if (!path) fail('envelope path required');

let env;
try {
  env = JSON.parse(fs.readFileSync(path, 'utf8'));
} catch (e) {
  fail('cannot parse envelope JSON: ' + e.message);
}

if (!env || typeof env !== 'object') fail('envelope must be a JSON object');
const findings = Array.isArray(env.findings) ? env.findings : null;
const clean = Array.isArray(env.clean_dimensions) ? env.clean_dimensions : null;
if (!findings) fail('envelope.findings must be an array');
if (!clean) fail('envelope.clean_dimensions must be an array');

if (clean.length < 1) {
  fail(
    'non-vacuous review proof required: clean_dimensions.length must be >= 1 ' +
      '(empty envelopes are not proof of review; see ADR-003 §4)'
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

process.stdout.write('envelope-gate: ok unresolved_s0_s1=0 clean_dimensions=' + clean.length + '\n');
process.exit(0);
