# LLM Skill Review — Reference

Companion to `skill.md` (kept under the 250-line structural limit per `skill-health-check`). Load this file when actually dispatching the Specialist Personas or applying the Mandatory Checks in full detail — `skill.md` only summarizes them.

## Specialist Personas (full detail)

Run these in parallel if tooling allows (e.g. `Task()`-based parallel sub-agent dispatch, as `code-review-battery` already documents for its own reviewer roster). If not, emulate them sequentially while keeping their scoring separate.

### 1) Runtime Determinist

Focus: instruction ordering, trigger precision, hidden branching, stop conditions, ambiguous language, state preconditions.

Start from:
- skill triggers and anti-triggers
- ordered steps in `skill.md`
- any routing logic or command dispatch
- any text that tells the model to infer, decide, or continue

Questions:
- Would two strong models do the same thing here?
- Is precedence explicit when rules conflict?
- Are refusal/escalation paths defined?
- Are outputs constrained enough to be machine-usable?

### 2) Shell Portability Auditor

Focus: shell scripts, installers, hooks, path logic, process control, quoting, environment assumptions.

Start from:
- install/setup/uninstall scripts
- helper shell libraries
- hook scripts
- path-resolution and filesystem mutations

Questions:
- Is this explicitly bash, POSIX sh, or zsh, and is the code consistent with that?
- Are GNU/BSD differences accounted for?
- Are quoting, globbing, and word splitting safe?
- Does rerunning preserve a clean state?
- Does the script fail loudly and locally, not later and elsewhere?

**Be extremely picky.** Shell is part of the product surface.

### 3) Tool Contract Guardian

Focus: MCP/tool wiring, argument discipline, validation before side effects, parseability, fallback rules.

Start from:
- tool invocation instructions
- MCP config
- wrappers around tool-calling behavior
- prompt text that maps user intent to tools

Questions:
- Could a model choose the wrong tool and believe it succeeded?
- Are required arguments always explicit?
- Are destructive operations gated by validation?
- Does tool output have a structure the next model step can reliably consume?
- Are unavailable tools handled by safe degradation rather than unsafe improvisation?

### 4) Cross-Agent Compatibility Critic

Focus: Claude/Augment/Cursor differences, hook semantics, file placement, plugin assumptions, context windows, slash-command assumptions.

Start from:
- agent-specific docs and manifests
- routing/install destinations
- feature flags or platform conditionals
- any vendor-specific prompting assumptions

Questions:
- Is any agent-specific behavior incorrectly presented as universal?
- Are supported platforms materially equivalent, or only nominally supported?
- Are install paths and config conventions consistent across agents?
- Does the prompt style rely on one vendor's reasoning behavior?

### 5) Context Efficiency Examiner

Focus: token pressure, duplication, buried constraints, prompt sprawl, compaction resilience.

Start from:
- long skill files
- repeated guidance blocks
- nested checklists and examples
- required output formats

Questions:
- Are the most important invariants front-loaded?
- Could this survive summarization without losing safety?
- Is any prose ornamental when it should be algorithmic?
- Are there repeated instructions that should become a short rubric?

### 6) Prose/Design Critic ensemble (from progressive-harsh-review)

Run as PHR's actual three-persona ensemble, not a single pass -- a round-2 self-review found that collapsing this into one persona silently dropped PHR's ensemble/averaging/correlated-failure design, the exact "silent fallback" failure class this skill exists to catch in others. Each sub-persona scores all five Prose/Design Quality Axes (`skill.md`) using its OWN weights below; average the three weighted scores with equal weight afterward (PHR's Step 2 rule). Dimension definitions and weights are copied verbatim from `progressive-harsh-review`'s "The Three Personas" section to avoid re-deriving them out of sync with the source.

**6a) JuniorDevNitpicker (Surface Quality)** -- weights: Correctness 35%, Simplicity 25%, Blind Spots 20%, Verifiability 15%, Operational Risk 5%. Start from: line-by-line reading of the skill.md -- every heading, trigger, table entry, undefined term.

**6b) SeniorArchCritic (Structural Quality)** -- weights: Correctness 25%, Simplicity 15%, Verifiability 25%, Blind Spots 15%, Operational Risk 20%. Start from: promises made vs. evidence provided -- do coordination/escalation claims and companion-skill references hold when traced against the actual sibling skills on disk?

**6c) OpsRealist (Operational Quality)** -- weights: Correctness 25%, Simplicity 10%, Blind Spots 25%, Verifiability 10%, Operational Risk 30%. Start from: failure scenarios -- what happens if a trigger never fires, a step is skipped, or the skill collides with a sibling?

**Drift risk (design-critic dogfood finding, 2026-07-17):** the three weight sets above are hand-copied from `progressive-harsh-review`'s "The Three Personas" section, not read from it live -- if that section is ever renamed, restructured, or reweighted, these copies silently go stale. `coordination.requires` in `skill.md` names the dependency for the skill-router's dependency graph, but nothing mechanically re-verifies the numbers match. Before trusting a review that leans on this ensemble, diff these three lines against PHR's current "The Three Personas" section by hand; a durable fix would be a CI check comparing them automatically.

Skill-file-specific questions (all three sub-personas ask these, moved here from `progressive-harsh-review` -- that skill no longer reviews skill files): are triggers unique across the installed skill set, is the YAML frontmatter valid, are there broken cross-references, are coordination fields correct with no overlap with peer skills, do anti-triggers actually prevent false positives, is the Failure Modes table populated?

## Mandatory Checks (full flag lists)

`skill.md` lists these six categories; the concrete flags for each are here.

### A. Instruction Determinism

Flag any of the following:
- vague verbs like "handle", "manage", "appropriate", "careful", "robust", "ensure" without exact operational meaning
- multiple interpretations of trigger or routing behavior
- missing precedence between triggers, anti-triggers, and overrides
- instructions requiring common-sense inference instead of explicit rules
- scoring systems without pass/fail thresholds or merge thresholds
- prompts that say "review thoroughly" without enumerated dimensions

### B. Shell and Runtime Portability

**Fenced `bash`/`sh` code blocks embedded in the skill.md/reference.md itself are in scope too, not just standalone `.sh` files** -- an illustrative example that looks correct to a human reader can still be invalid shell (e.g. a bare `<file>` placeholder inside a fence tokenizes as `< file` followed by a dangling `>` redirect: a real, reproducible `bash -n` failure, not a hypothetical one). Run `tools/fence-scan.sh <changed .md file>` -- a mechanical, judgment-free `bash -n` (blocking) + ShellCheck (advisory) pass over every embedded fence -- before asserting a doc's examples are clean. Known limitation: this catches syntactic breakage only; a fence kept syntactically valid but made semantically wrong by a rewritten surrounding paragraph will not be caught.

Flag any of the following:
- bashisms without a guaranteed bash runtime
- zsh-only features in supposedly portable code
- GNU/BSD incompatibilities in `sed`, `grep`, `find`, `date`, `stat`, `readlink`, `xargs`, `mktemp`
- unsafe quoting, unquoted expansions, command substitution hazards
- reliance on current working directory or fragile relative paths
- hidden env vars or mutable PATH assumptions
- interactive behavior inside automation paths
- weak cleanup of temporary files or partially written state
- error handling that masks failures in pipelines or subshells

### C. Tool Contract Safety

Flag any of the following:
- tools selected by implication rather than explicit criteria
- under-specified required parameters
- output contracts that are hard for models to parse reliably
- dangerous side effects before validation
- fallback instructions that keep going after ambiguous failure
- mismatches between tool docs and prompt expectations

### D. Failure-Mode Resilience

Flag any of the following:
- missing stop-and-report rules
- retries that can loop or amplify damage
- state mutation before confirming prerequisites
- dependence on prior conversation state that compaction may erase
- success conditions that are asserted, not verified
- partial failure paths with no operator-visible remediation

### E. Cross-Agent Interoperability

Flag any of the following:
- Claude-only hooks or semantics assumed to apply everywhere
- Cursor or Augment support claimed without equivalent implementation detail
- undocumented differences in plugin/config destinations
- slash commands or invocation behavior that only one platform supports
- tool-calling assumptions that vary by vendor/model tier

### F. Test Realism

Flag any of the following:
- tests that only grep for strings instead of validating runtime behavior
- no tests for reruns and idempotency
- no tests for absent tools or partial installs
- no adversarial tests for ambiguous instructions
- no regression coverage for install/setup scripts
- no fixtures for cross-platform shell differences

## Evidence Schema

Full detail for the Evidence Requirement (`skill.md`) -- load this before dispatching if any reviewer will submit findings.

A finding is a claim about the artifact under review. A claim with no way to check it is indistinguishable from a guess, and a verdict built on unchecked claims is worse than no review at all: it looks rigorous while catching nothing. Every finding AND every clean-dimension verdict ("no issues found in X") MUST carry a JSON `evidence` block:

```json
{
  "claim": "no producer for the Metrics.AgentAPI.Success counter this diff references",
  "evidence": {
    "command": "grep -rE 'AgentAPI\\.Success\\.(emit|inc)' src/",
    "expectation": { "type": "count", "value": "==0" },
    "verifiable": true,
    "rationale": "if any producer line exists, the claim is false"
  }
}
```

### Expectation types (one per type)

```json
[
  { "type": "count",     "value": ">0",          "note": "grep for symbol; must exist" },
  { "type": "count",     "value": "==0",         "note": "no callers; absent producers" },
  { "type": "exit_code", "value": 0,             "note": "bash -n / shellcheck succeeds" },
  { "type": "match",     "value": "^- \\[ \\]",  "note": "any unchecked TODO bullet" },
  { "type": "absent",                            "note": "value omitted; passes iff stdout has zero non-blank lines" },
  { "type": "exact",     "value": "2.4.1",        "note": "cat VERSION" }
]
```

Use `"verifiable": false` for genuine judgment claims that cannot be re-executed deterministically -- race conditions, "a frontier model would misread this phrasing," design smells -- and include a `rationale`. These are real, valuable findings; mark them honestly rather than inventing a grep that doesn't actually test the claim. A finding or clean-dimension verdict with no `evidence` block at all is treated identically to `verifiable: false` -- capped, not rejected, but never counted as confirmed.

### Forbidden command patterns

Do not submit these as `evidence.command`:

- **Fabrication-only commands** -- `true`, `false`, `echo PASS`, `printf 0`. These prove nothing about the artifact; the exit code is mechanically checkable but a semantic mismatch between the claim text and the command (the claim says "no circular trigger dependency," the command says `true`) is invisible to anyone just checking the exit code.
- **Over-broad greps** -- `grep "verify"` matches far more than intended and will falsify a real finding on an unrelated hit. Anchor to the exact construct: `grep -n 'sed -i'`, not a bare `sed`.
- **Tools that may not be installed** -- prefer POSIX `grep -rE`, `find`, `git`, `awk`, `bash -n` for portability. `shellcheck` is a legitimate dependency for this skill specifically (it is exactly the mechanism Shell Portability Auditor leans on) -- but if it is unavailable in the dispatch environment, say so explicitly (`Possible: shellcheck unavailable in this environment`) rather than silently skipping the check or fabricating output.
- **A command that doesn't test the actual claim** -- a command that merely exits 0 is not the same as one that tests the assertion in the claim text. Writing some grep that happens to succeed is not evidence.
- **Long-running commands** -- narrow scope to the specific file(s) under review rather than an unbounded repo-wide scan; a command that never returns is unverifiable, not confirmed.
- **Undoubled backslashes in a regex command** -- `evidence.command` is a JSON string, so every backslash in a regex metacharacter (`\b`, `\s`, `\d`, `\.`, etc.) MUST be written doubled (`\\b`, `\\s`, `\\.`) in the actual JSON, not single. A single `\s` is not a legal JSON escape.
- **Piping a `count`-type command through anything that reports a count instead of emitting one line per match** (`| wc -l`, `grep -c`, `grep -rc`) -- the verifier's `count` type counts stdout *lines*, not a parsed number. `wc -l` and single-file `grep -c` always print exactly one line (the digit itself), so `count`/`==0` against either is **always falsified** even when the claim is true (stdout is always the one line `"0\n"`). Recursive `grep -rc` is a related but distinct trap: it prints one `file:count` line per file scanned, so its line count tracks the number of files, not the number of matches -- also never a reliable stand-in for "no matches anywhere." Use a command whose own line count IS the thing being measured (plain `grep -rE 'pattern' dir/` with no `-c`, one line per real match) with `count`, or switch to `{"type": "absent"}` for a pure existence check.
- **A `match`-type regex anchored with a trailing `$`** -- most commands (`echo`, most `grep`/`printf` invocations) leave a trailing newline in stdout, and JavaScript's `$` (without the `m` flag) matches end-of-string, not before that trailing newline. `"value": "^yes$"` against stdout `"yes\n"` is **falsified**, not verified. Either drop the trailing anchor (`"^yes"`) or account for it explicitly (`"^yes\\n?$"`).

### Why this exists

A review that ships a high verdict alongside material defects is worse than a review that ships a low verdict and gets re-run -- the first looks done and isn't. Prose assertions ("no issues found," "this is safe") are cheap to produce and easy to rubber-stamp under time pressure; a falsifiable claim forces the reviewer to actually run the check it describes, and forces anyone re-reading the review later to see exactly what was and wasn't verified, rather than trusting adjectives.

## Enforcement Detail

`tools/run-llm-skill-review.sh --verdict <verdict> --min-score <combined-score>` gives this skill's Evidence Requirement mechanical teeth, parallel to how `tools/run-battery.sh` already does evidence replay for `code-review-battery`. It requires a `.cr-battery-runs/<HEAD-sha>-llm-skill-review.json` envelope -- shape `{"findings": [...], "clean_dimensions": [...]}`, identical to the Evidence Schema above -- and replays every `evidence.command` in it via `tools/verify-cr-battery-evidence.js` (the same verifier code-review-battery uses, unmodified) before writing `.llm-skill-review-cleared`. A falsified claim aborts the write with no sentinel. `--no-envelope` bypasses the check with a loud warning; use it only when there is genuinely nothing to verify, not as a routine shortcut.

This is a **separate sentinel from `.phr-cleared`**, deliberately -- `tools/run-phr.sh` is also the sentinel-writer for plain progressive-harsh-review rounds on plans/designs that never produce an Evidence Schema envelope at all, so making it require one unconditionally would break that unrelated use case. `tools/pre-push` does **not** yet require `.llm-skill-review-cleared` for anything -- writing it today is additive discipline on top of the existing `.phr-cleared` requirement, not a replacement. Whether to make it a required pre-push gate (and whether that should supersede or supplement the PHR requirement specifically for skill.md/reference.md changes) is a deliberate, separate decision, not something this script assumes on its own.
