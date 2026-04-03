---
name: todo-guardian
source: superpowers-plus
triggers:
  - "I'll fix this later"
  - "I'll address this later"
  - "noted for later"
  - "let me skip this for now"
  - "I'll come back to this"
  - "follow up on this later"
  - "I'll do this later"
  - "I'll do this in a follow-up"
anti_triggers:
  - "TODO.md file format"
  - "todo-management skill"
  - "todo-crud.sh"
  - "revisit the meeting"
  - "come back to the main branch"
description: "Use when: detecting deferral language in agent output. Captures loose ends immediately via todo-crud.sh and blocks completion claims if unresolved items exist. ENFORCEMENT, not CRUD."
summary: "Use when: deferral language detected or before claiming completion. Skip when: discussing todo-management tooling."
coordination:
  group: todo-enforcement
  order: 1
  requires: [todo-management]
  enables: [verification-before-completion]
  escalates_to: [quantitative-decision-gate]
  internal: false
---

# TODO Guardian

> **Wrong skill?** Creating TODOs → `todo-management`. Planning → `plan-and-execute`. Completion retrospective → see `verification-before-completion` Loose-Ends Retrospective section.

**Announce at start:** "I am using the **todo-guardian** skill to enforce TODO discipline."

## When to Use

- The moment explicit deferral language appears in your planned output
- Before claiming completion — audit for open `#loose-end` items
- At natural session milestones (before commit, before completion claim, at session end)
- When reviewing session for missed action items

## Deferral Language Patterns (High-Precision Only)

Capture immediately when you write any of these explicit commitment-to-defer phrases:

| Pattern | Examples |
|---------|---------|
| Explicit future commitment | "I'll fix this later", "I'll do this later", "I'll address this later", "I'll come back to this" |
| Explicit skip | "let me skip this for now", "I'll do this in a follow-up" |
| Explicit deferral | "I need to follow up on this later", "this needs follow-up" |

**Do NOT capture** coordination language like "for now let's use X", "we should also consider Y in a future PR", or "I noticed Z" — these are normal working speech, not deferral commitments.

## Enforcement Rules

### Rule 1: Capture or Block

Deferral language detected → record immediately with justification:

```bash
~/.codex/superpowers-plus/tools/todo-crud.sh add \
  --priority P3 \
  --description "<what was deferred> — deferred at <context>" \
  --note "Deferred reason: <why it can't be done now>" \
  --tags "#loose-end"
```

**Dedup check first:** Before adding, run the audit command below and scan for the same core item. If already present with `#loose-end`, skip — do not double-record.

**Justification is required at creation time.** There is no supported way to retrofit a note to an existing task. If you cannot state a deferral reason, the item should be resolved, not deferred.

NEVER allow deferral-language to pass without either (a) recording with `--note` or (b) resolving immediately.

### Rule 2: Audit at Milestones

At any natural session milestone (before a commit, at session end, before a completion claim), audit:

```bash
# Step A — Count (clean = count:0)
~/.codex/superpowers-plus/tools/todo-crud.sh --json list --tag "#loose-end" --all 2>&1
# Returns: {"tasks": [...], "count": N}
# count: 0 = clean. count > 0 = review each task.

# Step B — Inspect notes on any found items (to verify justification exists)
~/.codex/superpowers-plus/tools/todo-crud.sh cat 2>&1 | grep -A 3 "#loose-end"
# Each item block shows "Added:" and any "- Note:" lines.
```

`--all` is required to surface items moved to DEFERRED.

### Rule 3: Completion Gate

Before claiming any work is complete:

- [ ] Step A returns `count: 0`, OR all listed items have been reviewed
- [ ] Any `must-address` item is fully resolved
- [ ] Any `deferred` item: Step B confirms a note/reason line is present in its block

Items with no observable justification note → **BLOCK completion** → resolve or escalate to human.

### Rule 4: Session-End Sweep

At session end, report: Created: N · Resolved: M · Deferred with justification: K

Unresolved `#loose-end` items persist to the next session automatically — they will surface in the next run of `verification-before-completion`.

---

## Anti-Patterns

| Anti-Pattern | Detection | Correction |
|--------------|-----------|------------|
| Explicit deferral, no record | "I'll fix this later" → no add call | Record with `--note` immediately |
| Completion with open loose ends | Audit finds `#loose-end` items | Block; resolve or escalate |
| Missing creation-time justification | `--note` absent on deferred items | Cannot retrofit — escalate to human |
| Double-record | Same item added twice | Dedup scan before adding |
| Over-capture | Normal speech flagged as deferral | Check pattern table — only explicit commitment phrases trigger capture |

## Failure Modes

| Failure | Recovery |
|---------|----------|
| Missed deferral | Add retroactively; note it as retroactive in `--note` |
| False positive trigger | Add phrase to `anti_triggers` |
| Blocks incorrectly | Verify items are genuinely resolved; close them |

## Companion Skills

- **todo-management**: CRUD operations
- **verification-before-completion**: Completion gate (Loose-Ends Retrospective section)
- **plan-and-execute**: Planning sequences
- **quantitative-decision-gate**: TODO priorities
