'use strict';

// Test-only Full export. Installers execute in a disposable source copy, with
// an allowlisted environment and private CLI bin. No model or network calls.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const { spawnSync } = require('node:child_process');

const ORACLE = '0a3959923097dd5af3ade06fe68668a9561983fd';
const ROOTS = ['.codex/skills', '.claude/skills', '.agents/skills',
    '.augment/rules', '.claude/commands', '.local/bin'];
const hash = bytes => crypto.createHash('sha256').update(bytes).digest('hex');

function executable(name) {
    const candidate = (process.env.PATH || '').split(path.delimiter)
        .map(dir => path.resolve(dir, name)).find(file => {
            try { fs.accessSync(file, fs.constants.X_OK); return fs.statSync(file).isFile(); }
            catch { return false; }
        });
    assert.ok(candidate, `Full harness requires ${name} on PATH`);
    return fs.realpathSync(candidate);
}

function run(argv, cwd, env, log) {
    const result = spawnSync(argv[0], argv.slice(1), {
        cwd, env, encoding: null, timeout: 180000, maxBuffer: 8 * 1024 * 1024,
    });
    if (log) fs.writeFileSync(log, Buffer.concat([result.stdout || Buffer.alloc(0),
        result.stderr || Buffer.alloc(0)]));
    assert.ifError(result.error);
    assert.equal(result.status, 0, `${argv[0]} exited ${result.status}: ${
        Buffer.concat([result.stdout, result.stderr]).toString().slice(-8000)}`);
    return result;
}

function copySource(root, dest, env) {
    // Include current working bytes and untracked, nonignored files so a test
    // cannot silently install HEAD instead of the change under review.
    const files = run([executable('git'), '-C', root, 'ls-files', '-z',
        '--cached', '--others', '--exclude-standard'], root, env).stdout.toString().split('\0');
    for (const file of new Set(files.filter(Boolean))) {
        assert.ok(!path.isAbsolute(file) && !file.split('/').includes('..'), 'Unsafe source path');
        assert.ok(!file.split('/').includes('.git'), 'Git metadata is not a source payload');
        if (file === '.env') continue;
        const from = path.join(root, file);
        const to = path.join(dest, file);
        let stat;
        try { stat = fs.lstatSync(from); }
        catch (error) { if (error.code === 'ENOENT') continue; throw error; }
        fs.mkdirSync(path.dirname(to), { recursive: true });
        if (stat.isSymbolicLink()) {
            const target = fs.readlinkSync(from);
            const relative = path.relative(root, path.resolve(path.dirname(from), target));
            assert.ok(!path.isAbsolute(target) && !relative.startsWith('..') &&
                !relative.split(path.sep).includes('.git'), `Unsafe source link: ${file}`);
            fs.symlinkSync(target, to);
            continue;
        }
        assert.ok(stat.isFile(), `Unsupported source entry: ${file}`);
        fs.copyFileSync(from, to);
        fs.chmodSync(to, stat.mode & 0o777);
    }
}

function installFull(root, workspace) {
    const home = path.join(workspace, 'home');
    const source = path.join(workspace, 'source');
    const bin = path.join(workspace, 'bin');
    for (const dir of [home, source, bin, path.join(home, '.local/bin'), path.join(workspace, 'tmp')]) {
        fs.mkdirSync(dir, { recursive: true });
    }
    const tools = { node: process.execPath };
    for (const name of ['bash', 'git', 'python3', 'jq', 'zip', 'unzip']) tools[name] = executable(name);
    assert.ok(Number(run([tools.bash, '-c', 'printf "%s" "$BASH_VERSINFO"'], workspace,
        { HOME: home, PATH: '/usr/bin:/bin' }).stdout) >= 4, 'Full installer requires Bash 4+');
    for (const [name, target] of Object.entries(tools)) fs.symlinkSync(target, path.join(bin, name));
    const blocker = path.join(workspace, 'blocked-command.js');
    const blockedLog = path.join(workspace, 'blocked-command.log');
    fs.writeFileSync(blocker, `#!${process.execPath}\n` +
        `require('fs').appendFileSync(${JSON.stringify(blockedLog)}, process.argv[1] + '\\n');\n` +
        "process.stderr.write('Full harness forbids network/package commands\\n'); process.exit(97);\n",
    { mode: 0o755 });
    for (const name of ['sudo', 'brew', 'apt', 'apt-get', 'dnf', 'yum', 'pacman',
        'zypper', 'curl', 'wget', 'npm', 'npx', 'pnpm']) fs.symlinkSync(blocker, path.join(bin, name));
    const env = {
        HOME: home, CODEX_HOME: path.join(home, '.codex'),
        CLAUDE_CONFIG_DIR: path.join(home, '.claude'), XDG_CONFIG_HOME: path.join(home, '.config'),
        TMPDIR: path.join(workspace, 'tmp'), SHELL: path.join(bin, 'bash'),
        PATH: [path.join(home, '.local/bin'), bin, '/usr/bin', '/bin', '/usr/sbin', '/sbin'].join(path.delimiter),
        LANG: 'C', LC_ALL: 'C', TZ: 'UTC', USER: 'fixture', LOGNAME: 'fixture',
        GIT_CONFIG_NOSYSTEM: '1', GIT_CONFIG_GLOBAL: '/dev/null', GIT_CEILING_DIRECTORIES: workspace,
        PYTHONDONTWRITEBYTECODE: '1',
    };
    copySource(root, source, env);
    // Archive-style source has no .git; hooks cannot discover the outer repo.
    assert.ok(!fs.existsSync(path.join(source, '.git')));
    const mask = process.umask(0o022);
    try {
        run([tools.bash, path.join(source, 'install.sh'), '--yes'], source, env,
            path.join(workspace, 'install.log'));
        assert.ok(!fs.existsSync(blockedLog), 'Installer attempted a network/package command');
    } finally { process.umask(mask); }
    return { home, source, workspace, env, node: tools.node };
}

function inventory(installed, relativeRoot) {
    const root = path.join(installed.home, relativeRoot);
    assert.ok(fs.statSync(root).isDirectory(), `Missing Full root: ${relativeRoot}`);
    const records = [];
    let bytes = 0;
    function walk(dir) {
        for (const name of fs.readdirSync(dir).sort()) {
            const file = path.join(dir, name);
            const relative = path.relative(root, file).split(path.sep).join('/');
            const stat = fs.lstatSync(file);
            if (stat.isDirectory()) { walk(file); continue; }
            let data;
            const kind = stat.isSymbolicLink() ? 'link' : 'file';
            if (kind === 'link') {
                const target = fs.readlinkSync(file);
                const expected = path.join(installed.home, '.codex/superpowers-plus/tools', `${name}.sh`);
                assert.ok(relativeRoot === '.local/bin' && target === expected && fs.existsSync(target),
                    `Unexpected Full CLI target: ${relative}`);
                data = Buffer.from(`$HOME/.codex/superpowers-plus/tools/${name}.sh`);
            } else {
                assert.ok(stat.isFile(), `Unexpected Full entry: ${relative}`);
                data = fs.readFileSync(file);
                if (relativeRoot === '.claude/commands') {
                    const command = path.basename(relative, '.md');
                    const text = data.toString('utf8');
                    const prefix = `Invoke the \`${command}\` skill from \``;
                    const lines = text.split('\n').filter(row => row.startsWith(prefix));
                    assert.equal(lines.length, 1, `Unexpected Full command target: ${relative}`);
                    const line = lines[0];
                    const target = line.slice(prefix.length).split('`')[0];
                    const homePrefix = `${installed.home}/.agents/skills/`;
                    const suffix = target.slice(homePrefix.length);
                    assert.ok(target.startsWith(homePrefix) && /^[A-Za-z0-9_-]+\/{1,2}SKILL\.md$/.test(suffix) &&
                        fs.existsSync(target) && line === `${prefix}${target}\`. Read the SKILL.md file and follow its procedure exactly.`,
                        `Unexpected Full command target: ${relative}`);
                    // Preserve canonical/alias mapping and even doubled slashes.
                    data = Buffer.from(text.replace(line, line.replace(target, `$HOME/.agents/skills/${suffix}`)));
                }
            }
            bytes += data.length;
            // Symlink permission bits are OS metadata (Darwin 0755, Linux 0777).
            // Keep every regular-file mode and every exact owned link target.
            records.push([relative, kind, kind === 'link' ? null : stat.mode & 0o777, data.length, hash(data)]);
        }
    }
    walk(root);
    assert.ok(records.length > 0, `Empty Full root: ${relativeRoot}`);
    return { summary: { entries: records.length, bytes, sha256: hash(JSON.stringify(records)) }, records };
}

function snapshotFull(installed) {
    const roots = {};
    const detail = {};
    for (const root of ROOTS) {
        const captured = inventory(installed, root);
        roots[root] = captured.summary;
        detail[root] = captured.records;
    }
    fs.writeFileSync(path.join(installed.workspace, 'inventory.json'), JSON.stringify(detail, null, 2) + '\n');
    const result = run([installed.node, path.join(installed.home,
        '.codex/superpowers-augment/superpowers-augment.js'), 'bootstrap'], installed.workspace,
    { ...installed.env, SPP_SOURCE_DIR: installed.source,
        WORKFLOW_STATE_FILE: path.join(installed.workspace, 'workflow.json') });
    return { schema: 1, oracle: ORACLE, roots,
        bootstrap: { stdout: result.stdout.toString('utf8'), stderr: result.stderr.toString('utf8') } };
}

function assertParity(actual, expected) {
    assert.equal(expected.oracle, ORACLE, 'Full fixture must retain the permanent oracle');
    assert.deepEqual(actual, expected, 'Full output parity differs from permanent oracle');
}

module.exports = { installFull, snapshotFull, assertParity };
