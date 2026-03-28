---
name: code-review-battery
description: Use when reviewing code changes to dispatch parallel specialized reviewers instead of a single monolithic review — provides deeper, more precise findings across 5 focused lenses
---

# Code Review Battery

Dispatch 5 specialized reviewer agents in parallel, each focused on a distinct set of review dimensions. A triage coordinator selects which reviewers to activate based on the diff, then aggregates findings into a unified report.

**Why this exists**: A single reviewer tries to evaluate everything simultaneously, leading to shallow coverage, inconsistent focus, and ~40% false positive rates. Specialized reviewers with focused prompts produce deeper analysis with near-zero false positives.

## When to Use

- When `requesting-code-review` or `progressive-code-review-gate` triggers a review
- When you want a thorough review of staged changes, a commit range, or a PR diff
- When reviewing someone else's code

## Procedure

### Step 1: Capture the diff AND source context
Run `git diff` (staged, commit range, or branch diff) and `git diff --stat`.

**Then gather ripple analysis context** (see `coordinator.md` Phase 2 — Diff + Source Context):
- For every field SET/RESET/NULLED in the diff: grep all readers of that field
- For every threshold comparison: grep all producers of values crossing it
- For stateful code: include full state type definition
- For changed signatures: include all callers

This source context is appended to each reviewer's instruction alongside the diff. Without it, reviewers miss cross-cutting regressions.

### Step 2: Triage

Read `coordinator.md` in this skill directory. Apply the triage decision rules to the diff:

| Change Type | Reviewers to Activate |
|------------|----------------------|
| Docs only (.md, .txt, comments) | Standards Enforcer only |
| Config/deps only (package.json, .yml) | Guardian only |
| Any code change | Defect Finder + Guardian + Standards Enforcer |
| Code adds/modifies classes, functions, APIs | + Design Critic |
| Code touches DB, loops, caching, >500 LOC | + Performance Analyst |

State your triage decision before dispatching.

### Step 3: Dispatch reviewers in parallel

Read the reviewer prompt from `reviewers/<name>.md`. Append the full diff to the prompt. Dispatch ALL activated reviewers simultaneously.

**On Augment.ai** — use `sub-agent-code-reviewer` with unique names (`battery-defect-finder`, `battery-guardian`, etc.). Fire ALL activated reviewers simultaneously.

**On Claude Code** — use `Task()` calls or `.claude/agents/` subagent files.

**Critical**: Each reviewer receives the FULL diff AND relevant unchanged source context inline in its instruction. Sub-agents have isolated context — they cannot read workspace files. The source context enables ripple analysis (consumer traces, boundary value traces).

### Step 4: Aggregate and Classify

After all reviewers return, merge findings following `coordinator.md` Phase 3:

1. Sort by severity: Critical → Important → Minor
2. Prefix each finding with `[Reviewer Name]`
3. Note clean dimensions ("✅ No issues")
4. **Triple-filter** each Important/Critical finding:
   - **Implement**: Improves customer experience + reduces/neutral complexity + improves testability
   - **Defer**: Good finding but doesn't pass all 3 filters
   - **Reject**: Correct observation but fix adds more complexity than it removes
5. Present unified report with action classification

### Step 5: Escalation (Round 2)

Check escalation triggers per `coordinator.md` Phase 4. If any trigger fires, re-dispatch focused reviewers and append to the report under `### Round 2 Findings`.

## The 5 Standard Reviewers

| # | Reviewer | Mental Model | Key v2 Techniques |
|---|----------|-------------|-------------------|
| 1 | Defect Finder | "What breaks?" | Ripple analysis, consumer trace, state lifecycle, feedback loop analysis, interaction-path enumeration |
| 2 | Design Critic | "Well-structured?" | Factoring, complexity, naming, API design |
| 3 | Guardian | "Damage beyond diff?" | Blast radius, field consumer trace, caller contract drift, infrastructure error paths |
| 4 | Standards Enforcer | "Meets expectations?" | Comment-as-spec, test revert-safety, paired boundary tests, mock fidelity, observability |
| 5 | Performance Analyst | "Will it scale?" | Performance, logging |

### On-Demand Reviewers (activated by escalation or `--all`)

| Reviewer | When Activated |
|----------|---------------|
| Monolith | `--all` flag, or manual request for comprehensive single-reviewer pass |

## Overrides

- `--all`: Force all reviewers including on-demand
- `--only=<name>`: Run a single named reviewer
- `--skip=<name>`: Exclude a specific reviewer from triage selection
- `--round1-only`: Skip Round 2 escalation even if triggers fire
