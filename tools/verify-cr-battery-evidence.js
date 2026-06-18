#!/usr/bin/env node
// verify-cr-battery-evidence.js
//
// Replays the `evidence` block for each finding and clean-dimension verdict in
// a .cr-battery-runs/<HEAD-sha>.json envelope, compares observed output to the
// declared expectation, and writes a `verifier_result` back into the envelope.
//
// ==============================================================================
// TRUST MODEL (READ BEFORE INVOKING)
// ==============================================================================
// `evidence.command` is treated as CODE -- it is passed verbatim to a shell
// subprocess via execSync. The verifier therefore inherits the trust posture
// of WHATEVER WROTE THE ENVELOPE:
//
//   - In normal use, the envelope is written on the engineer's local machine by
//     the orchestrating agent during a cr-battery run. The agent is local and
//     trusted; commands are typically `grep`, `find`, `git diff`, etc.
//   - Invoking the verifier on an envelope from a HOSTILE OR UNTRUSTED source
//     (e.g., a `.cr-battery-runs/<sha>.json` checked into a malicious PR, an
//     envelope downloaded from an attacker, etc.) is equivalent to running
//     arbitrary code with the verifier's full shell privileges -- credential
//     theft, file destruction, network exfiltration are ALL possible.
//
// Envelope files are written to .cr-battery-runs/ which is .gitignore'd,
// preventing injection via PR diffs. If you invoke this verifier manually
// on a downloaded/external envelope, ensure you trust its origin — the
// evidence commands inside are executed by the shell.
//
// Caps applied per the cr-battery scoring rule (see code-review-battery/skill.md):
//   - any falsified claim caps the (reviewer, dimension) at 5.0
//   - any unverifiable / missing-evidence claim caps at 7.0
//   - lower cap wins (5.0 dominates 7.0)
//
// Exit codes (stable contract):
//   0  All claims either verified or unverifiable (no falsifications)
//   1  At least one falsified claim; dimensions capped; run-battery.sh aborts
//   2  Usage / IO / parse error
//
// Evidence-block schema (per finding AND per clean-dimension verdict):
//   {
//     "claim": "no alarms wired for GreetingUnlockOutcome",
//     "evidence": {
//       "command": "grep -rcE 'GreetingUnlockOutcome' infra/constructs/monitoring/",
//       "expectation": { "type": "count", "value": "==0" },
//       "verifiable": true,
//       "rationale": "(optional human-readable reason for the expectation)"
//     }
//   }
// `verifiable: false` is permitted for genuine judgment claims (race conditions,
// design smells) that cannot be replayed deterministically. The verifier surfaces
// them to the operator and caps at 7.0 rather than auto-failing.
//
// Expectation types (canonical):
//   count     value matches /^(>=|<=|==|>|<)(\d+)$/ ; e.g. ">0", "==0", "<=5"
//   exit_code value is an integer; passes if the command's exit matches
//   match     value is a regex string applied to stdout (case-sensitive)
//   absent    `value` field is IGNORED; passes iff stdout has zero non-blank lines
//   exact     value is a string; passes iff trimmed stdout equals value exactly

'use strict';

const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

function envIntOrDie(name, dflt) {
  const raw = process.env[name];
  if (raw === undefined || raw === '') return dflt;
  const n = parseInt(raw, 10);
  if (!Number.isFinite(n) || n <= 0) {
    console.error(`ERROR: env var ${name}="${raw}" is not a positive integer.`);
    process.exit(2);
  }
  return n;
}

const VERIFIER_TIMEOUT_MS  = envIntOrDie('VERIFIER_TIMEOUT_MS',  30000);
const MAX_STDOUT_FOR_MATCH = envIntOrDie('VERIFIER_MAX_MATCH_BYTES', 65536);
const MAX_FINDINGS_PER_ENV = envIntOrDie('VERIFIER_MAX_FINDINGS', 1000);
const MAX_REGEX_PATTERN_LEN = 256; // ReDoS guard: refuse pathologically long patterns

// Score caps applied to (reviewer, dimension) tuples; lower wins.
const FALSIFIED_CAP    = 5.0;
const UNVERIFIABLE_CAP = 7.0;

function usage(msg) {
  if (msg) console.error(`ERROR: ${msg}`);
  console.error('Usage: node verify-cr-battery-evidence.js <envelope.json> [--cwd <repo-root>]');
  console.error('  envelope.json   path to .cr-battery-runs/<sha>.json');
  console.error('  --cwd           working directory for evidence.command execution (default: $PWD).');
  console.error('                  Must be inside a git repo; verifier warns if --cwd is outside the repo root.');
  console.error('');
  console.error('Environment:');
  console.error(`  VERIFIER_TIMEOUT_MS       per-command timeout (default 30000 = 30s)`);
  console.error(`  VERIFIER_MAX_MATCH_BYTES  truncate stdout to this many bytes before regex match (default 65536; ReDoS guard)`);
  console.error(`  VERIFIER_MAX_FINDINGS     max findings + clean_dimensions per envelope (default 1000; envelope-DoS cap)`);
  process.exit(2);
}

function parseExpectation(stdout, exitCode, expectation) {
  if (!expectation || !expectation.type) {
    return { status: 'error', detail: 'missing or malformed expectation' };
  }
  // Defensive default: never let null/undefined reach .split/.trim
  stdout = (stdout == null) ? '' : String(stdout);
  const lines = stdout.split('\n').filter(l => l.trim().length > 0);
  switch (expectation.type) {
    case 'count': {
      const m = String(expectation.value).match(/^(>=|<=|==|>|<)(\d+)$/);
      if (!m) return { status: 'error', detail: `bad count value "${expectation.value}" (expected one of: >N, >=N, <N, <=N, ==N where N is a non-negative integer)` };
      const [, cmp, n] = m;
      const N = parseInt(n, 10);
      const ok = cmp === '>'  ? lines.length >  N
               : cmp === '>=' ? lines.length >= N
               : cmp === '<'  ? lines.length <  N
               : cmp === '<=' ? lines.length <= N
               :                lines.length === N;
      return { status: ok ? 'verified' : 'falsified', observed: `non_blank_lines=${lines.length}` };
    }
    case 'exit_code': {
      const want = Number(expectation.value);
      return { status: exitCode === want ? 'verified' : 'falsified', observed: `exit=${exitCode}` };
    }
    case 'match': {
      const pat = String(expectation.value || '');
      if (pat.length > MAX_REGEX_PATTERN_LEN) {
        return { status: 'error', detail: `regex pattern length ${pat.length} exceeds ${MAX_REGEX_PATTERN_LEN}-byte ReDoS guard` };
      }
      // Truncate stdout before .test() so a pathological pattern cannot run unbounded
      const haystack = stdout.length > MAX_STDOUT_FOR_MATCH ? stdout.slice(0, MAX_STDOUT_FOR_MATCH) : stdout;
      let re;
      try { re = new RegExp(pat); }
      catch (e) { return { status: 'error', detail: `bad regex: ${e.message}` }; }
      return { status: re.test(haystack) ? 'verified' : 'falsified', observed: truncate(stdout, 200) };
    }
    case 'absent':
      // `value` is intentionally ignored for `absent`; passes iff stdout has zero non-blank lines.
      return { status: lines.length === 0 ? 'verified' : 'falsified', observed: `non_blank_lines=${lines.length}` };
    case 'exact':
      return { status: stdout.trim() === expectation.value ? 'verified' : 'falsified', observed: truncate(stdout, 200) };
    default:
      return { status: 'error', detail: `unknown expectation type "${expectation.type}"` };
  }
}

function truncate(s, n) { return s.length > n ? s.slice(0, n) + '...' : s; }

function replay(claim, cwd) {
  if (!claim || !claim.evidence) {
    return { status: 'no-evidence', detail: 'no evidence block present' };
  }
  const ev = claim.evidence;
  if (ev.verifiable === false) {
    return { status: 'unverifiable', detail: ev.rationale || 'judgment-claim flagged verifiable:false' };
  }
  if (!ev.command || typeof ev.command !== 'string') {
    return { status: 'error', detail: 'evidence.command missing or non-string' };
  }
  let stdout = '', exitCode = 0;
  try {
    stdout = execSync(ev.command, {
      cwd,
      encoding: 'utf8',
      timeout: VERIFIER_TIMEOUT_MS,
      stdio: ['ignore', 'pipe', 'pipe'],
      maxBuffer: 4 * 1024 * 1024,
    });
  } catch (err) {
    // Timeout: execSync sets err.killed=true and signal varies (SIGTERM, SIGKILL, null on some platforms)
    if (err.killed || /ETIMEDOUT/.test(err.code || '') || /timed? ?out/i.test(err.message || '')) {
      return { status: 'error', detail: `command exceeded ${VERIFIER_TIMEOUT_MS}ms timeout` };
    }
    // maxBuffer exceeded: ENOBUFS (older Node), ERR_CHILD_PROCESS_STDIO_MAXBUFFER (newer Node); both thrown by execSync
    if (err.code === 'ENOBUFS' || err.code === 'ERR_CHILD_PROCESS_STDIO_MAXBUFFER') {
      return { status: 'error', detail: `command stdout exceeded 4MB execSync buffer; narrow the evidence.command (e.g. add | head, | wc -l)` };
    }
    if (err.status !== null && err.status !== undefined) {
      exitCode = err.status;
      stdout = err.stdout ? err.stdout.toString() : '';
    } else {
      return { status: 'error', detail: `command spawn failed: ${err.message}` };
    }
  }
  return parseExpectation(stdout, exitCode, ev.expectation);
}

function capDimension(state, reviewer, dimension, cap, claim) {
  if (!reviewer || !dimension) return false; // orphan claim, no dimension to cap
  state[reviewer] = state[reviewer] || {};
  const existing = state[reviewer][dimension];
  if (existing === undefined || cap < existing.cap) {
    state[reviewer][dimension] = { cap, reason: claim };
  }
  return true;
}

function processClaims(claims, kind, cwd, state, summary) {
  if (!Array.isArray(claims)) return;
  for (const claim of claims) {
    summary.claims_total++;
    if (!claim || typeof claim !== 'object') {
      // null / non-object entry: count as unverifiable orphan; no cap possible
      summary.claims_unverifiable++;
      summary.claims_orphan = (summary.claims_orphan || 0) + 1;
      continue;
    }
    const rep = replay(claim, cwd);
    claim.verifier = rep;
    const ctx = `${kind} "${truncate(claim.claim || '(no claim)', 80)}"`;
    switch (rep.status) {
      case 'verified':
        summary.claims_verified++;
        summary.claims_replayed++;
        break;
      case 'falsified': {
        summary.claims_falsified++;
        summary.claims_replayed++;
        const observedDetail = rep.observed ? ` (observed: ${rep.observed})` : '';
        const cmdDetail = claim.evidence && claim.evidence.command ? ` [cmd: ${truncate(claim.evidence.command, 80)}]` : '';
        const reason = `${ctx} falsified${observedDetail}${cmdDetail}`;
        const capped = capDimension(state, claim.reviewer, claim.dimension, FALSIFIED_CAP, reason);
        if (!capped) summary.claims_orphan = (summary.claims_orphan || 0) + 1;
        break;
      }
      case 'unverifiable':
      case 'no-evidence':
      case 'error': {
        summary.claims_unverifiable++;
        const reason = `${ctx} unverifiable: ${rep.detail || rep.status}`;
        const capped = capDimension(state, claim.reviewer, claim.dimension, UNVERIFIABLE_CAP, reason);
        if (!capped) summary.claims_orphan = (summary.claims_orphan || 0) + 1;
        break;
      }
    }
  }
}

// Library entry-point for callers embedding the verifier in another tool.
// Reads the envelope at `envelopePath`, replays evidence in `cwd`, mutates the
// envelope file in place with a verifier_result, and returns the same summary
// object that main() exits on. Throws on JSON parse / IO errors.
function verifyEnvelope(envelopePath, cwd) {
  if (!fs.existsSync(envelopePath)) throw new Error(`envelope not found: ${envelopePath}`);
  if (!fs.statSync(cwd).isDirectory()) throw new Error(`cwd is not a directory: ${cwd}`);
  const envelope = JSON.parse(fs.readFileSync(envelopePath, 'utf8'));
  const summary = {
    claims_total: 0, claims_replayed: 0,
    claims_verified: 0, claims_falsified: 0, claims_unverifiable: 0,
    claims_orphan: 0,
    dimensions_capped: [],
    timeout_ms: VERIFIER_TIMEOUT_MS,
    max_match_bytes: MAX_STDOUT_FOR_MATCH,
    cwd,
  };
  const state = {};
  const totalClaims = (Array.isArray(envelope.findings) ? envelope.findings.length : 0)
                    + (Array.isArray(envelope.clean_dimensions) ? envelope.clean_dimensions.length : 0);
  if (totalClaims > MAX_FINDINGS_PER_ENV) {
    throw new Error(`envelope has ${totalClaims} claims; exceeds VERIFIER_MAX_FINDINGS=${MAX_FINDINGS_PER_ENV} envelope-DoS cap. Split the envelope or raise the limit.`);
  }
  processClaims(envelope.findings, 'finding', cwd, state, summary);
  processClaims(envelope.clean_dimensions, 'clean-dimension', cwd, state, summary);
  // Object-shaped capped entries (self-documenting; previously positional tuples)
  summary.dimensions_capped = Object.entries(state)
    .flatMap(([reviewer, dims]) =>
      Object.entries(dims).map(([dimension, info]) =>
        ({ reviewer, dimension, cap: info.cap, reason: info.reason })));
  envelope.verifier_result = summary;
  fs.writeFileSync(envelopePath, JSON.stringify(envelope, null, 2));
  return summary;
}

function main() {
  const argv = process.argv.slice(2);
  if (argv.length === 0 || argv[0] === '-h' || argv[0] === '--help') usage();
  const envelopePath = argv[0];
  let cwd = process.cwd();
  for (let i = 1; i < argv.length; i++) {
    if (argv[i] === '--cwd' && argv[i+1]) { cwd = path.resolve(argv[i+1]); i++; }
    else usage(`unknown arg "${argv[i]}"`);
  }
  if (!fs.existsSync(envelopePath)) usage(`envelope not found: ${envelopePath}`);
  let cwdStat;
  try { cwdStat = fs.statSync(cwd); } catch (e) { usage(`--cwd path does not exist: ${cwd}`); }
  if (!cwdStat.isDirectory()) usage(`--cwd is not a directory: ${cwd}`);

  // --cwd boundary warning: if --cwd is outside the git repo we'd normally audit,
  // print a notice so the operator notices accidental misconfiguration. Not fatal --
  // some workflows (test fixtures, scratch directories) legitimately need this.
  try {
    const topLevel = execSync('git rev-parse --show-toplevel', {
      cwd, encoding: 'utf8', stdio: ['ignore', 'pipe', 'ignore'], timeout: 5000,
    }).trim();
    if (topLevel && !cwd.startsWith(topLevel)) {
      console.error(`WARNING: --cwd ${cwd} is outside its git repo root ${topLevel}; evidence.command will run from the supplied --cwd, not the repo root.`);
    }
  } catch (_) { /* not in a git repo; that's fine for fixtures */ }

  let summary;
  try { summary = verifyEnvelope(envelopePath, cwd); }
  catch (e) { console.error(`ERROR: ${e.message}`); process.exit(2); }

  console.log(`Verifier replay complete: ${summary.claims_verified}/${summary.claims_total} verified, `
    + `${summary.claims_falsified} falsified, ${summary.claims_unverifiable} unverifiable`
    + (summary.claims_orphan ? `, ${summary.claims_orphan} orphan (no reviewer/dimension; dimension cap not applied)` : '')
    + '.');
  if (summary.dimensions_capped.length) {
    console.log('Dimensions capped:');
    summary.dimensions_capped.forEach(({ reviewer, dimension, cap, reason }) =>
      console.log(`  - ${reviewer} / ${dimension} -> ${cap.toFixed(1)}  (${reason})`));
  }
  if (summary.claims_falsified > 0) {
    console.error('At least one claim was FALSIFIED. cr-battery score must be re-computed with the dimension caps above.');
    process.exit(1);
  }
  process.exit(0);
}

if (require.main === module) main();
module.exports = { verifyEnvelope, parseExpectation, replay, processClaims, truncate, FALSIFIED_CAP, UNVERIFIABLE_CAP };
