'use strict';

const assert = require('node:assert/strict');
const { test } = require('node:test');
const fs = require('node:fs');
const path = require('node:path');
const { installFull, snapshotFull, assertParity } = require('./helpers/lite-full-install');

test('real Full installation matches the permanent oracle and rejects deployed drift', () => {
    const root = path.resolve(__dirname, '..');
    const workspace = fs.mkdtempSync(path.join(process.env.TMPDIR || process.env.HOME, 'lite-full-'));
    try {
        const expected = JSON.parse(fs.readFileSync(path.join(__dirname, 'fixtures/lite/full-oracle.json')));
        const installed = installFull(root, workspace);
        const capture = () => snapshotFull(installed);
        assertParity(capture(), expected);

        const rawLstat = fs.lstatSync;
        try {
            for (const permissions of [0o755, 0o777]) {
                fs.lstatSync = (...args) => {
                    const stat = rawLstat(...args);
                    return stat.isSymbolicLink() ? Object.assign(
                        Object.create(Object.getPrototypeOf(stat)), stat,
                        { mode: (stat.mode & ~0o777) | permissions }) : stat;
                };
                assertParity(capture(), expected);
            }
        } finally { fs.lstatSync = rawLstat; }

        const skill = path.join(installed.home, '.claude/skills/sp-debug/skill.md');
        const original = fs.readFileSync(skill);
        fs.appendFileSync(skill, '\nChanged.\n');
        assert.throws(() => assertParity(capture(), expected), /Full output parity/);
        fs.writeFileSync(skill, original);

        const mode = fs.statSync(skill).mode & 0o777;
        fs.chmodSync(skill, mode ^ 0o100);
        assert.throws(() => assertParity(capture(), expected), /Full output parity/);
        fs.chmodSync(skill, mode);

        const companion = path.join(path.dirname(skill), 'root-cause-tracing.md');
        const companionBytes = fs.readFileSync(companion);
        fs.appendFileSync(companion, '\nChanged companion.\n');
        assert.throws(() => assertParity(capture(), expected), /Full output parity/);
        fs.writeFileSync(companion, companionBytes);

        const extra = path.join(installed.home, '.agents/skills/sp-catalog');
        fs.mkdirSync(extra);
        fs.writeFileSync(path.join(extra, 'SKILL.md'), 'Light helper.\n');
        assert.throws(() => assertParity(capture(), expected), /Full output parity/);
        fs.rmSync(extra, { recursive: true });

        const command = path.join(installed.home, '.claude/commands/systematic-debugging.md');
        const commandBytes = fs.readFileSync(command);
        fs.writeFileSync(command, commandBytes.toString().replace('/.agents/skills/', '/wrong/skills/'));
        assert.throws(capture, /command target/);
        fs.writeFileSync(command, commandBytes);

        fs.writeFileSync(command, commandBytes.toString().replace('/sp-debug//SKILL.md', '/sp-blast//SKILL.md'));
        assert.throws(() => assertParity(capture(), expected), /Full output parity/);
        fs.writeFileSync(command, commandBytes);

        const cli = path.join(installed.home, '.local/bin/sp-doctor');
        const cliTarget = fs.readlinkSync(cli);
        fs.unlinkSync(cli);
        fs.symlinkSync(path.join(installed.home, '.codex/superpowers-plus/tools/sp-update.sh'), cli);
        assert.throws(capture, /CLI target/);
        fs.unlinkSync(cli);
        fs.symlinkSync(cliTarget, cli);

        const adapter = path.join(installed.home, '.codex/superpowers-augment/superpowers-augment.js');
        fs.appendFileSync(adapter, '\nconsole.log("Unexpected bootstrap output");\n');
        assert.throws(() => assertParity(capture(), expected), /Full output parity/);
        fs.writeFileSync(adapter, fs.readFileSync(path.join(installed.source, 'superpowers-augment.js')));
        assertParity(capture(), expected);
    } finally {
        fs.rmSync(workspace, { recursive: true, force: true });
    }
});
