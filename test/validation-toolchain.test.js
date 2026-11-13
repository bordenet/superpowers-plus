#!/usr/bin/env node
'use strict';
const assert = require('assert');
const fs = require('fs');
const os = require('os');
const path = require('path');
const { spawnSync } = require('child_process');
const source = path.resolve(__dirname, '..');
const area = fs.mkdtempSync(path.join(os.tmpdir(), 'toolchain contract '));
const root = path.join(area, 'source');
const home = path.join(area, 'home');
const bin = path.join(area, 'bin');
for (const p of [root, home, bin, path.join(root, 'tools'), path.join(root, 'config')]) fs.mkdirSync(p);
const env = { HOME: home, PATH: bin + path.delimiter + process.env.PATH, LANG: 'C', COUNTER: path.join(area, 'heavy') };
const exec = (cmd, args, extra = {}) => spawnSync(cmd, args, { cwd: root, env: { ...env, ...extra }, encoding: 'utf8', timeout: 15000 });
const pass = r => assert.strictEqual(r.status, 0, r.stdout + r.stderr);
const count = () => fs.existsSync(env.COUNTER) ? fs.readFileSync(env.COUNTER, 'utf8').length : 0;
try {
    // The absent new entrypoint is the initial RED; no heavyweight body ran.
    assert(fs.existsSync(path.join(source, 'tools/validation-toolchain.py')), 'shared preflight must exist');
    for (const name of ['validation-receipt.py', 'validation-strategy.py', 'validation-inputs.py', 'validation-toolchain.py', 'test-tree-guard.sh']) {
        fs.copyFileSync(path.join(source, 'tools', name), path.join(root, 'tools', name));
    }
    fs.chmodSync(path.join(root, 'tools/test-tree-guard.sh'), 0o755);
    const contract = fs.readFileSync(path.join(source, 'config/validation-toolchain.json'), 'utf8');
    const policy = path.join(root, 'config/validation-toolchain.json'); fs.writeFileSync(policy, contract);
    fs.writeFileSync(path.join(root, 'tools/public-repo-ip-check.sh'), '#!/usr/bin/env bash\nexit 0\n');
    const prefix = fs.readFileSync(path.join(source, 'tools/test-all.sh'), 'utf8').split('# VALIDATION_RECEIPT_BODY\n')[0];
    fs.writeFileSync(path.join(root, 'tools/test-all.sh'), prefix + '# VALIDATION_RECEIPT_BODY\nprintf x >> "$COUNTER"\n');
    const lint = path.join(bin, 'shellcheck');
    const shellcheck = version => fs.writeFileSync(lint, `#!/usr/bin/env bash\nif [[ "$1" == --version ]]; then printf 'ShellCheck\\nversion: ${version}\\n'; else printf x >> "$COUNTER"; fi\n`, { mode: 0o755 });
    fs.writeFileSync(path.join(bin, 'bats'), '#!/usr/bin/env bash\necho Bats 1.11.0\n', { mode: 0o755 });
    shellcheck('0.10.0');
    for (const args of [['init', '-q'], ['config', 'user.name', 'Tool Fixture'], ['config', 'user.email', 'tool@example.invalid'], ['add', '.'], ['commit', '-qm', 'baseline']]) pass(exec('git', args));
    const run = args => exec('bash', ['tools/test-all.sh', ...(args || [])]);
    let r = run(); assert.notStrictEqual(r.status, 0); assert(/shellcheck.*0\.11\.0/i.test(r.stderr), r.stderr); assert.strictEqual(count(), 0);
    shellcheck('0.11.0'); pass(run()); assert.strictEqual(count(), 1);
    const executionBin = path.join(area, 'Git execution tools'); fs.mkdirSync(executionBin);
    fs.writeFileSync(path.join(executionBin, 'shellcheck'), fs.readFileSync(lint, 'utf8').replace('0.11.0', '0.10.0'), { mode: 0o755 });
    r = exec('bash', ['tools/test-all.sh'], { GIT_EXEC_PATH: executionBin });
    assert.notStrictEqual(r.status, 0, 'preflight must validate the actual normalized execution PATH');
    assert.strictEqual(count(), 1, 'shadowed incompatible tool refuses before any heavy body');

    // Missing and a configured executable differing from the actual dispatch
    // are refused before context/lock/body work, including after a prior PASS.
    const changed = JSON.parse(contract); changed.tools.shellcheck.command = '/nonexistent/shellcheck';
    fs.writeFileSync(policy, JSON.stringify(changed));
    r = run(); assert.notStrictEqual(r.status, 0); assert(/shellcheck/i.test(r.stderr)); assert.strictEqual(count(), 1);
    const other = path.join(area, 'other-shellcheck'); fs.copyFileSync(lint, other); fs.chmodSync(other, 0o755);
    changed.tools.shellcheck.command = other; fs.writeFileSync(policy, JSON.stringify(changed));
    r = run(); assert.notStrictEqual(r.status, 0); assert(/dispatch|configured/i.test(r.stderr)); assert.strictEqual(count(), 1);
    fs.writeFileSync(policy, contract);
    // Exercise the actual unsupported-platform predicate without adding a
    // public environment escape hatch for pretending to be another platform.
    r = exec('python3', ['-B', '-c', `import importlib.util,pathlib\np=pathlib.Path('tools/validation-toolchain.py');s=importlib.util.spec_from_file_location('t',p);m=importlib.util.module_from_spec(s);s.loader.exec_module(m)\nm.platform.system=lambda:'Windows'\nm.preflight(pathlib.Path('.'), ['shellcheck'])`]);
    assert.notStrictEqual(r.status, 0); assert(/platform/i.test(r.stderr)); assert.strictEqual(count(), 1);
    // Real native hook Git variables are normalized before preflight, and the
    // intentional Python dispatch preserves the line-specific exec directive.
    r = run(['--check', 'shellcheck']); pass(r);
    const native = exec('bash', ['tools/test-all.sh', '--check', 'shellcheck'], { GIT_DIR: path.join(root, '.git') }); pass(native);
    assert(native.stdout.includes('reusing PASS'), native.stdout);
    fs.unlinkSync(policy); r = run(); assert.notStrictEqual(r.status, 0); assert.strictEqual(count(), 1);
    const contractData = JSON.parse(contract);
    for (const asset of Object.values(contractData.shellcheck_release.assets)) {
        assert(/^[a-f0-9]{64}$/.test(asset.sha256));
        assert(asset.url.startsWith('https://github.com/koalaman/shellcheck/releases/download/v0.11.0/'));
    }
    for (const workflow of ['test.yml', 'harsh-review.yml']) {
        const text = fs.readFileSync(path.join(source, '.github/workflows', workflow), 'utf8');
        assert(!/apt-get install -y shellcheck/.test(text));
        assert(text.includes('validation-toolchain.py --provision-shellcheck'));
    }
    console.log('toolchain: mismatch/missing/configured executable/native platform refuse before heavy work; pinned CI contract and native reuse pass');
} finally { fs.rmSync(area, { recursive: true, force: true }); }
