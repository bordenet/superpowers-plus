---
name: progressive-harsh-review
source: superpowers-plus
triggers: ["harsh review", "progressive review", "red team this", "review this harshly",
           "hostile review", "critic review", "find what's wrong",
           "score this work"]
anti_triggers: ["code review", "PR review", "review someone's PR", "design review inside design-triad", "quick feedback"]
description: "Multi-persona adversarial review for non-code deliverables (plans, skills, documents, designs after design-triad). Simulates 3 critic personas scoring on correctness, simplicity, testability, edge cases, and security. Score <6 = REJECT. For code PRs, use progressive-code-review-gate instead."
summary: "Use when: validating non-code deliverables. For code PRs use progressive-code-review-gate."
coordination:
  group: quality
  order: 0
  requires: []
  enables: ["think-twice", "design-triad"]
  escalates_to: []
  internal: false
---

# Progressive Harsh Review

> **Wrong skill?** Code PR review → `progressive-code-review-gate`. File-protocol review → `code-review-respond`. Quick feedback → `providing-code-review`.

> **Purpose:** Multi-persona adversarial review that catches what self-review cannot.
> **Pattern:** Three escalating critic personas, each scoring independently.

**Announce at start:** "I'm using the **progressive-harsh-review** skill to red-team this work."

## Companion Skills

- **progressive-code-review-gate**: Code-level review (this skill reviews designs/plans)
- **brainstorming**: Generating options before review
- **micro-harsh-review**: Per-batch code review
- **providing-code-review**: Code-specific review
## When to Use

- After completing a significant non-code deliverable (plan, skill, document, design)
- As a quality gate for artifacts that `progressive-code-review-gate` doesn't cover
- When the user says "review this harshly" or "find what's wrong"
- NOT for: code PRs (`progressive-code-review-gate`), design comparison inside `design-triad`, initial brainstorming (too early)

## The Three Personas

### Persona 1: JuniorDevNitpicker (Surface Quality)

Focus: typos, formatting, naming, style, obvious bugs, missing error handling.
Tone: eager, thorough, detail-oriented.

### Persona 2: SeniorArchCritic (Structural Quality)

Focus: architecture, design patterns, separation of concerns, extensibility, testability.
Tone: experienced, skeptical, pattern-aware.

### Persona 3: ProdOpsHardass (Operational Quality)

Focus: failure modes, edge cases, security, performance, monitoring, rollback.
Tone: battle-scarred, worst-case thinker, "what breaks at 3am?"

## The Process

### Step 1: Dispatch Review

**HARD GATE: Author ≠ Reviewer.** Use a sub-agent or explicit role switch.

For each persona, answer ALL scoring dimensions:

| Dimension | Weight | Question |
|-----------|--------|----------|
| Correctness | 30% | Does it do what it claims? Are there bugs? |
| Simplicity | 20% | Is it the simplest solution? Over-engineered? |
| Testability | 15% | Can each component be tested independently? |
| Edge Cases | 20% | What breaks? What wasn't considered? |
| Security/Perf | 15% | Vulnerabilities? Performance bottlenecks? |

### Step 2: Score and Aggregate

Each persona scores 1-10 on each dimension. **Aggregation rule:** take the MINIMUM weighted average across all three personas. This prevents one lenient persona from masking another's concerns.

### Step 3: Verdict

| Minimum Persona Average | Verdict | Action |
|--------------------------|---------|--------|
| ≥8 | **PASS** | Ship it |
| 6-7 | **PASS_WITH_FIXES** | Fix all findings, re-score changed areas only. Exit when minimum ≥8 or Round 2 finds no new issues. |
| <6 | **REJECT** | Root-cause analysis → remediate → full re-review |

### Step 4: Remediation (if needed)

On REJECT:
1. **Root-cause analysis** — why did the issues exist? (missed requirement, wrong assumption, insufficient context)
2. **Chain to remediation skills:**
   - Design issues → `design-triad` (generate alternatives)
   - Stuck/circular → `think-twice` (fresh perspective)
   - Plan issues → `plan-and-execute` (replan)
3. **Re-review** — minimum 2 rounds. Round 2 reviews ONLY delta changes.

### Step 5: Convergence

- **Exit when:** Final round minimum persona average ≥6 AND no new material issues in latest round
- **Escalate when:** 3 rounds without convergence → summarize blockers, escalate to human

## Scoring Output Format

```markdown
### Persona: SeniorArchCritic
| Dimension | Score | Finding |
|-----------|-------|---------|
| Correctness | 7 | Lock release doesn't check PID ownership |
| Simplicity | 8 | Clean, minimal |
| Testability | 6 | No unit tests for lock race condition |
| Edge Cases | 5 | What if process dies mid-lock? |
| Security/Perf | 7 | Lock file readable by any user |
**Weighted Average: 6.5 → PASS_WITH_FIXES**
```


## Example

```bash
# Run the harsh review tool
cd ~/.codex/superpowers-plus && bash tools/harsh-review.sh
# Check specific skill
bash tools/harsh-review.sh skills/engineering/my-skill/skill.md
```

## Anti-Patterns

| Anti-Pattern | Detection | Correction |
|--------------|-----------|------------|
| Soft review | No score <7 given | Recalibrate with known-bad example |
| Same feedback loop | Same comment 3 iterations | Escalate to structural fix |
| Style over substance | All comments are formatting | Check logic, edge cases, error handling first |
| Perfection paralysis | 5+ rounds, no convergence | Set hard limit: 3 rounds then ship |
| Missing context | Review without reading full file | Load surrounding context first |

## Failure Modes

| Failure | Fix |
|---------|-----|
| Self-reviewed in same thinking pass | Use sub-agent or explicit role switch — author ≠ reviewer |
| All personas gave same feedback | Personas must have distinct focus areas — if identical, you're not role-switching |
| Score inflated to avoid re-work | Findings with concrete issues MUST score ≤7 on that dimension |
| Remediation skipped after REJECT | REJECT means start over. No "fix one thing and call it done" |
| Only reviewed happy path | ProdOpsHardass must consider failure, rollback, 3am scenarios |
