#!/usr/bin/env node
'use strict';
const assert = require('node:assert/strict');
const {buildIntentBoosts} = require('../lib/skill-router');
for (const prompt of [
    'fix this repeated test execution',
    'modify code to repair validation reuse',
    'refactor this bounded function',
    'implement this process correction',
    'create a promotion history sync',
]) {
    assert.equal(buildIntentBoosts(prompt)['feature-development'] || 0, 0,
        `bounded work must not start full feature ceremony: ${prompt}`);
}
for (const prompt of ['start feature', 'full development workflow', 'add feature',
    'new feature', 'build a feature', 'implement feature']) {
    assert.ok(buildIntentBoosts(prompt)['feature-development'] > 0,
        `explicit feature work retains its workflow: ${prompt}`);
}
console.log('Validation workflow routing: 11 behavioral cases passed');
