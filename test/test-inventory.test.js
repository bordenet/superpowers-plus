#!/usr/bin/env node
'use strict';

const assert = require('assert');
const fs = require('fs');
const path = require('path');

const ROOT = path.resolve(__dirname, '..');
const INVENTORY = path.join(ROOT, 'docs', 'harness', 'test-inventory.tsv');

function walk(dir, out = []) {
    if (!fs.existsSync(dir)) return out;
    for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
        const full = path.join(dir, entry.name);
        if (entry.isDirectory()) walk(full, out);
        else out.push(path.relative(ROOT, full));
    }
    return out;
}

function retainedTests() {
    const all = [
        ...walk(path.join(ROOT, 'test')),
        ...walk(path.join(ROOT, 'tests')),
        ...walk(path.join(ROOT, 'skills')),
        ...walk(path.join(ROOT, 'tools', 'tests')),
    ];
    const selected = all.filter(file => (
        file.endsWith('.bats')
        || /^test\/(?:[^/]+\.test|test_[^/]+|integration-test)\.(js|sh|py)$/.test(file)
        || /^tools\/tests\/test_[^/]+\.(js|sh|py)$/.test(file)
        || /^skills\/.*\/tests\/test_[^/]+\.(js|sh|py)$/.test(file)
    ));
    selected.push('mcp/smoke-test.js');
    return [...new Set(selected)].sort();
}

assert(fs.existsSync(INVENTORY), `missing durable test inventory: ${path.relative(ROOT, INVENTORY)}`);

const lines = fs.readFileSync(INVENTORY, 'utf8')
    .split(/\r?\n/)
    .filter(line => line && !line.startsWith('#'));
assert.strictEqual(lines.shift(), 'status\tkind\tpath\trunner\tcoverage');

const rows = new Map();
for (const line of lines) {
    const fields = line.split('\t');
    assert.strictEqual(fields.length, 5, `inventory row must have 5 tab-separated fields: ${line}`);
    const [status, kind, file, runner, coverage] = fields;
    assert(['retained', 'deleted'].includes(status), `invalid status for ${file}: ${status}`);
    assert(kind.trim(), `missing kind for ${file}`);
    assert(file.trim(), 'inventory path must not be empty');
    assert(runner.trim() && !/^tbd$/i.test(runner), `missing runner for ${file}`);
    assert(coverage.trim() && !/^tbd$/i.test(coverage), `missing coverage for ${file}`);
    assert(!rows.has(file), `duplicate inventory path: ${file}`);
    rows.set(file, { status, kind, runner, coverage });
}

const retained = retainedTests();
assert(retained.length > 0, 'test discovery returned zero retained suites');
for (const file of retained) {
    assert(rows.has(file), `retained test missing from inventory: ${file}`);
    assert.strictEqual(rows.get(file).status, 'retained', `live test marked deleted: ${file}`);
}

const staleRetained = [...rows]
    .filter(([, row]) => row.status === 'retained')
    .map(([file]) => file)
    .filter(file => !retained.includes(file));
assert.deepStrictEqual(staleRetained, [], `inventory has stale retained tests: ${staleRetained.join(', ')}`);

const deleted = [...rows].filter(([, row]) => row.status === 'deleted');
assert(deleted.length > 0, 'inventory must preserve P1h deletion decisions');
for (const [file] of deleted) {
    assert(!fs.existsSync(path.join(ROOT, file)), `deleted inventory path still exists: ${file}`);
}

console.log(`test inventory valid: ${retained.length} retained tests, ${deleted.length} deleted artifacts`);
