---
name: code-review-battery
source: superpowers-plus
triggers: ["battery review", "run the battery", "parallel review", "parallel code review", "specialized review", "multi-agent review", "run all reviewers", "review battery", "six reviewer", "six-agent review"]
anti_triggers: ["simple review", "quick review", "lint only"]
description: "Use when: reviewing code changes with parallel specialized reviewers + monolith. Dispatches 6 agents (5 specialists + 1 monolith) for deep analysis with automatic learning."
summary: "Use when: code review needed. Dispatches 6 parallel reviewer agents with automatic gap analysis and learning."
coordination:
  group: code-review
  order: 0
  requires: []
  enables: ["progressive-code-review-gate"]
  escalates_to: []
  internal: false
---

# Code Review Battery

Dispatch 5 specialized reviewer agents + 1 monolithic reviewer in parallel. A triage coordinator selects which specialists to activate based on the diff. The monolith ALWAYS runs. After aggregation, a gap analysis compares battery vs monolith findings and feeds the learning system.

**Why this exists**: Specialized reviewers with focused prompts produce broader coverage across security, performance, design, defects, and standards — with parallel speedup. The monolith runs alongside as both a safety net and a teacher: gaps between battery and monolith findings drive automatic learning that makes the specialists stronger over time.

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

### Step 3: Dispatch reviewers in parallel

Read the reviewer prompt from `reviewers/<name>.md`. Dispatch ALL activated reviewers simultaneously.

**On Augment** — use `sub-agent-code-reviewer` with unique names (`battery-defect-finder`, `battery-guardian`, etc.). Fire ALL activated reviewers simultaneously. Each reviewer gets the repo path and instructions to run `git diff` and read source files directly.

**On Claude Code** — use `subagent()` or `Task()` with tool access enabled. Each reviewer needs shell access to run `git diff` and `cat` source files. Use parallel dispatch where supported.

Each reviewer instruction MUST include (see `coordinator.md` for the full contract):
1. **Repo path** — so the reviewer can `cd` to the right directory
2. **Exact diff command** — matching the review scope (e.g., `git diff --cached`, `git diff @{u}..HEAD`, `git diff main..HEAD`)
3. **Reviewer prompt** — from `reviewers/<name>.md`
4. **Instruction to read full source files** — not just the diff output

### Step 4: Aggregate

After all reviewers return (specialists + monolith), merge findings following `coordinator.md` Phase 3:

1. Sort by severity: Critical → Important → Minor
2. Prefix each finding with `[Reviewer Name]`
3. Note clean dimensions ("✅ No issues")
4. Present unified report

### Step 5: Gap Analysis

After aggregation, compare battery findings vs monolith findings. Follow `coordinator.md` Phase 5:

1. For each monolith finding, check if any specialist found the same or equivalent issue
2. **Monolith-only findings** = gaps (battery missed it)
3. **Battery-only findings** = specialist depth (monolith missed it)
4. Classify each gap: pattern-learnable (heuristic) or script-learnable (deterministic)
5. Generate candidate patterns and/or check scripts
6. Stage candidates in the Shadow Lane (candidate lane, not baseline)
7. Record all gaps in the Gap Analysis Log

### Step 6: Update Dashboard

After gap analysis, update the wiki dashboard page:
- **Wiki page**: `Code Review Battery — Performance Dashboard` (Outline ID: `66eec34c-5590-4f4f-a370-b4d134cd174e`)
- Add a new row to the **Review-Level Metrics** table
- Update **Rolling Aggregates** for the current week
- Update **Learning Pipeline** metrics if candidates were generated
- Update **Gap Analysis Log** with any new gaps

## The 6 Reviewers

| # | Reviewer | Mental Model | Dimensions | Activation |
|---|----------|-------------|------------|------------|
| 1 | Defect Finder | "What breaks this code?" | Correctness, Edge Cases, Error Handling, Concurrency | Triage-gated |
| 2 | Design Critic | "Is this well-structured?" | Factoring, Complexity, Testability, API Design | Triage-gated |
| 3 | Guardian | "What damage beyond the diff?" | Security, Blast Radius, Dependencies, Backwards Compat | Triage-gated |
| 4 | Standards Enforcer | "Does this meet expectations?" | Style, Spec Compliance, Doc Drift, Test Quality, Data Integrity | Triage-gated |
| 5 | Performance Analyst | "Will this scale?" | Performance, Observability/Logging | Triage-gated |
| 6 | **Monolith** | "What would a senior engineer catch?" | ALL dimensions + cross-file tracing | **ALWAYS on full reviews** |

### Monolith Activation Rules

- **Full review rounds** (Step 2): Monolith ALWAYS fires alongside activated specialists
- **Targeted re-review** (Step 3a / Phase 4): Monolith does NOT fire unless it was the reviewer that produced the nits. Targeted re-reviews scope to nit-producing reviewers only.
- Gap analysis (Phase 5) and dashboard update (Phase 6) only run after full review rounds, not targeted re-reviews.

## Overrides

- `--all`: Force all 5 specialists regardless of triage (monolith always runs on full reviews)
- `--only=<name>`: Run a single named reviewer (monolith still runs alongside on full reviews)
- `--skip=<name>`: Exclude a specific specialist from triage selection (cannot skip monolith on full reviews)
- `--skip-monolith`: Explicitly skip the monolith (for speed-only runs; disables learning)

## Learning System

The battery improves automatically after every review. See `coordinator.md` Phase 5-6.

### How It Works (Shadow Lane Model)

```
Review Run
  ├─ Baseline Lane (frozen, trusted) ──→ User-visible findings
  └─ Candidate Lane (shadow, learning) ──→ Gap analysis only
                                              │
                                  Compare battery vs monolith
                                              │
                              Propose candidate patterns/scripts
                                              │
                              Adversarial validation (holdout set)
                                              │
                              30-day stability → Graduate to baseline
```

- **Pattern files**: `reviewers/<name>-patterns.md` — heuristic entries per reviewer
- **Check scripts**: `checks/<name>.sh` — deterministic detection scripts
- **Graduation**: Candidates must hit ≥92% precision on 200+ stratified diffs over 30 days
- **Retirement**: Active patterns that drop below 85% precision are quarantined
- **TTL**: Every pattern expires unless revalidated
- **Hard budgets**: Max tokens per pattern file, max active patterns per reviewer
