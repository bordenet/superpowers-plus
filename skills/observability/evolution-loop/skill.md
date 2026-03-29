---
name: evolution-loop
source: superpowers-plus
triggers:
  - "improve the skills"
  - "self-improve"
  - "learn from mistakes"
  - "skill evolution"
  - "recurring pattern"
  - "keeps happening"
anti_triggers:
  - "improve the code"
  - "improve performance"
  - "upgrade dependencies"
description: "Self-improvement cycle: scans session logs, failure autopsies, and decision logs for recurring patterns. Auto-generates skill updates or new skills. Tracks improvement metrics over time."
summary: "Use when: reviewing outcomes for improvement. Skip when: mid-task."
coordination:
  group: meta-improvement
  order: 1
  requires: [failure-autopsy, measurement-integrity]
  enables: [skill-authoring]
  escalates_to: []
  internal: false
---

# Evolution Loop

> **Wrong skill?** New skill from scratch -> skill-authoring. Post-mortem -> failure-autopsy. Skill formatting -> skill-health-check.

**Announce at start:** "I am using the **evolution-loop** skill to identify improvement opportunities."

## When to Use

- At end of significant session (3+ hours)
- After failure autopsies reveal a pattern
- When same mistake occurs 3rd time
- During deliberate improvement sprints


### Example

```bash
# Example: Pattern detection from failure log
echo "=== Recurring Patterns ==="
echo "| Pattern        | Count | Affected Skill | Action          |"
echo "| File not found | 3     | save-file      | Add path verify |"
echo "| Wrong branch   | 2     | pre-commit     | Add branch gate |"
echo "Actions: 2 skill updates queued"
```

## Evolution Protocol

### Step 1: Scan Sources

Failure log, decision log, conversation struggles, recurring TODO deferrals.

### Step 2: Classify

| Type | Signal | Action |
|------|--------|--------|
| Repeated failure | Same root cause 2+ | Update failure modes |
| Missing trigger | Skill does not fire | Add trigger |
| Missing skill | No coverage | Draft via skill-authoring |
| Weak gate | False passes | Strengthen criteria |
| Process gap | Manual step | Automate in skill |

### Step 3: Generate Updates

**Pattern** + **Frequency** + **Affected skill** + **Update type** + **Change**

### Step 4: Track

Patterns detected: N . Skills updated: M . New skills: K . Failures eliminated: J

---

## Anti-Patterns

| Anti-Pattern | Detection | Correction |
|--------------|-----------|------------|
| Over-fitting | Skill for one-time event | Require 2+ occurrences |
| Metrics-free update | No before/after | Add measurement-integrity |
| Endless self-improvement | Self-modifies repeatedly | Cap: 1 self-update/session |
| Ignoring data | Pattern found, no action | Generate PR or TODO |

## Failure Modes

| Failure | Detection | Recovery |
|---------|-----------|----------|
| Useless skills | Never triggers | Review triggers, add examples |
| Over-fitting | Created for one-time event | Require 2+ occurrences |
| No metrics | No before/after | Add measurement-integrity |
| Self-referential loop | Improves itself endlessly | Cap: 1 self-update/session |

## Companion Skills

- **failure-autopsy**: Primary input (failure patterns)
- **skill-authoring**: Creating new skills from patterns
- **skill-health-check**: Validating updates
- **measurement-integrity**: Tracking metrics
- **quantitative-decision-gate**: Deciding which patterns matter
