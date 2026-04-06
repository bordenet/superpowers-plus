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

// --- Anti-trigger penalty ---
console.log('\n--- Anti-trigger penalty ---');
{
  const mockSkills = [
    { name: 'pre-commit-gate', triggers: ['before commit', 'pre-commit'], description: 'Pre-commit quality gate',
      anti_triggers: ['review PR', 'review this PR', 'output looks wrong', 'debug this'] },
    { name: 'systematic-debugging', triggers: ['debug', 'test failing'], description: 'Debugging process',
      anti_triggers: [] },
  ];
  const results = matchSkillsTfIdf('debug this error', mockSkills, 2);
  // pre-commit-gate has anti_trigger 'debug this' — should be penalized
  assert(results.length === 2, `anti-trigger: expected 2 results (got ${results.length})`);
  const preCommitResult = results.find(r => r.name === 'pre-commit-gate');
  const debugResult = results.find(r => r.name === 'systematic-debugging');
  assert(preCommitResult, 'anti-trigger: pre-commit-gate must appear in results');
  assert(debugResult, 'anti-trigger: systematic-debugging must appear in results');
  assert(debugResult.score > preCommitResult.score,
    'anti-trigger "debug this" penalizes pre-commit-gate below systematic-debugging');
}

// --- Query expansion: concept synonyms ---
console.log('\n--- Query expansion ---');
{
  const mockSkills = [
    { name: 'systematic-debugging', triggers: ['debug'], description: 'Systematic debugging process', anti_triggers: [] },
    { name: 'writing-plans', triggers: ['plan'], description: 'Writing plans', anti_triggers: [] },
  ];
  // "crash" should expand to include "debug" via CONCEPT_EXPANSIONS
  const results = matchSkillsTfIdf('crash in production', mockSkills, 2);
  assert(results.length > 0, 'query expansion returns results');
  if (results.length > 0) {
    eq(results[0].name, 'systematic-debugging', '"crash" expands to debug-related skill');
  }
}

// --- Composition pipeline: basic dependency resolution ---
console.log('\n--- Composition pipeline ---');
{
  const mockSkills = [
    {
      name: 'skill-a', description: 'Produces artifact-x',
      composition: { produces: ['artifact-x'], consumes: ['user-intent'], capabilities: ['cap-a'], priority: 10 }
    },
    {
      name: 'skill-b', description: 'Consumes artifact-x, produces artifact-y',
      composition: { produces: ['artifact-y'], consumes: ['artifact-x'], capabilities: ['cap-b'], priority: 20 }
    },
    {
      name: 'skill-c', description: 'Consumes artifact-y, has target capability',
      composition: { produces: ['final-output'], consumes: ['artifact-y'], capabilities: ['target-cap'], priority: 30 }
    },
  ];

  const result = buildPipeline('target-cap', mockSkills);
  assert(result.error === null, 'pipeline resolves without error');
  assert(result.pipeline.length === 3, `pipeline has 3 skills (got ${result.pipeline.length})`);
  eq(result.pipeline[0].name, 'skill-a', 'pipeline starts with lowest priority producer');
  eq(result.pipeline[1].name, 'skill-b', 'pipeline has intermediate skill');
  eq(result.pipeline[2].name, 'skill-c', 'pipeline ends with target skill');
  assert(result.produced.has('final-output'), 'pipeline produces final artifact');
}

// --- Composition pipeline: missing capability ---
console.log('\n--- Composition: missing capability ---');
{
  const result = buildPipeline('nonexistent-cap', [
    { name: 'skill-a', composition: { produces: ['x'], consumes: [], capabilities: ['other'], priority: 10 } },
  ]);
  eq(result.error, 'CAPABILITY_NOT_FOUND', 'missing capability returns CAPABILITY_NOT_FOUND');
  eq(result.pipeline.length, 0, 'no pipeline for missing capability');
}

// --- Composition pipeline: no composable skills ---
console.log('\n--- Composition: no composable skills ---');
{
  const result = buildPipeline('any-cap', [
    { name: 'skill-a', description: 'No composition metadata' },
  ]);
  eq(result.error, 'NO_COMPOSABLE_SKILLS', 'no composable skills returns correct error');
}

// --- Composition pipeline: cycle prevention ---
console.log('\n--- Composition: cycle prevention ---');
{
  const mockSkills = [
    {
      name: 'skill-a',
      composition: { produces: ['artifact-b'], consumes: ['artifact-a'], capabilities: ['cap-a'], priority: 10 }
    },
    {
      name: 'skill-b',
      composition: { produces: ['artifact-a'], consumes: ['artifact-b'], capabilities: ['target'], priority: 20 }
    },
  ];
  const result = buildPipeline('target', mockSkills, ['artifact-a']);
  // Should resolve (artifact-a is pre-available, so no cycle)
  assert(result.pipeline.length > 0, 'cycle prevention: pipeline resolves when start artifact available');
}

// --- TF-IDF: trigger phrase boost ---
console.log('\n--- TF-IDF: trigger phrase boost ---');
{
  const mockSkills = [
    { name: 'skill-with-triggers', triggers: ['exact match phrase'], description: 'Has a specific trigger', anti_triggers: [] },
    { name: 'generic-skill', triggers: ['something else'], description: 'Generic description', anti_triggers: [] },
  ];
  const results = matchSkillsTfIdf('exact match phrase', mockSkills, 2);
  if (results.length >= 2) {
    assert(results[0].name === 'skill-with-triggers',
      'exact trigger match boosts skill to top');
  }
}

// --- TF-IDF: multiple skills same query ---
console.log('\n--- TF-IDF: result ordering ---');
{
  const mockSkills = [
    { name: 'wiki-editing', triggers: ['edit wiki', 'update page'], description: 'Edit wiki pages', anti_triggers: [] },
    { name: 'wiki-verify', triggers: ['verify wiki', 'check wiki accuracy'], description: 'Verify wiki accuracy', anti_triggers: [] },
    { name: 'brainstorming', triggers: ['brainstorm', 'ideas'], description: 'Brainstorm ideas', anti_triggers: [] },
  ];
  const results = matchSkillsTfIdf('verify wiki accuracy', mockSkills, 3);
  assert(results.length === 3, 'returns all skills');
  eq(results[0].name, 'wiki-verify', 'wiki-verify ranks first for verify wiki query');
}

// --- stem function ---
console.log('\n--- stem function ---');
{
  const { stem } = require('../lib/skill-router');
  eq(stem('debugging'), 'debugg', 'debugging → debugg (strip -ing)');
  eq(stem('fixed'), 'fix', 'fixed → fix (strip -ed)');
  eq(stem('tests'), 'test', 'tests → test (strip -s)');
  eq(stem('quickly'), 'quick', 'quickly → quick (strip -ly)');
  eq(stem('creation'), 'creat', 'creation → creat (strip -tion → -t)');
  eq(stem('deployment'), 'deploy', 'deployment → deploy (strip -ment)');
}

// --- Summary ---
console.log(`\n=== Results: ${pass} passed, ${fail} failed ===`);
process.exit(fail > 0 ? 1 : 0);
