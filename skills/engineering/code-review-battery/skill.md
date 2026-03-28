---
name: code-review-battery
source: superpowers-plus
triggers: ["battery review", "run the battery", "parallel review", "parallel code review", "specialized review", "multi-agent review", "run all reviewers", "review battery", "six reviewer", "six-agent review"]
anti_triggers: ["simple review", "quick review", "lint only"]
description: "Use when: reviewing code changes with parallel specialized reviewers + monolith. Dispatches 6 agents (5 specialists + 1 monolith) for deep analysis with gap analysis and candidate staging."
summary: "Use when: code review needed. Dispatches 6 parallel reviewer agents with gap analysis and candidate staging."
coordination:
  group: code-review
  order: 0
  requires: []
  enables: ["progressive-code-review-gate"]
  escalates_to: []
  internal: false
---

# Code Review Battery

Dispatch 5 specialized reviewer agents + 1 monolithic reviewer in parallel. A triage coordinator selects which specialists to activate based on the diff. The monolith runs by default on full review rounds (can be skipped with `--skip-monolith`). After aggregation, a gap analysis compares battery vs monolith findings and feeds the learning system.

**Why this exists**: Specialized reviewers with focused prompts produce broader coverage across security, performance, design, defects, and standards — with parallel speedup. The monolith runs alongside as both a safety net and a teacher: gaps between battery and monolith findings drive automatic candidate staging that makes the specialists stronger over time.

## When to Use

- When `progressive-code-review-gate` triggers a review (primary entry point)
- When `requesting-code-review` triggers a review (if it delegates to the battery)
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

### Step 2.5: Context Expansion (conditional)

If the diff changes ≥2 files or ≥20 lines: read `context-expansion.md` and build the context package. Otherwise skip — reviewers explore manually.

### Step 3: Dispatch reviewers in parallel

Read the reviewer prompt from `reviewers/<name>.md`. Dispatch ALL activated reviewers simultaneously.

**On Augment** — `sub-agent-code-reviewer` with unique names. **On Claude Code** — `subagent()` or `Task()`.

Each reviewer instruction MUST include the 5-part contract (see `coordinator.md`):
1. Repo path → 2. Exact diff command → 3. Reviewer prompt → 4. Read full source files → 5. Context package (from Step 2.5)

For monolith, defect-finder, guardian: also load `investigation-protocol.md`.

### Step 3.5: Verify findings

Read `verification.md`. Parse each reviewer's structured findings. Run deterministic checks (file exists, line valid, symbol in file). Tag each finding `[VERIFIED]`, `[UNVERIFIED: <reason>]`, or `[UNSTRUCTURED]`.

### Step 4: Aggregate

After verification, merge findings following `coordinator.md` Phase 3:

1. Separate verified, unverified, and unstructured findings
2. Sort verified findings by severity: Critical → Important → Minor
3. Prefix each with `[Reviewer Name]` and verification tag
4. Unverified/unstructured → Appendix
5. Present unified report

### Step 5: Gap Analysis (full review rounds only)

Load `gap-analysis.md`. Compare battery vs monolith findings. Skip if `--skip-monolith` or monolith failed.

### Step 6: Update Dashboard (full review rounds only)

Follow `gap-analysis.md` Phase 6. Skip if `--skip-monolith`. Dashboard failure does not block the review verdict.

## The 6 Reviewers

| # | Reviewer | Mental Model | Dimensions | Activation |
|---|----------|-------------|------------|------------|
| 1 | Defect Finder | "What breaks this code?" | Correctness, Edge Cases, Error Handling, Concurrency | Triage-gated |
| 2 | Design Critic | "Is this well-structured?" | Factoring, Complexity, Testability, API Design, Architectural Layering | Triage-gated |
| 3 | Guardian | "What damage beyond the diff?" | Security, Blast Radius, Dependencies, Backwards Compat, Reliability | Triage-gated |
| 4 | Standards Enforcer | "Does this meet expectations?" | Style, Spec Compliance, Doc Drift, Test Quality & Adequacy, Data Integrity | Triage-gated |
| 5 | Performance Analyst | "Will this scale?" | Performance, Observability/Logging | Triage-gated |
| 6 | **Monolith** | "What would a senior engineer catch?" | ALL dimensions + cross-file tracing | **Default on full reviews** |

### Monolith Activation Rules

- **Full review rounds** (Step 2): Monolith fires alongside activated specialists by default (unless `--skip-monolith`)
- **Targeted re-review** (Step 3a / Phase 4): Monolith does NOT fire unless it was the reviewer that produced the nits. Targeted re-reviews scope to nit-producing reviewers only.
- Gap analysis (Phase 5) and dashboard update (Phase 6) only run after full review rounds, not targeted re-reviews.

## Overrides

- `--all`: Force all 5 specialists regardless of triage (monolith still runs by default unless `--skip-monolith`)
- `--only=<name>`: Run a single named reviewer (monolith still runs alongside on full reviews)
- `--skip=<name>`: Exclude a specific specialist from triage selection (cannot skip monolith on full reviews)
- `--skip-monolith`: Explicitly skip the monolith (for speed-only runs; disables learning)

## Learning System

Gap analysis on full review rounds (Steps 5-6) feeds the Shadow Lane learning pipeline. See `gap-analysis.md` and `DESIGN.md` for details.
