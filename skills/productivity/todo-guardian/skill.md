---
name: todo-guardian
source: superpowers-plus
triggers:
  - "handle later"
  - "come back to"
  - "remember to"
  - "needs follow-up"
  - "revisit"
  - "defer"
anti_triggers:
  - "TODO.md file format"
  - "todo-management skill"
  - "todo-crud.sh"
description: "Continuous enforcement for TODO discipline. Auto-extracts TODOs from outputs, detects stale items (unchanged >3 steps), blocks completion if open TODOs exist. ENFORCEMENT, not CRUD."
summary: "Use when: TODO mentioned or implied. Skip when: discussing todo-management."
coordination:
  group: todo-enforcement
  order: 1
  requires: [todo-management]
  enables: [verification-before-completion]
  escalates_to: [quantitative-decision-gate]
  internal: false
---

# TODO Guardian

> **Wrong skill?** Creating TODOs -> todo-management. Planning -> plan-and-execute.

**Announce at start:** "I am using the **todo-guardian** skill to enforce TODO discipline."

## When to Use

- When output contains defer-language ("handle later", "come back to")
- Before claiming completion (check open TODOs)
- After every 3 steps (staleness check)
- When reviewing session for missed action items

### Example

```bash
# Example: Staleness check
echo "=== TODO Staleness Audit ==="
echo "| TODO              | Steps | Status    |"
echo "| Fix error handler | 1     | Fresh     |"
echo "| Refactor auth     | 4     | STALE     |"
echo "| Check perf        | 7     | ORPHANED  |"
echo "Action: 1 stale (re-evaluate), 1 orphaned (close)"
```

## Enforcement Rules

### Rule 1: Extract or Reject

"Handle later" detected -> extract TODO immediately.
Log to todo_evolution.md. NEVER allow defer-language without logged TODO.

### Rule 2: Staleness (every 3 steps)

| TODO | Steps Since Update | Action |
|------|-------------------|--------|
| Fix X | 1 | Fresh |
| Refactor Y | 3 | STALE — re-evaluate |
| Check Z | 5+ | ORPHANED — close or escalate |

### Rule 3: Completion Gate

- [ ] All session TODOs reviewed
- [ ] No stale TODOs (>3 steps)
- [ ] No orphaned TODOs
- [ ] Deferred have justification

Fail -> BLOCK completion -> resolve first.

### Rule 4: Session-End Sweep

Created: N . Completed: M . Deferred: K . Stale: J

---

## Anti-Patterns

| Anti-Pattern | Detection | Correction |
|--------------|-----------|------------|
| "Handle later" no TODO | Defer-language, nothing logged | Extract immediately |
| Done with open TODOs | "Done!" + unclosed items | Block, resolve |
| Stale ignored | Unchanged 3+ steps | Force re-evaluation |
| TODO inflation | >20 open | Triage: batch-close resolved |

## Failure Modes

| Failure | Detection | Recovery |
|---------|-----------|----------|
| Missed TODO in output | Session review finds unlogged | Add retroactively |
| False positive | "Come back to main page" | Add to anti_triggers |
| Log file missing | Not found | Create with header template |
| Blocks incorrectly | All resolved | Close stale entries |

## Companion Skills

- **todo-management**: CRUD operations
- **verification-before-completion**: Completion gate
- **plan-and-execute**: Planning sequences
- **quantitative-decision-gate**: TODO priorities
