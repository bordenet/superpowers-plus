'use strict';

const assert = require('node:assert/strict');
const { test } = require('node:test');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { spawnSync } = require('node:child_process');

const ROOT = path.resolve(__dirname, '..');
const SCRIPT = path.join(ROOT, 'scripts/validate-lite-manifest.js');
const CORE = [
    'using-superpowers', 'push-authorization-gate', 'merge-authorization-gate',
    'unified-commit-gate', 'branch-sync-gate', 'superpowers-doctor',
    'systematic-debugging', 'verification-before-completion',
];
const HOSTS = ['claude-code', 'augment', 'codex'];

function fixture(run) {
    const root = fs.mkdtempSync(path.join(os.tmpdir(), 'lite-manifest-'));
    const skills = [...CORE, 'example-reference'].map(name => {
        const relative = `skills/example/${name}/skill.md`;
        const file = path.join(root, relative);
        fs.mkdirSync(path.dirname(file), { recursive: true });
        fs.writeFileSync(file, `---\nname: ${name}\ndescription: "Read the reference."\n---\nBody.\n`);
        return {
            name, path: relative, tier: CORE.includes(name) ? 'core' : 'on-demand',
            hosts: Object.fromEntries(HOSTS.map(host => [host, name])),
        };
    });
    try {
        return run({ root, manifest: { schema_version: 1, default_tier: 'on-demand', skills } });
    } finally {
        fs.rmSync(root, { recursive: true, force: true });
    }
}

function verify(f) {
    return require(SCRIPT).validateManifest(f.manifest, { repoRoot: f.root });
}

test('repository manifest validates against the full source inventory', () => {
    const result = spawnSync(process.execPath, [SCRIPT], { encoding: 'utf8' });
    assert.equal(result.status, 0, result.stderr);
    const report = JSON.parse(result.stdout);
    assert.equal(report.core_count, CORE.length);
    assert.ok(report.skill_count > report.core_count);
    assert.equal(report.manifest_entry_count, CORE.length);
    assert.equal(report.default_tier, 'on-demand');
    assert.equal(report.core_metadata_bytes, 2390);
});

test('valid manifest includes references without listing them as core', () => fixture(f => {
    const result = verify(f);
    assert.equal(result.skill_count, 9);
    assert.equal(result.core_count, 8);
}));

test('safe on-demand default preserves unreferenced store entries', () => fixture(f => {
    f.manifest.default_tier = 'on-demand';
    f.manifest.skills = f.manifest.skills.filter(e => e.tier === 'core');
    const result = verify(f);
    assert.equal(result.skill_count, 9);
    assert.equal(result.manifest_entry_count, 8);
    assert.equal(result.core_count, 8);
}));

test('byte metric measures decoded strings, including Unicode and whitespace', () => {
    const { metadataBytes } = require(SCRIPT);
    const decoded = JSON.parse('{"name":"a","description":"\u00e9\ud83d\ude00\\n"}');
    assert.equal(metadataBytes([decoded]), 8);
    assert.equal(metadataBytes([{ name: 'n', description: ' x ' }]), 4);
    assert.throws(() => metadataBytes([{ name: 'n' }]), /description/);
});

test('canonical core membership is exact, including doctor', () => fixture(f => {
    f.manifest.skills.find(e => e.name === 'superpowers-doctor').tier = 'on-demand';
    assert.throws(() => verify(f), /core set/);
}));

test('an extra core skill is rejected', () => fixture(f => {
    f.manifest.skills.at(-1).tier = 'core';
    assert.throws(() => verify(f), /core set/);
}));

test('duplicate canonical names and source paths are rejected', () => fixture(f => {
    f.manifest.skills.push(structuredClone(f.manifest.skills[0]));
    assert.throws(() => verify(f), /duplicate canonical/);
}));

test('duplicate destinations are checked within each host', () => fixture(f => {
    f.manifest.skills[1].hosts.codex = f.manifest.skills[0].hosts.codex;
    assert.throws(() => verify(f), /duplicate.*destination.*codex/);
}));

test('the same destination on different hosts is allowed', () => fixture(f => {
    f.manifest.skills[0].hosts['claude-code'] = 'cross-root-name';
    f.manifest.skills[1].hosts.augment = 'cross-root-name';
    f.manifest.skills[1].hosts.codex = 'cross-root-name';
    assert.doesNotThrow(() => verify(f));
}));

test('Augment and Codex destinations agree for their shared listing root', () => fixture(f => {
    f.manifest.skills[0].hosts.augment = 'different-shared-name';
    assert.throws(() => verify(f), /shared.*destination/);
}));

test('destinations cannot collide across hosts sharing the same root', () => fixture(f => {
    f.manifest.skills.at(-1).hosts = { augment: 'shared-collision' };
    const relative = 'skills/example/another-reference/skill.md';
    fs.mkdirSync(path.dirname(path.join(f.root, relative)), { recursive: true });
    fs.writeFileSync(path.join(f.root, relative),
        '---\nname: another-reference\ndescription: "Another reference."\n---\n');
    f.manifest.skills.push({
        name: 'another-reference', path: relative, tier: 'on-demand',
        hosts: { codex: 'shared-collision' },
    });
    assert.throws(() => verify(f), /duplicate.*destination.*shared/);
}));

test('unknown hosts and missing core host selections are rejected', () => fixture(f => {
    f.manifest.skills[0].hosts.unknown = 'unknown';
    assert.throws(() => verify(f), /unknown host/);
    delete f.manifest.skills[0].hosts.unknown;
    delete f.manifest.skills[0].hosts.codex;
    assert.throws(() => verify(f), /core.*host/);
}));

test('unsafe destination and source paths are rejected', () => fixture(f => {
    f.manifest.skills[0].hosts.codex = '../outside';
    assert.throws(() => verify(f), /destination/);
    f.manifest.skills[0].hosts.codex = f.manifest.skills[0].name;
    f.manifest.skills[0].path = '../outside/skill.md';
    assert.throws(() => verify(f), /source path/);
}));

test('missing referenced files and missing core entries fail closed', () => fixture(f => {
    f.manifest.skills[0].path = 'skills/example/missing/skill.md';
    assert.throws(() => verify(f), /source path/);
    f.manifest.skills.shift();
    assert.throws(() => verify(f), /core set/);
}));

test('manifest names must match source metadata', () => fixture(f => {
    const file = path.join(f.root, f.manifest.skills[0].path);
    fs.writeFileSync(file, '---\nname: different\ndescription: "Reference."\n---\n');
    assert.throws(() => verify(f), /source path|metadata/);
}));

test('source symlinks cannot read outside the inventory', () => fixture(f => {
    const file = path.join(f.root, f.manifest.skills[0].path);
    fs.unlinkSync(file);
    fs.symlinkSync(path.join(f.root, f.manifest.skills[1].path), file);
    assert.throws(() => verify(f), /symlink/);
}));

test('malformed or empty source metadata is rejected', () => fixture(f => {
    const file = path.join(f.root, f.manifest.skills[0].path);
    fs.writeFileSync(file, 'No frontmatter.\n');
    assert.throws(() => verify(f), /frontmatter|metadata/);
}));

test('decoded core metadata cap is enforced with no manifest override', () => fixture(f => {
    const file = path.join(f.root, f.manifest.skills[0].path);
    fs.writeFileSync(file, `---\nname: ${f.manifest.skills[0].name}\ndescription: "${'é'.repeat(1600)}"\n---\n`);
    assert.throws(() => verify(f), /core metadata.*3000/);
    f.manifest.core_metadata_max_bytes = 999999;
    assert.throws(() => verify(f), /unknown.*field/);
}));

test('unknown versions, fields and tiers fail closed', () => fixture(f => {
    f.manifest.schema_version = 2;
    assert.throws(() => verify(f), /schema_version/);
    f.manifest.schema_version = 1;
    f.manifest.skills[0].tier = 'automatic';
    assert.throws(() => verify(f), /tier/);
    f.manifest.skills[0].tier = 'core';
    f.manifest.skills[0].typo = true;
    assert.throws(() => verify(f), /unknown.*field/);
}));

test('default tier cannot automatically list unreferenced skills', () => fixture(f => {
    f.manifest.default_tier = 'core';
    assert.throws(() => verify(f), /default_tier/);
}));

test('CLI distinguishes invalid manifests from usage errors', () => fixture(f => {
    const file = path.join(f.root, 'manifest.json');
    fs.writeFileSync(file, '{');
    const invalid = spawnSync(process.execPath, [SCRIPT, '--manifest', file], { encoding: 'utf8' });
    assert.equal(invalid.status, 1);
    assert.match(invalid.stderr, /JSON/);
    const usage = spawnSync(process.execPath, [SCRIPT, '--unknown'], { encoding: 'utf8' });
    assert.equal(usage.status, 2);
    const missing = spawnSync(process.execPath, [SCRIPT, '--manifest'], { encoding: 'utf8' });
    assert.equal(missing.status, 2);
}));
