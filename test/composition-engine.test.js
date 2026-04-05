#!/usr/bin/env node
/**
 * Tests for the Auto-Composition Engine (RFC-001) in lib/skill-router.js
 * Tests: getComposition, findProducers, findSkillWithCapability,
 *        buildPipeline, explainPipeline, pipelineToMermaid
 */
'use strict';

const assert = require('assert');
const {
    getComposition,
    findProducers,
    findSkillWithCapability,
    buildPipeline,
    explainPipeline,
    pipelineToMermaid,
    getCoordination,
    resolveCoordinationChain,
    getEscalationTargets,
} = require('../lib/skill-router');

let pass = 0, fail = 0;
function test(name, fn) {
    try { fn(); pass++; console.log(`  ok: ${name}`); }
    catch (e) { fail++; console.log(`  FAIL: ${name}: ${e.message}`); }
}

// ---- Test fixtures ----
function makeSkill(name, composition) {
    return { name, composition, description: `${name} skill`, triggers: [] };
}

const analyzer = makeSkill('analyzer', {
    produces: ['analysis-report'],
    consumes: ['user-intent'],
    capabilities: ['analyzes-code'],
    priority: 10,
});

const reviewer = makeSkill('reviewer', {
    produces: ['review-verdict'],
    consumes: ['analysis-report'],
    capabilities: ['reviews-code'],
    priority: 20,
});

const publisher = makeSkill('publisher', {
    produces: ['published-doc'],
    consumes: ['review-verdict'],
    capabilities: ['publishes-wiki'],
    priority: 30,
});

const optionalLinter = makeSkill('linter', {
    produces: ['lint-report'],
    consumes: ['user-intent'],
    capabilities: ['lints-code'],
    priority: 5,
    optional: true,
});

const noComp = makeSkill('plain', null);

const allSkills = [analyzer, reviewer, publisher, optionalLinter, noComp];

// ---- getComposition ----
test('getComposition extracts composition metadata', () => {
    const comp = getComposition(analyzer);
    assert(comp !== null);
    assert.deepStrictEqual(comp.produces, ['analysis-report']);
    assert.deepStrictEqual(comp.consumes, ['user-intent']);
    assert.deepStrictEqual(comp.capabilities, ['analyzes-code']);
    assert(comp.priority === 10);
});

test('getComposition returns null for no composition', () => {
    assert(getComposition(noComp) === null);
});

test('getComposition applies defaults', () => {
    const minimal = makeSkill('min', { produces: ['x'] });
    const comp = getComposition(minimal);
    assert.deepStrictEqual(comp.consumes, []);
    assert.deepStrictEqual(comp.capabilities, []);
    assert(comp.priority === 50, `priority: ${comp.priority}`);
    assert(comp.optional === false);
    assert(comp.requires_all === false);
});

// ---- findProducers ----
test('findProducers finds skills that produce an artifact', () => {
    const producers = findProducers(allSkills, 'analysis-report');
    assert(producers.length === 1);
    assert(producers[0].name === 'analyzer');
});

test('findProducers returns empty for unknown artifact', () => {
    assert.deepStrictEqual(findProducers(allSkills, 'nonexistent'), []);
});

test('findProducers sorts by priority', () => {
    const multiProducer = [
        makeSkill('slow', { produces: ['x'], priority: 99 }),
        makeSkill('fast', { produces: ['x'], priority: 1 }),
    ];
    const result = findProducers(multiProducer, 'x');
    assert(result[0].name === 'fast', 'lower priority should come first');
});

// ---- findSkillWithCapability ----
test('findSkillWithCapability returns matching skill', () => {
    const skill = findSkillWithCapability(allSkills, 'reviews-code');
    assert(skill !== null);
    assert(skill.name === 'reviewer');
});

test('findSkillWithCapability returns null for unknown', () => {
    assert(findSkillWithCapability(allSkills, 'teleports') === null);
});

// ---- buildPipeline ----
test('buildPipeline resolves a simple chain', () => {
    const result = buildPipeline('publishes-wiki', allSkills);
    assert(!result.error, `error: ${result.error}`);
    const names = result.pipeline.map(s => s.name);
    assert(names.includes('analyzer'), 'should include analyzer');
    assert(names.includes('reviewer'), 'should include reviewer');
    assert(names.includes('publisher'), 'should include publisher');
    assert(names.indexOf('analyzer') < names.indexOf('reviewer'), 'analyzer before reviewer');
    assert(names.indexOf('reviewer') < names.indexOf('publisher'), 'reviewer before publisher');
});

test('buildPipeline returns error for no composable skills', () => {
    const result = buildPipeline('x', [noComp]);
    assert(result.error === 'NO_COMPOSABLE_SKILLS');
});

test('buildPipeline returns error for unknown capability', () => {
    const result = buildPipeline('teleports', allSkills);
    assert(result.error === 'CAPABILITY_NOT_FOUND');
});

// ---- pipelineToMermaid ----
test('pipelineToMermaid generates valid mermaid', () => {
    const result = buildPipeline('publishes-wiki', allSkills);
    const mermaid = pipelineToMermaid(result.pipeline);
    assert(mermaid.startsWith('graph LR'), `starts with: ${mermaid.slice(0, 20)}`);
    assert(mermaid.includes('analyzer'), 'includes analyzer');
});

test('pipelineToMermaid handles empty pipeline', () => {
    const mermaid = pipelineToMermaid([]);
    assert(mermaid.includes('No pipeline'));
});

// ---- explainPipeline ----
test('explainPipeline includes all sections', () => {
    const output = explainPipeline('publishes-wiki', allSkills);
    assert(output.includes('Auto-Composition Engine'), 'header');
    assert(output.includes('publishes-wiki'), 'target');
    assert(output.includes('mermaid'), 'diagram');
});

test('explainPipeline shows error for bad capability', () => {
    const output = explainPipeline('nonexistent', allSkills);
    assert(output.includes('CAPABILITY_NOT_FOUND'));
});

// ========================================================================
// Coordination Engine tests
// ========================================================================

function makeCoordSkill(name, coordination) {
    return { name, coordination, composition: null, description: `${name} skill`, triggers: [] };
}

// ---- getCoordination ----
test('getCoordination extracts coordination metadata', () => {
    const s = makeCoordSkill('a', { group: 'linear', order: 1, requires: [], enables: ['b'], escalates_to: ['think-twice'], internal: false });
    const coord = getCoordination(s);
    assert(coord !== null);
    assert.strictEqual(coord.group, 'linear');
    assert.strictEqual(coord.order, 1);
    assert.deepStrictEqual(coord.enables, ['b']);
    assert.deepStrictEqual(coord.escalates_to, ['think-twice']);
    assert.strictEqual(coord.internal, false);
});

test('getCoordination returns null for no coordination', () => {
    assert(getCoordination({ name: 'x', coordination: null }) === null);
    assert(getCoordination({ name: 'x' }) === null);
});

test('getCoordination applies defaults', () => {
    const coord = getCoordination(makeCoordSkill('min', {}));
    assert.strictEqual(coord.group, '');
    assert.strictEqual(coord.order, 0);
    assert.deepStrictEqual(coord.requires, []);
    assert.deepStrictEqual(coord.enables, []);
    assert.deepStrictEqual(coord.escalates_to, []);
    assert.strictEqual(coord.internal, false);
});

// ---- resolveCoordinationChain ----

// PHR adversarial #1: A.enables=[B] + B.requires=[A] → NOT a cycle (same edge)
test('resolveCoordinationChain: A.enables B + B.requires A is NOT a cycle', () => {
    const a = makeCoordSkill('a', { order: 1, enables: ['b'], requires: [] });
    const b = makeCoordSkill('b', { order: 2, enables: [], requires: ['a'] });
    const result = resolveCoordinationChain('a', [a, b]);
    assert.strictEqual(result.error, null, `unexpected error: ${result.error}`);
    assert.deepStrictEqual(result.chain, ['a', 'b']);
});

// PHR adversarial #2: A.enables=[B] + B.enables=[A] → IS a cycle
test('resolveCoordinationChain: A.enables B + B.enables A IS a cycle', () => {
    const a = makeCoordSkill('a', { order: 1, enables: ['b'], requires: [] });
    const b = makeCoordSkill('b', { order: 2, enables: ['a'], requires: [] });
    const result = resolveCoordinationChain('a', [a, b]);
    assert.strictEqual(result.error, 'CYCLE_DETECTED');
});

// PHR adversarial #3: B.requires=[missing] → blocked error, not warning
test('resolveCoordinationChain: missing required skill is blocking error', () => {
    const b = makeCoordSkill('b', { order: 1, enables: [], requires: ['missing-skill'] });
    const result = resolveCoordinationChain('b', [b]);
    assert.strictEqual(result.error, 'MISSING_REQUIRED_SKILL');
    assert(result.explanation.some(l => l.includes('BLOCKED')));
});

// PHR adversarial #4: missing enabled skill is warning only (not error)
test('resolveCoordinationChain: missing enabled skill is warning not error', () => {
    const a = makeCoordSkill('a', { order: 1, enables: ['not-installed'], requires: [] });
    const result = resolveCoordinationChain('a', [a]);
    assert.strictEqual(result.error, null);
    assert.deepStrictEqual(result.chain, ['a']);
    assert(result.explanation.some(l => l.includes('WARN')));
});

// PHR adversarial #5: shuffled input array → same chain order (determinism)
test('resolveCoordinationChain: deterministic regardless of input order', () => {
    const a = makeCoordSkill('a', { order: 1, enables: ['b'], requires: [] });
    const b = makeCoordSkill('b', { order: 2, enables: ['c'], requires: [] });
    const c = makeCoordSkill('c', { order: 3, enables: [], requires: [] });
    const result1 = resolveCoordinationChain('a', [a, b, c]);
    const result2 = resolveCoordinationChain('a', [c, b, a]);
    const result3 = resolveCoordinationChain('a', [b, a, c]);
    assert.deepStrictEqual(result1.chain, result2.chain, 'shuffle 1 vs 2');
    assert.deepStrictEqual(result1.chain, result3.chain, 'shuffle 1 vs 3');
    assert.deepStrictEqual(result1.chain, ['a', 'b', 'c']);
});

test('resolveCoordinationChain: skill not found', () => {
    const result = resolveCoordinationChain('nonexistent', []);
    assert.strictEqual(result.error, 'SKILL_NOT_FOUND');
});

test('resolveCoordinationChain: three-step chain', () => {
    const s1 = makeCoordSkill('step1', { order: 1, enables: ['step2'], requires: [] });
    const s2 = makeCoordSkill('step2', { order: 2, enables: ['step3'], requires: [] });
    const s3 = makeCoordSkill('step3', { order: 3, enables: [], requires: [] });
    const result = resolveCoordinationChain('step1', [s1, s2, s3]);
    assert.strictEqual(result.error, null);
    assert.deepStrictEqual(result.chain, ['step1', 'step2', 'step3']);
});

// ---- getEscalationTargets ----
test('getEscalationTargets returns available targets', () => {
    const a = makeCoordSkill('a', { escalates_to: ['think-twice', 'missing'] });
    const tt = makeCoordSkill('think-twice', {});
    const result = getEscalationTargets('a', [a, tt]);
    assert.deepStrictEqual(result.targets, ['think-twice']);
    assert(result.explanation.some(l => l.includes('WARN') && l.includes('missing')));
});

test('getEscalationTargets returns empty for no coordination', () => {
    const result = getEscalationTargets('plain', [noComp]);
    assert.deepStrictEqual(result.targets, []);
});

test('getEscalationTargets returns empty for unknown skill', () => {
    const result = getEscalationTargets('nonexistent', []);
    assert.deepStrictEqual(result.targets, []);
});

// Cleanup
console.log('');
console.log(`=== Results: ${pass} passed, ${fail} failed ===`);
process.exit(fail > 0 ? 1 : 0);
