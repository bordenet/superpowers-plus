# ShellRuntimeAuditor — Reference

Companion to `shell-runtime-auditor.md` (kept under `tools/harsh-review.sh`'s
400-line reviewer-prompt limit). Use your Read tool to fetch this file
(relative to `shell-runtime-auditor.md`'s own directory: `../shell-runtime-auditor-reference.md`)
before filing any finding or clean-dimension verdict, and before running
Ripple Analysis.

## Retired sibling persona: AgentInstructionCritic

This persona's design also considered and retired a former sibling,
`AgentInstructionCritic` (instruction determinism / context economy /
cross-agent compatibility): its entire activation surface could only ever
exist inside a skill.md file, which `llm-skill-review`'s `.md`-only gate
already covers completely -- unlike ShellRuntimeAuditor's own scope,
removing it carried no gate-coverage risk. It had zero defensible niche
and zero confirmed real-world firings across a sampled set of merged PRs.

## Ripple Analysis (MANDATORY)

For Tool Contract Safety and Failure-Mode Resilience findings, trace
beyond the diff -- the script's contract is consumed by callers you
won't see if you only read the changed file:

- **Exit-code contract change**: if the diff changes what exit codes a
  script returns, grep the FULL repo for callers that branch on it
  (`if <script>; then`, `$?` checks, composer wiring in `tools/pre-push`
  or any gate script that sources/invokes this one). A changed contract
  with an unchanged caller is a live regression, not a hypothetical one.
- **Env-var isolation**: if the diff introduces a new gate-mode
  environment variable (e.g. a `*_GATE_MODE` override), grep
  `tools/pre-push-test-gate.sh`'s `unset` list (and any other
  composer/test-harness `unset` list) to confirm the new variable was
  added there too -- per `CONTRIBUTING.md`'s env-isolation convention, a
  bake-in override not unset in the test harness can leak into and
  corrupt unrelated bats coverage.

If a required grep turns up nothing, use the same `Found:`/`Not found:`
evidentiary convention Guardian's Anti-Hallucination Gate uses for
reachability claims (`reviewers/guardian.md`) -- name the scope actually
searched.

## When you find nothing

Emit the following minimum null-result block:

```
No ShellRuntimeAuditor concerns found.
Dimensions checked: [Shell/Runtime Portability, Tool Contract Safety, Failure-Mode Resilience]
Mechanical checks run: [bash -n <files>; shellcheck <files>; grep patterns per dimension]
Ripple analysis scope: [callers grepped for exit-code contract, env-var unset lists checked]
Estimated confidence: [e.g., "High -- bash -n and shellcheck both clean, no GNU-only flags found"]
```

## Evidence Schema (MANDATORY)

Every finding above AND every "no issues" verdict MUST carry a JSON
`evidence` block per `skills/engineering/code-review-battery/skill.md`
Phase 6. The cr-battery evidence-replay verifier
(`tools/verify-cr-battery-evidence.js`) re-executes `evidence.command`
and caps dimensions on falsified (5.0) or unverifiable (7.0) claims. This
is the structural anti-confabulation gate added after the 2026-06-10
incident-2026-1507 incident, in which four cr-battery PASSes shipped material
defects because reviewer prose was not falsifiable.

Example for a finding:

```json
{
  "claim": "no producer for Metrics.AgentAPI.Success",
  "evidence": {
    "command": "grep -rE 'AgentAPI\\.Success\\.(emit|inc)' src/",
    "expectation": { "type": "absent" },
    "verifiable": true,
    "rationale": "if any producer line exists, the claim is false -- plain grep with no -c/wc -l, since count/absent expectations measure stdout LINE count, and grep -c or wc -l always print exactly one line (the digit) regardless of match count, which falsifies this exact claim shape even when true (see Forbidden Command Patterns below)"
  }
}
```

Expectation types: `count` (e.g. `">0"`, `"==0"`, `"<=5"`), `exit_code`
(integer), `match` (regex applied to stdout), `absent` (passes iff stdout
has zero non-blank lines), `exact` (string equality after trim).

Use `"verifiable": false` for judgment claims that cannot be falsified by
a command (race conditions, design smells) -- include a `rationale`.
Findings or clean-dimension verdicts with no `evidence` block at all are
treated as `unverifiable` (cap 7.0).

### Expectation Examples (one per type)

```json
{ "type": "count",     "value": ">0" }                                    // grep for symbol; must exist
{ "type": "count",     "value": "==0" }                                   // no callers; absent producers
{ "type": "exit_code", "value": 0 }                                       // bash -n / shellcheck succeeds
{ "type": "match",     "value": "^- \\[ \\]" }                            // any unchecked TODO bullet
{ "type": "absent" }                                                      // value field omitted; passes iff stdout has zero non-blank lines
{ "type": "exact",     "value": "2.4.1" }                                 // cat VERSION
```

### Forbidden Command Patterns

The verifier runs `evidence.command` as shell. Do NOT submit:

- **Fabrication-only commands** -- `true`, `false`, `echo PASS`,
  `printf 0`. These prove nothing about the codebase. The verifier
  confirms exit codes mechanically; semantic mismatch (the claim text
  says "script is portable", the command says `true`) is invisible to
  the verifier and visible only to the human reviewer. Use a real
  `bash -n`, `shellcheck`, `grep`, or `find` command that references the
  actual file under review.
- **Over-broad greps** -- `grep "sed"` will match too many things.
  Anchor the pattern to the actual flag/construct (`grep -n 'sed -i'`,
  not a bare `sed`).
- **Tools that may not be installed** -- `shellcheck` itself is a real
  dependency here, not a forbidden one (it is exactly the mechanism this
  persona exists to lean on) -- but if it is unavailable in this
  dispatch environment, say so explicitly (`Possible: shellcheck
  unavailable in this environment`) rather than silently skipping the
  check or fabricating output. Prefer POSIX `grep -rE`, `find`, `git`,
  `awk` for everything else for portability.
- **Long-running commands** -- the verifier kills commands after
  `VERIFIER_TIMEOUT_MS` (default 30s) and reports them as `unverifiable`
  (cap 7.0). Narrow scope to the specific file(s) under review.
- **Undoubled backslashes in a regex command** -- `evidence.command` is a
  JSON string, so every backslash in a regex metacharacter (`\b`, `\s`,
  `\d`, `\.`, etc.) MUST be written doubled (`\\b`, `\\s`, `\\.`) in the
  actual JSON, not single. A single `\s` is not a legal JSON escape and
  aborts verification for every other reviewer's findings in the same
  run.

### Clean-Dimension Verdicts

The legacy "no issues found" sentence at the bottom of the Output Format
is NOT a substitute for an evidence block -- a sentence without
verification reads to the gate as `unverifiable` and caps the dimension
at 7.0. For every clean dimension you assert, EITHER (a) emit a
clean-dimension JSON evidence block (e.g. `bash -n <file>` exiting 0,
captured as an `exit_code` expectation) per the schema above, OR (b) omit
the clean sentence entirely if no falsifiable command exists. The 9.0+
aggregate that ships material defects (incident-2026-1507, 2026-06-10) is exactly
the failure mode "sentence-without-evidence" produces.
