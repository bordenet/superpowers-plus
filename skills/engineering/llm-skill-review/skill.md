---
name: llm-skill-review
source: superpowers-plus
augment_menu: true
triggers:
  - /sp-llm-review
  - /sp-skill-review
  - review this superpower
  - review these skill changes
  - review this prompt infrastructure
  - review this agent tooling
  - review this installer
  - review this shell code for agents
  - review this for claude augment cursor
  - harsh code review for skills
  - review skill file
  - before pushing skill changes
aliases: [agent-runtime-review, superpowers-skill-review]
anti_triggers:
  - quick feedback
  - typo pass
  - summarize this diff
  - design brainstorming
  - user-facing product UX review
description: "Primary, default reviewer for ANY skill.md file or skill-adjacent tooling infrastructure -- covers both LLM-execution safety (determinism, shell portability, tool contracts, cross-agent compatibility) and prose/design quality (correctness, simplicity, blind spots, verifiability, operational risk, folded in from progressive-harsh-review) in one pass. Reviews superpower skills, shell tooling, installers, MCP/tool contracts, and agent-specific integration files as infrastructure consumed by frontier models, not as ordinary production code or human-facing prose alone."
summary: "Use for skills, prompts, shell scripts, tool wrappers, install/setup code, and agent-runtime infrastructure. Default to this skill -- instead of progressive-harsh-review or code-review-battery -- for any skill.md or skill-adjacent change."
coordination:
  group: code-quality
  order: 1
  requires: ["progressive-harsh-review"]
  enables: ["think-twice"]
  escalates_to: ["code-review-battery", "progressive-harsh-review"]
  internal: false
composition:
  consumes: [git-diff, skill-files, shell-scripts, tool-config, test-results]
  produces: [review-feedback]
  capabilities: [reviews-agent-infrastructure, gates-llm-runtime-quality]
  priority: 40
---

# LLM Skill Review

> **Mechanical routing:** don't decide from memory or from the "Wrong skill?" prose below -- run `tools/review.sh route <path> [<path> ...]` first (paths of the files you're about to review). It wraps `tools/which-gate.sh` and prints the correct skill + sentinel + runner for each artifact. If the router says a different skill, follow the router, not this banner. If the router errors or is unavailable, stop and report -- do not fall back to the prose. The banner is an inner backstop, not a substitute for the mechanical check.
>
> **Purpose:** The primary, default reviewer for ANY skill.md file or skill-adjacent tooling -- covers both LLM-execution safety and prose/design quality in one pass, so a skill review no longer needs a separate `progressive-harsh-review` pass to also judge whether it is a well-written, sensible artifact for a human.
>
> **Wrong skill?** Use `progressive-harsh-review` instead only for non-skill artifacts -- plans, specs, designs, general documents. Conventional code PR review -> `code-review-battery` (skill/tooling-infrastructure changes should still redirect here first). Quick code comments -> `providing-code-review`.

**Announce at start:** "I'm using the **llm-skill-review** skill to review this as LLM-execution infrastructure, not ordinary app code."

## Companion Skills

- **progressive-harsh-review**: Reviews non-skill deliverables (plans, specs, designs, documents) with the same adversarial rigor; this skill absorbed its skill-review responsibility (see Prose/Design Quality Axes below)
- **code-review-battery**: Conventional code PR review; escalate here for ordinary application-code changes bundled alongside skill/tooling changes
- **skill-health-check**: Structural lint (frontmatter validity, line budget) -- run before this skill, not instead of it; use **think-twice** (fresh-perspective sub-agent) if this review gets stuck in a circular loop
- **superpowers-doctor**: Runtime/ecosystem diagnostics (trigger collisions, orphaned installs) after this skill's review passes

## When to Use

**This is the default reviewer for skill.md files and skill-adjacent tooling** -- invoke it instead of `progressive-harsh-review` or `code-review-battery` for these, not alongside them as a third opinion.

**Invoke automatically when changes touch any of these areas:**
- `skills/**`, `tools/**`, `scripts/**`, `setup/**`, `mcp/**`
- `install.sh`, `install-*.sh`, `uninstall.sh`
- `.ai-guidance/**` (AGENTS.md overflow -- same audience, just split out on a line-count limit)
- `AGENTS.md`, `CLAUDE.md`, `CODEX.md`, `COPILOT.md`, `GEMINI.md`, `AGENT.md`, at any path depth (see `tools/md-files-changed.sh`'s `LLM_OWNED_REGEX` for the single source of truth on this boundary)
- plugin manifests, routing files, hook specs, or agent-specific configuration

**Also invoke when the user asks for:** harsh review of skills, prompts, shell tooling, installers, or agent infrastructure; review for Claude Code/Augment Code/Cursor compatibility; review for prompt/runtime determinism; review of MCP or tool-calling behavior; review before pushing skill changes.

**Do NOT use as the primary skill for:** pure product UX review; ordinary application code with no skill/tooling/runtime implications; early brainstorming before artifacts exist; non-skill plans/specs/designs/documents (use `progressive-harsh-review`).

## Review Doctrine and Heuristics

Reviews for the failure modes frontier models actually exhibit: ambiguity under constrained context, partial tool availability, over-eager completion claims, silent fallback behavior, environment coupling, poor shell portability, instruction drift under summarization/compaction, token bloat hiding critical constraints. Assume anything ambiguous will be misread by at least one model, anything relying on human intuition will fail under automation, and any unstated default will vary across agents.

Apply these heuristics aggressively: Ambiguity is a bug. Silent fallback is a bug. Undocumented assumptions are bugs. Human-obvious is not model-obvious. Works on one machine is failing portability. Passes once is not idempotent. Readable is not executable. Comprehensive is not token-efficient.

Default stance: **REJECT** unless the implementation is clearly safe for repeated LLM execution.

## Primary Review Axes

Score each axis from 0.0 to 10.0 and justify with evidence:

| Axis | What to evaluate |
|---|---|
| Determinism | Whether repeated runs by different frontier models are likely to produce the same action sequence and result |
| Instruction clarity | Whether the prompt/skill says exactly what to do, in what order, with what stop conditions |
| Shell portability | Whether shell code works reliably across supported environments and avoids GNU/BSD/zsh/bash traps |
| Tool contract safety | Whether tool use is explicit, validated, parseable, and safe under failure |
| Failure handling | Whether errors, partial success, retries, and stop/report behavior are clearly defined |
| Idempotency | Whether reruns avoid duplicating state, corrupting config, or masking partial prior runs |
| Cross-agent compatibility | Whether the change works across Claude Code, Augment Code, and Cursor without hidden assumptions |
| Context efficiency | Whether critical requirements are short, front-loaded, and robust under summarization |
| Test adequacy | Whether tests validate realistic agent/runtime failure modes |
| Operational maintainability | Whether humans can debug, repair, and evolve the behavior without guessing |

## Prose/Design Quality Axes (absorbed from progressive-harsh-review)

A skill.md review must also judge whether it is a well-written, sensible artifact for a human -- not just whether an LLM can execute it safely. Score these five axes (0.0-10.0) by running Persona 6 as PHR's actual three-sub-persona ensemble (see Specialist Personas below), using `progressive-harsh-review`'s own per-persona weights, aggregation rule, and critical-veto rule verbatim -- see that skill's **"The Three Personas"** section (NOT "Step 1: Dispatch Review," which is only the generic fallback table used when a persona has no explicit weight definition -- citing the fallback table here was a round-2 self-review defect, fixed):

| Axis | What to evaluate |
|---|---|
| Correctness | Does the skill do what it claims? Internal contradictions, false assertions, broken cross-references? |
| Simplicity | Is this the simplest way to express the workflow? Redundant sections, over-qualification, repeated heuristics? |
| Verifiability | Can each instruction or claim be independently checked against the repo/skill ecosystem? |
| Blind Spots | What scenarios, edge cases, or artifact types does the skill fail to address? |
| Operational Risk | What breaks the skill under adverse conditions -- wrong trigger match, absent dependency, misuse, trigger collision with a sibling skill? |

**Aggregation:** each of the three sub-personas scores all five axes using its OWN per-persona weights (never a shared/averaged weight set), then the three weighted scores are averaged with equal weight -- PHR's Step 2 rule, not re-derived here.

**Critical veto (verbatim from progressive-harsh-review):** if ANY sub-persona scores Correctness or Operational Risk <=4 AND cites a specific defect (not a general concern), that is an automatic REJECT regardless of the weighted mean. An unrecoverable-failure-style finding MUST be scored on Operational Risk -- not Blind Spots alone -- to be veto-eligible; scoring it only on Blind Spots bypasses the veto gate.

**Combining both scorecards into one top-level Verdict** (the gap a round-2 self-review found: two scorecards with no rule for merging them into one Verdict): use the WORSE of what either implies, never an average.
- **LLM-Execution critical veto:** any unresolved S0 finding forces **REJECT** regardless of both scorecards' means -- an execution-safety finding this severe is never merely "at least MAJOR REVISIONS REQUIRED" (design-critic dogfood finding, 2026-07-17: an earlier draft referenced "either scorecard's critical veto" before this one existed, then contradicted it by capping S0 in the fallback bullet below).
- Prose/Design's own critical veto (above) fires -> **REJECT**.
- Prose/Design weighted mean <7 (PHR's REJECT band) -> at least **MAJOR REVISIONS REQUIRED**, regardless of S0-S3 findings.
- Prose/Design weighted mean 7 to <8 (PHR's PASS_WITH_FIXES band) -> at least **PASS WITH RISKS**.
- Otherwise, follow the worse of: highest unresolved severity (S1 present -> at least MAJOR REVISIONS REQUIRED; S2 only -> at least PASS WITH RISKS; S3-only/none -> PASS eligible) and the Prose/Design band above.

## Specialist Personas

Run these in parallel if tooling allows (e.g. `Task()`-based parallel sub-agent dispatch, as `code-review-battery` already documents). Full start-points and questions for each are in `reference.md` -- load it before dispatching.

| # | Persona | Focus |
|---|---------|-------|
| 1 | Runtime Determinist | Instruction ordering, trigger precision, hidden branching, stop conditions |
| 2 | Shell Portability Auditor | Shell scripts, installers, hooks, quoting, environment assumptions -- be extremely picky |
| 3 | Tool Contract Guardian | MCP/tool wiring, argument discipline, validation before side effects |
| 4 | Cross-Agent Compatibility Critic | Claude/Augment/Cursor differences, hook semantics, file placement |
| 5 | Context Efficiency Examiner | Token pressure, duplication, buried constraints, compaction resilience |
| 6 | Prose/Design Critic ensemble (3 sub-personas, from `progressive-harsh-review`) | The five Prose/Design Quality Axes above, run as PHR's real 3-persona ensemble (Nitpicker/ArchCritic/OpsRealist, see reference.md), plus skill-file specifics: unique triggers, valid YAML, no broken cross-references, correct coordination fields, effective anti-triggers, populated Failure Modes table |

## Mandatory Checks

You MUST inspect these six areas and report concrete findings -- full flag lists for each are in `reference.md`. If a category has no applicable content in the artifact under review (e.g., no shell/tool-wrapper code in a pure-prompt skill), state that explicitly -- "N/A -- no shell/tool-wrapper content in this artifact" -- rather than fabricating a finding or silently omitting the section.

- **A. Instruction Determinism** -- vague verbs, ambiguous trigger/routing precedence, missing pass/fail thresholds
- **B. Shell and Runtime Portability** -- bashisms, GNU/BSD incompatibilities, unsafe quoting, fragile paths, weak cleanup. Embedded fenced examples in the skill.md/reference.md itself are in scope too -- run `tools/fence-scan.sh <changed .md file>` (see `reference.md` for why this matters and its known limitation).
- **C. Tool Contract Safety** -- implicit tool selection, under-specified parameters, unparseable output, unvalidated side effects
- **D. Failure-Mode Resilience** -- missing stop-and-report rules, looping retries, asserted-not-verified success
- **E. Cross-Agent Interoperability** -- Claude-only behavior assumed universal, unequal Cursor/Augment support
- **F. Test Realism** -- string-grep-only tests, no idempotency/absent-tool/adversarial coverage

## Diff-Sensitive Focus Map

Apply extra scrutiny based on changed paths:

- `skills/**` -> trigger precision, output format, token cost, invariants, routing clarity
- `tools/**`, `mcp/**` -> argument validation, parseability, safety boundaries, failure semantics
- `install*.sh`, `setup/**`, `scripts/**` -> portability, idempotency, cleanup, environment assumptions
- `.ai-guidance/**` -> same scrutiny as `AGENTS.md` itself (it's AGENTS.md content split out on a line-count limit, not a different audience)
- `AGENTS.md`, `CLAUDE.md`, `CODEX.md`, `COPILOT.md`, `GEMINI.md`, `AGENT.md` (any path depth), manifests -> cross-agent drift and unsupported universal claims
- `tests/**` -> realism of execution-path coverage, not just assertion count

## Required Output Format

Produce these sections in order.

### Verdict

Choose one:
- REJECT
- MAJOR REVISIONS REQUIRED
- PASS WITH RISKS
- PASS

Default to REJECT unless clearly proven otherwise.

### Executive Risk Summary

2-5 bullets, highest risk first.

### Findings by Severity

Use these levels exactly:
- **S0 Critical**: likely to cause destructive, dangerous, or silently wrong agent behavior
- **S1 High**: likely to cause frequent execution failure, wrong tool use, portability breakage, or broken install/setup
- **S2 Medium**: likely to reduce determinism, clarity, or maintainability
- **S3 Low**: polish or optimization issue with some execution relevance

For each finding include:
1. Severity
2. Title
3. Why this matters for LLM execution
4. Concrete evidence
5. Likely failure mode
6. Exact recommendation
7. An `evidence` block per the Evidence Requirement below

### Evidence Requirement (MANDATORY)

A finding is a claim about the artifact. A claim without a way to check it is indistinguishable from a guess, and a high verdict built on unchecked claims is worse than no review at all -- it looks rigorous while catching nothing. Every finding AND every clean-dimension verdict ("no issues found in X") MUST carry a JSON `evidence` block (schema, worked example, expectation types, and forbidden command patterns: see `reference.md` -> "Evidence Schema"). A finding or clean-dimension verdict with no `evidence` block at all is treated identically to `"verifiable": false` -- capped, not rejected, but never counted as confirmed.

### LLM-Execution Scorecard

List every primary review axis with score and evidence.

### Prose/Design Quality Scorecard

List every Prose/Design Quality axis with score and evidence, per the veto rule above.

### Top 3 Fixes Before Merge

Name the three changes with the highest risk-reduction value.

### What I Would Test Next

List the next test scenarios that should run before merge.

## Reviewer Conduct

- Be tough, terse, and specific.
- Do not praise unless it clearly reduces execution risk.
- Do not spend time on style commentary unless it affects agent behavior.
- Do not call something safe because it is elegant.
- Prefer explicit evidence from the diff or repository state.
- If no diff is provided, inspect the effective implementation and infer the real behavior from the files.

## Failure Modes

| Failure | Fix |
|---------|-----|
| Reviewer fabricates a Shell/Tool Contract finding on a pure-prompt skill with no shell/tool code | State "N/A" explicitly per the Mandatory Checks instruction -- never invent a finding to fill a section |
| Trigger-collision check skipped | Grep every sibling `skill.md`'s `triggers`/`aliases` for exact-string overlap before approving frontmatter -- this is mechanical, not judgment-based |
| Self-reviewed in the same thinking pass as authoring | Use a sub-agent (preferred), matching `progressive-harsh-review`'s "Author != Reviewer" hard gate |
| Both Prose/Design and LLM-execution scorecards skipped in the same pass | Both are mandatory for any skill.md -- this skill replaces two separate passes, not one |
| Verdict asserted without both scorecards shown | Required Output Format lists both scorecards in order; a verdict with neither is not a valid report |
| A clean-dimension verdict ("no issues found") ships with no evidence block | Treated identically to `verifiable: false` -- capped, not confirmed. A sentence asserting cleanliness is not evidence of it; see Evidence Requirement |
| Embedded `bash`/`sh` example in the skill.md itself never actually run through `bash -n` | Prose review alone cannot catch this -- run `tools/fence-scan.sh <file>` before asserting the doc's own examples are clean |

## Enforcement Status

`tools/pre-push`'s Gate 6 (`tools/pre-push-llm-skill-review-gate.sh`) requires `.llm-skill-review-cleared` for any push touching `skills/*.md`, `.ai-guidance/*.md`, or an AGENTS.md-family file (`AGENTS.md`, `CLAUDE.md`, `GEMINI.md`, `CODEX.md`, `COPILOT.md`, `AGENT.md`, at any path depth), and **supersedes** -- not supplements -- the PHR and code-review gates for those file classes (both explicitly exclude them; see each gate's own header, and `tools/md-files-changed.sh`'s `LLM_OWNED_REGEX` for the single-source-of-truth boundary). A push touching only these files therefore needs exactly one review, not two or three redundant ones (a push touching other file classes too still needs their own gates). `tools/run-phr.sh`/`tools/run-battery.sh` are pure sentinel-writers; the combined score from this skill's own scorecards (see "Combining both scorecards" above) is the `--min-score` fed to `tools/run-llm-skill-review.sh`. See reference.md's "Enforcement Detail" for the envelope format. Non-`.md` files under `skills/` (scripts, config) are still code-review's job, not this gate's -- it owns skill *prose* and the other LLM-instruction file classes above.

## Final Reminder

These artifacts are not consumed primarily by humans. They are consumed by LLMs acting under uncertainty.
Review accordingly.
