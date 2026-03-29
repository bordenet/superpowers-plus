---
name: implementation-tracker
source: superpowers-[company]
triggers: ["start implementation", "track implementation", "resume work on issue", "update progress", "implementation complete", "archive progress"]
description: Use when implementing large Linear issues across multiple Auggie sessions. Creates and maintains a living progress document that tracks completed work, decisions, refinements, and findings.
summary: "Use when: implementing large issues across multiple sessions. Maintains progress doc."
coordination:
  group: engineering
  order: 1
  requires: []
  enables: []
  escalates_to: []
  internal: false
anti_triggers: ['investigate bug', 'debug issue', 'systematic debugging']
---

# Implementation Tracker

> **Purpose:** Maintain implementation context across Auggie sessions
> **Path:** `docs/plans/{PREFIX}-XXXX-progress.md` (git-ignored during active work)

**Announce at start:** "Using implementation-tracker to maintain progress across sessions."

---

## Triggers

| Trigger | Action |
|---------|--------|
| `writing-plans` completes | Auto-create progress doc |
| "Track implementation for {PREFIX}-XXX" | Manual creation |
| "Update progress" / milestone | Update doc + verify |
| "Resume work on {PREFIX}-XXX" | Load existing context |
| "Implementation complete" | Archive prompt |

---

## Session Resume

When existing progress doc found:

```
I found: docs/plans/{PREFIX}-1234-progress.md
Last session: aug_abc123 (2026-03-05)
Status: 3/7 tasks, 2 decisions, 1 open question
[Yes / No / Show summary first]
```

### What Carries Forward

| ✅ Facts (persist) | ❌ Fresh Each Session |
|--------------------|----------------------|
| Completed tasks, files modified | Reasoning/approach |
| Blockers, decisions, refinements | Tool call sequences |
| Open questions, key insights | Error messages |
| Wiki context | Debugging hypotheses |

---

## Verification (After Every Update)

| Order | Method | Purpose |
|-------|--------|---------|
| 1 | `git diff --name-only` | What actually changed |
| 2 | `test -f path/to/file.ts` | Files exist |
| 3 | `grep -rn "symbol" --include="*.ts"` | Symbols present |
| 4 | `tsc --noEmit` | Type errors |
| 5 | `npm test -- --filter=relevant` | Tests pass |

---

## Auto-Condense

Target: **~1,500 words**. When exceeded: move completed tasks → summary table, condense session summaries, archive resolved questions.

---

## Red Flags — STOP

- Progress doc says complete but git shows no changes
- Verification fails after update
- Doc >2,000 words without condensing
- Wiki context stale (>7 days)

---

## References

| File | Contents |
|------|----------|
| `references/doc-template.md` | Full progress doc structure, checklists, archive workflow |


## Failure Modes

| Mode | Symptom | Recovery |
|------|---------|----------|
| Confuse with debugging | Wrong skill | This tracks architecture, not bugs |

## Companion Skills

| Skill | Relationship |
|-------|--------------|
| `writing-plans` | Chains into this skill |
| `engineering-rigor` | Complementary discipline |
| `[product]-data-flow-verification` | For scheduler changes |
| `field-rename-verification` | For field renames |

## When to Use

- Tracking implementation progress across a multi-file feature
- Verifying all planned changes have been applied
- Auditing completeness of a refactoring effort

## Common Failure Modes

- **Scope drift:** Tracking items that weren't in the original plan
- **False completion:** Marking items done based on file changes without verifying behavior
- **Missing downstream:** Tracking primary changes but forgetting test updates and documentation
