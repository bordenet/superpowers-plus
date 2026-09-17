#!/usr/bin/env node
'use strict';

const assert = require('assert');
const {
    refreshTriggers,
    validateReviewedFixture,
} = require('../tools/seed-invocation-fixtures');

let passed = 0;

function rejects(label, fixture, pattern) {
    assert.throws(() => validateReviewedFixture(label, fixture), pattern);
    passed++;
}

rejects('zero-assertions', {
    expected_substrings: [],
    triggers: ['some trigger'],
    verified_by: 'Reviewer',
    verified_at: '2026-09-17',
}, /operative assertion/i);

rejects('self-seeded', {
    expected_substrings: ['A literal procedure anchor'],
    triggers: [],
    verified_by: 'auto-seed from compressed output',
    verified_at: '2026-09-17',
}, /independent review/i);

const reviewed = {
    expected_substrings: ['A literal procedure anchor'],
    triggers: ['old trigger'],
    verified_by: 'P1h independent oracle review',
    verified_at: '2026-09-17',
};
assert.doesNotThrow(() => validateReviewedFixture('reviewed', reviewed));
passed++;

const refreshed = refreshTriggers(reviewed, ['new trigger']);
assert.deepStrictEqual(refreshed.expected_substrings, reviewed.expected_substrings);
assert.strictEqual(refreshed.verified_by, reviewed.verified_by);
assert.strictEqual(refreshed.verified_at, reviewed.verified_at);
assert.deepStrictEqual(refreshed.triggers, ['new trigger']);
passed++;

console.log(`${passed} invocation fixture oracle tests passed`);
