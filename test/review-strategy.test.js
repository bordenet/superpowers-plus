#!/usr/bin/env node
'use strict';
const assert = require('assert');
const fs = require('fs');
const os = require('os');
const path = require('path');
const { spawnSync } = require('child_process');
const source = path.resolve(__dirname, '..');
const selected = process.argv.slice(2);
if (selected.length && (selected.length !== 2 || selected[0] !== '--case' || !['hook-output', 'context-freshness'].includes(selected[1]))) {
    throw new Error('Usage: review-strategy.test.js [--case hook-output|context-freshness]');
}
if (!selected.length || selected[1] === 'context-freshness') {
    const freshness = spawnSync('python3', ['-B', '-c', String.raw`
import os,pathlib,shutil,subprocess,sys,tempfile,types
source=pathlib.Path(sys.argv[1])
def load(name,path):
    m=types.ModuleType(name);m.__file__=str(path);exec(compile(path.read_bytes(),str(path),'exec'),m.__dict__);return m
m=load('snapshot',source/'tools/review-context-snapshot.py')
r=load('receipt',source/'tools/validation-receipt.py');r.TOOLS=('node','git','python3')
with tempfile.TemporaryDirectory(prefix='review freshness ') as area:
    base=pathlib.Path(area);root=base/'repo';home=base/'home';bin=base/'bin'
    for p in (root,home,bin):p.mkdir()
    alias=base/'PATH alias';alias.symlink_to(bin,target_is_directory=True)
    os.environ['HOME']=str(home);os.environ['PATH']=str(alias)+os.pathsep+os.environ['PATH'];os.chdir(root)
    subprocess.run(['git','init','-q'],check=True)
    (root/'tools').mkdir();shutil.copy(source/'tools/validation-inputs.py',root/'tools/validation-inputs.py')
    file=root/'value';file.write_text('original')
    node=bin/'node';node.write_text('#!/bin/sh\nexit 0\n');node.chmod(0o755)
    calls=[0];original=r.context
    def counted(*args,**kwargs):calls[0]+=1;return original(*args,**kwargs)
    r.context=counted
    def resolve():
        before=calls[0];payload,fresh,stats=m.resolve(r,root)
        assert calls[0]==before+1 and fresh() and fresh()
        assert calls[0]==before+1, 'freshness verification must not rerun full context hashing'
        assert stats['paths_observed']>0 and stats['full_resolutions']==1
        return fresh
    fresh=resolve();st=file.stat();file.write_text('changed!');os.utime(file,ns=(st.st_atime_ns,st.st_mtime_ns))
    assert not fresh(), 'ctime must catch changed bytes even when mtime/size are restored'
    fresh=resolve();node.write_text('#!/bin/sh\n# changed tool bytes\nexit 0\n');assert not fresh()
    fresh=resolve();(root/'unknown').write_text('unknown dependency');assert not fresh()
    fresh=resolve();subprocess.run(['git','config','core.filemode','false'],check=True);assert not fresh()
    fresh=resolve();subprocess.run(['git','add','value'],check=True);assert not fresh(), 'tracked selection changes are reader inputs'
    fresh=resolve();subprocess.run(['git','config','branch.history-only.remote','origin'],check=True)
    assert fresh(), 'branch bookkeeping excluded by authoritative config normalization'
    fresh=resolve();(home/'.codex').mkdir();(home/'.codex/AGENTS.md').write_text('new guidance');assert not fresh()
    fresh=resolve();(bin/'new-command').write_text('new PATH entry');assert not fresh()
print('freshness: one full resolve; source/tool/PATH/guidance/config/unknown mutations refuse without rehash; metadata-only branch change remains valid')
`, source], { encoding: 'utf8', env: { PATH: process.env.PATH, LANG: 'C' } });
    assert.strictEqual(freshness.status, 0, freshness.stdout + freshness.stderr);
    if (selected.length) { process.stdout.write(freshness.stdout); console.log('# coverage: context freshness only'); process.exit(0); }
}
const outputContract = spawnSync('python3', ['-B', '-c', String.raw`
import contextlib,importlib.util,io,json,sys
spec=importlib.util.spec_from_file_location('guard',sys.argv[1]);g=importlib.util.module_from_spec(spec);spec.loader.exec_module(g)
for admitted in (True, False):
    buffer=io.StringIO()
    with contextlib.redirect_stdout(buffer):g.answer(admitted,'fixture decision','REVIEW_REQUIRED' if admitted else 'STOP')
    payload=json.loads(buffer.getvalue())['hookSpecificOutput']
    assert payload['hookEventName']=='PreToolUse'
    if admitted:
        assert 'permissionDecision' not in payload, 'admitted strategy must preserve the normal host permission flow'
        assert payload['additionalContext'].startswith('REVIEW_REQUIRED:')
    else:assert payload['permissionDecision']=='deny'
`, path.join(source, 'tools/review-dispatch-guard.py')], { encoding: 'utf8' });
assert.strictEqual(outputContract.status, 0, outputContract.stdout + outputContract.stderr);
if (selected.length) { console.log('# coverage: hook output contract only'); process.exit(0); }
const area = fs.mkdtempSync(path.join(os.tmpdir(), 'review boundary '));
try {
    const root = path.join(area, 'source'); const home = path.join(area, 'home');
    fs.mkdirSync(root); fs.mkdirSync(home);
    fs.writeFileSync(path.join(root, '.gitignore'), '.code-review-cleared\n');
    fs.cpSync(path.join(source, 'tools'), path.join(root, 'tools'), { recursive: true });
    const nativeMarker = '# REVIEW_NATIVE_BODY\n';
    const battery = path.join(root, 'tools/run-battery.sh');
    const batterySource = fs.readFileSync(battery, 'utf8');
    // Orchestration fixture substitutes the expensive body, preserving the
    // real public wrapper, registered producer and native-result verifier.
    if (batterySource.includes(nativeMarker)) fs.writeFileSync(battery,
        batterySource.split(nativeMarker)[0] + nativeMarker +
        "#!/usr/bin/env bash\nset -eu\nprintf x >> \"$NATIVE_COUNTER\"\nif [[ \"${1:-}\" == --fixture-fail ]]; then exit 9; fi\nif [[ \"${1:-}\" == --fixture-wait ]]; then sleep 0.5; fi\nif [[ \"${1:-}\" == --fixture-output ]]; then while [[ ! -f \"$OUTPUT_RELEASE\" ]]; do sleep .01; done; python3 -c 'import os; os.write(1, b\"x\"*2097152)'; fi\nprintf 'v1|tree:%s|PASS|fixture-time|min-score=7.0\\n' \"$(git write-tree)\" > .code-review-cleared\n");
    fs.mkdirSync(path.join(root, 'lib'));
    fs.writeFileSync(path.join(root, 'lib/value.js'), 'const value = 1;\n');
    const bin = path.join(area, 'review bin'); fs.mkdirSync(bin);
    const nodeTool = path.join(bin, 'node'); const originalTool = '#!/bin/sh\nexit 0\n';
    fs.writeFileSync(nodeTool, originalTool, { mode: 0o755 });
    const env = { PATH: bin + path.delimiter + process.env.PATH, HOME: home, LANG: 'C', NATIVE_COUNTER: path.join(area, 'native calls'), OUTPUT_RELEASE: path.join(area, 'release output') };
    function git(...args) {
        const r = spawnSync('git', args, { cwd: root, env, encoding: 'utf8' });
        assert.strictEqual(r.status, 0, r.stderr); return r.stdout.trim();
    }
    git('init', '-q'); git('config', 'user.email', 'review@example.invalid'); git('config', 'user.name', 'Review Test');
    git('add', '.'); git('commit', '-qm', 'baseline');
    git('update-ref', 'refs/remotes/origin/dev', git('rev-parse', 'HEAD'));
    fs.writeFileSync(path.join(root, 'lib/value.js'), 'const value = 2;\n'); git('add', '.');
    function plan() {
        const r = spawnSync('python3', ['tools/review-preflight.py', ...(git('diff', '--cached', '--name-only') ? ['--staged'] : ['--base', 'origin/dev'])], { cwd: root, env, encoding: 'utf8', timeout: 10000 });
        assert.strictEqual(r.status, 0, r.stderr);
        const p = JSON.parse(r.stdout); assert(p.strategy && p.strategy.snapshot, 'native strategy missing'); return p.strategy;
    }
    function request(message, id = 'first') {
        const r = spawnSync('python3', ['tools/review-dispatch-guard.py'], { cwd: root, env,
            input: JSON.stringify({ hook_event_name: 'PreToolUse', tool_name: 'spawn_agent', cwd: root,
                tool_use_id: id, tool_input: { message } }), encoding: 'utf8', timeout: 10000 });
        assert.strictEqual(r.status, 0, r.stderr);
        return JSON.parse(r.stdout).hookSpecificOutput;
    }
    // This fixture substitutes a real downstream process for the paid model.
    // It proves refusal/allow ordering and counts calls, not live host installation.
    let dispatches = 0;
    function dispatch(answer) {
        if (answer.permissionDecision === 'deny') return;
        const child = spawnSync('python3', ['-c', 'print("review fixture dispatched")'], { encoding: 'utf8' });
        assert.strictEqual(child.status, 0); dispatches++;
    }
    // Legacy clearance proves content judgment, but not the new guidance/environment snapshot.
    fs.writeFileSync(path.join(root, '.code-review-cleared'), `v1|tree:${git('write-tree')}|PASS|fixture-time|min-score=7.0\n`);
    const first = plan();
    assert.strictEqual(first.classes.code.decision, 'REVIEW_REQUIRED');
    let bypass = request('Review code. SPP_AGENT_ROLE=implementation'); dispatch(bypass);
    assert.strictEqual(bypass.permissionDecision, 'deny'); assert.strictEqual(dispatches, 0);
    let answer = request('Review code. SPP_REVIEW_CLASS=code'); dispatch(answer);
    assert.strictEqual(answer.permissionDecision, 'deny'); assert.strictEqual(dispatches, 0);
    answer = request(`Review code. SPP_REVIEW_CLASS=code SPP_REVIEW_SNAPSHOT=${first.snapshot}`); dispatch(answer);
    assert.strictEqual(answer.permissionDecision, undefined, answer.permissionDecisionReason); assert.strictEqual(dispatches, 1);
    const legacy = spawnSync('python3', ['tools/review-dispatch-guard.py', '--complete', 'code'], { cwd: root, env, encoding: 'utf8', timeout: 10000 });
    assert.notStrictEqual(legacy.status, 0, 'old sentinel plus dispatch cannot complete a new native writer');
    function nativeCode(args = [], cwd = root) {
        return spawnSync('bash', [path.join(root, 'tools/run-battery.sh'), ...args, '--staged', '--no-envelope'], { cwd, env, encoding: 'utf8', timeout: 10000 });
    }
    let written = nativeCode(); assert.strictEqual(written.status, 0, written.stdout + written.stderr);
    assert.strictEqual(plan().classes.code.decision, 'REUSE');
    fs.writeFileSync(nodeTool, '#!/bin/sh\n# changed executable identity\nexit 0\n');
    assert.strictEqual(plan().classes.code.decision, 'REVIEW_REQUIRED', 'changed executable bytes invalidate reviewed context at the same path');
    assert.strictEqual(fs.readFileSync(env.NATIVE_COUNTER, 'utf8'), 'x', 'tool mismatch classification runs no native checks');
    fs.writeFileSync(nodeTool, originalTool); assert.strictEqual(plan().classes.code.decision, 'REUSE');
    git('config', 'core.filemode', 'false');
    assert.strictEqual(plan().classes.code.decision, 'REVIEW_REQUIRED', 'effective Git configuration is a review input');
    git('config', 'core.filemode', 'true'); assert.strictEqual(plan().classes.code.decision, 'REUSE');
    written = nativeCode([], area); assert.strictEqual(written.status, 0, 'canonical writer outside Git must fall back to script repository: ' + written.stdout + written.stderr);
    assert.strictEqual(plan().classes.code.decision, 'REUSE', 'same-context native completion is idempotent');
    assert.strictEqual(fs.readFileSync(env.NATIVE_COUNTER, 'utf8'), 'xx');
    const bound = fs.readFileSync(path.join(root, '.code-review-cleared'), 'utf8');
    fs.writeFileSync(path.join(root, '.code-review-cleared'), bound.replace('fixture-time', 'altered-time'));
    assert.strictEqual(plan().classes.code.decision, 'STOP', 'a valid-looking replacement cannot satisfy the original binding');
    assert.notStrictEqual(nativeCode().status, 0, 'unprovable evidence cannot be overwritten into success');
    assert.strictEqual(fs.readFileSync(env.NATIVE_COUNTER, 'utf8'), 'xx');
    fs.writeFileSync(path.join(root, '.code-review-cleared'), bound);
    git('commit', '-qm', 'same reviewed tree');
    const promotion = spawnSync('bash', ['tools/post-commit'], { cwd: root, env, encoding: 'utf8' });
    assert.strictEqual(promotion.status, 0, promotion.stdout + promotion.stderr);
    const carried = plan(); assert.strictEqual(carried.snapshot, first.snapshot);
    assert.strictEqual(carried.classes.code.decision, 'REUSE', 'native SHA promotion preserves proven context without another reviewer');
    fs.mkdirSync(path.join(home, '.codex'), { recursive: true });
    fs.writeFileSync(path.join(home, '.codex/AGENTS.md'), 'changed review guidance\n');
    assert.strictEqual(plan().classes.code.decision, 'REVIEW_REQUIRED', 'legacy sentinel cannot attest changed guidance');
    answer = request(`Review again. SPP_REVIEW_CLASS=code SPP_REVIEW_SNAPSHOT=${first.snapshot}`, 'second'); dispatch(answer);
    assert.strictEqual(answer.permissionDecision, 'deny'); assert.strictEqual(dispatches, 1);
    fs.writeFileSync(path.join(root, 'lib/value.js'), 'const value = 3;\n'); git('add', '.');
    answer = request(`Review code. SPP_REVIEW_CLASS=code SPP_REVIEW_SNAPSHOT=${first.snapshot}`, 'third'); dispatch(answer);
    assert.strictEqual(answer.permissionDecision, 'deny'); assert.strictEqual(dispatches, 1);
    const changed = plan(); assert.notStrictEqual(changed.snapshot, first.snapshot);
    answer = request(`Review material fix. SPP_REVIEW_CLASS=code SPP_REVIEW_SNAPSHOT=${changed.snapshot}`, 'fourth'); dispatch(answer);
    assert.strictEqual(answer.permissionDecision, undefined); assert.strictEqual(dispatches, 2);
    const failed = nativeCode(['--fixture-fail']); assert.strictEqual(failed.status, 9, failed.stdout + failed.stderr);
    assert.notStrictEqual(nativeCode(['--fixture-fail']).status, 0);
    assert.strictEqual(fs.readFileSync(env.NATIVE_COUNTER, 'utf8'), 'xxx', 'unchanged failed producer must not execute again');
    fs.writeFileSync(path.join(root, 'lib/value.js'), 'const value = 4;\n'); git('add', '.');
    const interrupted = plan();
    answer = request(`Review interrupted scope. SPP_REVIEW_CLASS=code SPP_REVIEW_SNAPSHOT=${interrupted.snapshot}`, 'interrupted'); dispatch(answer);
    assert.strictEqual(answer.permissionDecision, undefined, answer.permissionDecisionReason);
    const killed = spawnSync('python3', ['-c', String.raw`
import os,pathlib,subprocess,time
counter=pathlib.Path(os.environ['NATIVE_COUNTER'])
p=subprocess.Popen(['bash','tools/run-battery.sh','--fixture-wait'],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
limit=time.monotonic()+5
while (not counter.exists() or len(counter.read_text())<4) and time.monotonic()<limit: time.sleep(.01)
assert counter.exists() and len(counter.read_text())==4, 'writer did not start'
p.terminate();p.wait(timeout=2)
# The inherited lock remains with the bounded child. Its eventual success
# cannot seal a parent producer that was killed before finalization.
time.sleep(.6)
`], { cwd: root, env, encoding: 'utf8', timeout: 10000 });
    assert.strictEqual(killed.status, 0, killed.stdout + killed.stderr);
    assert.notStrictEqual(nativeCode().status, 0, 'interrupted native producer must not silently retry');
    assert.strictEqual(fs.readFileSync(env.NATIVE_COUNTER, 'utf8'), 'xxxx');
    fs.writeFileSync(path.join(root, 'lib/value.js'), 'const value = 5;\n'); git('add', '.');
    const outputScope = plan();
    answer = request(`Review output scope. SPP_REVIEW_CLASS=code SPP_REVIEW_SNAPSHOT=${outputScope.snapshot}`, 'output'); dispatch(answer);
    assert.strictEqual(answer.permissionDecision, undefined, answer.permissionDecisionReason);
    const closed = spawnSync('python3', ['-c', String.raw`
import os,pathlib,subprocess,time
counter=pathlib.Path(os.environ['NATIVE_COUNTER'])
p=subprocess.Popen(['bash','tools/run-battery.sh','--fixture-output'],stdout=subprocess.PIPE,stderr=subprocess.DEVNULL)
limit=time.monotonic()+5
while len(counter.read_text())<5 and time.monotonic()<limit: time.sleep(.01)
assert len(counter.read_text())==5, 'writer did not start'
p.stdout.close();pathlib.Path(os.environ['OUTPUT_RELEASE']).touch()
try: p.wait(timeout=2)
except subprocess.TimeoutExpired:
    p.kill();p.wait();raise AssertionError('output consumer failure deadlocked the native producer')
assert p.returncode != 0, 'output failure must not establish PASS'
`], { cwd: root, env, encoding: 'utf8', timeout: 10000 });
    assert.strictEqual(closed.status, 0, closed.stdout + closed.stderr);
    assert(!fs.existsSync(path.join(root, '.code-review-cleared')), 'failed output producer cannot leave a new clearance');
    assert.notStrictEqual(nativeCode().status, 0); assert.strictEqual(fs.readFileSync(env.NATIVE_COUNTER, 'utf8'), 'xxxxx');
    fs.mkdirSync(path.join(root, 'docs')); fs.writeFileSync(path.join(root, 'docs/plan.md'), '# Test plan\n'); git('add', '.');
    const design = plan(); assert.strictEqual(design.classes.design.decision, 'REVIEW_REQUIRED');
    answer = request(`Review plan. SPP_REVIEW_CLASS=design SPP_REVIEW_SNAPSHOT=${design.snapshot}`, 'design'); dispatch(answer);
    assert.strictEqual(answer.permissionDecision, undefined, answer.permissionDecisionReason);
    const realWriter = spawnSync('bash', ['tools/run-phr.sh', '--verdict', 'PASS', '--min-score', '9.5'], { cwd: root, env, encoding: 'utf8', timeout: 10000 });
    assert.strictEqual(realWriter.status, 0, realWriter.stdout + realWriter.stderr);
    assert.strictEqual(plan().classes.design.decision, 'REUSE', 'real native PHR writer result seals its elected context');
    // Real skill writer, real evidence verifier and ADR gate; paid judgment is
    // represented only by the explicit isolated fixture envelope.
    env.PATH = process.env.PATH;
    fs.mkdirSync(path.join(root, 'skills/engineering/fixture'), { recursive: true });
    const skillPath = 'skills/engineering/fixture/skill.md';
    fs.writeFileSync(path.join(root, skillPath), '# Fixture skill\n'); git('add', '.');
    fs.mkdirSync(path.join(root, '.cr-battery-runs'), { recursive: true });
    fs.writeFileSync(path.join(root, '.cr-battery-runs', git('rev-parse', 'HEAD') + '-llm-skill-review.json'), JSON.stringify({
        head_sha: git('rev-parse', 'HEAD'), findings: [], clean_dimensions: [{ reviewer: 'Fixture', dimension: 'Correctness',
            claim: 'fixture skill exists', evidence: { command: 'test -f ' + skillPath,
                expectation: { type: 'exit_code', value: 0 }, verifiable: true } }],
    }));
    const skill = plan(); assert.strictEqual(skill.classes.skill.decision, 'REVIEW_REQUIRED');
    answer = request(`Review fixture skill. SPP_REVIEW_CLASS=skill SPP_REVIEW_SNAPSHOT=${skill.snapshot}`, 'skill'); dispatch(answer);
    assert.strictEqual(answer.permissionDecision, undefined, answer.permissionDecisionReason);
    const skillWriter = spawnSync('bash', ['tools/run-llm-skill-review.sh', '--verdict', 'PASS', '--min-score', '8.0'],
        { cwd: root, env, encoding: 'utf8', timeout: 10000 });
    assert.strictEqual(skillWriter.status, 0, skillWriter.stdout + skillWriter.stderr);
    assert.strictEqual(plan().classes.skill.decision, 'REUSE', 'actual skill writer seals native context after real evidence replay');
    console.log('review boundary: missing/stale/repeated decisions refuse real downstream calls; changed scope dispatches once');
} finally { fs.rmSync(area, { recursive: true, force: true }); }
