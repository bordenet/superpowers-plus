#!/usr/bin/env node
'use strict';
// Semantic tests use the production wrapper/helper and real Git/tree guard.
// The invocation counter lives outside the fixture: a receipt is evidence that
// the command ran, rather than a hand-written or mocked PASS marker.
const assert = require('assert');
const fs = require('fs');
const os = require('os');
const path = require('path');
const { spawn, spawnSync } = require('child_process');
const SOURCE = path.resolve(__dirname, '..');
const base = fs.mkdtempSync(path.join(os.tmpdir(), 'validation receipts with spaces '));
// Standalone diagnostics may name one exact scenario. The authoritative full
// and named-file producers never forward this selector or infer full coverage.
const selection = process.argv.slice(2);
if (selection.length && (selection.length !== 2 || selection[0] !== '--case' || !selection[1])) {
    throw new Error('Usage: validation-receipt.test.js [--case EXACT_NAME]');
}
const selectedCase = selection[1];
let cases = 0;
function fixture() {
    const area = fs.mkdtempSync(path.join(base, 'case '));
    const root = path.join(area, 'source tree');
    const home = path.join(area, 'empty home');
    fs.mkdirSync(path.join(root, 'tools'), { recursive: true });
    fs.mkdirSync(home);
    fs.copyFileSync(path.join(SOURCE, 'tools/validation-receipt.py'), path.join(root, 'tools/validation-receipt.py'));
    fs.copyFileSync(path.join(SOURCE, 'tools/validation-strategy.py'), path.join(root, 'tools/validation-strategy.py'));
    fs.copyFileSync(path.join(SOURCE, 'tools/validation-inputs.py'), path.join(root, 'tools/validation-inputs.py'));
    fs.copyFileSync(path.join(SOURCE, 'tools/test-tree-guard.sh'), path.join(root, 'tools/test-tree-guard.sh'));
    fs.chmodSync(path.join(root, 'tools/test-tree-guard.sh'), 0o755);
    // Dynamic authorization is outside static receipts; this fixture stubs
    // that separate concern rather than manufacturing its cached clearance.
    fs.writeFileSync(path.join(root, 'tools/public-repo-ip-check.sh'), '#!/usr/bin/env bash\nexit 0\n');
    const entry = path.join(root, 'tools/test-all.sh');
    // Keep the actual wrapper dispatch, including its executable body marker.
    const prefix = fs.readFileSync(path.join(SOURCE, 'tools/test-all.sh'), 'utf8').split('# VALIDATION_RECEIPT_BODY\n')[0];
    fs.writeFileSync(entry, prefix + '# VALIDATION_RECEIPT_BODY\n' + `
set -eu
printf '%s' x >> "$COUNTER"
printf '%s' "$$" > "$CHILD_PID"
sleep "\${DELAY:-0}"
state=$(mktemp)
"$(dirname "$0")/test-tree-guard.sh" snapshot "$state"
if [[ "\${POLLUTE:-0}" == 1 ]]; then echo bad > unexpected-file; fi
if [[ "\${MUTATE:-0}" == 1 ]]; then echo mutated > input; fi
"$(dirname "$0")/test-tree-guard.sh" verify "$state"
rm -f "$state"
exit "\${FAILURE:-0}"
`);
    fs.writeFileSync(path.join(root, 'input'), 'first');
    const git = args => {
        const r = spawnSync('git', ['-C', root, ...args], { encoding: 'utf8' });
        assert.strictEqual(r.status, 0, r.stderr);
        return r.stdout.trim();
    };
    git(['init', '-q']);
    git(['config', 'user.name', 'Receipt Test']);
    git(['config', 'user.email', 'receipt@example.invalid']);
    git(['add', '.']);
    git(['commit', '-qm', 'initial']);
    const env = { PATH: process.env.PATH, HOME: home, LANG: 'C',
        COUNTER: path.join(area, 'counter'), CHILD_PID: path.join(area, 'child pid') };
    const run = (args = ['--fast'], extra = {}) => spawnSync('bash', [entry, ...args], {
        cwd: root, env: { ...env, ...extra }, encoding: 'utf8', timeout: 15000,
    });
    const count = () => fs.existsSync(env.COUNTER) ? fs.readFileSync(env.COUNTER, 'utf8').length : 0;
    const start = extra => spawn('bash', [entry, '--fast'], { cwd: root,
        env: { ...env, ...extra }, stdio: ['ignore', 'pipe', 'pipe'] });
    return { area, root, home, entry, env, run, count, start, git };
}
function staticFixture() {
    const f = fixture();
    fs.mkdirSync(path.join(f.root, 'tools/lib'));
    fs.mkdirSync(path.join(f.root, 'test'));
    fs.writeFileSync(path.join(f.root, 'test/skill-router.test.js'), '// fixture\n');
    fs.copyFileSync(path.join(SOURCE, 'tools/test-all.sh'), f.entry);
    fs.copyFileSync(path.join(SOURCE, 'tools/lib/validation-check-bodies.sh'), path.join(f.root, 'tools/lib/validation-check-bodies.sh'));
    fs.writeFileSync(path.join(f.root, 'tools/lib/harsh-review-body.sh'), '#!/usr/bin/env bash\nprintf "harsh\\n" >> "$STATIC_COUNTER"\n');
    const bin = path.join(f.area, 'registered tools'); fs.mkdirSync(bin);
    for (const tool of ['shellcheck', 'node', 'bats']) {
        fs.writeFileSync(path.join(bin, tool), '#!/usr/bin/env bash\nprintf "' + tool + '\\n" >> "$STATIC_COUNTER"\n', { mode: 0o755 });
    }
    const countFile = path.join(f.area, 'static calls');
    return { f, bin, countFile, extra: { STATIC_COUNTER: countFile, PATH: bin + path.delimiter + f.env.PATH } };
}
function passed(result) {
    assert.strictEqual(result.status, 0, `${result.stdout}\n${result.stderr}`);
}
async function test(name, fn) {
    if (selectedCase && name !== selectedCase) return;
    try { await fn(); }
    catch (error) { console.error(`not ok - ${name}`); throw error; }
    cases++;
    console.log(`ok ${cases} - ${name}`);
}
function done(child) {
    return new Promise((resolve, reject) => {
        let output = '';
        child.stdout.on('data', data => { output += data; });
        child.stderr.on('data', data => { output += data; });
        child.on('error', reject);
        child.on('close', (code, signal) => resolve({ code, signal, output }));
    });
}
const pause = ms => new Promise(resolve => setTimeout(resolve, ms));
async function waitFor(check) {
    for (let n = 0; n < 300; n++) {
        if (check()) return;
        await pause(20);
    }
    throw new Error('timed out waiting for child fixture');
}
async function main() {
    await test('input-change diagnostics identify components without exposing values', () => {
        const f = fixture();
        const body = fs.readFileSync(f.entry, 'utf8').replace(
            'exit "${FAILURE:-0}"', 'git config diagnostic.value "$DIAG_SECRET"\nexit "${FAILURE:-0}"');
        fs.writeFileSync(f.entry, body);
        const secret = 'private-context-value-must-stay-hidden';
        const result = f.run(['--fast'], { DIAG_SECRET: secret });
        assert.strictEqual(result.status, 1, result.stdout + result.stderr);
        assert(result.stderr.includes('inputs changed during run'), result.stderr);
        assert(result.stderr.includes('"components": ["git-config"]'), result.stderr);
        assert(!(result.stdout + result.stderr).includes(secret));
        assert.strictEqual(f.count(), 1);
    });
    await test('missing required lint cannot establish named coverage', () => {
        const first = staticFixture();
        const bin = path.join(first.f.area, 'without shellcheck'); fs.mkdirSync(bin);
        for (const directory of first.extra.PATH.split(path.delimiter)) {
            if (!directory || !fs.existsSync(directory)) continue;
            for (const name of fs.readdirSync(directory)) {
                const target = path.join(bin, name);
                if (name === 'shellcheck' || fs.existsSync(target)) continue;
                try {
                    if (fs.statSync(path.join(directory, name)).isFile()) fs.symlinkSync(path.join(directory, name), target);
                } catch (_) { /* inaccessible or broken entries are not executable inputs */ }
            }
        }
        const namedEnv = { ...first.extra, PATH: bin };
        const missing = first.f.run(['--check', 'shellcheck'], namedEnv);
        assert.strictEqual(missing.status, 127, missing.stdout + missing.stderr);
        assert(missing.stderr.includes('shellcheck is required'), missing.stderr);
        assert.notStrictEqual(first.f.run(['--check', 'shellcheck'], namedEnv).status, 0);
        assert.notStrictEqual(first.f.run(['--check', 'harsh'], namedEnv).status, 0);
        const second = staticFixture();
        assert.notStrictEqual(second.f.run([], { ...second.extra, PATH: bin }).status, 0);
        for (const f of [first.f, second.f]) {
            const cache = path.join(f.root, '.git/validation-receipts-v1');
            assert(!fs.readdirSync(cache).filter(n => n.endsWith('.json')).some(n =>
                JSON.parse(fs.readFileSync(path.join(cache, n), 'utf8')).result === 'PASS'));
        }
    });
    await test('composed full receipts retain reused producer evidence', () => {
        for (const damage of ['log', 'receipt', 'missing']) {
            const { f, extra, countFile } = staticFixture();
            passed(f.run(['--check', 'shellcheck'], extra));
            passed(f.run(['--check', 'harsh'], extra));
            passed(f.run([], extra)); passed(f.run([], extra));
            const before = fs.readFileSync(countFile, 'utf8');
            const cache = path.join(f.root, '.git/validation-receipts-v1');
            const name = fs.readdirSync(cache).find(n => n.endsWith('.json') &&
                JSON.parse(fs.readFileSync(path.join(cache, n), 'utf8')).args.join(' ') === '--check shellcheck');
            const receipt = path.join(cache, name);
            const lint = JSON.parse(fs.readFileSync(receipt, 'utf8'));
            if (damage === 'log') fs.appendFileSync(path.join(cache, lint.log), 'tampered original evidence');
            if (damage === 'receipt') fs.appendFileSync(receipt, ' ');
            if (damage === 'missing') fs.unlinkSync(receipt);
            const refused = f.run([], extra);
            assert.notStrictEqual(refused.status, 0, 'composed full PASS must validate its reused evidence');
            assert.strictEqual(fs.readFileSync(countFile, 'utf8'), before, 'damaged provenance must not rerun expensive bodies');
        }
    });
    await test('registered individual node coverage executes once and changes invalidate', () => {
        const f = fixture();
        fs.mkdirSync(path.join(f.root, 'tools/lib'));
        fs.copyFileSync(path.join(SOURCE, 'tools/lib/validation-check-bodies.sh'), path.join(f.root, 'tools/lib/validation-check-bodies.sh'));
        fs.mkdirSync(path.join(f.root, 'test'));
        const input = path.join(f.root, 'test/example.test.js'); fs.writeFileSync(input, '// first\n');
        const bin = path.join(f.area, 'node bin'); fs.mkdirSync(bin);
        fs.writeFileSync(path.join(bin, 'node'), '#!/usr/bin/env bash\nprintf x >> "$NODE_COUNTER"\n', { mode: 0o755 });
        const countFile = path.join(f.area, 'node count');
        const extra = { NODE_COUNTER: countFile, PATH: bin + path.delimiter + f.env.PATH };
        passed(f.run(['--check', 'node:example.test.js'], extra));
        passed(f.run(['--check', 'node:example.test.js'], extra));
        assert.strictEqual(fs.readFileSync(countFile, 'utf8'), 'x');
        fs.writeFileSync(input, '// changed\n');
        passed(f.run(['--check', 'node:example.test.js'], extra));
        assert.strictEqual(fs.readFileSync(countFile, 'utf8'), 'xx');
        assert.notStrictEqual(f.run(['--check', 'node:../arbitrary.js'], extra).status, 0);
    });
    await test('only the registered producer entry can establish coverage', () => {
        const f = fixture(); const alternate = path.join(f.root, 'tools/arbitrary.sh');
        fs.copyFileSync(f.entry, alternate);
        const result = spawnSync('python3', [path.join(f.root, 'tools/validation-receipt.py'), alternate], {
            cwd: f.root, env: f.env, encoding: 'utf8', timeout: 10000,
        });
        assert.notStrictEqual(result.status, 0, result.stdout + result.stderr);
        assert.strictEqual(f.count(), 0, 'arbitrary script must never mint registered coverage');
    });
    await test('audited documentation changes reuse lint; unknown and shell inputs execute', () => {
        const f = fixture();
        for (const dir of ['tools/lib', 'config', 'docs']) fs.mkdirSync(path.join(f.root, dir));
        fs.copyFileSync(path.join(SOURCE, 'tools/lib/validation-check-bodies.sh'), path.join(f.root, 'tools/lib/validation-check-bodies.sh'));
        const doc = path.join(f.root, 'docs/note.md'); fs.writeFileSync(doc, 'baseline');
        const bin = path.join(f.area, 'lint bin'); fs.mkdirSync(bin);
        fs.writeFileSync(path.join(bin, 'shellcheck'), '#!/usr/bin/env bash\nprintf x >> "$LINT_COUNTER"\n', { mode: 0o755 });
        const setup = spawnSync('python3', ['-B', '-c', String.raw`
import importlib.util,json,pathlib,sys
root=pathlib.Path(sys.argv[1]); spec=importlib.util.spec_from_file_location('inputs',root/'tools/validation-inputs.py')
m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
(root/'config/validation-inputs.json').write_text(json.dumps({'schema':1,'shell_audit':m.shell_snapshot(root),'shellcheck_exclusions':['docs/note.md']}))
`, f.root], { encoding: 'utf8' }); passed(setup);
        f.git(['add', '.']);
        const counter = path.join(f.area, 'lint count');
        const extra = { LINT_COUNTER: counter, PATH: bin + path.delimiter + f.env.PATH };
        passed(f.run(['--check', 'shellcheck'], extra));
        fs.writeFileSync(doc, 'changed documentation');
        const reused = f.run(['--check', 'shellcheck'], extra); passed(reused);
        assert(reused.stdout.includes('reusing PASS'), reused.stdout);
        assert.strictEqual(fs.readFileSync(counter, 'utf8'), 'x');
        fs.writeFileSync(path.join(f.root, 'unknown-input'), 'unknown dependency');
        passed(f.run(['--check', 'shellcheck'], extra));
        // Independent safety matrix: these are global, even for lint. Each
        // mutation must execute once, then its identical successor must reuse.
        const globals = ['config/suite-manifest.json', '.github/workflows/test.yml',
            'tools/generated-reader.js', 'docs/unknown.md'];
        for (let i = 0; i < globals.length; i++) {
            const target = path.join(f.root, globals[i]);
            fs.mkdirSync(path.dirname(target), { recursive: true });
            fs.writeFileSync(target, 'changed global input\n');
            passed(f.run(['--check', 'shellcheck'], extra));
            const same = f.run(['--check', 'shellcheck'], extra); passed(same);
            assert(same.stdout.includes('reusing PASS'), same.stdout);
            assert.strictEqual(fs.readFileSync(counter, 'utf8'), 'x'.repeat(3 + i));
            fs.writeFileSync(doc, 'documentation mutation ' + i);
            const active = f.run(['--check', 'shellcheck'], extra); passed(active);
            assert(active.stdout.includes('reusing PASS'), 'selection must remain active during global matrix: ' + active.stdout);
            assert.strictEqual(fs.readFileSync(counter, 'utf8'), 'x'.repeat(3 + i));
        }
        fs.appendFileSync(f.entry, '\n# changed audited shell source\n');
        passed(f.run(['--check', 'shellcheck'], extra));
        assert.strictEqual(fs.readFileSync(counter, 'utf8'), 'xxxxxxx');
    });
    await test('native precommit selection invalidates when HEAD changes with the same index', () => {
        const { f, extra } = staticFixture();
        fs.copyFileSync(path.join(SOURCE, 'tools/lib/pre-commit-static-body.sh'), path.join(f.root, 'tools/lib/pre-commit-static-body.sh'));
        fs.writeFileSync(path.join(f.root, 'invalid.sh'), '#!/usr/bin/env bash\nif then\n');
        f.git(['add', '.']); f.git(['commit', '-qm', 'invalid committed file outside staged selection']);
        const index = f.git(['write-tree']);
        passed(f.run(['--check', 'native:pre-commit-static'], extra));
        f.git(['reset', '--soft', 'HEAD^']);
        assert.strictEqual(f.git(['write-tree']), index, 'index bytes remain identical');
        const changed = f.run(['--check', 'native:pre-commit-static'], extra);
        assert.notStrictEqual(changed.status, 0, 'newly selected invalid source must not reuse empty-selection PASS');
        assert(changed.stdout.includes('bash syntax error'), changed.stdout + changed.stderr);
    });
    await test('native precommit and default Bats enter registered bodies without caching authorization', () => {
        const { f, bin, countFile, extra } = staticFixture();
        for (const name of ['tools/pre-commit', 'tools/commit-gate.sh', 'tools/harsh-review.sh', 'tools/lib/review-token.sh', 'tools/lib/pre-commit-static-body.sh']) {
            if (fs.existsSync(path.join(SOURCE, name))) fs.copyFileSync(path.join(SOURCE, name), path.join(f.root, name));
        }
        fs.mkdirSync(path.join(f.root, 'tests'));
        fs.writeFileSync(path.join(f.root, 'tests/example.bats'), '# fixture inventory\n');
        fs.writeFileSync(path.join(f.home, '.gitconfig'), '[user]\n name = Native Fixture\n email = native@example.invalid\n');
        fs.writeFileSync(path.join(f.root, '.agent-gates'), 'SKIP_REVIEW_TOKEN=true\nREQUIRE_CODE_REVIEW_SENTINEL=false\n');
        const auth = path.join(f.area, 'native authority');
        fs.writeFileSync(path.join(f.root, 'tools/public-repo-ip-check.sh'), '#!/usr/bin/env bash\nprintf x >> "$NATIVE_AUTH_COUNTER"\n');
        f.git(['add', '.']); f.git(['commit', '-qm', 'native fixture']);
        const feature = path.join(f.root, 'feature.sh');
        fs.writeFileSync(feature, '#!/usr/bin/env bash\necho ok\n'); f.git(['add', 'feature.sh']);
        const opaque = path.join(f.area, 'opaque configured command');
        const env = { ...f.env, ...extra, NATIVE_AUTH_COUNTER: auth, OPAQUE_COUNTER: opaque };
        const run = name => spawnSync('bash', [path.join(f.root, 'tools', name)], { cwd: f.root, env, encoding: 'utf8', timeout: 15000 });
        passed(run('pre-commit'));
        const precommit = run('pre-commit'); passed(precommit);
        assert(precommit.stdout.includes('reusing PASS'), precommit.stdout);
        assert.strictEqual(fs.readFileSync(countFile, 'utf8').split('\n').filter(x => x === 'shellcheck').length, 1);
        passed(run('commit-gate.sh'));
        const commit = run('commit-gate.sh'); passed(commit);
        assert(commit.stdout.includes('reusing PASS'), commit.stdout);
        assert.strictEqual(fs.readFileSync(countFile, 'utf8').split('\n').filter(x => x === 'bats').length, 1);
        assert.strictEqual(fs.readFileSync(auth, 'utf8'), 'xxxx', 'two precommits and two native clearances authorize freshly');
        const tokens = path.join(f.home, '.codex/review-tokens');
        assert.strictEqual(fs.readdirSync(tokens).length, 2, 'each native clearance mints its own genuine new fixture token');
        fs.writeFileSync(feature, '#!/usr/bin/env bash\nif then\n');
        assert.notStrictEqual(run('pre-commit').status, 0, 'changed staged-path working bytes still reject invalid shell');
        const afterFailure = fs.readFileSync(countFile, 'utf8');
        assert.notStrictEqual(run('pre-commit').status, 0);
        assert.strictEqual(fs.readFileSync(countFile, 'utf8'), afterFailure, 'same failed static check does not execute twice');
        fs.writeFileSync(feature, '#!/usr/bin/env bash\necho restored\n');
        fs.appendFileSync(path.join(f.root, '.agent-gates'), 'EXTRA_TEST=printf x >> "$OPAQUE_COUNTER"\n');
        passed(run('commit-gate.sh'));
        const configured = run('commit-gate.sh'); passed(configured);
        assert(configured.stdout.includes('reusing PASS'), configured.stdout);
        assert.strictEqual(fs.readFileSync(opaque, 'utf8'), 'xx', 'static reuse cannot suppress an unregistered configured command');
    });
    await test('registered CI checks preserve body, selection and fresh setup boundaries', () => {
        const { f, bin, extra } = staticFixture();
        fs.mkdirSync(path.join(f.root, 'config'));
        fs.copyFileSync(path.join(SOURCE, 'config/validation-checks.json'), path.join(f.root, 'config/validation-checks.json'));
        fs.copyFileSync(path.join(SOURCE, 'tools/lib/ci-validation-bodies.sh'), path.join(f.root, 'tools/lib/ci-validation-bodies.sh'));
        const calls = path.join(f.area, 'ci calls'), authority = path.join(f.area, 'ip calls');
        const harness = path.join(f.area, 'security harness calls');
        fs.writeFileSync(path.join(f.root, 'test/public-repo-ip-check.test.sh'), '#!/usr/bin/env bash\nprintf x >> "$CI_HARNESS_COUNTER"\n');
        fs.writeFileSync(path.join(bin, 'node'), '#!/usr/bin/env bash\nprintf "%s\\n" "$*" >> "$CI_COUNTER"\n', { mode: 0o755 });
        fs.writeFileSync(path.join(f.root, 'tools/public-repo-ip-check.sh'), '#!/usr/bin/env bash\nprintf x >> "$IP_COUNTER"\n');
        // Provisioning occurs before producer context capture and is not a check.
        f.git(['config', '--file', path.join(f.home, '.gitconfig'), 'user.name', 'Fixture CI']);
        f.git(['config', '--file', path.join(f.home, '.gitconfig'), 'user.email', 'ci@example.invalid']);
        f.git(['add', '.']);
        fs.writeFileSync(path.join(f.root, 'new-input'), 'present but not staged\n');
        const env = { ...extra, CI_COUNTER: calls, IP_COUNTER: authority, CI_HARNESS_COUNTER: harness };
        passed(f.run(['--check', 'ci:node-tests-frontmatter-parser-tests'], env));
        const reused = f.run(['--check', 'ci:node-tests-frontmatter-parser-tests'], env); passed(reused);
        assert(reused.stdout.includes('reusing PASS'), reused.stdout);
        assert.strictEqual(fs.readFileSync(calls, 'utf8'), 'test/frontmatter.test.js\n');
        f.git(['add', 'new-input']);
        passed(f.run(['--check', 'ci:node-tests-frontmatter-parser-tests'], env));
        assert.strictEqual(fs.readFileSync(calls, 'utf8'), 'test/frontmatter.test.js\ntest/frontmatter.test.js\n');
        const stagedOnly = path.join(f.area, 'index-only version');
        fs.writeFileSync(stagedOnly, 'different index bytes, identical worktree\n');
        const blob = f.git(['hash-object', '-w', stagedOnly]);
        f.git(['update-index', '--cacheinfo', '100644,' + blob + ',new-input']);
        passed(f.run(['--check', 'ci:node-tests-frontmatter-parser-tests'], env));
        assert.strictEqual(fs.readFileSync(calls, 'utf8'), 'test/frontmatter.test.js\n'.repeat(3),
            'changed staged bytes must invalidate even when name/status and worktree bytes are unchanged');
        passed(f.run(['--check', 'ci:security-scan-ip-disclosure-audit'], env));
        passed(f.run(['--check', 'ci:security-scan-ip-disclosure-audit'], env));
        assert.strictEqual(fs.readFileSync(harness, 'utf8'), 'x', 'repeatable IP regression harness runs once and is never dropped');
        assert.strictEqual(fs.readFileSync(authority, 'utf8'), 'xx', 'IP authority must remain fresh on static reuse');
        const setup = f.run(['--check', 'ci:shell-tests-configure-git-identity'], env);
        assert.notStrictEqual(setup.status, 0, 'setup cannot be reused as validation coverage');
    });
    await test('real full dispatcher shares raw static bodies with prior direct requests', () => {
        const f = fixture();
        fs.mkdirSync(path.join(f.root, 'tools/lib'));
        fs.mkdirSync(path.join(f.root, 'test'));
        fs.writeFileSync(path.join(f.root, 'test/skill-router.test.js'), '// fixture\n');
        fs.copyFileSync(path.join(SOURCE, 'tools/test-all.sh'), f.entry);
        fs.copyFileSync(path.join(SOURCE, 'tools/lib/validation-check-bodies.sh'), path.join(f.root, 'tools/lib/validation-check-bodies.sh'));
        fs.writeFileSync(path.join(f.root, 'tools/lib/harsh-review-body.sh'), '#!/usr/bin/env bash\nprintf "harsh\\n" >> "$STATIC_COUNTER"\n');
        const bin = path.join(f.area, 'registered tools'); fs.mkdirSync(bin);
        for (const tool of ['shellcheck', 'node', 'bats']) {
            fs.writeFileSync(path.join(bin, tool), `#!/usr/bin/env bash\nprintf '${tool}\\n' >> "$STATIC_COUNTER"\n`, { mode: 0o755 });
        }
        const countFile = path.join(f.area, 'static calls');
        const extra = { STATIC_COUNTER: countFile, PATH: bin + path.delimiter + f.env.PATH };
        for (const check of ['shellcheck', 'harsh', 'router']) passed(f.run(['--check', check], extra));
        passed(f.run([], extra));
        const calls = fs.readFileSync(countFile, 'utf8').trim().split('\n');
        for (const tool of ['shellcheck', 'harsh', 'node']) {
            assert.strictEqual(calls.filter(n => n === tool).length, 1, `${tool}: ${calls}`);
        }
        // Raw bodies must refuse the public front door instead of reacquiring
        // their parent's real inherited lock and hanging forever.
        fs.writeFileSync(path.join(f.root, 'tools/lib/harsh-review-body.sh'),
            '#!/usr/bin/env bash\nexec bash "$(dirname "$0")/../test-all.sh" --check harsh\n');
        const recursive = f.run(['--check', 'harsh'], extra);
        assert.strictEqual(recursive.status, 1, recursive.stdout + recursive.stderr);
        assert(recursive.stderr.includes('recursive receipt front door'), recursive.stderr);
        // Bats and other process launchers may close inherited descriptors.
        // Losing the descriptor must not turn same-owner reentry into a wait.
        fs.writeFileSync(path.join(f.root, 'tools/lib/harsh-review-body.sh'),
            '#!/usr/bin/env bash\npython3 -c \'import subprocess,sys;sys.exit(subprocess.call(["bash",sys.argv[1],"--check","harsh"],close_fds=True))\' "$(dirname "$0")/../test-all.sh"\n');
        const closed = f.run(['--check', 'harsh'], extra);
        assert.strictEqual(closed.status, 1, closed.stdout + closed.stderr);
        assert(closed.stderr.includes('recursive receipt front door'), closed.stderr);

    });
    await test('registered static requests reuse full coverage and unknown checks refuse', () => {
        const f = fixture();
        passed(f.run([]));
        passed(f.run(['--check', 'shellcheck']));
        passed(f.run(['--check', 'harsh']));
        passed(f.run(['--check', 'router']));
        assert.strictEqual(f.count(), 1, 'covered static checks must not execute after full');
        const unknown = f.run(['--check', 'caller-command']);
        assert.notStrictEqual(unknown.status, 0);
        assert.strictEqual(f.count(), 1);
    });
    await test('first executes; identical dirty contents and history-only commits reuse', () => {
        const f = fixture();
        passed(f.run()); passed(f.run());
        assert.strictEqual(f.count(), 1);
        f.git(['commit', '--allow-empty', '-qm', 'history only']);
        f.git(['checkout', '-qb', 'other-branch']);
        f.git(['config', 'branch.other-branch.remote', 'origin']);
        f.git(['config', 'branch.other-branch.merge', 'refs/heads/dev']);
        passed(f.run()); assert.strictEqual(f.count(), 1);
        fs.writeFileSync(path.join(f.root, 'input'), 'dirty');
        passed(f.run()); passed(f.run()); assert.strictEqual(f.count(), 2);
        f.git(['add', 'input']); passed(f.run());
        assert.strictEqual(f.count(), 3, 'changed staged blob is a real input, even with unchanged working bytes');
        f.git(['commit', '-qm', 'same tested bytes now committed']); passed(f.run());
        assert.strictEqual(f.count(), 3, 'commit identity alone does not invalidate the staged input');
    });
    await test('identical linked worktree uses the common-dir receipt', () => {
        const f = fixture(); passed(f.run());
        const sibling = path.join(f.area, 'linked worktree');
        f.git(['worktree', 'add', '--detach', sibling, 'HEAD']);
        passed(spawnSync('bash', [path.join(sibling, 'tools/test-all.sh'), '--fast'], {
            cwd: sibling, env: f.env, encoding: 'utf8', timeout: 15000,
        }));
        assert.strictEqual(f.count(), 1);
    });
    await test('new inputs, executable bits, symlink targets and ignored dependencies invalidate', () => {
        const f = fixture(); passed(f.run());
        fs.writeFileSync(path.join(f.root, 'new file'), 'new');
        passed(f.run()); assert.strictEqual(f.count(), 2);
        fs.chmodSync(path.join(f.root, 'input'), 0o755);
        passed(f.run()); assert.strictEqual(f.count(), 3);
        fs.symlinkSync('input', path.join(f.root, 'link'));
        passed(f.run()); assert.strictEqual(f.count(), 4);
        fs.unlinkSync(path.join(f.root, 'link'));
        fs.symlinkSync('new file', path.join(f.root, 'link'));
        passed(f.run()); assert.strictEqual(f.count(), 5);
        fs.writeFileSync(path.join(f.root, '.gitignore'), 'dependency/\n');
        fs.mkdirSync(path.join(f.root, 'dependency'));
        fs.writeFileSync(path.join(f.root, 'dependency', 'index'), 'ignored dependency');
        passed(f.run()); assert.strictEqual(f.count(), 6);
        fs.writeFileSync(path.join(f.root, 'dependency', 'index'), 'changed');
        passed(f.run()); assert.strictEqual(f.count(), 7);
    });
    await test('tracked fixture/cache and root output-like names remain inputs', () => {
        const f = fixture();
        fs.mkdirSync(path.join(f.root, 'test/fixtures/cache'), { recursive: true });
        fs.mkdirSync(path.join(f.root, 'install-state'));
        const nested = path.join(f.root, 'test/fixtures/cache/input');
        const outputLike = path.join(f.root, 'install-state/source');
        fs.writeFileSync(nested, 'original'); fs.writeFileSync(outputLike, 'original');
        f.git(['add', '.']); f.git(['commit', '-qm', 'tracked cache fixtures']);
        passed(f.run());
        fs.writeFileSync(nested, 'changed'); passed(f.run());
        fs.writeFileSync(outputLike, 'changed'); passed(f.run());
        assert.strictEqual(f.count(), 3);
    });
    await test('staging an existing shell file expands actual shellcheck selection and invalidates PASS', () => {
        const f = fixture();
        const original = fs.readFileSync(path.join(SOURCE, 'tools/test-all.sh'), 'utf8');
        const start = original.indexOf('run_shellcheck() {');
        const end = original.indexOf('\n# shellcheck disable=SC2329', start);
        const fn = original.slice(start, end);
        const prefix = original.split('# VALIDATION_RECEIPT_BODY\n')[0];
        fs.writeFileSync(f.entry, prefix + '# VALIDATION_RECEIPT_BODY\nset -uo pipefail\n' +
            fn + '\nprintf x >> "$COUNTER"\nrun_shellcheck\n');
        const bin = path.join(f.area, 'lint bin'); fs.mkdirSync(bin);
        fs.writeFileSync(path.join(bin, 'shellcheck'), '#!/bin/sh\nprintf "%s\\n" "$@" >> "$CHECKED"\n' +
            'for arg do if [ "$arg" = bad.sh ]; then exit 1; fi; done\n', { mode: 0o755 });
        const checked = path.join(f.area, 'checked');
        const extra = { PATH: bin + path.delimiter + f.env.PATH, CHECKED: checked };
        fs.writeFileSync(path.join(f.root, 'bad.sh'), 'invalid shell content\n');
        passed(f.run([], extra));
        assert(!fs.readFileSync(checked, 'utf8').includes('bad.sh'));
        f.git(['add', 'bad.sh']);
        assert.strictEqual(f.run([], extra).status, 1);
        assert(fs.readFileSync(checked, 'utf8').includes('bad.sh'));
        assert.strictEqual(f.count(), 2);
    });
    await test('suite arguments and environment remain distinct without secret persistence', () => {
        const f = fixture(); passed(f.run()); passed(f.run([]));
        passed(f.run(['--fast'], { PRIVATE_TEST_TOKEN: 'secret receipt must never contain' }));
        assert.strictEqual(f.count(), 3);
        const cache = path.join(f.root, '.git', 'validation-receipts-v1');
        for (const name of fs.readdirSync(cache).filter(n => n.endsWith('.json'))) {
            assert(!fs.readFileSync(path.join(cache, name), 'utf8').includes('secret'));
        }
    });
    await test('default full success satisfies exact fast coverage, never the reverse', () => {
        const full = fixture(); passed(full.run([]));
        const reused = full.run(['--fast']); passed(reused);
        assert(reused.stdout.includes('default FULL coverage')); assert.strictEqual(full.count(), 1);
        const fast = fixture(); passed(fast.run(['--fast'])); passed(fast.run([]));
        assert.strictEqual(fast.count(), 2);
    });
    await test('partial/help arguments cannot authorize fast and context changes invalidate full superset', () => {
        for (const args of [['--no-node'], ['--help'], ['--unknown'], ['--fast', '--no-node']]) {
            const f = fixture(); passed(f.run(args)); passed(f.run(['--fast']));
            assert.strictEqual(f.count(), 2);
        }
        const changed = fixture(); passed(changed.run([]));
        passed(changed.run(['--fast'], { NEW_CONTEXT: 'different' }));
        assert.strictEqual(changed.count(), 2);
    });
    await test('native default GIT_EXEC_PATH equals direct context; custom override is distinct', () => {
        const f = fixture(); passed(f.run());
        const defaultPath = spawnSync('git', ['--exec-path'], { encoding: 'utf8', env: f.env }).stdout.trim();
        passed(f.run(['--fast'], { GIT_EXEC_PATH: defaultPath }));
        assert.strictEqual(f.count(), 1);
        const custom = path.join(f.area, 'custom git exec'); fs.mkdirSync(custom);
        passed(f.run(['--fast'], { GIT_EXEC_PATH: custom }));
        assert.strictEqual(f.count(), 2);
    });
    await test('Codex invocation identifiers are removed from execution and reuse context', () => {
        const f = fixture();
        fs.writeFileSync(f.entry, fs.readFileSync(f.entry, 'utf8').replace('set -eu\n',
            'set -eu\ntest -z "${CODEX_TOOL_CALL_ID+x}${CODEX_THREAD_ID+x}${CODEX_SESSION_ID+x}"\n'));
        passed(f.run([], { CODEX_TOOL_CALL_ID: 'first-call', CODEX_THREAD_ID: 'first-thread',
            CODEX_SESSION_ID: 'first-session' }));
        passed(f.run(['--fast'], { CODEX_TOOL_CALL_ID: 'second-call', CODEX_THREAD_ID: 'second-thread',
            CODEX_SESSION_ID: 'second-session' }));
        assert.strictEqual(f.count(), 1);
        passed(f.run(['--fast'], { CODEX_PERMISSION_PROFILE: 'changed-execution-policy' }));
        assert.strictEqual(f.count(), 2, 'execution policy must remain an input');
    });
    await test('a real native git pre-push reuses direct FULL coverage without executing again', () => {
        const f = fixture();
        // Keep PATH tools and Git configuration identical before and after the
        // baseline; only Git's own hook environment may change.
        const remote = path.join(f.area, 'bare remote');
        passed(spawnSync('git', ['init', '-q', '--bare', remote], { env: f.env, encoding: 'utf8' }));
        const hook = path.join(f.root, '.git/hooks/pre-push');
        fs.writeFileSync(hook, '#!/bin/sh\nexec bash tools/test-all.sh --fast\n', { mode: 0o755 });
        passed(f.run([]));
        const push = spawnSync('git', ['push', remote, 'HEAD:main'], {
            cwd: f.root, env: f.env, encoding: 'utf8', timeout: 15000,
        });
        passed(push);
        assert(push.stdout.includes('validation: reusing PASS'), push.stdout);
        assert.strictEqual(f.count(), 1, 'native hook must not execute the suite again');
    });
    await test('runner receipts bind streamed execution logs and complete result metadata', () => {
        const f = fixture();
        const source = fs.readFileSync(f.entry, 'utf8').replace('state=$(mktemp)',
            'printf "visible stdout\\n"; printf "visible stderr\\n" >&2\nstate=$(mktemp)');
        fs.writeFileSync(f.entry, source);
        const first = f.run(); passed(first);
        assert(first.stdout.includes('visible stdout')); assert(first.stderr.includes('visible stderr'));
        const cache = path.join(f.root, '.git/validation-receipts-v1');
        const filename = fs.readdirSync(cache).find(n => n.endsWith('.json'));
        const saved = JSON.parse(fs.readFileSync(path.join(cache, filename), 'utf8'));
        assert.strictEqual(saved.schema, 3); assert.strictEqual(saved.producer, 'test-all.sh/validation-receipt-v3');
        assert.deepStrictEqual(saved.args, ['--fast']); assert(saved.started <= saved.completed);
        const log = fs.readFileSync(path.join(cache, saved.log), 'utf8');
        assert(log.includes('visible stdout')); assert(log.includes('visible stderr'));
        const second = f.run(); passed(second);
        assert(second.stdout.includes('validation: evidence ')); assert.strictEqual(f.count(), 1);
    });
    await test('tampered or missing execution logs fail clear without duplicate execution', () => {
        for (const mode of ['tamper', 'missing', 'malformed']) {
            const f = fixture(); passed(f.run());
            const cache = path.join(f.root, '.git/validation-receipts-v1');
            const filename = fs.readdirSync(cache).find(n => n.endsWith('.json'));
            const receipt = path.join(cache, filename);
            const saved = JSON.parse(fs.readFileSync(receipt, 'utf8'));
            if (mode === 'tamper') fs.appendFileSync(path.join(cache, saved.log), 'tampered evidence');
            if (mode === 'missing') fs.unlinkSync(path.join(cache, saved.log));
            if (mode === 'malformed') fs.writeFileSync(receipt, '{invalid json');
            const result = f.run();
            assert.strictEqual(result.status, 1);
            assert(result.stderr.includes('existing validation receipt is invalid'), result.stderr);
            assert.strictEqual(f.count(), 1, mode + ' must not rerun identical validation');
        }
    });
    await test('toolchain contents and installed nonempty HOME input invalidate', () => {
        const f = fixture();
        const bin = path.join(f.area, 'bin'); fs.mkdirSync(bin);
        fs.writeFileSync(path.join(bin, 'node'), '#!/bin/sh\nexit 0\n', { mode: 0o755 });
        const env = { PATH: bin + path.delimiter + f.env.PATH };
        passed(f.run(['--fast'], env)); passed(f.run(['--fast'], env));
        assert.strictEqual(f.count(), 1);
        fs.appendFileSync(path.join(bin, 'node'), '# changed runtime\n');
        passed(f.run(['--fast'], env)); assert.strictEqual(f.count(), 2);
        fs.mkdirSync(path.join(f.home, '.agents/skills'), { recursive: true });
        const installed = path.join(f.home, '.agents/skills/instruction.md');
        fs.writeFileSync(installed, 'first installed payload');
        passed(f.run(['--fast'], env)); assert.strictEqual(f.count(), 3);
        fs.writeFileSync(installed, 'second installed payload');
        passed(f.run(['--fast'], env)); assert.strictEqual(f.count(), 4);
        fs.symlinkSync(f.home, path.join(f.home, '.agents/skills/cycle'));
        passed(f.run(['--fast'], env));
    });
    await test('host hook telemetry churn reuses; hook scripts/config/cache remain inputs', () => {
        const f = fixture();
        const hooks = path.join(f.home, '.claude/hooks'); fs.mkdirSync(hooks, { recursive: true });
        const hook = path.join(hooks, 'hook.sh'); fs.writeFileSync(hook, 'first script');
        fs.writeFileSync(path.join(hooks, 'settings.json'), 'first config');
        fs.writeFileSync(path.join(hooks, 'skill-router-cache.json'), 'first cache');
        passed(f.run());
        for (const name of ['hook-audit.log', 'hook-audit.log.1', 'skill-router-metrics.jsonl',
            'skill-router-metrics.jsonl.1', '.log-rotation.reclaim.lock']) {
            fs.writeFileSync(path.join(hooks, name), 'new runtime output');
        }
        fs.mkdirSync(path.join(hooks, '.log-rotation.lock'));
        fs.writeFileSync(path.join(hooks, '.log-rotation.lock/pid'), '12345');
        passed(f.run()); assert.strictEqual(f.count(), 1);
        fs.appendFileSync(path.join(hooks, 'hook-audit.log'), 'appended audit event');
        passed(f.run()); assert.strictEqual(f.count(), 1);
        fs.writeFileSync(hook, 'changed script'); passed(f.run());
        fs.writeFileSync(path.join(hooks, 'settings.json'), 'changed config'); passed(f.run());
        fs.writeFileSync(path.join(hooks, 'skill-router-cache.json'), 'changed cache'); passed(f.run());
        assert.strictEqual(f.count(), 4);
    });
    await test('external hook omissions never hide tracked source with output-like names', () => {
        const f = fixture();
        const source = path.join(f.root, 'hook-source'); fs.mkdirSync(source);
        const input = path.join(source, 'hook-audit.log'); fs.writeFileSync(input, 'tracked fixture');
        f.git(['add', 'hook-source']);
        fs.mkdirSync(path.join(f.home, '.claude'));
        fs.symlinkSync(source, path.join(f.home, '.claude/hooks'));
        passed(f.run()); fs.writeFileSync(input, 'changed tracked fixture'); passed(f.run());
        assert.strictEqual(f.count(), 2);
    });
    await test('equivalent empty HOME/TMPDIR wrappers reuse canonical execution context', () => {
        const f = fixture(); passed(f.run());
        const another = path.join(f.area, 'another empty home'); fs.mkdirSync(another);
        const temporary = path.join(f.area, 'another temp'); fs.mkdirSync(temporary);
        passed(f.run(['--fast'], { HOME: another, TMPDIR: temporary }));
        assert.strictEqual(f.count(), 1);
    });
    await test('canonical HOME and TMPDIR stay outside Git even when input TMPDIR is in checkout', () => {
        const f = fixture();
        const proof = path.join(f.area, 'scratch proof.json');
        const code = `python3 -c 'import json, os, subprocess, stat
paths={name:os.environ[name] for name in ("HOME","TMPDIR")}
for name,p in paths.items():
    assert subprocess.run(["git","-C",p,"rev-parse","--git-dir"],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL).returncode != 0
    child=os.path.join(p,"non-git-child")
    os.makedirs(child,exist_ok=True)
    assert subprocess.run(["git","-C",child,"rev-parse","--git-dir"],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL).returncode != 0
    info=os.lstat(p)
    assert stat.S_ISDIR(info.st_mode) and stat.S_IMODE(info.st_mode)==0o700 and info.st_uid==os.geteuid()
with open(os.environ["SCRATCH_PROOF"],"w") as out: json.dump(paths,out)
'\n`;
        fs.writeFileSync(f.entry, fs.readFileSync(f.entry, 'utf8').replace('state=$(mktemp)', code + 'state=$(mktemp)'));
        const inputTemp = path.join(f.root, 'inside checkout temp'); fs.mkdirSync(inputTemp);
        passed(f.run(['--fast'], { TMPDIR: inputTemp, SCRATCH_PROOF: proof }));
        const observed = JSON.parse(fs.readFileSync(proof, 'utf8'));
        assert(!observed.HOME.startsWith(f.root + path.sep));
        assert(!observed.TMPDIR.startsWith(f.root + path.sep));
        passed(f.run(['--fast'], { TMPDIR: inputTemp, SCRATCH_PROOF: proof }));
        assert.strictEqual(f.count(), 1);
    });
    await test('actual isolated native wrapper overrides reuse across fresh empty homes', () => {
        const f = fixture();
        const originalEnv = home => ({ HOME: home, CODEX_HOME: path.join(home, '.codex'),
            CLAUDE_CONFIG_DIR: path.join(home, '.claude'), GIT_CONFIG_GLOBAL: '/dev/null',
            GIT_CONFIG_NOSYSTEM: '1' });
        passed(f.run(['--fast'], originalEnv(f.home)));
        const another = path.join(f.area, 'fresh home'); fs.mkdirSync(another);
        passed(f.run(['--fast'], originalEnv(another)));
        assert.strictEqual(f.count(), 1);
    });
    await test('explicit external Codex and Claude config roots invalidate on input changes', () => {
        const f = fixture();
        const codex = path.join(f.area, 'custom codex');
        const claude = path.join(f.area, 'custom claude');
        fs.mkdirSync(path.join(codex, 'skills'), { recursive: true });
        fs.mkdirSync(path.join(claude, 'hooks'), { recursive: true });
        const codexInput = path.join(codex, 'skills/input.md');
        const claudeInput = path.join(claude, 'hooks/input.sh');
        fs.writeFileSync(codexInput, 'first'); fs.writeFileSync(claudeInput, 'first');
        const extra = { CODEX_HOME: codex, CLAUDE_CONFIG_DIR: claude };
        passed(f.run(['--fast'], extra)); passed(f.run(['--fast'], extra));
        assert.strictEqual(f.count(), 1);
        fs.writeFileSync(codexInput, 'second'); passed(f.run(['--fast'], extra));
        fs.writeFileSync(claudeInput, 'second'); passed(f.run(['--fast'], extra));
        assert.strictEqual(f.count(), 3);
    });
    await test('failure and tree-guard pollution never mint a PASS', () => {
        const f = fixture();
        assert.strictEqual(f.run(['--fast'], { FAILURE: '1' }).status, 1);
        assert.strictEqual(f.run(['--fast'], { FAILURE: '1' }).status, 1);
        assert.strictEqual(f.count(), 1);
        assert.strictEqual(f.run(['--fast'], { POLLUTE: '1' }).status, 1);
        assert.strictEqual(f.count(), 2);
        assert(!fs.readdirSync(path.join(f.root, '.git/validation-receipts-v1')).filter(n => n.endsWith('.json')).some(
            n => JSON.parse(fs.readFileSync(path.join(f.root, '.git/validation-receipts-v1', n), 'utf8')).result === 'PASS'));
    });
    await test('known failed inputs return original code/evidence; changed input can recover', () => {
        const f = fixture();
        fs.writeFileSync(f.entry, fs.readFileSync(f.entry, 'utf8').replace('state=$(mktemp)',
            'if [[ "$(cat input)" == fail ]]; then exit 7; fi\nstate=$(mktemp)'));
        fs.writeFileSync(path.join(f.root, 'input'), 'fail');
        assert.strictEqual(f.run().status, 7);
        const second = f.run(); assert.strictEqual(second.status, 7);
        assert(second.stdout.includes('reusing FAIL')); assert(second.stdout.includes('validation: evidence'));
        assert.strictEqual(f.count(), 1);
        fs.writeFileSync(path.join(f.root, 'input'), 'recovered');
        passed(f.run()); assert.strictEqual(f.count(), 2);
    });
    await test('closed output consumer drains large child output and releases shared lock', async () => {
        const f = fixture();
        fs.writeFileSync(f.entry, fs.readFileSync(f.entry, 'utf8').replace('state=$(mktemp)',
            'python3 -c \'import sys; sys.stdout.write("x" * 10000000)\'\nstate=$(mktemp)'));
        const child = f.start({});
        let errorOutput = '';
        child.stderr.on('data', chunk => { errorOutput += chunk; });
        const finished = new Promise((resolve, reject) => {
            child.on('error', reject); child.on('close', code => resolve(code));
        });
        await waitFor(() => f.count() === 1);
        child.stdout.destroy();
        const code = await Promise.race([finished, pause(8000).then(() => { child.kill('SIGTERM');
            throw new Error('closed-output validation deadlocked'); })]);
        assert.notStrictEqual(code, 0, errorOutput);
        const repeated = f.run(); assert.strictEqual(repeated.status, 1);
        assert.strictEqual(f.count(), 1, 'known output failure must not execute twice');
    });
    await test('dirty file changed during successful guard run cannot mint PASS', () => {
        const f = fixture();
        fs.writeFileSync(path.join(f.root, 'input'), 'already dirty');
        const result = f.run(['--fast'], { MUTATE: '1' });
        assert.strictEqual(result.status, 1);
        assert(result.stderr.includes('inputs changed during run'), result.stderr);
        assert(!fs.readdirSync(path.join(f.root, '.git/validation-receipts-v1')).filter(n => n.endsWith('.json')).some(
            n => JSON.parse(fs.readFileSync(path.join(f.root, '.git/validation-receipts-v1', n), 'utf8')).result === 'PASS'));
    });
    await test('missing guard cannot reuse existing PASS', () => {
        const f = fixture(); passed(f.run());
        fs.chmodSync(path.join(f.root, 'tools/test-tree-guard.sh'), 0o644);
        assert.strictEqual(f.run().status, 1);
        assert.strictEqual(f.count(), 1);
    });
    await test('concurrent identical callers run exactly once', async () => {
        const f = fixture();
        const results = await Promise.all([done(f.start({ DELAY: '0.4' })), done(f.start({ DELAY: '0.4' }))]);
        assert(results.every(r => r.code === 0), JSON.stringify(results));
        assert.strictEqual(f.count(), 1);
    });
    await test('killed parent leaves live child lock intact; stale kernel lock then releases', async () => {
        const f = fixture();
        const leader = f.start({ DELAY: '1.2' });
        const leaderDone = done(leader);
        await waitFor(() => f.count() === 1);
        leader.kill('SIGKILL');
        const follower = f.start({ DELAY: '1.2' });
        const followerDone = done(follower);
        await pause(250);
        assert.strictEqual(f.count(), 1, 'follower must wait for surviving live child');
        const result = await followerDone;
        await leaderDone;
        assert.strictEqual(result.code, 1, result.output);
        assert(result.output.includes('interrupted or unresolved'), result.output);
        assert.strictEqual(f.count(), 1, 'abandoned journal must block duplicate execution');
        assert.strictEqual(f.run(['--fast'], { DELAY: '1.2' }).status, 1);
        assert.strictEqual(f.count(), 1);
    });
    await test('SIGTERM interrupts child and cannot leave PASS evidence', async () => {
        const f = fixture();
        const child = f.start({ DELAY: '5' }); const finished = done(child);
        await waitFor(() => f.count() === 1);
        child.kill('SIGTERM');
        const result = await finished;
        assert.notStrictEqual(result.code, 0);
        assert(!fs.readdirSync(path.join(f.root, '.git/validation-receipts-v1')).filter(n => n.endsWith('.json')).some(
            n => JSON.parse(fs.readFileSync(path.join(f.root, '.git/validation-receipts-v1', n), 'utf8')).result === 'PASS'));
        passed(f.run()); assert.strictEqual(f.count(), 2);
    });
    if (selectedCase && cases !== 1) throw new Error('Unknown exact receipt scenario: ' + selectedCase);
    if (selectedCase) console.log('# coverage: one exact scenario only');
    console.log(`1..${cases}`);
}
main().then(() => fs.rmSync(base, { recursive: true, force: true })).catch(error => {
    console.error(error.stack || error);
    fs.rmSync(base, { recursive: true, force: true });
    process.exitCode = 1;
});
