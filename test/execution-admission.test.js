#!/usr/bin/env node
'use strict';
const assert = require('assert');
const fs = require('fs');
const os = require('os');
const path = require('path');
const { spawnSync } = require('child_process');
const area = fs.mkdtempSync(path.join(os.tmpdir(), 'execution admission '));
try {
    const state = { schema: 1, root: area, active: 'foundation',
        phases: { foundation: { predecessors: [], criteria: { F1: { status: 'open', inputs: ['tools/receipt.py'] } } },
            strategy: { predecessors: ['foundation'], criteria: { S1: { status: 'open' } } } },
        actions: { repair: { phase: 'foundation', kind: 'edit', gaps: ['F1'], paths: ['tools/receipt.py'] },
            expand: { phase: 'strategy', kind: 'edit', gaps: ['S1'], paths: ['.github/workflows/test.yml'] },
            focused: { phase: 'foundation', kind: 'check', gaps: ['F1'], argv_prefix: ['node', 'test/receipt.js', '--case'], selectors: { F1: ['F1 exact case'] } },
            broad: { phase: 'foundation', kind: 'check', gaps: ['F1'], argv: ['node', 'test/receipt.js'], requires_verified: ['F1'] } } };
    fs.mkdirSync(path.join(area, 'tools'));
    fs.writeFileSync(path.join(area, 'tools/receipt.py'), 'original source');
    const stateFile = path.join(area, 'state.json'); fs.writeFileSync(stateFile, JSON.stringify(state));
    const patchFile = path.join(area, 'change.patch');
    function check(action, gap, file) {
        fs.writeFileSync(patchFile, `*** Begin Patch\n*** Add File: ${path.join(area, file)}\n+test\n*** End Patch\n`);
        return spawnSync('python3', [path.join(__dirname, '../tools/execution-admission.py'), stateFile],
            { input: JSON.stringify({ action, kind: 'edit', gap, patch: patchFile }), encoding: 'utf8' });
    }
    let downstream = 0;
    function execute(r) { if (r.status === 0) downstream++; }
    const valid = check('repair', 'F1', 'tools/receipt.py'); execute(valid);
    assert.strictEqual(valid.status, 0, valid.stderr + valid.stdout); assert.strictEqual(downstream, 1);
    const successor = check('expand', 'S1', '.github/workflows/test.yml'); execute(successor);
    assert.notStrictEqual(successor.status, 0); assert.strictEqual(downstream, 1);
    const mislabeled = check('repair', 'F1', '.github/workflows/test.yml'); execute(mislabeled);
    assert.notStrictEqual(mislabeled.status, 0); assert.strictEqual(downstream, 1);
    const noGap = check('repair', 'invented-gap', 'tools/receipt.py'); execute(noGap);
    assert.notStrictEqual(noGap.status, 0); assert.strictEqual(downstream, 1);
    function request(data) {
        return spawnSync('python3', [path.join(__dirname, '../tools/execution-admission.py'), stateFile],
            { input: JSON.stringify(data), encoding: 'utf8' });
    }
    const unrelated = request({ action: 'focused', kind: 'check', gap: 'F1', argv: ['node', 'test/receipt.js', '--case', 'unrelated valid case'] });
    assert.notStrictEqual(unrelated.status, 0, 'unrelated selector must not qualify as F1 work');
    const focused = request({ action: 'focused', kind: 'check', gap: 'F1', argv: ['node', 'test/receipt.js', '--case', 'F1 exact case'] });
    assert.strictEqual(focused.status, 0, focused.stdout);
    const fingerprint = spawnSync('python3', [path.join(__dirname, '../tools/execution-admission.py'), stateFile, '--fingerprint', 'F1'], { encoding: 'utf8' });
    assert.strictEqual(fingerprint.status, 0, fingerprint.stdout + fingerprint.stderr);
    state.phases.foundation.criteria.F1.status = 'verified';
    state.phases.foundation.criteria.F1.fingerprint = JSON.parse(fingerprint.stdout).fingerprint;
    fs.writeFileSync(stateFile, JSON.stringify(state));
    const broad = { action: 'broad', kind: 'check', gap: 'F1', argv: ['node', 'test/receipt.js'] };
    assert.strictEqual(request(broad).status, 0);
    fs.writeFileSync(path.join(area, 'tools/receipt.py'), 'changed source');
    assert.notStrictEqual(request(broad).status, 0, 'old verified status must not admit changed inputs');
    fs.writeFileSync(path.join(area, 'tools/receipt.py'), 'original source');
    assert.strictEqual(request(broad).status, 0, 'unchanged content may reuse valid proof without a new test');
    console.log('admission: active-gap repair allowed; successor, mislabeled path and invented-gap edits refused');
} finally { fs.rmSync(area, { recursive: true, force: true }); }
