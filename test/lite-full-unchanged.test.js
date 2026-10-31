'use strict';

const assert = require('node:assert/strict');
const { test } = require('node:test');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { spawnSync } = require('node:child_process');

const ROOT = path.resolve(__dirname, '..');
const ORACLE = '5f9d9e57ac135cb862ed821dba5feb3b214ba744';

// P1 changes metadata/CI only. Freeze both payload and installer/runtime inputs
// to prove that Full sees no new file, changed byte, destination, or command.
// Installer phases must supply deployed-output parity before changing inputs.
function fullInput(file) {
    return /^(skills|rules|lib|tools)\//.test(file) ||
        ['superpowers-augment.js', 'install.sh', 'uninstall.sh'].includes(file);
}

function git(root, args) {
    const result = spawnSync('git', ['-C', root, ...args], { encoding: null });
    assert.equal(result.status, 0, `git ${args.join(' ')}: ${result.stderr}`);
    return result.stdout;
}

function compareInputs(root, oracle) {
    const tree = git(root, ['ls-tree', '-r', '-z', oracle]).toString().split('\0').filter(Boolean);
    const expected = new Map();
    for (const record of tree) {
        const [header, file] = record.split('\t');
        if (fullInput(file)) expected.set(file, header.split(' ')[0]);
    }
    const current = [...new Set(git(root, ['ls-files', '-z', '--cached', '--others', '--exclude-standard'])
        .toString().split('\0').filter(file => file && fullInput(file)))].sort();
    assert.deepEqual(current, [...expected.keys()].sort(), 'Full input inventory differs from oracle');
    for (const [file, mode] of expected) {
        const target = path.join(root, file);
        const stat = fs.lstatSync(target);
        const actual = stat.isSymbolicLink() ? Buffer.from(fs.readlinkSync(target)) : fs.readFileSync(target);
        assert.deepEqual(actual, git(root, ['show', `${oracle}:${file}`]), `Full bytes changed: ${file}`);
        const actualMode = stat.isSymbolicLink() ? '120000' : (stat.mode & 0o111 ? '100755' : '100644');
        assert.equal(actualMode, mode, `Full file mode changed: ${file}`);
    }
}

test('Full input inventory, bytes and file modes match the permanent oracle', () => {
    compareInputs(ROOT, ORACLE);
});

test('oracle comparison rejects changed bytes, added files and changed modes', () => {
    const root = fs.mkdtempSync(path.join(os.tmpdir(), 'lite-oracle-'));
    try {
        fs.mkdirSync(path.join(root, 'skills'));
        const file = path.join(root, 'skills/skill.md');
        fs.writeFileSync(file, 'Original.\n');
        git(root, ['init', '-q']);
        git(root, ['add', '.']);
        git(root, ['-c', 'user.name=Fixture', '-c', 'user.email=fixture@example.invalid', 'commit', '-qm', 'fixture']);
        const oracle = git(root, ['rev-parse', 'HEAD']).toString().trim();
        compareInputs(root, oracle);
        fs.writeFileSync(file, 'Changed.\n');
        assert.throws(() => compareInputs(root, oracle), /Full bytes changed/);
        fs.writeFileSync(file, 'Original.\n');
        fs.writeFileSync(path.join(root, 'skills/extra.md'), 'Extra.\n');
        assert.throws(() => compareInputs(root, oracle), /Full input inventory/);
        fs.unlinkSync(path.join(root, 'skills/extra.md'));
        fs.chmodSync(file, 0o755);
        assert.throws(() => compareInputs(root, oracle), /Full file mode/);
    } finally {
        fs.rmSync(root, { recursive: true, force: true });
    }
});
