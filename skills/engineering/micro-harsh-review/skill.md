---
name: micro-harsh-review
source: superpowers-plus
triggers:
  - "review this change"
  - "review this code"
  - "harsh review"
  - "micro review"
  - "code quality check"
anti_triggers:
  - "PR review"
  - "pull request review"
  - "full code review"
description: >
  Per-batch adversarial review for ANY code change. 3 critic personas
  score on 5 dimensions each. Score <8 average = REJECT + rework.
  Faster than full review, more rigorous than lint.
summary: "Use when: any code change before commit. Skip when: docs-only."
coordination:
  group: code-quality
  order: 1
  requires: []
  enables: [pre-commit-gate]
  escalates_to: [progressive-code-review-gate]
  internal: false
---

# Micro Harsh Review

> **Wrong skill?** Full PR -> progressive-code-review-gate. Non-code -> progressive-harsh-review. Style -> enforce-style-guide.

**Announce at start:** "I am using the **micro-harsh-review** skill to review this change."

## When to Use

- Before committing ANY code change (even 1 function)
- After modifying logic, not just formatting
- Before pushing to shared branch
- When editing router patterns or gate thresholds


### Example

```bash
# Example: 3-critic scoring
echo "=== Micro Harsh Review: router pattern change ==="
echo "Critic 1 (Nitpick):  8/10 - case sensitivity concern"
echo "Critic 2 (Arch):     9/10 - minimal scope, pattern-local"
echo "Critic 3 (Prod):     7/10 - no collision test added"
echo "Average: 8.0 -> PASS (conditional: add collision test)"
```

## Scope Exclusions

- Documentation-only -> progressive-harsh-review
- Full PR -> progressive-code-review-gate
- Style only -> enforce-style-guide

---

## 3-Critic Protocol

### Critic 1: NitpickLineByLine

| Check | Score /10 | Notes |
|-------|-----------|-------|
| Off-by-one | | |
| Null handling | | |
| String comparison | | |
| Error messages | | |
| Variable naming | | |

### Critic 2: ArchSoundnessProbe

Respects patterns? /10 . Downstream impact? /10 . Minimal scope? /10 . 10x load? /10 . Reversible? /10

### Critic 3: ProdBattleTest

Edge cases? /10 . Failure mode? /10 . Logging? /10 . Backward compat? /10 . Ship at 3 AM? /10

---

## Scoring

Average = (Nitpick + Arch + Prod) / 3

- >= 8.0 -> PASS
- >= 6.0 -> CONDITIONAL — fix flagged, re-review
- < 6.0 -> REJECT -> think-twice -> redo

---

## Anti-Patterns

| Anti-Pattern | Detection | Correction |
|--------------|-----------|------------|
| Rubber-stamp | All scores 9-10, no notes | Find >=1 concern per critic |
| Inflated scores | Average > 9.0 consistently | Recalibrate with known-bad code |
| Critics agree | Same findings across all 3 | Force one disagreement |
| Review > coding time | >15 min for <20 lines | Top 3 risks only |

## Failure Modes

| Failure | Detection | Recovery |
|---------|-----------|----------|
| Rubber-stamp (all 10s) | No notes | Find >=1 concern per critic |
| Review > change time | >15 min for <20 lines | Top 3 risks only |
| Critics agree on everything | Same findings | Force disagreement |
| Score inflation | Average > 9.0 consistently | Recalibrate with bad code |

## Companion Skills

- **progressive-code-review-gate**: Full PR review (heavier)
- **pre-commit-gate**: Pre-commit (lighter, automated)
- **enforce-style-guide**: Style enforcement
- **think-twice**: Deeper problem revealed
- **failure-autopsy**: Reviewed code fails later
