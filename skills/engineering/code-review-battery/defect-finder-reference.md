# DefectFinder — Evidence Schema Reference

Companion to `defect-finder.md` (kept under `tools/harsh-review.sh`'s
400-line reviewer-prompt limit). Load this file before filing any finding
or clean-dimension verdict — the Evidence Schema is MANDATORY, not optional.

## Evidence Schema (MANDATORY)

Every finding above AND every "no issues" verdict MUST carry a JSON `evidence` block per `skills/engineering/code-review-battery/skill.md` Phase 6. The cr-battery evidence-replay verifier (`tools/verify-cr-battery-evidence.js`) re-executes `evidence.command` and caps dimensions on falsified (5.0) or unverifiable (7.0) claims. This is the structural anti-confabulation gate added after the 2026-06-10 incident-2026-1507 incident, in which four cr-battery PASSes shipped material defects because reviewer prose was not falsifiable.

Example for a finding:

```json
{
  "claim": "no producer for Metrics.AgentAPI.Success",
  "evidence": {
    "command": "grep -rE 'AgentAPI\\.Success\\.(emit|inc)' src/",
    "expectation": { "type": "count", "value": "==0" },
    "verifiable": true,
    "rationale": "if any producer line exists, the claim is false"
  }
}
```

Expectation types: `count` (e.g. `">0"`, `"==0"`, `"<=5"`), `exit_code` (integer), `match` (regex applied to stdout), `absent` (passes iff stdout has zero non-blank lines), `exact` (string equality after trim).

Use `"verifiable": false` for judgment claims that cannot be falsified by a command (race conditions, design smells) -- include a `rationale`. Findings or clean-dimension verdicts with no `evidence` block at all are treated as `unverifiable` (cap 7.0).

### Expectation Examples (one per type)

```json
{ "type": "count",     "value": ">0" }                                    // grep for symbol; must exist
{ "type": "count",     "value": "==0" }                                   // no callers; absent producers
{ "type": "exit_code", "value": 0 }                                       // tsc --noEmit succeeds
{ "type": "match",     "value": "^- \\[ \\]" }                            // any unchecked TODO bullet
{ "type": "absent" }                                                      // value field omitted; passes iff stdout has zero non-blank lines
{ "type": "exact",     "value": "2.4.1" }                                 // cat VERSION
```

### Forbidden Command Patterns

The verifier runs `evidence.command` as shell. Do NOT submit:

- **Fabrication-only commands** -- `true`, `false`, `echo PASS`, `printf 0`. These prove nothing about the codebase. The verifier confirms exit codes mechanically; semantic mismatch (the claim text says "no SQL injection in 50k lines", the command says `true`) is invisible to the verifier and visible only to the human reviewer. Use a real grep/find/git/test command that references diff content or repo symbols.
- **Over-broad greps** -- `grep "Success"` will match too many things and falsify real findings. Anchor: `grep -rE '\bMetrics\.AgentAPI\.Success\.(emit|inc)\(' src/`.
- **Tools that may not be installed** -- `rg`, `jq`, `fd`, `ast-grep`, language-specific linters. Prefer POSIX `grep -rE`, `find`, `git`, `awk` for portability. If a non-portable tool is required, declare it in `evidence.rationale`.
- **Long-running commands** -- the verifier kills commands after `VERIFIER_TIMEOUT_MS` (default 30s) and reports them as `unverifiable` (cap 7.0). Narrow scope (e.g. `git diff --name-only main..HEAD` instead of `git log --all`).
- **Undoubled backslashes in a regex command** -- `evidence.command` is a JSON string, so every backslash in a regex metacharacter (`\b`, `\s`, `\d`, `\w`, `\.`, etc.) MUST be written doubled (`\\b`, `\\s`, `\\.`) in the actual JSON, not single. A single `\s` is not a legal JSON escape and fails to parse the ENTIRE envelope (not just this claim), aborting verification for every other reviewer's findings in the same run. Worse, a single `\b` IS a legal JSON escape -- but it means backspace (0x08), not a regex word boundary, and silently corrupts the pattern with no error at all (verified: the JSON string `"\bOrder\b"` parses to a 7-character value containing two backspace control-character bytes, not the intended anchored text). This bullet above (`\bMetrics\.AgentAPI\.Success\.(emit|inc)\(`) is written for markdown display, not as literal JSON -- if copying an example like it into an actual `evidence.command` string, double every backslash first.

### Clean-Dimension Verdicts

The legacy "✅ No issues found" sentence at the bottom of the Output Format is NOT a substitute for an evidence block -- a sentence without verification reads to the gate as `unverifiable` and caps the dimension at 7.0. For every clean dimension you assert, EITHER (a) emit a clean-dimension JSON evidence block per the schema above, OR (b) omit the clean sentence entirely if no falsifiable command exists. The 9.0+ aggregate that ships material defects (incident-2026-1507, 2026-06-10) is exactly the failure mode "sentence-without-evidence" produces.
