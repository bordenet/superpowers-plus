#!/usr/bin/env node
'use strict';
const assert = require('assert');
const fs = require('fs');
const path = require('path');
const root = path.resolve(__dirname, '..');
const names = ['test-driven-development', 'requesting-code-review', 'receiving-code-review',
    'executing-plans', 'code-review-battery', 'unified-commit-gate', 'verification-before-completion'];
for (const name of names) {
    const source = fs.readFileSync(path.join(root, 'skills/engineering', name, 'skill.md'), 'utf8');
    assert(source.includes('Before every automated review or test/check pass'), name);
    for (const decision of ['REUSE', 'WAIT', 'RUN_MINIMAL', 'REVIEW_REQUIRED', 'STOP']) assert(source.includes(decision), name);
}
const battery = fs.readFileSync(path.join(root, 'skills/engineering/code-review-battery/skill.md'), 'utf8');
const convergence = battery.split('### Phase 5: Convergence')[1].split('###')[0];
assert(convergence.includes('one initial review'));
assert(!convergence.includes('last 2 passes'));
const requesting = fs.readFileSync(path.join(root, 'skills/engineering/requesting-code-review/skill.md'), 'utf8');
assert(!requesting.includes('Sentinel SHA ≠ HEAD SHA'));
assert(!requesting.includes('Delete `.code-review-cleared`'));
assert(requesting.includes('Progress updates'));
console.log('strategy policies: mandatory decisions and specific legacy restart procedures corrected');

const controller = fs.readFileSync(path.join(root, 'skills/productivity/autonomous-chain-controller/skill.md'), 'utf8');
const executor = fs.readFileSync(path.join(root, 'skills/engineering/executing-plans/skill.md'), 'utf8');
for (const source of [controller, executor]) {
    assert(source.includes('execution-admission.py'));
    assert(source.includes('acceptance criterion'));
    assert(source.includes('independent execution controller'));
}
assert(!controller.includes('Gate failure: retry < 2'));
assert(!controller.includes('Add gate, re-run previous skill'));

const description = requesting.match(/^description: (.*)$/m)[1];
assert(!description.includes('Always runs battery'));
assert(!requesting.includes('| **Subagent-driven development** | After EACH task'));
assert(!requesting.includes('Fix immediately. Re-dispatch battery.'));
assert(!requesting.includes('Re-dispatch if >1 fixed.'));
assert(!battery.includes('| **Valid sentinel for HEAD exists** |'));
assert(!battery.includes('Sentinel SHA == HEAD → skip re-dispatch'));

assert(executor.includes('SPP_REVIEW_CLASS=<required-class> SPP_REVIEW_SNAPSHOT=<strategy.snapshot>'));
assert(!executor.includes('sentinel must exist for HEAD'));
const llm = fs.readFileSync(path.join(root, 'skills/engineering/llm-skill-review/skill.md'), 'utf8');
const llmReference = fs.readFileSync(path.join(root, 'skills/engineering/llm-skill-review/reference.md'), 'utf8');
assert(!llm.includes('`tools/fence-scan.sh` output'));
assert(!llmReference.includes('bash tools/fence-scan.sh <changed-skill.md>'));
assert(!llmReference.includes('tools/fence-scan.sh <changed .md file>'));
