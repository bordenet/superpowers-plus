const assert = require('assert');
const {
  applyHeuristicBoosts,
  assertUniqueSkillNames,
  buildIntentBoosts,
  matchSkillsTfIdf,
} = require('../../lib/skill-router');

const strategicSkills = [
  { name: 'thinking-orchestrator', description: 'Routes strategic questions', isSuperpower: true, triggers: ["what's the best approach", 'where should we put'] },
  { name: 'debate', description: 'Compare design alternatives', isSuperpower: true, triggers: ['design options', 'compare design approaches'] },
  { name: 'plan-and-execute', description: 'Turn a chosen design into a plan', isSuperpower: true, triggers: ['plan and execute'] },
  { name: 'test-driven-development', description: 'Write tests first', isSuperpower: true, triggers: ['tdd'] },
];

function assertOrderedNames(results, expectedNames) {
  assert.deepStrictEqual(results.slice(0, expectedNames.length).map(r => r.name), expectedNames);
}

function testEmbeddingHeuristicBoosts() {
  const query = 'where should we put retry logic';
  const baseResults = [
    { name: 'test-driven-development', description: '', isSuperpower: true, score: 0.95 },
    { name: 'thinking-orchestrator', description: '', isSuperpower: true, score: 0.40 },
    { name: 'debate', description: '', isSuperpower: true, score: 0.39 },
    { name: 'plan-and-execute', description: '', isSuperpower: true, score: 0.38 },
  ];

  applyHeuristicBoosts(baseResults, strategicSkills, query.toLowerCase(), query.toLowerCase().split(/\s+/));
  baseResults.sort((a, b) => b.score - a.score);

  assertOrderedNames(baseResults, ['thinking-orchestrator', 'debate', 'plan-and-execute']);
}

function testBroadNonStrategicQueryDoesNotTriggerIntentBoosts() {
  const boosts = buildIntentBoosts("what's the right test command for this repo");
  assert.deepStrictEqual(boosts, {});
}

function testDebateIntentBoostsWinOnCanonicalTrigger() {
  const boosts = buildIntentBoosts('compare design approaches');
  assert(boosts['debate'] >= 3);
}

function testHeuristicBoostsIgnoreStaleCachedSkill() {
  const query = 'what\'s the best approach for retry logic placement';
  const results = [
    { name: 'stale-skill', description: '', isSuperpower: true, score: 0.99 },
    { name: 'thinking-orchestrator', description: '', isSuperpower: true, score: 0.20 },
  ];

  assert.doesNotThrow(() => {
    applyHeuristicBoosts(results, strategicSkills, query.toLowerCase(), query.toLowerCase().split(/\s+/));
  });
  assert(results[1].score > 0.20);
}

function testTfidfStrategicRouting() {
  const results = matchSkillsTfIdf('what\'s the best approach for retry logic placement', strategicSkills, 3);
  assert.strictEqual(results[0].name, 'thinking-orchestrator');
}

function testTfidfPlanAndExecuteRouting() {
  const results = matchSkillsTfIdf('create a plan and execute it', strategicSkills, 4);
  assert.strictEqual(results[0].name, 'plan-and-execute');
}

function testDuplicateSkillNamesWarnsNotThrows() {
  // assertUniqueSkillNames now warns (console.error) instead of throwing.
  // Throwing crashed matchSkills on every query when a user has duplicate skill dirs.
  const duplicateSkills = [
    { name: 'duplicate-skill', description: 'first', isSuperpower: true, triggers: ['first trigger'] },
    { name: 'duplicate-skill', description: 'second', isSuperpower: true, triggers: ['second trigger'] },
  ];

  const errors = [];
  const origError = console.error;
  console.error = (...args) => errors.push(args.join(' '));

  try {
    assert.doesNotThrow(() => assertUniqueSkillNames(duplicateSkills));
    assert(errors.some(e => e.includes('duplicate-skill')),
      'Expected a console.error warning mentioning the duplicate skill name');

    // matchSkillsTfIdf must also not throw — should warn then proceed
    errors.length = 0;
    assert.doesNotThrow(() => matchSkillsTfIdf('duplicate skill', duplicateSkills, 2));
    assert(errors.some(e => e.includes('duplicate-skill')),
      'Expected matchSkillsTfIdf to warn about duplicate skill names');
  } finally {
    console.error = origError;
  }
}

function testValidateIntentPatternsWarnsOnDuplicate() {
  // validateIntentPatterns uses the same warn-not-throw approach
  const { validateIntentPatterns } = require('../../lib/skill-router');
  const errors = [];
  const origError = console.error;
  console.error = (...args) => errors.push(args.join(' '));
  try {
    const patternWithDupe = [
      { patterns: ['commit', 'pre-commit'], skills: ['pre-commit-gate'] },
      { patterns: ['commit'], skills: ['sp-commit'] },  // 'commit' is a duplicate
    ];
    assert.doesNotThrow(() => validateIntentPatterns(patternWithDupe));
    assert(errors.some(e => e.includes('commit')), 'Expected duplicate pattern warning');
  } finally {
    console.error = origError;
  }
}

testEmbeddingHeuristicBoosts();
testBroadNonStrategicQueryDoesNotTriggerIntentBoosts();
testDebateIntentBoostsWinOnCanonicalTrigger();
testHeuristicBoostsIgnoreStaleCachedSkill();
testTfidfStrategicRouting();
testTfidfPlanAndExecuteRouting();
testDuplicateSkillNamesWarnsNotThrows();
testValidateIntentPatternsWarnsOnDuplicate();

console.log('skill-router tests passed');
