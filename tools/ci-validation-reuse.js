#!/usr/bin/env node
'use strict';

// Actions artifacts are the ledger; run IDs impose an acyclic ownership order.
// Same-repository PR authors are trusted collaborators. Fork runs never produce
// reusable evidence. No concurrency group is used: pending required jobs survive.
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const crypto = require('node:crypto');
const { execFileSync } = require('node:child_process');

const JOBS = { node: 'Node.js Tests', shell: 'Shell Tests' };
const WORKFLOW = '.github/workflows/test.yml';
const HELPER = 'tools/ci-validation-reuse.js';
const hash = value => crypto.createHash('sha256').update(JSON.stringify(value)).digest('hex');
const command = (bin, args) => execFileSync(bin, args, { encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe'] }).trim();
const git = (...args) => command('git', args);
const artifactName = (kind, plan) => `ci-${kind}-${plan.suite}-${plan.fingerprint}`;
const waiverLines = value => (value || '').split(/\r?\n/).filter(line => /(?:EI|OP)-WAIVER:/.test(line));

// Capture the triggering event once. GitHub can remove a merged PR from a
// workflow run's pull_requests association array; that array is not a ledger.
function pullRequestProvenance(event) {
  const pr = event.pull_request;
  if (!pr) return null;
  return { number: Number(event.number || pr.number), headSha: pr.head.sha, baseSha: pr.base.sha,
    headRepositoryId: String(pr.head.repo.id), baseRepositoryId: String(pr.base.repo.id) };
}

function createPlan(suite, env = process.env) {
  if (!JOBS[suite]) throw new Error('Expected suite: node or shell');
  const event = JSON.parse(fs.readFileSync(env.GITHUB_EVENT_PATH, 'utf8'));
  const context = {
    schema: 1, suite, tree: git('rev-parse', 'HEAD^{tree}'),
    // CI suites retain the global closure: their dynamic/oracle readers have
    // no proven narrow exclusion. Bind the shared audited-selection policy.
    selectionPolicy: fs.existsSync('config/validation-inputs.json')
      ? hash(fs.readFileSync('config/validation-inputs.json', 'utf8')) : 'global-unknown-closure',
    workflow: git('rev-parse', `HEAD:${WORKFLOW}`), helper: git('rev-parse', `HEAD:${HELPER}`),
    runner: [env.RUNNER_OS, env.RUNNER_ARCH, env.ImageOS, env.ImageVersion],
    runtime: [process.version, os.release(), command('npm', ['--version']),
      command('python3', ['--version']), command('bash', ['--version']).split('\n')[0],
      command('git', ['--version'])],
    waivers: waiverLines(event.pull_request?.body),
  };
  return {
    schema: 1, suite, context, fingerprint: hash(context), repository: env.GITHUB_REPOSITORY,
    repositoryId: String(event.repository.id), runId: Number(env.GITHUB_RUN_ID),
    attempt: Number(env.GITHUB_RUN_ATTEMPT), commit: git('rev-parse', 'HEAD'),
    event: env.GITHUB_EVENT_NAME, job: JOBS[suite], pullRequest: pullRequestProvenance(event),
  };
}

function validPlan(plan, expected) {
  if (!plan || plan.schema !== 1 || plan.fingerprint !== hash(plan.context)
      || plan.fingerprint !== expected.fingerprint || JSON.stringify(plan.context) !== JSON.stringify(expected.context)
      || plan.suite !== expected.suite || plan.repository !== expected.repository
      || plan.repositoryId !== expected.repositoryId || plan.job !== JOBS[expected.suite]
      || !Number.isSafeInteger(plan.runId) || !Number.isSafeInteger(plan.attempt)
      || !/^[a-f0-9]{40}$/.test(plan.commit)) throw new Error('Malformed or mismatched validation plan');
  return plan;
}

class GitHub {
  constructor(env = process.env) {
    this.repository = env.GITHUB_REPOSITORY;
    this.token = env.GH_TOKEN || env.GITHUB_TOKEN;
    this.base = env.GITHUB_API_URL || 'https://api.github.com';
  }
  async request(endpoint, binary = false) {
    const response = await fetch(`${this.base}/repos/${this.repository}/${endpoint}`, {
      headers: { Authorization: `Bearer ${this.token}`, Accept: 'application/vnd.github+json',
        'X-GitHub-Api-Version': '2022-11-28' },
    });
    if (!response.ok) {
      const error = new Error(`GitHub validation evidence request failed (${response.status}): ${endpoint}`);
      error.status = response.status;
      throw error;
    }
    return binary ? Buffer.from(await response.arrayBuffer()) : response.json();
  }
  async pages(endpoint, key) {
    const result = [];
    for (let page = 1; ; page++) {
      const data = await this.request(`${endpoint}${endpoint.includes('?') ? '&' : '?'}per_page=100&page=${page}`);
      result.push(...data[key]);
      if (data[key].length < 100) return result;
    }
  }
  runs() { return this.pages('actions/workflows/test.yml/runs', 'workflow_runs'); }
  run(id) { return this.request(`actions/runs/${id}`); }
  jobs(run) { return this.pages(`actions/runs/${run.id}/attempts/${run.run_attempt}/jobs`, 'jobs'); }
  artifacts(run) { return this.pages(`actions/runs/${run.id}/artifacts`, 'artifacts'); }
  matching(plan) { return this.pages(`actions/artifacts?name=${artifactName('plan', plan)}`, 'artifacts'); }
  commit(sha) { return this.request(`git/commits/${sha}`); }
  async blob(sha, file) {
    try {
      const result = await this.request(`contents/${file}?ref=${sha}`);
      return result.sha;
    } catch (error) {
      if (error.status === 404) return null; // Legacy runs lack this protocol.
      throw error;
    }
  }
  async document(artifact, filename) {
    if (artifact.expired) throw new Error('Validation evidence expired');
    const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'ci-evidence-'));
    try {
      const archive = path.join(directory, 'evidence.zip');
      fs.writeFileSync(archive, await this.request(`actions/artifacts/${artifact.id}/zip`, true));
      // Read just the expected member; never extract an untrusted archive.
      return JSON.parse(command('unzip', ['-p', archive, filename]));
    } finally { fs.rmSync(directory, { recursive: true, force: true }); }
  }
  async potentialTree(run) {
    // A PR run SHA may be its head or merge checkout. Mutable associations
    // cannot prove which: a later force-reset can even make an old parent look
    // like today's PR head. Await the immutable plan for every PR instead.
    if (run.event !== 'push') return null;
    return (await this.commit(run.head_sha)).tree.sha;
  }
}

function trusted(run, plan) {
  return String(run.repository?.id) === plan.repositoryId
    && String(run.head_repository?.id) === plan.repositoryId
    && run.path === WORKFLOW
    && (run.event === 'pull_request' || (run.event === 'push' && ['dev', 'main'].includes(run.head_branch)));
}

async function verifyPlan(api, producer, consumer, run) {
  validPlan(producer, consumer);
  if (!trusted(run, consumer) || producer.runId !== run.id || producer.attempt !== run.run_attempt
      || producer.event !== run.event) throw new Error('Validation producer provenance mismatch');
  const commit = await api.commit(producer.commit);
  if (commit.tree.sha !== producer.context.tree
      || await api.blob(producer.commit, WORKFLOW) !== producer.context.workflow
      || await api.blob(producer.commit, HELPER) !== producer.context.helper) throw new Error('Producer checkout or policy mismatch');
  if (run.event === 'push' && producer.commit !== run.head_sha) throw new Error('Producer push checkout mismatch');
  if (run.event === 'pull_request') {
    const pr = producer.pullRequest;
    if (!pr || !Number.isSafeInteger(pr.number) || pr.number <= 0
        || !/^[a-f0-9]{40}$/.test(pr.headSha) || !/^[a-f0-9]{40}$/.test(pr.baseSha)
        || pr.headRepositoryId !== consumer.repositoryId || pr.baseRepositoryId !== consumer.repositoryId
        || ![pr.headSha, producer.commit].includes(run.head_sha))
      throw new Error('Producer PR event provenance mismatch');
    if (commit.parents?.length !== 2 || commit.parents[0].sha !== pr.baseSha
        || commit.parents[1].sha !== pr.headSha) throw new Error('Producer merge checkout mismatch');
    // The API association can disappear or describe a later PR revision.
    // It neither authorizes nor rejects this immutable event/run/parent proof.
  }
}

async function resolve(plan, api, options = {}) {
  const sleep = options.sleep || (ms => new Promise(resolveSleep => setTimeout(resolveSleep, ms)));
  const timeout = options.timeout ?? 30 * 60 * 1000;
  const started = Date.now();
  const pause = async reason => {
    if (Date.now() - started >= timeout) throw new Error(`Timed out verifying equivalent validation: ${reason}`);
    console.log(`validation reuse: waiting for ${reason}`);
    await sleep(options.poll ?? 15000);
  };
  // Never depend on a later run, including one that has already finished. This
  // prevents two suites/jobs/runs from forming a dependency cycle.
  const before = run => run.id < plan.runId;
  const candidates = new Set();
  // One snapshot across statuses avoids missing a queued -> in_progress
  // transition between separate filtered API requests.
  for (const run of await api.runs()) {
    if (run.status === 'completed' || !before(run) || !trusted(run, plan)) continue;
    // A PR's head can carry old policy while its merge checkout receives the
    // current helper/workflow from the base. Only its plan proves the policy.
    if (run.event === 'pull_request') { candidates.add(run.id); continue; }
    // Push checkout equals immutable HEAD, so exact policy/tree filtering is safe.
    if (await api.blob(run.head_sha, WORKFLOW) !== plan.context.workflow
        || await api.blob(run.head_sha, HELPER) !== plan.context.helper) continue;
    if (await api.potentialTree(run) === plan.context.tree) candidates.add(run.id);
  }
  // Read the ledger after active runs: a producer can complete while we list
  // runs, but its published plan must then be in this second snapshot.
  for (const artifact of await api.matching(plan)) {
    if (artifact.workflow_run.id < plan.runId) candidates.add(artifact.workflow_run.id);
  }
  for (const id of [...candidates].sort((a, b) => a - b)) {
    let producer;
    for (;;) {
      const run = await api.run(id);
      if (!trusted(run, plan)) break; // In particular, never authorize from forks.
      const artifacts = await api.artifacts(run);
      const plans = artifacts.filter(a => a.name === artifactName('plan', plan) && !a.expired);
      if (!plans.length) {
        // A different-context plan can exclude this candidate only when it
        // describes this attempt. Reruns retain artifacts from older attempts.
        let differentContext = false;
        for (const artifact of artifacts.filter(a => a.name.startsWith(`ci-plan-${plan.suite}-`) && !a.expired)) {
          const other = await api.document(artifact, 'plan.json');
          validPlan(other, other);
          if (other.repository !== plan.repository || other.repositoryId !== plan.repositoryId
              || other.suite !== plan.suite || other.runId !== run.id
              || artifact.name !== artifactName('plan', other)) throw new Error(`Run ${id} has malformed context evidence`);
          if (other.attempt < run.run_attempt) continue;
          await verifyPlan(api, other, other, run);
          differentContext = true;
        }
        if (differentContext) break;
        const job = (await api.jobs(run)).find(candidate => candidate.name === plan.job);
        // Future steps/jobs can be absent from queued/running API snapshots.
        // Only a completed successful job's executed list proves legacy policy.
        if (!job && run.status === 'completed') break;
        if (job?.status === 'completed') {
          const protocol = new Set(['Describe validation inputs', 'Publish validation plan',
            'Reuse equivalent validation', 'Validation execution marker',
            'Record successful validation', 'Publish successful validation']);
          if (job.conclusion === 'success' && Array.isArray(job.steps) && job.steps.length
              && job.steps.some(step => step.conclusion === 'success')
              && !job.steps.some(step => protocol.has(step.name))) break;
          throw new Error(`Run ${id} completed without its expected validation plan`);
        }
        if (run.status === 'completed') throw new Error(`Run ${id} completed without its expected validation plan`);
        await pause(`run ${id} to publish its plan`);
        continue;
      }
      if (plans.length !== 1) throw new Error(`Run ${id} has ambiguous validation plans`);
      producer = await api.document(plans[0], 'plan.json');
      await verifyPlan(api, producer, plan, run);
      const job = (await api.jobs(run)).find(candidate => candidate.name === plan.job);
      // Coverage belongs to this suite. An unrelated pending/failed job does
      // not erase its executed PASS; each required forge check stays enforced.
      if ((!job || job.status !== 'completed') && !job?.conclusion && run.status !== 'completed') {
        await pause(`run ${id}'s ${plan.job} job to finish`);
        continue;
      }
      if (!job || job.status !== 'completed' || job.conclusion !== 'success')
        throw new Error(`Equivalent validation job ${id}/${plan.job} ${job?.status || 'missing'}/${job?.conclusion || 'missing'}; refusing duplicate execution`);
      const marker = job.steps?.find(step => step.name === 'Validation execution marker');
      const receiptStep = job.steps?.find(step => step.name === 'Record successful validation');
      // Successful consumers deliberately publish no fresh pass. Their earlier
      // owner is also in the artifact ledger; only executed suites can authorize.
      if (marker?.conclusion === 'skipped' && receiptStep?.conclusion === 'skipped')
        throw new Error(`Run ${id} reused validation, but its original executed receipt is unavailable`);
      // A job may finish between our initial artifact read and its status read.
      // Refresh after success so a newly uploaded receipt is not falsely absent.
      const receipt = (await api.artifacts(run)).filter(a => a.name === artifactName('pass', plan) && !a.expired);
      if (marker?.conclusion !== 'success' || receiptStep?.conclusion !== 'success' || receipt.length !== 1)
        throw new Error(`Run ${id} is missing executed validation evidence`);
      const evidence = await api.document(receipt[0], 'receipt.json');
      if (JSON.stringify(evidence) !== JSON.stringify(producer)) throw new Error(`Run ${id} has a forged or mismatched validation receipt`);
      console.log(`validation reuse: ${plan.suite} tree ${plan.context.tree} passed in run ${id}, attempt ${run.run_attempt}`);
      return { skip: true, producer: id };
    }
  }
  return { skip: false };
}

async function main() {
  const [phase, suite] = process.argv.slice(2);
  if (phase === '--help' || !phase) {
    console.log('Usage: node tools/ci-validation-reuse.js <plan|resolve|receipt> <node|shell>');
    return;
  }
  if (!JOBS[suite]) throw new Error('Expected suite: node or shell');
  const directory = path.join('.ci-validation', suite);
  fs.mkdirSync(directory, { recursive: true });
  const filename = path.join(directory, 'plan.json');
  if (phase === 'plan') {
    const plan = createPlan(suite);
    fs.writeFileSync(filename, JSON.stringify(plan));
    fs.appendFileSync(process.env.GITHUB_OUTPUT, `plan-name=${artifactName('plan', plan)}\npass-name=${artifactName('pass', plan)}\n`);
  } else if (phase === 'resolve') {
    const result = await resolve(JSON.parse(fs.readFileSync(filename)), new GitHub());
    fs.appendFileSync(process.env.GITHUB_OUTPUT, `skip=${result.skip}\n`);
  } else if (phase === 'receipt') {
    const saved = JSON.parse(fs.readFileSync(filename));
    if (JSON.stringify(createPlan(suite)) !== JSON.stringify(saved)) throw new Error('Validation inputs changed during execution');
    fs.writeFileSync(path.join(directory, 'receipt.json'), JSON.stringify(saved));
  } else throw new Error(`Unknown phase: ${phase}`);
}

module.exports = { createPlan, pullRequestProvenance, validPlan, resolve, verifyPlan, trusted, artifactName, hash, GitHub };
if (require.main === module) main().catch(error => { console.error(`validation reuse: ${error.message}`); process.exitCode = 1; });
