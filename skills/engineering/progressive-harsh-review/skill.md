---
name: progressive-harsh-review
source: superpowers-plus
augment_menu: true
triggers:
  - /sp-phr
  - /sp-redteam
  - harsh review
  - progressive review
  - red team this
  - review this harshly
  - hostile review
  - critic review
  - find what's wrong
  - score this work
  - ready to present plan
  - ready to present design
  - ready to present spec
  - before pushing skill changes
  - before pushing design docs
  - run PHR on skill
  - gate skill push with PHR
  - review skill file
  - review this skill
aliases: [PHR, harsh-review]
anti_triggers:
  - code review
  - PR review
  - review someone's PR
  - design review inside debate
  - quick feedback
description: "Multi-persona adversarial review for non-code deliverables (plans, skills, documents, designs after debate). Simulates 3 critic personas scoring on correctness, simplicity, testability, edge cases, and security. Score <7 = REJECT. Self-assessment trigger: invoke before presenting any non-code deliverable (see When to Use in skill body). For code PRs, use code-review-battery instead."
summary: "Use when: about to present a plan, spec, or non-code proposal. Fires on intent to present, not only on explicit user request. For code PRs use code-review-battery."
coordination:
  group: quality
  order: 2
  requires: []
  enables: ["think-twice", "debate"]
  escalates_to: []
  internal: false
composition:
  consumes: [design-options, phased-plan, markdown-content]
  produces: [review-feedback]
  capabilities: [reviews-design, gates-quality]
  priority: 30
---

# Progressive Harsh Review

> **Wrong skill?** Code PR review → `progressive-code-review-gate`. File-protocol review → `code-review-respond`. Quick feedback → `providing-code-review`.
>
> **Purpose:** Multi-persona adversarial review that catches what self-review cannot.
> **Pattern:** Three escalating critic personas, each scoring independently.

**Announce at start:** "I'm using the **progressive-harsh-review** skill to red-team this work."

## Companion Skills

- **progressive-code-review-gate**: Code-level review (this skill reviews designs/plans)
- **brainstorming**: Generating options before review
- **micro-harsh-review**: Per-batch code review
- **providing-code-review**: Code-specific review

## When to Use

**Intent-based (self-fire — do not wait to be asked):**
- **About to present any non-code deliverable to the human** — plans, specs, skill files, designs, documents
- The trigger is the INTENT to present, not whether the human explicitly requested review
- If there is even a 1% chance the human expects a solid artifact, run PHR first

**Explicit request:**
- When the user says "review this harshly", "find what's wrong", or "red team this"

**NOT for:**
- Code PRs → use `code-review-battery` instead
- Design comparison (choosing between options) → `debate` handles that
- Initial brainstorming (too early — nothing to review yet)

## The Three Personas

### Persona 1: JuniorDevNitpicker (Surface Quality)

Focus: typos, formatting, naming, style, obvious bugs, missing error handling.
Tone: eager, thorough, detail-oriented.
**Full access:** All codebase context is available. Every persona may follow any lead.
**START FROM:** The local diff — line-by-line reading of changed code.
**PRIORITIZE:** Surface correctness, naming consistency, null handling, off-by-one errors, error message quality.
**Dimension weights:** Correctness 35%, Simplicity 25%, Edge Cases 20%, Testability 15%, Security/Perf 5%.

### Persona 2: SeniorArchCritic (Structural Quality)

Focus: architecture, design patterns, separation of concerns, extensibility, testability.
Tone: experienced, skeptical, pattern-aware.
**Full access:** All codebase context is available. Every persona may follow any lead.
**START FROM:** Interface contracts and public APIs affected by the change. Check downstream impact before scoring.
**PRIORITIZE:** Ripple analysis across all callers and consumers, design pattern adherence, reversibility, extensibility.
**Dimension weights:** Correctness 25%, Simplicity 15%, Edge Cases 15%, Testability 25%, Security/Perf 20%.

### Persona 3: ProdOpsHardass (Operational Quality)

Focus: failure modes, edge cases, security, performance, monitoring, rollback.
Tone: battle-scarred, worst-case thinker, "what breaks at 3am?"
**Full access:** All codebase context is available. Every persona may follow any lead.
**START FROM:** Failure modes and state transitions. Trace error handling paths and retry/rollback behavior first.
**PRIORITIZE:** Operational safety, monitoring/logging coverage, backward compatibility, deployment risk, 3 AM resilience.
**Dimension weights:** Correctness 25%, Simplicity 10%, Edge Cases 25%, Testability 10%, Security/Perf 30%.

## The Process

### Step 0: Fresh-Reader Pre-Check (author-noise audit)

Before dispatching personas, grep the artifact for author-noise leakage — content only the author would recognize that will confuse a fresh reader:

- Machine-local paths (e.g., `/Users/matt/`, `/home/runner/`, `/tmp/build-123/`)
- Invented identifiers not defined in the artifact (e.g., referencing a function that doesn't exist in the diff)
- Process commentary left in ("I added this because...", "TODO from our discussion", "per the Slack thread")
- Internal ticket/PR references a public reader cannot resolve

If any are found, flag them as **Minor author-noise findings** in the report. Do NOT score down for these — they are editorial, not correctness failures. Remove them before shipping if found.

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

Each persona scores 1-10 on each dimension. **Aggregation rule:** take the **weighted mean** across all three personas (equal persona weight by default). This replaces the previous MINIMUM rule, which was overly pessimistic when one persona was mismatched to the task.

**Critical veto:** If ANY persona scores Correctness or Security/Perf ≤4 AND cites a specific defect (not a general concern), that finding acts as a **hard veto** — automatic REJECT regardless of the weighted mean. This preserves safety without making the whole system hostage to the weakest persona on non-critical dimensions.

### Step 3: Verdict

| Weighted Mean | Verdict | Action |
|---------------|---------|--------|
| ≥8 | **PASS** | Ship it |
| 7–7.9 | **PASS_WITH_FIXES** | Fix all findings, re-score changed areas only. Exit when mean ≥8 or Round 2 finds no new issues. |
| <7 | **REJECT** | Root-cause analysis → remediate → full re-review |
| Any | **REJECT (veto)** | Critical veto fired — fix the cited defect, full re-review |

> Project-min override: a project floor (e.g. 9.5) supersedes the band; anything below is PASS_WITH_FIXES.

### Step 4: Remediation (if needed)

On REJECT:

1. **Root-cause analysis** — why did the issues exist? (missed requirement, wrong assumption, insufficient context)
2. **Chain to remediation skills:**
   - Design issues → `debate` (generate alternatives)
   - Stuck/circular → `think-twice` (fresh perspective)
   - Plan issues → `plan-and-execute` (replan)
3. **Re-review** — minimum 2 rounds. Round 2 reviews ONLY delta changes.

### Step 5: Correlated-Failure Detection

After scoring, scan persona outputs for **shared blind spots**:

1. **Evidence overlap:** If all 3 personas cite the same evidence for their findings, flag `⚠️ CORRELATED EVIDENCE`. At least one persona must re-examine from a different starting point (Nitpicker: local diff, ArchCritic: interface contracts, ProdOps: failure modes).
2. **Phrasing similarity:** If 2+ personas use near-identical phrasing, flag `⚠️ ECHO REASONING`. Require the echoing persona to restate the finding through their own analytical lens.
3. **Clean-sweep suspicion:** If ALL personas report no findings, verify each persona's output shows evidence of their distinct starting point (Nitpicker: line-level reading, ArchCritic: caller/contract analysis, ProdOps: failure mode tracing). If any persona's output lacks starting-point-specific evidence, re-examine.

Flags trigger re-examination, not automatic verdict changes.

### Step 6: Convergence

- **Exit when:** Final round weighted mean ≥8 (or project min if higher) AND no active Critical vetoes AND no correlated-failure flags AND no new material issues in latest round
- **Escalate when:** 3 rounds without convergence → summarize blockers, escalate to human

## Sentinel Write After PASS (MANDATORY)

When the final round verdict is **PASS** (weighted mean ≥ 8.0 per the verdict
table above, AND ≥ the project minimum if one is set, AND no active critical
vetoes, AND no correlated-failure flags), **immediately** run:

```bash
tools/run-phr.sh --verdict PASS --min-score <weighted-mean>
```

This writes `.phr-cleared` with format `v1|<HEAD-SHA>|PASS|<UTC-TS>|min-score=<N>`.
The pre-push hook's Gate 4 reads this sentinel; without it, any push
that touches skill/design .md files is refused at the local pre-push hook
(developer-machine self-discipline, not a server-side security boundary).

**Only PASS clears the gate.** PASS_WITH_FIXES (mean 7.0-7.9 or below project-min) → another round, do NOT write sentinel. REJECT (<7 or critical veto) → root-cause, remediate, full re-review.

Run PHR AFTER `git commit` -- the sentinel binds to HEAD SHA. Any
subsequent commit/amend/rebase invalidates it (Gate 4 will report stale).

> **Why this is mandatory:** PHR was discipline-only for too long --
> skill changes shipped without running it repeatedly. The sentinel +
> Gate 4 closes the loop. Note Gate 4 is a productivity guardrail
> (catches forgetting), not a tamper-proof security control. Code
> review must still verify PHR actually ran, not just that the sentinel
> is present.

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
**Weighted Average: 6.5 → REJECT** (below 7.0 threshold)
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
| All personas gave same feedback | Each persona must name ≥1 plausible failure mode unique to their lens, or cite a specific property of the change explaining why none exists (generic dismissal = rubber-stamp) — identical findings means the lenses aren't distinct |
| Score inflated to avoid re-work | Findings with concrete issues MUST score ≤7 on that dimension |
| Remediation skipped after REJECT | REJECT means start over. No "fix one thing and call it done" |
| Only reviewed happy path | ProdOpsHardass must consider failure, rollback, 3am scenarios |
| Skipped sentinel write after PASS | Pre-push Gate 4 refuses the push with "PHR sentinel missing." Run `tools/run-phr.sh --verdict PASS --min-score <N>` and retry. |
