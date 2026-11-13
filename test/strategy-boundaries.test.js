#!/usr/bin/env node
'use strict';
const assert = require('assert');
const fs = require('fs');
const path = require('path');
const root = path.resolve(__dirname, '..');
const manifest = JSON.parse(fs.readFileSync(path.join(root, 'config/validation-checks.json'), 'utf8'));
const bodies = fs.readFileSync(path.join(root, 'tools/lib/ci-validation-bodies.sh'), 'utf8');
assert.strictEqual(manifest.schema, 1);
assert.strictEqual(new Set(manifest.ci_checks).size, manifest.ci_checks.length);
for (const check of manifest.ci_checks) assert(bodies.includes(`        ${check})`), check);
for (const filename of ['test.yml', 'harsh-review.yml']) {
    const source = fs.readFileSync(path.join(root, '.github/workflows', filename), 'utf8');
    let name = '';
    for (const line of source.split('\n')) {
        const named = line.match(/^      - name: (.*)/); if (named) name = named[1];
        const run = line.match(/^        run: (.*)/); if (!run) continue;
        if (manifest.provisioning_steps.includes(name) || manifest.protocol_steps.includes(name)) continue;
        assert(run[1].startsWith('bash tools/test-all.sh --check '), `${filename}: unregistered ${name}: ${run[1]}`);
        const check = run[1].split(' ').at(-1);
        assert(check === 'harsh' || manifest.ci_checks.includes(check), `${filename}: unknown check`);
    }
}
console.log('strategy boundaries: CI execution bodies are registered; provisioning and protocol steps remain explicit');

assert(manifest.provisioning_steps.includes('Configure git identity'));
assert(!manifest.ci_checks.includes('ci:shell-tests-configure-git-identity'));
assert(!bodies.includes('ci:shell-tests-configure-git-identity)'));

// This checkout's supported contract has no opaque configured gate. Preserve
// legacy evaluation elsewhere; adding one here requires an audited registration
// or explicit support amendment before this enforcement matrix can pass.
for (const line of fs.readFileSync(path.join(root, '.agent-gates'), 'utf8').split(/\r?\n/)) {
    const match = line.match(/^\s*(EXTRA_LINT|EXTRA_TYPECHECK|EXTRA_TEST)\s*=\s*(.*)$/);
    if (!match) continue;
    const value = match[2].trim().replace(/^(".*"|'.*')$/, text => text.slice(1, -1));
    assert(!value, `${match[1]} is opaque: register its coverage or amend the declared support contract`);
}
