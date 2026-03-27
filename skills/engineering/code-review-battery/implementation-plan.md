# Code Review Battery — Implementation Plan

> **Plan Version**: 1.0
> **Created**: 2026-03-27
> **Branch**: `feat/code-review-battery` on `superpowers-plus`
> **Prerequisite**: Phase 1a COMPLETE (skill authored, committed @ 5bd896b)

## Phase Overview

| Phase | Description | Dependency | Skills to Invoke |
|-------|-------------|------------|-----------------|
| 1b | Register in skill catalog | 1a ✅ | brainstorming → implementation |
| 1c | Validate on 3+ real diffs | 1b | dispatching-parallel-agents, think-twice, harsh-review |
| 1d | Wire into progressive-code-review-gate | 1c PASS | design-triad, requesting-code-review |
| 1e | Battery becomes default | 1d | verification-before-completion, finishing-a-development-branch |

---

## Phase 1b: Register in Skill Catalog

**Goal**: Make the battery invocable via `use-skill code-review-battery`

### Task Tree

```
1b.1 [BRAINSTORM] Design trigger phrases and routing
  └─ What phrases should activate the battery vs individual review skills?
  └─ Relationship to existing "requesting-code-review" triggers?
  └─ Should "review my code" go to battery or existing?

1b.2 [IMPLEMENT] Add CONCEPT_EXPANSIONS to skill-router.js      ║ parallel-safe
  └─ File: lib/skill-router.js
  └─ Add: 'battery', 'parallel', 'specialized', 'multi-agent' concepts
  └─ Risk: Collision with existing review-related concepts

1b.3 [IMPLEMENT] Add INTENT_PATTERNS to skill-router.js          ║ parallel-safe
  └─ File: lib/skill-router.js
  └─ Patterns: "run the battery", "parallel review", "battery review", etc.
  └─ Risk: Must not steal routes from progressive-code-review-gate

1b.4 [IMPLEMENT] Add skill metadata to catalog
  └─ File: skills/engineering/code-review-battery/skill.md (YAML frontmatter)
  └─ Ensure: triggers array, coordination block, description
  └─ Dep: 1b.1 (trigger phrases finalized)

1b.5 [IMPLEMENT] Update README.md skill count and table
  └─ File: README.md
  └─ Increment engineering skill count
  └─ Add table row for code-review-battery

1b.6 [IMPLEMENT] Update engineering-rigor hub
  └─ File: skills/engineering/engineering-rigor/skill.md
  └─ Add code-review-battery to skill routing table

1b.7 [TEST] Verify skill-router resolves battery correctly
  └─ Run: node -e "require('./lib/skill-router').route('run the battery review')"
  └─ Expected: code-review-battery in top 3 results
  └─ Run on 5+ test queries

1b.8 [COMMIT] Commit Phase 1b changes
  └─ Dep: 1b.2-1b.7 all complete
  └─ Security scan before commit
```

### Risks
- Trigger collision with progressive-code-review-gate or requesting-code-review
- Skill-router changes may break existing routing tests

---

## Phase 1c: Validate on 3+ Real Diffs

**Goal**: Prove battery ≥ monolithic quality on diverse diffs

### Task Tree

```
1c.1 [GATHER] Find 3+ diverse real diffs                        ║ parallel-safe
  └─ Diff A: Small JS change (~50 lines, 2-3 files)
  └─ Diff B: Medium multi-file change (~200 lines, 5+ files)
  └─ Diff C: Large refactor or new feature (~500+ lines)
  └─ Diff D (optional): Config/docs-only change (triage edge case)
  └─ Source: superpowers-plus git history, or Personal/ repos

1c.2 [DISPATCH] Run full battery on each diff                    ║ parallel-safe (across diffs)
  └─ For each diff: triage → dispatch reviewers → aggregate
  └─ Use dispatching-parallel-agents skill for sub-agent dispatch
  └─ Record: triage decision, findings, timing

1c.3 [DISPATCH] Run monolithic review on same diffs              ║ parallel-safe (across diffs)
  └─ Use existing code-reviewer.md prompt
  └─ Record: findings, timing

1c.4 [ANALYZE] Compare battery vs monolithic per diff
  └─ Dep: 1c.2 + 1c.3
  └─ Metrics: precision, recall, false positive rate, severity accuracy
  └─ Invoke THINK-TWICE if battery recall < 70%
  └─ Invoke HARSH-REVIEW on battery output quality

1c.5 [FIX] Iterate on reviewer prompts if gaps found
  └─ Dep: 1c.4
  └─ May modify: reviewers/*.md, coordinator.md
  └─ Re-run affected diffs after fixes

1c.6 [DOCUMENT] Update DESIGN.md investigation log
  └─ Dep: 1c.4 (or 1c.5 if iteration happened)
  └─ Add V6-V8 entries for new diff validations

1c.7 [GATE] Phase 1c pass/fail decision
  └─ Dep: 1c.6
  └─ PASS if: ≥3 diffs validated, precision ≥90%, recall ≥70%
  └─ FAIL if: any diff produces ≥20% false positives
  └─ If FAIL: loop back to 1c.5 (max 2 iterations)

1c.8 [COMMIT] Commit Phase 1c changes (prompt improvements, docs)
```

### Risks
- Recall gap persists across diverse diffs → need prompt redesign
- Large diffs hit token limits → need chunking strategy
- Diminishing returns from prompt iteration → know when to stop

---


## Phase 1d: Wire into progressive-code-review-gate

**Goal**: Battery is callable from the existing review gate (opt-in)

### Task Tree

```
1d.1 [DESIGN-TRIAD] Architecture for delegation
  └─ Read: skills/engineering/progressive-code-review-gate/skill.md
  └─ Decision: How does the gate detect battery availability?
  └─ Decision: Feature flag mechanism (env var? config? skill presence?)
  └─ Decision: Fallback behavior when battery unavailable
  └─ Invoke design-triad: Architect proposes, Critic challenges, PM arbitrates

1d.2 [IMPLEMENT] Modify progressive-code-review-gate/skill.md
  └─ Dep: 1d.1
  └─ Add: delegation to battery when available AND flag set
  └─ Preserve: existing behavior when battery not available

1d.3 [IMPLEMENT] Update requesting-code-review
  └─ Add: note about battery availability
  └─ Risk: must not break existing skill behavior

1d.4 [TEST] End-to-end integration test
  └─ Invoke REQUESTING-CODE-REVIEW on the integration changes themselves

1d.5 [COMMIT] Commit Phase 1d changes
```

## Phase 1e: Battery Becomes Default

**Goal**: Remove feature flag, battery is the standard review path

### Task Tree

```
1e.1 [VERIFY] Final validation sweep
  └─ Invoke VERIFICATION-BEFORE-COMPLETION
  └─ Run battery on 2 new diffs, check all PRD acceptance criteria

1e.2 [IMPLEMENT] Remove feature flag, battery = default

1e.3 [IMPLEMENT] Update all documentation
  └─ Remove "Draft" markers, add "Shipped" status

1e.4 [SELF-REVIEW] Run battery on its own changes (meta-test)

1e.5 [COMMIT] Final commit

1e.6 [SHIP] Push upstream → PR → merge → sync origin
  └─ Invoke FINISHING-A-DEVELOPMENT-BRANCH
```

## Skill Invocation Schedule

| Checkpoint | Skill(s) | Purpose |
|-----------|----------|---------|
| Before 1b | brainstorming | Design trigger phrases |
| After 1b | verification-before-completion | Verify routing works |
| 1c.2-1c.3 | dispatching-parallel-agents | Parallel battery + monolithic |
| 1c.4 (if recall <70%) | think-twice | Diagnose and pivot |
| 1c.4 | harsh-review (progressive) | Ruthlessly critique output |
| 1d.1 | design-triad | Architecture for gate delegation |
| 1d.4 | requesting-code-review | Review integration changes |
| 1e.1 | verification-before-completion | Final AC check |
| 1e.4 | requesting-code-review | Self-review final changeset |
| 1e.6 | finishing-a-development-branch | PR/merge flow |

## Abort Criteria

Stop and escalate to user if:
- Phase 1c fails after 2 prompt iteration cycles (recall stays <70%)
- Phase 1d integration breaks existing review flow
- Token cost exceeds 5x monolithic
- Any phase introduces >3 files of changes to existing skills