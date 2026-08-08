# Tiered Model Dispatch (Opus Analysis -> Sonnet Execution)

**Reference file, no triggers, no frontmatter. Load explicitly when qualifying a skill for this pattern.**

**How to load:** `references/tiered-model-dispatch.md`, relative to this skill's own directory. Load explicitly; it is not included by default.

**This is a SEQUENTIAL pattern** (high-tier analysis, then low-tier execution). It is not a form of parallel dispatch. It lives alongside `dispatching-parallel-agents` because tiered dispatch IS a dispatch strategy, but the two agents run in series, not concurrently.

Cross-reference: `dispatching-parallel-agents/skill.md` for general parallel dispatch mechanics.

---

## WHEN NOT TO USE, READ THIS FIRST

This pattern **increases cost 4 to 5x** when applied outside its narrow qualifying window. The foot-gun table below covers every known misapplication. If any row matches your situation, use Sonnet end-to-end.

| Condition | Why it makes things worse |
|-----------|--------------------------|
| Analysis phase is <=50K tokens | Opus premium not recovered by fewer retries; net loss |
| Analysis is not judgment-intensive | Sonnet reaches same quality; 4 to 5x Opus cost is pure waste |
| Full-skill baseline is Haiku | Tiering to Opus+Sonnet is an increase on **both** tiers |
| Full-skill baseline is already Opus | Added complexity, zero cost change |
| Skill is new with no baseline data | May add Opus to a task Sonnet handles fine; no savings to measure |
| Analysis is trivial (lookup, schema check, format validation) | Sonnet correct >=99% of the time; Opus adds nothing |
| Platform does not support per-dispatch model selection | Cannot implement; pattern is inapplicable |

**Default: Sonnet end-to-end.** This pattern is an opt-in exception, not a best practice.

---

## Qualifying Conditions (Binary Checklist)

ALL five must be YES. One NO, use Sonnet end-to-end, full stop.

- [ ] **A. Prior evidence of Sonnet misses.** There is documented evidence (not assumption) that Sonnet misses semantic or behavioral errors in this exact task type. Prior runs, incident logs, or known failure modes count. Intuition does not.
- [ ] **B. Analysis phase is large.** >=100K tokens in the analysis pass, OR the skill has historically required 2+ Sonnet passes to complete correctly.
- [ ] **C. Execution phase is purely mechanical.** Fixed sequence, no editorial choices, hard preflight gates that catch agent mistakes before any destructive write occurs. Negative examples (NOT purely mechanical): choosing between output formats based on content; deciding which records are in scope; resolving ambiguity in what to write. If the execution agent needs to make any judgment call, this condition is NO.
- [ ] **D. Baseline is Sonnet end-to-end.** The model being replaced in the analysis role is specifically Sonnet. If the baseline is Haiku, the calculation changes entirely. If the baseline is already Opus, there is nothing to save.
- [ ] **E. Platform supports per-dispatch model selection.** You MUST verify this before proceeding, do not assume it exists. Augment Code: confirm `sub-agent-general-purpose` accepts a model-tier argument on your version (this feature may not be available). Claude Code: confirm `Task()` accepts a `model` parameter. If the feature cannot be confirmed, this condition is NO, use Sonnet end-to-end.

---

## Evidence Base

**Run:** a bulk Linear label-reconciliation task, 2026-07-23

| Phase | Model | Tokens | Passes | Outcome |
|-------|-------|--------|--------|---------|
| Analysis | Opus | ~175K | 1 | Caught execution-safety bug (see below) |
| Execution | Sonnet | ~250K | 2 | Fetch / snapshot / preflight / write / verify, no editorial judgment |

**What Opus caught that mattered:** Linear's `save_issue` replaces the **entire** label set, not appending. Sonnet, in a previous session running a comparable bulk label-reconciliation task, treated it as a safe append. This is a silent destructive operation: a single misapplied call would have wiped existing labels across all reviewed issues. Opus identified the behavioral contract from the API docs during analysis and added a preflight gate before Sonnet's execution phase began.

**Why it was net-positive:** The analysis phase qualified under all five conditions. Execution was a fixed read to snapshot to preflight to write to verify sequence with no judgment required. One Opus pass replaced what had been two Sonnet passes on similar tasks; the Opus premium was recovered.

**This evidence does NOT generalize automatically.** Savings come from this specific failure mode (silent destructive API behavior) in this specific task class (bulk wiki/issue updates via APIs with non-obvious write semantics). Other task types require their own measurement.

---

## Implementation Pattern

Pseudocode for wiring tiered dispatch inside a SKILL.md:

```
# Phase 1: Dispatch high-tier sub-agent for analysis ONLY (no writes)
ANALYSIS_OUTPUT = dispatch_subagent(
  model = "high-tier (e.g. Opus)",
  task = """
    Analyze [corpus/diff/config] for semantic and behavioral errors.
    Produce structured output:
      - findings: [{severity, description, evidence, required_preflight_gate}]
      - safe_to_proceed: boolean
      - execution_plan: ordered list of mechanical steps
    Do NOT execute writes. Do NOT call mutating APIs.
  """
)

IF ANALYSIS_OUTPUT.safe_to_proceed == false:
  HALT and surface ANALYSIS_OUTPUT.findings to user

# Validate schema before passing to Sonnet (REQUIRED, do not skip)
REQUIRED_FIELDS = ["safe_to_proceed", "findings", "execution_plan"]
FOR field IN REQUIRED_FIELDS:
  IF field absent OR malformed in ANALYSIS_OUTPUT:
    HALT: "Opus output schema invalid: [missing/malformed fields]"

# Phase 2: Dispatch low-tier sub-agent for mechanical execution
EXECUTION_RESULT = dispatch_subagent(
  model = "low-tier (e.g. Sonnet)",
  task = """
    Execute the following plan. Each step is mechanical, no editorial judgment.
    Hard preflight gates are mandatory before any write.
    Plan: [ANALYSIS_OUTPUT.execution_plan verbatim]
    Avoid: [ANALYSIS_OUTPUT.findings verbatim]
  """
)
```

**Schema validation (required before Sonnet dispatch):**

Validate ANALYSIS_OUTPUT before passing to Sonnet. Required fields: `safe_to_proceed` (boolean), `findings` (list), `execution_plan` (list). If any required field is absent or malformed: HALT and surface "Opus output schema invalid: [missing/malformed fields]". Do NOT pass broken output to Sonnet.

**Critical constraints on the Opus prompt:**
- Forbid writes explicitly: "Do NOT call mutating APIs"
- Define the structured output schema in the prompt, do not let Opus invent it
- Pass `execution_plan` and `findings` verbatim into the Sonnet prompt, never summarize
- Sonnet executes what Opus produced; it does not re-derive the plan

**Platform invocation (confirm model-tier arg availability before using):**

Augment Code: `dispatch_subagent(tool="sub-agent-general-purpose", model="opus", instruction="...")` for analysis; same with `model="sonnet"` for execution. If the `model` argument is not accepted, Condition E is NO.

Claude Code: `Task("...", model="claude-opus-4-8")` for analysis; `Task("...", model="claude-sonnet-5")` for execution. Confirm the `model` param is available on your Claude Code version first, and substitute whatever the current Opus/Sonnet tier names are at the time; this pairing will drift as new models ship.

**Latency:** Opus is approximately 2 to 4x slower than Sonnet wall-clock. Record latency in Step 3 of the measurement protocol and note it in Known Applications. A 25% cost reduction that doubles latency may be net-negative for the use case.

---

## Known Applications

*None confirmed yet. Phase 2 measurement is required before any skill is listed here.*

<!-- Add entries here only after completing the measurement protocol below.
     Format per entry:
       - **Skill:** `skill-name`
       - **Date confirmed:** YYYY-MM-DD
       - **Cost reduction:** X% (dollar cost: Opus+Sonnet vs. Sonnet-only baseline, same input, accounting for Opus/Sonnet price differential)
       - **Latency impact:** X% increase/decrease in wall-clock time
       - **What Opus caught:** one sentence
       - **Evidence:** session ID or link
-->

---

## How to Add a New Application

Complete ALL steps before adding a skill to Known Applications:

1. **Confirm all five qualifying conditions are YES.** If any is NO, stop.
2. **Establish a Sonnet-only baseline.** Run the full skill with Sonnet end-to-end on a representative input. Record: total tokens (input + output), pass count, errors/retries, wall-clock time. **Side-effect warning:** If the skill writes to Linear, Outline, databases, or any live system, run the baseline on a staging environment or with writes dry-run'd. Do NOT run identical live input twice; the second run may double-write or operate on state left by the first.
3. **Run tiered dispatch on identical input.** Same corpus, same platform. Apply the same staging/dry-run precaution. Record: Opus tokens (analysis), Sonnet tokens (execution), total passes, errors, wall-clock time.
4. **Measure net cost change.** Must be >=20% reduction in total dollar cost (tokens x price per token, using current Opus and Sonnet pricing). Token count alone is insufficient; Opus tokens cost 4 to 5x more than Sonnet tokens. Below 20% cost reduction: do not add, pattern is not net-positive for this task type. Also record latency change (wall-clock Step 3 vs Step 2).
5. **Document what Opus caught.** State specifically what Opus identified that mattered and would have been missed or required a retry under Sonnet-only. If Opus caught nothing actionable, the skill does not qualify even if cost math works.
6. **Check for Linear or similar API write semantics.** If the skill calls any API that sets a field collection (labels, assignees, cycles, tags), verify whether the write is append or replace-all. `save_issue` in Linear replaces the entire label set. Treat any replace-all write as a high-risk preflight gate step.
7. **Add the entry** using the comment template in Known Applications. Include the cost reduction %, latency impact, and an auditable evidence link.
8. **Re-measure after 5 runs.** Single-run results are noisy. Confirm reduction holds across >=5 runs before treating the application as stable. Use varied but representative inputs for each run, OR repeat on staging/dry-run only. The Step 2 prohibition on identical live input applies equally here.

---

## Phased Introduction Status

| Phase | Status | Gate |
|-------|--------|------|
| 1, Reference doc only | Complete | This file; no existing skills changed |
| 2, One instrumented application | Not started | >=20% cost reduction measured on >=1 skill |
| 3, Two more applications | Blocked on Phase 2 | 2/3 must show >=20% reduction, else mark "narrow edge case" |
| 4, Pointer in skill-authoring | Blocked on Phase 3 | One sentence only; no promotion until Phase 3 succeeds |
