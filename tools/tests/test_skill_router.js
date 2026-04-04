const assert = require('assert');
const {
  applyHeuristicBoosts,
  assertUniqueSkillNames,
  buildIntentBoosts,
  matchSkillsTfIdf,
} = require('../../lib/skill-router');

const strategicSkills = [
  { name: 'thinking-orchestrator', description: 'Routes strategic questions', isSuperpower: true, triggers: ["what's the best approach", 'where should we put'] },
  { name: 'design-triad', description: 'Compare design alternatives', isSuperpower: true, triggers: ['design options', 'compare design approaches'] },
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
    { name: 'design-triad', description: '', isSuperpower: true, score: 0.39 },
    { name: 'plan-and-execute', description: '', isSuperpower: true, score: 0.38 },
  ];

  applyHeuristicBoosts(baseResults, strategicSkills, query.toLowerCase(), query.toLowerCase().split(/\s+/));
  baseResults.sort((a, b) => b.score - a.score);

  assertOrderedNames(baseResults, ['thinking-orchestrator', 'design-triad', 'plan-and-execute']);
}

function testBroadNonStrategicQueryDoesNotTriggerIntentBoosts() {
  const boosts = buildIntentBoosts("what's the right test command for this repo");
  assert.deepStrictEqual(boosts, {});
}

function testDesignTriadIntentBoostsWinOnCanonicalTrigger() {
  const boosts = buildIntentBoosts('compare design approaches');
  assert(boosts['design-triad'] >= 3);
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

function testDuplicateSkillNamesThrow() {
  const duplicateSkills = [
    { name: 'duplicate-skill', description: 'first', isSuperpower: true, triggers: ['first trigger'] },
    { name: 'duplicate-skill', description: 'second', isSuperpower: true, triggers: ['second trigger'] },
  ];

  assert.throws(
    () => assertUniqueSkillNames(duplicateSkills),
    /Duplicate skill names detected: duplicate-skill/
  );

  assert.throws(
    () => matchSkillsTfIdf('duplicate skill', duplicateSkills, 2),
    /Duplicate skill names detected: duplicate-skill/
  );
}

testEmbeddingHeuristicBoosts();
testBroadNonStrategicQueryDoesNotTriggerIntentBoosts();
testDesignTriadIntentBoostsWinOnCanonicalTrigger();
testHeuristicBoostsIgnoreStaleCachedSkill();
testTfidfStrategicRouting();
testTfidfPlanAndExecuteRouting();
testDuplicateSkillNamesThrow();

console.log('skill-router tests passed');
