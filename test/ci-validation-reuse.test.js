#!/usr/bin/env node
'use strict';

const { test } = require('node:test');
const assert = require('node:assert/strict');
const { resolve, hash, validPlan, GitHub, pullRequestProvenance } = require('../tools/ci-validation-reuse');
const sha = n => String(n).repeat(40);
const clone = value => JSON.parse(JSON.stringify(value));
function plan(id = 20, overrides = {}) {
  const context = { schema: 1, suite: 'shell', tree: sha(1), workflow: sha(2), helper: sha(3),
    runtime: ['v24', 'kernel', 'npm', 'python', 'bash', 'git'], runner: ['Linux', 'X64', 'ubuntu24', 'image1'], waivers: [] };
  Object.assign(context, overrides);
  return { schema: 1, suite: context.suite, context, fingerprint: hash(context), repository: 'owner/repo',
    repositoryId: '1', runId: id, attempt: 1, commit: sha(4), event: 'push', job: context.suite === 'node' ? 'Node.js Tests' : 'Shell Tests' };
}
function fixture(producer = plan(10)) {
  const run = { id: producer.runId, run_attempt: 1, repository: { id: 1 }, head_repository: { id: 1 },
    path: '.github/workflows/test.yml', event: 'push', head_branch: 'dev', head_sha: producer.commit,
    status: 'completed', conclusion: 'success' };
  const document = kind => ({ id: kind, name: `ci-${kind}-${producer.suite}-${producer.fingerprint}`, workflow_run: { id: run.id } });
  const state = { run, producer, receipt: clone(producer), artifacts: [document('plan'), document('pass')],
    marker: 'success', receiptStep: 'success', jobConclusion: 'success', active: [], sleeps: 0, invocations: 0 };
  const api = {
    matching: async consumer => state.artifacts.filter(a => a.name === `ci-plan-${consumer.suite}-${consumer.fingerprint}`),
    runs: async () => state.active,
    run: async () => clone(state.run),
    artifacts: async () => clone(state.artifacts),
    document: async artifact => clone(artifact.id === 'plan' ? state.producer : state.receipt),
    commit: async () => ({ tree: { sha: producer.context.tree }, parents: [{ sha: sha(5) }, { sha: sha(6) }] }),
    blob: async (_ref, file) => file.includes('workflows') ? producer.context.workflow : producer.context.helper,
    potentialTree: async () => producer.context.tree,
    jobs: async () => [{ name: producer.job, status: state.jobConclusion ? 'completed' : 'in_progress', conclusion: state.jobConclusion, steps: [
      { name: 'Validation execution marker', conclusion: state.marker },
      { name: 'Record successful validation', conclusion: state.receiptStep },
    ] }],
  };
  const execute = async (consumer = plan(), options = {}) => {
    const result = await resolve(consumer, api, { poll: 0, sleep: async () => { state.sleeps++; }, ...options });
    if (!result.skip) state.invocations++;
    return result;
  };
  return { state, api, execute, document };
}

function prFixture() {
  const f = fixture();
  f.state.producer.event = 'pull_request';
  f.state.producer.pullRequest = { number: 7, baseSha: sha(5), headSha: sha(6),
    baseRepositoryId: '1', headRepositoryId: '1' };
  f.state.receipt = clone(f.state.producer);
  f.state.run.event = 'pull_request';
  f.state.run.head_sha = sha(6);
  f.state.run.pull_requests = [];
  return f;
}

test('identical tree/context runs zero new validation commands', async () => {
  const f = fixture();
  assert.deepEqual(await f.execute(), { skip: true, producer: 10 });
  assert.equal(f.state.invocations, 0);
});

test('newer run waits for older plan publication and execution, then reuses', async () => {
  const f = fixture();
  f.state.run.status = 'in_progress';
  f.state.active = [f.state.run];
  f.state.artifacts = [];
  f.state.jobConclusion = null;
  let waits = 0;
  const result = await f.execute(plan(), { sleep: async () => {
    waits++;
    if (waits === 1) f.state.artifacts = [f.document('plan')];
    if (waits === 2) { f.state.jobConclusion = 'success'; f.state.artifacts.push(f.document('pass')); }
  } });
  assert.equal(result.producer, 10);
  assert.equal(waits, 2);
  assert.equal(f.state.invocations, 0);
});

test('two runners elect the earlier run without waiting on a later published plan', async () => {
  const f = fixture(plan(20));
  f.state.run.status = 'in_progress';
  f.state.active = [f.state.run];
  assert.equal((await f.execute(plan(10))).skip, false);
  assert.equal(f.state.invocations, 1);
});

for (const [name, overrides] of [
  ['tree', { tree: sha(9) }], ['runtime', { runtime: ['v25'] }],
  ['runner image', { runner: ['Linux', 'X64', 'ubuntu24', 'new-image'] }],
  ['EI waiver', { waivers: ['EI-WAIVER: skill -10%'] }],
  ['OP waiver', { waivers: ['OP-WAIVER: skill pattern -1'] }],
  ['workflow', { workflow: sha(9) }], ['helper', { helper: sha(9) }],
]) test(`changed ${name} requires exactly one fresh validation`, async () => {
  const f = fixture();
  assert.equal((await f.execute(plan(20, overrides))).skip, false);
  assert.equal(f.state.invocations, 1);
});

test('an active different context is ignored after its plan is published', async () => {
  const f = fixture();
  f.state.run.status = 'in_progress'; f.state.active = [f.state.run];
  assert.equal((await f.execute(plan(20, { waivers: ['EI-WAIVER: skill -10%'] }))).skip, false);
});

for (const conclusion of ['failure', 'cancelled', 'skipped']) test(`equivalent target job ${conclusion} never authorizes success or a duplicate run`, async () => {
  const f = fixture(); f.state.jobConclusion = conclusion;
  await assert.rejects(f.execute(), /refusing duplicate execution/);
  assert.equal(f.state.invocations, 0);
});

test('waiting producer cancellation fails without re-election or rerun', async () => {
  const f = fixture(); f.state.run.status = 'in_progress'; f.state.jobConclusion = null;
  await assert.rejects(f.execute(plan(), { sleep: async () => {
    f.state.run.status = 'completed'; f.state.run.conclusion = 'cancelled'; f.state.jobConclusion = 'cancelled';
  } }), /cancelled/);
  assert.equal(f.state.invocations, 0);
});

for (const suite of ['node', 'shell']) {
  for (const otherJobs of ['pending', 'failure', 'cancelled']) {
    test(`${suite} executed PASS remains reusable while unrelated jobs are ${otherJobs}`, async () => {
      const f = fixture(plan(10, { suite }));
      f.state.run.status = otherJobs === 'pending' ? 'in_progress' : 'completed';
      f.state.run.conclusion = otherJobs === 'pending' ? null : otherJobs;
      const result = await f.execute(plan(20, { suite }), { timeout: 0 });
      assert.equal(result.skip, true);
      assert.equal(f.state.invocations, 0);
      assert.equal(f.state.sleeps, 0);
    });
  }
}

test('successful target job missing its receipt fails even with other jobs pending', async () => {
  const f = fixture(); f.state.run.status = 'in_progress'; f.state.run.conclusion = null;
  f.state.artifacts.pop();
  await assert.rejects(f.execute(), /missing executed validation evidence/);
  assert.equal(f.state.invocations, 0);
});

test('a target success conclusion without completed job status is rejected', async () => {
  const f = fixture();
  const jobs = f.api.jobs;
  f.api.jobs = async run => (await jobs(run)).map(job => ({ ...job, status: 'in_progress' }));
  await assert.rejects(f.execute(), /in_progress\/success; refusing duplicate execution/);
  assert.equal(f.state.invocations, 0);
});

test('receipt is refreshed after target job transitions to success', async () => {
  const f = fixture(); f.state.artifacts.pop();
  const jobs = f.api.jobs;
  f.api.jobs = async run => {
    const result = await jobs(run);
    f.state.artifacts.push(f.document('pass'));
    return result;
  };
  assert.equal((await f.execute()).skip, true);
});

for (const kind of ['missing', 'forged', 'skipped job', 'skipped receipt', 'changed attempt', 'changed policy', 'changed checkout']) {
  test(`${kind} producer evidence fails closed`, async () => {
    const f = fixture();
    if (kind === 'missing') f.state.artifacts.pop();
    if (kind === 'forged') f.state.receipt.runId = 999;
    if (kind === 'skipped job') f.state.jobConclusion = 'skipped';
    if (kind === 'skipped receipt') f.state.receiptStep = 'skipped';
    if (kind === 'changed attempt') f.state.run.run_attempt = 2;
    if (kind === 'changed policy') f.api.blob = async () => sha(8);
    if (kind === 'changed checkout') f.api.commit = async () => ({ tree: { sha: sha(8) } });
    await assert.rejects(f.execute());
    assert.equal(f.state.invocations, 0);
  });
}

test('plan metadata mutation cannot retain an old fingerprint', async () => {
  const f = fixture(); f.state.producer.context.runtime.push('mutated');
  await assert.rejects(f.execute(), /Malformed or mismatched/);
  assert.equal(f.state.invocations, 0);
});

test('recomputed fingerprint with forged context also cannot reuse the old artifact key', async () => {
  const f = fixture(); f.state.producer.context.waivers.push('OP-WAIVER: x y -1');
  f.state.producer.fingerprint = hash(f.state.producer.context);
  await assert.rejects(f.execute(), /Malformed or mismatched/);
});

test('fork result cannot authorize a protected branch', async () => {
  const f = fixture(); f.state.run.head_repository.id = 2;
  assert.equal((await f.execute()).skip, false);
  assert.equal(f.state.invocations, 1);
});

test('same-repo PR merge result is reusable, a different base merge tree is not', async () => {
  const f = prFixture();
  f.state.run.pull_requests = [{ number: 7, base: { sha: sha(5) }, head: { sha: sha(6) } }];
  assert.equal((await f.execute()).skip, true);
  assert.equal((await f.execute(plan(30, { tree: sha(7) }))).skip, false);
  assert.equal(f.state.invocations, 1);
});

test('a merged PR with an empty Actions association array retains valid event provenance', async () => {
  const f = prFixture();
  assert.equal((await f.execute()).skip, true);
  assert.equal(f.state.invocations, 0);
});

test('run SHA can identify the recorded checkout merge instead of the PR head', async () => {
  const f = prFixture(); f.state.run.head_sha = f.state.producer.commit;
  assert.equal((await f.execute()).skip, true);
});

for (const field of ['headSha', 'baseSha', 'headRepositoryId', 'baseRepositoryId', 'number']) {
  test(`tampered recorded PR ${field} cannot authorize reuse`, async () => {
    const f = prFixture();
    f.state.producer.pullRequest[field] = field.endsWith('Sha') ? sha(8) : field === 'number' ? 0 : '99';
    f.state.receipt = clone(f.state.producer);
    await assert.rejects(f.execute(), /PR event provenance mismatch|merge checkout mismatch/);
    assert.equal(f.state.invocations, 0);
  });
}

test('a recorded PR head/merge unrelated to the immutable run SHA is rejected', async () => {
  const f = prFixture(); f.state.run.head_sha = sha(8);
  await assert.rejects(f.execute(), /PR event provenance mismatch/);
  assert.equal(f.state.invocations, 0);
});

test('a PR checkout with swapped base/head parents is rejected', async () => {
  const f = prFixture();
  f.api.commit = async () => ({ tree: { sha: sha(1) }, parents: [{ sha: sha(6) }, { sha: sha(5) }] });
  await assert.rejects(f.execute(), /merge checkout mismatch/);
});

test('advanced mutable PR associations cannot invalidate or replace recorded provenance', async () => {
  const f = prFixture();
  f.state.run.pull_requests = [{ number: 7, base: { sha: sha(8) }, head: { sha: sha(9) } }];
  assert.equal((await f.execute()).skip, true);
  delete f.state.producer.pullRequest;
  await assert.rejects(f.execute(), /PR event provenance mismatch/);
});

test('PR event capture preserves number, immutable head/base and both repository IDs', () => {
  assert.deepEqual(pullRequestProvenance({ number: 7, pull_request: {
    head: { sha: sha(6), repo: { id: 1 } }, base: { sha: sha(5), repo: { id: 1 } },
  } }), { number: 7, headSha: sha(6), baseSha: sha(5), headRepositoryId: '1', baseRepositoryId: '1' });
  assert.equal(pullRequestProvenance({}), null);
});

test('unknown active PR merge tree waits for its plan and then reuses', async () => {
  const f = prFixture(); f.state.run.status = 'in_progress'; f.state.active = [f.state.run];
  f.state.artifacts = []; f.state.jobConclusion = null; f.api.potentialTree = async () => null;
  const result = await f.execute(plan(), { sleep: async () => {
    f.state.sleeps++; f.state.jobConclusion = 'success'; f.state.artifacts = [f.document('plan'), f.document('pass')];
  } });
  assert.equal(result.skip, true);
  assert.equal(f.state.sleeps, 1);
  assert.equal(f.state.invocations, 0);
});

test('unknown active PR merge tree waits for a different-context plan before fresh validation', async () => {
  const f = prFixture(); f.state.run.status = 'in_progress'; f.state.active = [f.state.run];
  f.state.artifacts = []; f.state.jobConclusion = null; f.api.potentialTree = async () => null;
  const result = await f.execute(plan(20, { tree: sha(8) }), { sleep: async () => {
    f.state.sleeps++; f.state.jobConclusion = 'success'; f.state.run.status = 'completed';
    f.state.artifacts = [f.document('plan'), f.document('pass')];
  } });
  assert.equal(result.skip, false);
  assert.equal(f.state.sleeps, 1);
  assert.equal(f.state.invocations, 1);
});

test('API cannot infer an absent PR association; exact tree classification waits for the plan', async () => {
  const api = new GitHub({ GITHUB_REPOSITORY: 'owner/repo' });
  api.commit = async () => ({ tree: { sha: sha(1) } });
  assert.equal(await api.potentialTree({ event: 'pull_request', head_sha: sha(6), pull_requests: [] }), null);
  assert.equal(await api.potentialTree({ event: 'push', head_sha: sha(6) }), sha(1));
});

test('a PR head with a changed API base cannot prove the older merge tree unrelated', async () => {
  const api = new GitHub({ GITHUB_REPOSITORY: 'owner/repo' });
  api.commit = async () => ({ tree: { sha: sha(1) }, parents: [{ sha: sha(4) }] });
  assert.equal(await api.potentialTree({ event: 'pull_request', head_sha: sha(6),
    pull_requests: [{ head: { sha: sha(6) }, base: { sha: sha(8) } }],
  }), null);
});

test('force-reset PR association cannot exclude an equivalent older run before plan publication', async () => {
  const f = prFixture();
  f.state.run.status = 'in_progress'; f.state.active = [f.state.run]; f.state.artifacts = []; f.state.jobConclusion = null;
  // Today's PR head is an ordinary parent of the original run's PR head.
  // Its unmerged tree differs from the actual merge tree in the pending plan.
  f.state.run.pull_requests = [{ head: { sha: sha(5) }, base: { sha: sha(8) } }];
  const commit = f.api.commit;
  f.api.commit = async ref => ref === f.state.run.head_sha
    ? { tree: { sha: sha(9) }, parents: [{ sha: sha(5) }] } : commit(ref);
  f.api.potentialTree = GitHub.prototype.potentialTree.bind(f.api);
  const result = await f.execute(plan(), { sleep: async () => {
    f.state.sleeps++; f.state.jobConclusion = 'success'; f.state.artifacts = [f.document('plan'), f.document('pass')];
  } });
  assert.equal(result.skip, true);
  assert.equal(f.state.sleeps, 1);
  assert.equal(f.state.invocations, 0);
});

test('base-contributed merge policy cannot be excluded by older PR HEAD policy before its plan', async () => {
  const f = prFixture();
  f.state.run.status = 'in_progress'; f.state.active = [f.state.run]; f.state.artifacts = []; f.state.jobConclusion = null;
  const blob = f.api.blob;
  let headPolicyReads = 0;
  f.api.blob = async (ref, file) => {
    if (ref === f.state.run.head_sha) { headPolicyReads++; return sha(9); }
    return blob(ref, file);
  };
  const result = await f.execute(plan(), { sleep: async () => {
    f.state.sleeps++; f.state.jobConclusion = 'success'; f.state.artifacts = [f.document('plan'), f.document('pass')];
  } });
  assert.equal(result.skip, true);
  assert.equal(headPolicyReads, 0);
  assert.equal(f.state.sleeps, 1);
  assert.equal(f.state.invocations, 0);
});

test('completed legacy PR job proves different policy and allows one fresh current validation', async () => {
  const f = prFixture(); f.state.active = [{ ...f.state.run, status: 'in_progress' }]; f.state.artifacts = [];
  f.api.jobs = async () => [{ name: f.state.producer.job, status: 'completed', conclusion: 'success',
    steps: [{ name: 'Set up job', conclusion: 'success' }, { name: 'All bats suites', conclusion: 'success' }],
  }];
  assert.equal((await f.execute()).skip, false);
  assert.equal(f.state.invocations, 1);
  assert.equal(f.state.sleeps, 0);
});

test('a missing target job proves different workflow context only after the PR run completes', async () => {
  const f = prFixture(); f.state.active = [{ ...f.state.run, status: 'in_progress' }]; f.state.artifacts = [];
  f.api.jobs = async () => [];
  assert.equal((await f.execute()).skip, false);
  assert.equal(f.state.invocations, 1);
});

test('running PR job without visible future protocol steps is not prematurely classified legacy', async () => {
  const f = prFixture(); f.state.run.status = 'in_progress'; f.state.active = [f.state.run]; f.state.artifacts = [];
  const jobs = f.api.jobs;
  f.api.jobs = async run => f.state.artifacts.length ? jobs(run) : [{ name: f.state.producer.job,
    status: 'in_progress', conclusion: null, steps: [{ name: 'Set up job', conclusion: 'success' }],
  }];
  const result = await f.execute(plan(), { sleep: async () => {
    f.state.sleeps++; f.state.artifacts = [f.document('plan'), f.document('pass')];
  } });
  assert.equal(result.skip, true);
  assert.equal(f.state.sleeps, 1);
  assert.equal(f.state.invocations, 0);
});

test('completed current-protocol PR job with a missing plan fails instead of starting a duplicate', async () => {
  const f = prFixture(); f.state.active = [{ ...f.state.run, status: 'in_progress' }]; f.state.artifacts = [];
  await assert.rejects(f.execute(), /without its expected validation plan/);
  assert.equal(f.state.invocations, 0);
});

test('a prior-attempt different-context plan cannot exclude the current equivalent attempt', async () => {
  const f = fixture(plan(10, { runtime: ['old runtime'] }));
  f.state.run.status = 'in_progress'; f.state.run.run_attempt = 2; f.state.active = [f.state.run];
  f.state.artifacts = [f.document('plan')]; f.state.jobConclusion = null;
  const result = await f.execute(plan(), { sleep: async () => {
    f.state.sleeps++;
    Object.assign(f.state.producer, plan(10), { attempt: 2 });
    f.state.receipt = clone(f.state.producer); f.state.jobConclusion = 'success';
    f.state.artifacts = [f.document('plan'), f.document('pass')];
  } });
  assert.equal(result.skip, true);
  assert.equal(f.state.sleeps, 1);
  assert.equal(f.state.invocations, 0);
});

test('legacy active workflows and unrelated trees never block ownership', async () => {
  const f = fixture(); f.state.run.status = 'in_progress'; f.state.active = [f.state.run];
  f.state.artifacts = [];
  f.api.blob = async () => null;
  assert.equal((await f.execute()).skip, false);
  f.api.blob = async (_ref, file) => file.includes('workflows') ? sha(2) : sha(3);
  f.api.potentialTree = async () => sha(7);
  assert.equal((await f.execute()).skip, false);
});

test('matching producer missing its plan times out clearly without rerunning', async () => {
  const f = fixture(); f.state.run.status = 'in_progress'; f.state.active = [f.state.run]; f.state.artifacts = []; f.state.jobConclusion = null;
  await assert.rejects(f.execute(plan(), { timeout: 0 }), /Timed out verifying/);
  assert.equal(f.state.invocations, 0);
});

test('successful reuse consumers never fabricate executed receipts', async () => {
  const f = fixture(); f.state.marker = 'skipped'; f.state.receiptStep = 'skipped'; f.state.artifacts.pop();
  await assert.rejects(f.execute(), /original executed receipt is unavailable/);
  assert.equal(f.state.invocations, 0);
});

test('artifact receipt JSON must be valid, and malformed contexts are rejected', async () => {
  const f = fixture(); f.api.document = async () => { throw new Error('invalid JSON'); };
  await assert.rejects(f.execute(), /invalid JSON/);
  assert.throws(() => validPlan(null, plan()), /Malformed/);
});

test('completed owner with no published plan fails rather than re-running', async () => {
  const f = fixture(); f.state.run.status = 'in_progress'; f.state.active = [f.state.run]; f.state.artifacts = [];
  f.api.run = async () => ({ ...f.state.run, status: 'completed' });
  await assert.rejects(f.execute(), /without its expected validation plan/);
});

test('API errors are not treated as cache misses', async () => {
  const f = fixture(); f.api.matching = async () => { throw new Error('API unavailable'); };
  await assert.rejects(f.execute(), /API unavailable/);
  assert.equal(f.state.invocations, 0);
});

test('missing legacy helper is distinguished from other API failures', async () => {
  const api = new GitHub({ GITHUB_REPOSITORY: 'owner/repo' });
  api.request = async () => { const e = new Error('Not found'); e.status = 404; throw e; };
  assert.equal(await api.blob(sha(1), 'missing'), null);
  api.request = async () => { throw new Error('Unavailable'); };
  await assert.rejects(api.blob(sha(1), 'missing'), /Unavailable/);
});
