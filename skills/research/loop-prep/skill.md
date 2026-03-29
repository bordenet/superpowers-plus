---
name: loop-prep
source: superpowers-[product]
description: "Phase 4: Prepare for 1-hour interview loop session. Use when user says 'prep loop interview', 'system design prep for', 'implementation interview prep', 'behavioral prep for'. Generates session-specific question bank, rubric, and probing areas from phone screen."
triggers: ["prep loop interview", "system design prep for", "implementation interview prep", "behavioral prep for"]
coordination:
  group: research
  order: 5
  requires: []
  enables: []
  escalates_to: []
  internal: true
---

# Loop Prep

## When to Use

- Preparing for a 1-hour interview loop session (system design, implementation, or behavioral)
- User says "prep loop interview", "system design prep for", "implementation interview prep"
- Generates session-specific question bank, rubric, and probing areas from phone screen

> **Pipeline Position:** Phase 4 of 5
> **Input:** Phone screen synthesis + session type
> **Output:** 1-hour interview prep with rubric
> **Next Phase:** loop-synthesis (after interview)

---

## Session Types

| Type | Duration | Focus | Rubric |
|------|----------|-------|--------|
| **System Design** | 60 min | Architecture, tradeoffs, scale | Technical depth |
| **Implementation** | 60 min | Coding, debugging, pragmatism | Code quality |
| **Behavioral** | 60 min | Quadrants, growth mindset, collaboration | Career ladder |

**Ask user which session type before generating prep.**

---

## Required Inputs

1. **Candidate name**
2. **Session type** (System Design / Implementation / Behavioral)
3. **Phone screen synthesis** (for probing areas)
4. **Interviewer name** (who is conducting this session)

---

## Output Format

```markdown
# Loop Prep: [Candidate Name]

**Session:** [System Design | Implementation | Behavioral]
**Date:** YYYY-MM-DD
**Duration:** 60 minutes
**Interviewer:** [Name]
**Previous Stage:** [Link to phone screen synthesis]

---

## 📋 Pre-Interview Context

**From Phone Screen:**
- Verdict: [HIRE / STRONG HIRE]
- Key strengths: [From synthesis]
- Key concerns: [From synthesis]

**Areas to Probe (Carried Forward):**

| Area | Why | Source |
|------|-----|--------|
| [Gap] | [Evidence] | Phone screen |
| [Gap] | [Evidence] | Phone screen |

---

## ⏱️ Time Allocation

| Segment | Time | Focus |
|---------|------|-------|
| Intro + Context | 5 min | Rapport, set expectations |
| [Main Activity] | 45 min | [Session-specific] |
| Q&A + Close | 10 min | Candidate questions, sell |

---

## 🎯 Session-Specific Questions

### [Question 1 Title]

**Question:** [Full question text]

**What Good Looks Like:**
- [L2/Senior signal]
- [L2/Senior signal]

**Red Flags:**
- [Concern pattern]
- [Concern pattern]

**Notes:**
_[Space for interviewer notes]_

---

### [Question 2 Title]

**Question:** [Full question text]

**What Good Looks Like:**
- [L2/Senior signal]

**Red Flags:**
- [Concern pattern]

**Notes:**
_[Space for interviewer notes]_

---

## 📊 Scoring Rubric

### [Dimension 1]

| Score | Description |
|-------|-------------|
| 4 | Exceptional — [L3+ signal] |
| 3 | Meets bar — [L2 signal] |
| 2 | Below bar — [L1 signal] |
| 1 | Significant gap — [Concern] |

### [Dimension 2]

| Score | Description |
|-------|-------------|
| 4 | Exceptional |
| 3 | Meets bar |
| 2 | Below bar |
| 1 | Significant gap |

---

## 🚨 Red Flags to Watch

| Flag | What It Looks Like | Action |
|------|-------------------|--------|
| AI assistance | Reading, long pauses, perfect structure | Note, probe deeper |
| Rehearsed answers | Too polished, no stumbles | Ask follow-up |
| Vague on details | "We did X" vs "I did X" | Clarify ownership |

---

## 📝 Running Notes

_[Space for live notes during interview]_

---

## Post-Interview

**After interview, invoke `loop-synthesis` to create debrief.**
```

---

## Session-Specific Guidance

### System Design Session

**Time allocation:**
- 5 min: Intro, problem statement
- 10 min: Requirements gathering, clarifying questions
- 30 min: Design, components, tradeoffs
- 5 min: Scale discussion, failure modes
- 10 min: Q&A

**Dimensions to score:**
- Requirements gathering
- Architecture clarity
- Tradeoff articulation
- Scale awareness
- Communication

### Implementation Session

**Time allocation:**
- 5 min: Intro, problem statement
- 45 min: Coding, debugging, iteration
- 10 min: Q&A

**Dimensions to score:**
- Code quality
- Problem decomposition
- Debugging approach
- Testing awareness
- Communication

### Behavioral Session

**Time allocation:**
- 5 min: Intro
- 45 min: STAR questions (Growth Mindset, Customer Obsession, Conflict)
- 10 min: Q&A

**Dimensions to score:**
- Growth Mindset (L2 bar)
- Customer Obsession (L2 bar)
- Conflict Management (L2 bar)
- Self-awareness
- Communication

---

## Cross-References

| Resource | Location |
|----------|----------|
| Phone Screen Synthesis | `phone-screen-synthesis/skill.md` |
| Loop Synthesis (next) | `loop-synthesis/skill.md` |
| Career Ladder | [wiki](https://wiki.int.[company].net/doc/sr-sde-career-ladder-xMt5Ry9Jwp) |
| Four Quadrants | [wiki](https://wiki.int.[company].net/doc/core-behaviors-the-four-quadrants-8d4JNjomwk) |
| Behavioral Questions | [wiki](https://wiki.int.[company].net/doc/sr-sde-interview-growth-mindset-BgjtGgDyM7) |

*Last updated: 2026-03-03 | Pipeline overhaul v1*
