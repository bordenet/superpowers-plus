---
name: skill-effectiveness
source: superpowers-plus
triggers: ["record outcome", "skill worked", "skill failed", "skill didn't help", "that fixed it", "wrong approach", "analyze triggers", "learning report"]
description: Track skill outcomes to improve the system over time. Record success/failure after skill invocations, analyze trigger effectiveness, suggest improvements.
---

# Skill Effectiveness Tracking

Track outcomes of skill invocations to improve the superpowers system over time.

**Announce at start:** "I'm using the skill-effectiveness skill to record this outcome."

---

## When to Record Outcomes

Record outcomes **after completing work that was guided by a skill**:

| Outcome | When to Record | Example |
|---------|----------------|---------|
| ✅ Success | Skill guidance led to working solution | Bug fixed, tests pass |
| ❌ Failure | Skill guidance led wrong direction | Had to abandon approach |

---

## Commands

### Record an Outcome

After any skill-guided work completes:

```bash
node ~/.codex/superpowers-augment/superpowers-augment.js record-outcome <skill> <success|failure> [evidence]
```

**Examples:**
```bash
# After systematic-debugging found the bug
record-outcome systematic-debugging success "root cause identified, fix verified"

# After brainstorming produced approved design
record-outcome brainstorming success "design approved, ready for implementation"

# After TDD led to over-engineered solution
record-outcome test-driven-development failure "tests passed but solution too complex, had to simplify"
```

### View Trigger Analysis

```bash
node ~/.codex/superpowers-augment/superpowers-augment.js analyze-triggers
```

Shows:
- Success rate by skill
- Common trigger phrases
- Pending improvement suggestions

### Full Report

```bash
node ~/.codex/superpowers-augment/superpowers-augment.js learning-report
```

Shows:
- Overall statistics
- Skills needing attention
- Emerging patterns (potential new skills)
- Pending suggestions

### Record a Pattern

When you notice yourself doing the same multi-step sequence repeatedly:

```bash
node ~/.codex/superpowers-augment/superpowers-augment.js record-pattern "description" potential-skill-name
```

**Example:**
```bash
record-pattern "Always check for TypeScript strict mode errors after adding new types" typescript-strict-check
```

### Suggest a Trigger

When a skill should have fired but didn't:

```bash
node ~/.codex/superpowers-augment/superpowers-augment.js suggest-trigger <skill> <phrase>
```

### Check Synthesis Candidates

Find patterns ready to become skills (frequency ≥ 3):

```bash
node ~/.codex/superpowers-augment/superpowers-augment.js check-synthesis-candidates
```

When candidates exist, invoke `skill-authoring` Mode 2 to create the skill.

---

## Integration with Workflow

### After Every Skill Invocation

1. Complete the work guided by the skill
2. Evaluate: Did the skill help or hinder?
3. Record the outcome with evidence

### At Session End

Review outcomes for the session:
```bash
node ~/.codex/superpowers-augment/superpowers-augment.js learning-status
```

### Weekly Review

Generate full report:
```bash
node ~/.codex/superpowers-augment/superpowers-augment.js learning-report
```

---

## Success Rate Thresholds

| Rate | Status | Action |
|------|--------|--------|
| ≥80% | ✅ Healthy | No action needed |
| 50-79% | 🟡 Monitor | Review common failures |
| <50% | 🔴 Needs work | Investigate and fix skill |

---

## Data Location

Learning state is stored at:
```
~/.codex/.learning-state.json
```

This persists across sessions and enables cross-session learning.

---

## Skill Synthesis (Phase C) ✅

When patterns reach sufficient frequency, they become candidates for new skills:

1. Pattern observed 3+ times → flagged as "emerging"
2. Run `check-synthesis-candidates` to review candidates
3. User confirms pattern is valuable → invoke `skill-authoring` Mode 2
4. User refines triggers and content → new skill deployed

### Check for Synthesis Candidates

```bash
node ~/.codex/superpowers-augment/superpowers-augment.js check-synthesis-candidates
```

This displays patterns with frequency ≥ 3 that haven't been synthesized yet:

| # | Pattern | Freq | Suggested Name | Last Seen |
|---|---------|------|----------------|-----------|
| 1 | Always run lint before commit | 5x | pre-commit-lint | 2026-03-15 |
| 2 | Check for API key exposure... | 3x | secret-diff-check | 2026-03-14 |

### Create a Skill from a Pattern

When you see a good candidate, tell the AI:
> "Turn this pattern into a skill: [pattern description]"

This invokes `skill-authoring` Mode 2 (from-patterns), which guides you through skill creation.

This closes the feedback loop: **usage → outcomes → patterns → new skills → usage**.
