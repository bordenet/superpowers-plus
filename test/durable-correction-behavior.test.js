#!/usr/bin/env node
'use strict';

const fs = require('fs');
const path = require('path');

const evidencePath = path.join(
  __dirname,
  'fixtures/skill-guidance/durable-correction/behavioral-results.json'
);
const evidence = JSON.parse(fs.readFileSync(evidencePath, 'utf8'));
const cases = new Map(evidence.cases.map(testCase => [testCase.id, testCase]));

function assert(condition, message) {
  if (!condition) {
    console.error(`not ok - ${message}`);
    process.exitCode = 1;
    return;
  }
  console.log(`ok - ${message}`);
}

assert(/RED\/GREEN/.test(evidence.method), 'records the comparison method');

const recurrence = cases.get('failed-control-recurrence-under-deadline');
assert(recurrence, 'records the deadline recurrence case');
if (recurrence) {
  const response = recurrence.green.response.toLowerCase();
  assert(recurrence.green.classification === 'failed-control recurrence',
    'classifies a recurrence after a prior fix as failed-control recurrence');
  assert(response.includes('blocking'), 'replaces the failed advisory control with a blocking control');
  assert(response.includes('original failure'), 'requires a negative test with the original failure');
  assert(response.includes('valid case'), 'requires a positive test for valid behavior');
  assert(response.includes('real ci or commit boundary'), 'requires execution at the real workflow boundary');
  assert(recurrence.green.status === 'contained', 'withholds prevented until the evidence exists');
  assert(recurrence.red.response !== recurrence.green.response, 'GREEN materially differs from the RED baseline');
}

const typo = cases.get('ordinary-first-typo');
assert(typo, 'records the ordinary typo control case');
if (typo) {
  const response = typo.green.response.toLowerCase();
  assert(typo.green.classification === 'ordinary correction', 'keeps a first typo lightweight');
  assert(response.includes('do not open a prevention track'), 'does not force recurrence ceremony onto a typo');
}
