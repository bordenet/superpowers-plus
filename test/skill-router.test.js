#!/usr/bin/env node
/**
 * Unit tests for lib/skill-router.js
 * Run: node test/skill-router.test.js
 */

'use strict';

const {
  buildIntentBoosts,
  INTENT_PATTERNS,
  BOOST_DEFAULT, BOOST_LOW, BOOST_STANDARD, BOOST_ELEVATED,
  BOOST_HIGH, BOOST_CRITICAL, BOOST_EMERGENCY,
  matchSkillsTfIdf,
  buildPipeline,
  tokenize,
  cosineSimilarity,
} = require('../lib/skill-router');

let pass = 0;
let fail = 0;

function assert(condition, msg) {
  if (condition) { pass++; console.log(`  ✅ ${msg}`); }
  else { fail++; console.log(`  ❌ ${msg}`); }
}
function eq(a, b, msg) { assert(a === b, `${msg} (got: ${JSON.stringify(a)}, want: ${JSON.stringify(b)})`); }

// --- Boost constants ---
console.log('\n--- Boost constants ---');
eq(typeof BOOST_DEFAULT, 'number', 'BOOST_DEFAULT is a number');
eq(BOOST_DEFAULT, 1.5, 'BOOST_DEFAULT = 1.5');
eq(BOOST_LOW, 2, 'BOOST_LOW = 2');
eq(BOOST_STANDARD, 3, 'BOOST_STANDARD = 3');
eq(BOOST_ELEVATED, 4, 'BOOST_ELEVATED = 4');
eq(BOOST_HIGH, 5, 'BOOST_HIGH = 5');
eq(BOOST_CRITICAL, 6, 'BOOST_CRITICAL = 6');
eq(BOOST_EMERGENCY, 8, 'BOOST_EMERGENCY = 8');

// --- No duplicate patterns in INTENT_PATTERNS ---
console.log('\n--- No duplicate patterns ---');
{
  const seen = new Map();
  const dupes = [];
  INTENT_PATTERNS.forEach((intent, idx) => {
    for (const p of intent.patterns) {
      if (seen.has(p)) dupes.push(`"${p}" at ${idx} (first at ${seen.get(p)})`);
      seen.set(p, idx);
    }
  });
  assert(dupes.length === 0, `no duplicate patterns (found: ${dupes.join(', ') || 'none'})`);
}

// --- Intent pattern matching ---
console.log('\n--- Intent pattern matching: known queries → expected boosts ---');
{
  const b1 = buildIntentBoosts('design triad');
  assert((b1['design-triad'] || 0) >= BOOST_STANDARD, 'design triad → design-triad boosted');

  const b2 = buildIntentBoosts('plan and execute');
  assert((b2['plan-and-execute'] || 0) >= BOOST_STANDARD, 'plan and execute → plan-and-execute boosted');

  const b3 = buildIntentBoosts("what's the best approach");
  assert((b3['thinking-orchestrator'] || 0) > 0, "what's the best approach → thinking-orchestrator boosted");

  const b4 = buildIntentBoosts('failure autopsy what went wrong');
  assert((b4['failure-autopsy'] || 0) === BOOST_EMERGENCY, 'failure autopsy → BOOST_EMERGENCY (8)');

  const b5 = buildIntentBoosts('reviewer agent');
  assert((b5['code-review-respond'] || 0) === BOOST_CRITICAL, 'reviewer agent → BOOST_CRITICAL (6)');
}

// --- Boost accumulation: no doubled boosts from removed duplicates ---
console.log('\n--- Boost accumulation (no doubling from removed duplicates) ---');
{
  const b = buildIntentBoosts('design triad');
  const raw = b['design-triad'] || 0;
  // Before dedup fix, "design triad" matched twice → 6. After fix it should be 3.
  assert(raw <= BOOST_STANDARD, `design-triad boost is ≤ BOOST_STANDARD (got ${raw})`);
}

// --- Empty/edge queries ---
console.log('\n--- Edge cases ---');
{
  const empty = buildIntentBoosts('');
  eq(Object.keys(empty).length, 0, 'empty query produces no boosts');

  const single = buildIntentBoosts('debug');
  assert(typeof single === 'object', 'single word query returns object');

  const long = buildIntentBoosts('a '.repeat(500) + 'what went wrong');
  assert((long['failure-autopsy'] || 0) > 0, 'long query still matches failure-autopsy via "what went wrong"');
}

// --- TF-IDF basics ---
console.log('\n--- TF-IDF basics ---');
{
  const mockSkills = [
    { name: 'systematic-debugging', triggers: ['debug', 'fix bug', 'test failing', 'error', 'exception', 'crash'], description: 'Systematic debugging process', anti_triggers: [] },
    { name: 'design-triad', triggers: ['design triad', 'compare design approaches', 'three options'], description: 'Three design options comparison', anti_triggers: [] },
    { name: 'writing-plans', triggers: ['plan', 'write plan', 'roadmap'], description: 'Writing implementation plans', anti_triggers: [] },
  ];

  const results = matchSkillsTfIdf('debug test failure', mockSkills, 3);
  assert(Array.isArray(results), 'matchSkillsTfIdf returns array');
  assert(results.length > 0, 'matchSkillsTfIdf returns results for debug query');
  if (results.length > 0) {
    eq(results[0].name, 'systematic-debugging', 'systematic-debugging ranks first for debug query');
  }
}

// --- tokenize ---
console.log('\n--- tokenize ---');
{
  const tokens = tokenize('fix the broken test');
  assert(Array.isArray(tokens), 'tokenize returns array');
  assert(tokens.length > 0, 'tokenize produces tokens');
}

// --- cosineSimilarity (takes number arrays) ---
console.log('\n--- cosineSimilarity ---');
{
  const a = [1, 1, 0];
  const b = [1, 1, 0];
  const c = [0, 0, 1];
  const sim = cosineSimilarity(a, b);
  assert(sim > 0.99, `identical vectors → similarity ≈ 1 (got ${sim.toFixed(4)})`);
  const noSim = cosineSimilarity(a, c);
  eq(noSim, 0, 'orthogonal vectors → similarity = 0');
}

// --- Summary ---
console.log(`\n=== Results: ${pass} passed, ${fail} failed ===`);
process.exit(fail > 0 ? 1 : 0);
