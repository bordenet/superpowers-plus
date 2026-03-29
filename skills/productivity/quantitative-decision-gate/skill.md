---
name: quantitative-decision-gate
source: superpowers-plus
triggers:
  - "should I"
  - "do you want me to"
  - "which approach"
  - "deciding between"
  - "trade-off"
  - "weighing options"
anti_triggers:
  - "should I use this skill"
  - "should I announce"
  - "clarifying question about requirements"
description: "HARD GATE — Forces quantitative evaluation with a decision matrix before ANY question to the user. If the agent can score options numerically, it MUST choose highest-scoring and PROCEED. Only escalate when top 2 score within 10% AND decision is irreversible."
summary: "Use when: about to ask user to decide. Skip when: genuine requirements clarification."
coordination:
  group: decision-making
  order: 1
  requires: []
  enables: [brainstorming, design-triad, plan-and-execute]
  escalates_to: [think-twice]
  internal: false
---

# Quantitative Decision Gate

> **Wrong skill?** Design evaluation -> design-triad. Creative options -> brainstorming. Stuck -> think-twice.

**Announce at start:** "I am using the **quantitative-decision-gate** skill to evaluate options quantitatively."

## When to Use

- Before asking the user "should I...?" or "do you want me to...?"
- When choosing between 2+ implementation approaches
- When deciding whether to continue, pivot, or stop a task
- When evaluating trade-offs (speed vs quality, scope vs time)

### Example

```bash
# Example: Deciding between extract-method vs inline
echo "Decision: refactor approach"
echo "| Dimension    | Wt   | Extract | Inline |"
echo "| Impact       | 0.35 | 8       | 4      |"
echo "| Effort (inv) | 0.25 | 6       | 9      |"
echo "| Risk (inv)   | 0.25 | 7       | 8      |"
echo "| Reversible   | 0.15 | 9       | 9      |"
echo "| Weighted     |      | 7.35    | 6.85   |"
echo "Margin: 7% -> AUTO-SELECT extract-method"
```

## The Decision Matrix Protocol

### Step 1: Frame

State: "I need to decide: **[decision]**". List options (min 2, max 5).

### Step 2: Score (4 mandatory dimensions)

| Dimension | Weight | Option A | Option B |
|-----------|--------|----------|----------|
| Impact | 0.35 | 8 | 6 |
| Effort (inv) | 0.25 | 9 (low) | 4 (high) |
| Risk (inv) | 0.25 | 7 (low) | 8 (low) |
| Reversibility | 0.15 | 9 | 5 |
| **Weighted** | | **8.15** | **5.85** |

Score 1-10 (10=best). Effort is INVERSE (high score = low effort).

### Step 3: Decision Rule

- Margin > 10% -> AUTO-SELECT. Proceed without asking.
- Margin < 10% + reversible -> AUTO-SELECT with note.
- Margin < 10% + irreversible -> Present matrix to user.

### Step 4: Log

Record: decision, scores, 1-sentence rationale.

---

## Anti-Patterns

| Anti-Pattern | Detection | Correction |
|--------------|-----------|------------|
| Asking user a quantifiable decision | "should I" + options exist | Build matrix, auto-select |
| Victory-claiming without data | "better" without numbers | Produce the numbers |
| False ceiling diagnosis | "impossible because X" | Try 2 more approaches first |
| Single-option framing | "Should I do X?" only | Generate >=1 alternative |
| Gut-feel decision | "feels right" | Score it. Numbers confirm or deny |

## Failure Modes

| Failure | Detection | Recovery |
|---------|-----------|----------|
| Matrix not followed | Decision != highest score | Re-examine scoring |
| All options tie | Within 5% | Add context-specific 5th dimension |
| Scoring bias | One option all 9s/10s | Red-team: argue FOR the loser |
| Decision not acted on | TODO but no action | Execute or defer with reason |

## Companion Skills

- **think-twice**: When matrix reveals a trap
- **design-triad**: Multi-option design evaluation
- **brainstorming**: Generating options for the matrix
- **plan-and-execute**: Executing the chosen option
- **failure-autopsy**: Post-mortem if chosen option fails
