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

// Cleanup
console.log('');
console.log(`=== Results: ${pass} passed, ${fail} failed ===`);
process.exit(fail > 0 ? 1 : 0);
