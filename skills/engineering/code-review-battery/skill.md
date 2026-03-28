---
name: code-review-battery
source: superpowers-plus
triggers: ["battery review", "run the battery", "parallel review", "parallel code review", "specialized review", "multi-agent review", "run all reviewers", "review battery", "five reviewer", "five-agent review"]
anti_triggers: ["simple review", "quick review", "lint only"]
description: "Use when: reviewing code changes with parallel specialized reviewers. Dispatches 5 focused agents (defect finder, design critic, guardian, standards enforcer, performance analyst) for deeper analysis than monolithic review."
summary: "Use when: code review needed. Dispatches parallel specialized reviewer agents for deep, precise findings."
coordination:
  group: code-review
  order: 0
  requires: []
  enables: ["progressive-code-review-gate"]
  escalates_to: []
  internal: false
---

# Code Review Battery

Dispatch 5 specialized reviewer agents in parallel, each focused on a distinct set of review dimensions. A triage coordinator selects which reviewers to activate based on the diff, then aggregates findings into a unified report.

**Why this exists**: A single monolithic reviewer tries to evaluate everything simultaneously, leading to shallow coverage. Specialized reviewers with focused prompts and code execution produce deeper, broader analysis — finding more issues across more dimensions while maintaining the same verification rigor as monolithic review.

## When to Use

- When `requesting-code-review` or `progressive-code-review-gate` triggers a review
- When you want a thorough review of staged changes, a commit range, or a PR diff
- When reviewing someone else's code

## Procedure

### Step 1: Capture the diff
Run `git diff` (staged, commit range, or branch diff) and `git diff --stat`.

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

Read the reviewer prompt from `reviewers/<name>.md`. Dispatch ALL activated reviewers simultaneously.

**On Augment** — use `sub-agent-code-reviewer` with unique names (`battery-defect-finder`, `battery-guardian`, etc.). Fire ALL activated reviewers simultaneously. Each reviewer gets the repo path and instructions to run `git diff` and read source files directly.

**On Claude Code** — use `subagent()` or `Task()` with tool access enabled. Each reviewer needs shell access to run `git diff` and `cat` source files. Use parallel dispatch where supported.

Each reviewer instruction MUST include:
1. The repo path (so it can `cd` there and run `git diff`)
2. Instructions to read the FULL source files for changed code (not just the diff)
3. The reviewer prompt from `reviewers/<name>.md`

### Step 4: Aggregate

After all reviewers return, merge findings following `coordinator.md` Phase 3:

1. Sort by severity: Critical → Important → Minor
2. Prefix each finding with `[Reviewer Name]`
3. Note clean dimensions ("✅ No issues")
4. Present unified report

## The 5 Reviewers

| # | Reviewer | Mental Model | Dimensions |
|---|----------|-------------|------------|
| 1 | Defect Finder | "What breaks this code?" | Correctness, Edge Cases, Error Handling, Concurrency |
| 2 | Design Critic | "Is this well-structured?" | Factoring, Complexity, Testability, API Design |
| 3 | Guardian | "What damage beyond the diff?" | Security, Blast Radius, Dependencies, Backwards Compat |
| 4 | Standards Enforcer | "Does this meet expectations?" | Style, Spec Compliance, Doc Drift, Test Quality, Data Integrity |
| 5 | Performance Analyst | "Will this scale?" | Performance, Observability/Logging |

## Overrides

- `--all`: Force all 5 reviewers regardless of triage
- `--only=<name>`: Run a single named reviewer
- `--skip=<name>`: Exclude a specific reviewer from triage selection
