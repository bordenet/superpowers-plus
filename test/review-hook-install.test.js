#!/usr/bin/env node
'use strict';
const assert = require('assert');
const fs = require('fs');
const os = require('os');
const path = require('path');
const { spawnSync } = require('child_process');
const source = path.resolve(__dirname, '..');
const area = fs.mkdtempSync(path.join(os.tmpdir(), 'native hook registration '));
try {
    const home = path.join(area, 'home with spaces');
    const foreign = path.join(area, 'external codex profile');
    const project = path.join(area, 'project with spaces');
    for (const item of [home, foreign, project]) fs.mkdirSync(item);
    const env = { PATH: process.env.PATH, HOME: home, LANG: 'C' };
    const shell = spawnSync('bash', ['-c', 'command -v bash'], { env, encoding: 'utf8' }).stdout.trim();
    assert(path.isAbsolute(shell));
    const installer = path.join(source, 'setup/install-review-strategy-hooks.py');
    function install(args = [], installerEnv = env) {
        return spawnSync('python3', [installer, '--home', home, ...args], { env: installerEnv, encoding: 'utf8' });
    }
    const old = { permissions: { deny: ['Bash(rm *)'] }, custom: 'preserve', hooks: {
        PreToolUse: [{ matcher: 'Read', hooks: [{ type: 'command', command: 'echo foreign' }] }] } };
    for (const host of ['codex', 'claude']) {
        const base = path.join(home, '.' + host); fs.mkdirSync(base);
        fs.writeFileSync(path.join(base, host === 'codex' ? 'hooks.json' : 'settings.json'), JSON.stringify(old));
    }
    let r = install(['--host', 'codex', '--host', 'claude'], { ...env, CODEX_HOME: foreign });
    assert.strictEqual(r.status, 0, r.stdout + r.stderr);
    assert.deepStrictEqual(fs.readdirSync(foreign), [], '--home must isolate external profile overrides');
    const commands = {}, snapshots = {};
    function config(host) { return path.join(home, '.' + host, host === 'codex' ? 'hooks.json' : 'settings.json'); }
    for (const host of ['codex', 'claude']) {
        const data = JSON.parse(fs.readFileSync(config(host), 'utf8'));
        assert.deepStrictEqual(data.permissions, old.permissions); assert.strictEqual(data.custom, old.custom);
        assert.deepStrictEqual(data.hooks.PreToolUse[0], old.hooks.PreToolUse[0]);
        assert.strictEqual(data.hooks.PreToolUse.length, 2);
        commands[host] = data.hooks.PreToolUse[1].hooks[0].command;
        snapshots[host] = fs.readFileSync(config(host), 'utf8');
    }
    r = install(['--host', 'codex', '--host', 'claude']); assert.strictEqual(r.status, 0, r.stderr);
    for (const host of ['codex', 'claude']) assert.strictEqual(fs.readFileSync(config(host), 'utf8'), snapshots[host]);
    r = install(['--host', 'codex', '--host', 'claude', '--check']); assert.strictEqual(r.status, 0, r.stderr);
    // Registration presence is distinct from copied hook bytes.
    fs.writeFileSync(config('codex'), JSON.stringify(old));
    assert.notStrictEqual(install(['--host', 'codex', '--check']).status, 0);
    fs.writeFileSync(config('codex'), snapshots.codex);
    fs.cpSync(path.join(source, 'tools'), path.join(project, 'tools'), { recursive: true });
    fs.mkdirSync(path.join(project, 'config')); fs.mkdirSync(path.join(project, 'lib'));
    fs.copyFileSync(path.join(source, 'config/review-strategy.json'), path.join(project, 'config/review-strategy.json'));
    fs.writeFileSync(path.join(project, 'lib/value.js'), 'const value = 1;\n');
    function git(...args) {
        const result = spawnSync('git', args, { cwd: project, env, encoding: 'utf8' });
        assert.strictEqual(result.status, 0, result.stderr); return result.stdout.trim();
    }
    git('init', '-q'); git('config', 'user.email', 'hooks@example.invalid'); git('config', 'user.name', 'Hook Fixture');
    git('add', '.'); git('commit', '-qm', 'baseline'); git('update-ref', 'refs/remotes/origin/dev', git('rev-parse', 'HEAD'));
    fs.writeFileSync(path.join(project, 'lib/value.js'), 'const value = 2;\n'); git('add', '.');
    function plan() {
        const result = spawnSync('python3', ['tools/review-preflight.py', '--staged'], { cwd: project, env, encoding: 'utf8', timeout: 10000 });
        assert.strictEqual(result.status, 0, result.stderr); return JSON.parse(result.stdout).strategy.snapshot;
    }
    let calls = 0;
    function event(host, message, overrides = {}) {
        const input = { hook_event_name: 'PreToolUse', tool_name: host === 'codex' ? 'spawn_agent' : 'Agent',
            cwd: project, tool_use_id: host + '-fixture', tool_input: host === 'codex' ? { message } : { prompt: message } };
        const result = spawnSync(shell, ['-c', commands[host]], { cwd: project, env: { ...env, ...overrides },
            input: JSON.stringify(input), encoding: 'utf8', timeout: 30000 });
        assert.strictEqual(result.status, 0, String(result.error || '') + (result.stdout || '') + (result.stderr || ''));
        const payload = JSON.parse(result.stdout).hookSpecificOutput;
        assert.notStrictEqual(payload.permissionDecision, 'allow', 'optimizer must not grant host permissions');
        if (payload.permissionDecision !== 'deny') {
            assert(payload.additionalContext.startsWith('REVIEW_REQUIRED:'), result.stdout);
            const child = spawnSync(process.execPath, ['-e', 'process.stdout.write("fixture dispatch")'], { encoding: 'utf8' });
            assert.strictEqual(child.status, 0); calls++;
        }
        return payload;
    }
    assert.strictEqual(event('codex', 'Review missing snapshot', { CLAUDE_HOOKS_BYPASS: '1' }).permissionDecision, 'deny');
    assert.strictEqual(calls, 0);
    const first = plan();
    let message = `Review code. SPP_REVIEW_CLASS=code SPP_REVIEW_SNAPSHOT=${first}`;
    assert.strictEqual(event('codex', message).permissionDecision, undefined); assert.strictEqual(calls, 1);
    assert.strictEqual(event('codex', message).permissionDecision, 'deny'); assert.strictEqual(calls, 1);
    fs.writeFileSync(path.join(project, 'lib/value.js'), 'const value = 3;\n'); git('add', '.');
    message = `Review delta. SPP_REVIEW_CLASS=code SPP_REVIEW_SNAPSHOT=${plan()}`;
    assert.strictEqual(event('claude', message).permissionDecision, undefined); assert.strictEqual(calls, 2);
    // A broken interpreter or companion must return supported denial, not a
    // hook crash that the native host may treat as non-blocking.
    assert.strictEqual(event('codex', message, { PATH: '/nonexistent' }).permissionDecision, 'deny');
    assert.strictEqual(calls, 2);
    const broker = path.join(home, '.codex/hooks/pre-tool-use-review-strategy.py');
    fs.renameSync(broker, broker + '.saved');
    assert.strictEqual(event('codex', message).permissionDecision, 'deny'); fs.renameSync(broker + '.saved', broker);
    const backend = path.join(project, 'tools/review-dispatch-guard.py'); const originalBackend = fs.readFileSync(backend);
    fs.writeFileSync(backend, 'import json\nprint(json.dumps({"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"allow"}}))\n');
    assert.strictEqual(event('codex', message).permissionDecision, 'deny'); fs.writeFileSync(backend, originalBackend);
    assert.strictEqual(calls, 2);
    // Refresh never creates an unregistered host hook or changes foreign settings.
    fs.writeFileSync(config('codex'), JSON.stringify(old));
    r = install(['--refresh-existing']); assert.strictEqual(r.status, 0, r.stderr);
    assert.deepStrictEqual(JSON.parse(fs.readFileSync(config('codex'), 'utf8')), old);
    fs.writeFileSync(config('codex'), snapshots.codex);
    const otherBin = path.join(area, 'alternate Bash lookup'); fs.mkdirSync(otherBin);
    fs.symlinkSync(shell, path.join(otherBin, 'bash'));
    const changedPath = { ...env, PATH: otherBin + path.delimiter + env.PATH };
    r = install(['--refresh-existing', '--check'], changedPath);
    assert.strictEqual(r.status, 0, r.stderr);
    assert.strictEqual(JSON.parse(r.stdout).profiles, 2, 'owned registrations survive a changed Bash lookup');
    const managed = path.join(home, '.codex/hooks/pre-tool-use-review-strategy.sh');
    fs.appendFileSync(managed, '# owner customization\n');
    r = install(['--host', 'codex', '--host', 'claude', '--remove'], changedPath); assert.strictEqual(r.status, 0, r.stderr);
    assert(fs.existsSync(managed), 'modified file must be preserved');
    for (const host of ['codex', 'claude']) {
        const data = JSON.parse(fs.readFileSync(config(host), 'utf8'));
        assert.deepStrictEqual(data, old, 'remove only owned registration, preserving foreign keys/hooks');
    }
    // Generic HOME-targeting install/uninstall must not refresh or remove an
    // independently selected external Codex profile from the caller's env.
    const foreignProfile = fs.realpathSync(foreign);
    r = spawnSync('python3', [installer, '--host', 'codex'], { env: { ...env, CODEX_HOME: foreignProfile }, encoding: 'utf8' });
    assert.strictEqual(r.status, 0, r.stdout + r.stderr);
    const foreignHook = path.join(foreignProfile, 'hooks/pre-tool-use-review-strategy.sh');
    fs.appendFileSync(foreignHook, '# independent owner customization\n');
    const foreignConfig = fs.readFileSync(path.join(foreignProfile, 'hooks.json'));
    const foreignBytes = fs.readFileSync(foreignHook);
    const scopedEnv = { ...env, CODEX_HOME: foreignProfile, SUPERPOWERS_CLAUDE_GUARDRAILS: '1' };
    r = spawnSync(shell, [path.join(source, 'setup/install-claude-guardrails.sh')], { env: scopedEnv, encoding: 'utf8', timeout: 30000 });
    assert.strictEqual(r.status, 0, r.stdout + r.stderr);
    assert.deepStrictEqual(fs.readFileSync(foreignHook), foreignBytes, 'HOME installer must preserve external Codex profile');
    assert.deepStrictEqual(fs.readFileSync(path.join(foreignProfile, 'hooks.json')), foreignConfig);
    r = spawnSync(shell, [path.join(source, 'uninstall.sh'), '--yes'], { env: scopedEnv, encoding: 'utf8', timeout: 30000 });
    assert.strictEqual(r.status, 0, r.stdout + r.stderr);
    assert.deepStrictEqual(fs.readFileSync(foreignHook), foreignBytes, 'HOME uninstaller must preserve external Codex profile');
    assert.deepStrictEqual(fs.readFileSync(path.join(foreignProfile, 'hooks.json')), foreignConfig);
    console.log('native registration: Codex/Claude callbacks refuse missing/repeated/unsafe requests; valid scopes dispatch once; foreign settings, permissions, overrides and customized files preserved');
} finally { fs.rmSync(area, { recursive: true, force: true }); }
