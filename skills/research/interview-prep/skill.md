---
name: interview-prep
source: superpowers-recruiting
description: "Use when preparing for a behavioral interview loop, setting up hiring manager interview questions, or before a candidate's final round."
triggers: ["prep interview for", "create behavioral sheet for", "interview tomorrow", "HM interview prep"]
---

# Interview Prep

## When to Use

- Preparing for a behavioral interview loop or hiring manager interview
- User says "prep interview for", "interview [candidate] tomorrow", "HM interview prep"
- For loop-specific prep (system design, implementation sessions), use `loop-prep` instead
- Generates structured interview prep with questions, rubric, and probing areas

> **Pipeline:** Phase 3 of 5 | **Next:** interview-synthesis
> **Input:** Phone screen notes OR application Q&A + CV
> **Output:** `$RECRUITING_DIR/Interview Prep/{Name}__interview-prep__{YYYY-MM-DD}.md`
> **Env:** `$RECRUITING_DIR` — run `source ~/.codex/.env`

> **📋 Wiki guides:** [Growth Mindset](https://wiki.int.callbox.net/doc/sr-sde-interview-growth-mindset-BgjtGgDyM7) | [Customer Obsession](https://wiki.int.callbox.net/doc/sr-sde-interview-customer-obsession-D6XD06u1OI) | [Conflict Management](https://wiki.int.callbox.net/doc/sr-sde-interview-conflict-management-q0IAhH7SS6) | [Flex Probes](https://wiki.int.callbox.net/doc/sr-sde-interview-flex-coverage-and-follow-up-probes-x0yBsXvMH1) | [Closing](https://wiki.int.callbox.net/doc/sr-sde-interview-candidate-experience-and-closing-nQui9kY7Dv)
> **⚠️ Check wiki for updates before each loop.**

---

## 🚨 PII WARNING

| What | Git Status |
|------|------------|
| Skill file (`skill.md`) | ✅ Git-tracked |
| Interview prep files (`$RECRUITING_DIR/Interview Prep/*.md`) | ❌ **NEVER COMMIT** (OneDrive) |

---

## 🚨 MANDATORY: Four Required Sections

**EVERY interview sheet MUST include ALL FOUR. Do not skip or substitute.**

### 1. Growth Mindset (REQUIRED)
> "Tell me about a time you received critical feedback that was hard to hear. How did you respond, and what changed? **Focus on something out of the ordinary, though. Something you didn't really expect.**"

### 2. Customer Obsession (REQUIRED)
> "Describe a time you advocated for a customer need that wasn't popular or convenient internally. **Please be as specific as possible so I can understand what you did, especially in the very first steps.**"

### 3. Conflict Management (REQUIRED)
> "Describe a conflict that got worse before it got better. What happened, and what did you learn? **Focus on a situation where you weren't sure you were right — where it was genuinely ambiguous.**"

### 4. Systems Design (REQUIRED)
> Choose from: Context Carryover, Interruption Handling, or Custom (based on candidate background). See `references/questions-and-signals.md` for full options, probing questions, and signals.

**Incident 2026-03-04:** Interview sheet for Matthew Beckerleg was missing systems design. Now MANDATORY.

---

## 🎯 AI-Tripwire Extensions

**Apply at least ONE to EVERY behavioral question** to defeat AI-assisted cheating:

| Extension | Purpose |
|-----------|---------|
| "Focus on something out of the ordinary" | Forces unique, non-templated answer |
| "Please be as specific as possible" | Demands concrete details AI can't fabricate |
| "Focus on a situation where you weren't sure" | Requires genuine ambiguity |
| "Walk me through the first thing you did" | Tests real memory |
| "What was the dumbest thing you tried?" | AI won't volunteer failures |

---

## Question Depth Selection

| Phone Screen Signal | Recommended Depth |
|---------------------|-------------------|
| Strong signal | Start at L2, probe L3 if time |
| Weak/unclear | Start at L1, escalate based on answers |
| Concern flagged | Start at L1, use deepening probes |
| No data | Full L1 → L2 → L3 progression |

---

## Pre-Delivery Validation Checklist

| # | Check | Required |
|---|-------|----------|
| 1 | Growth Mindset question included? | ✅ MANDATORY |
| 2 | Customer Obsession question included? | ✅ MANDATORY |
| 3 | Conflict Management question included? | ✅ MANDATORY |
| 4 | Systems Design question included? | ✅ MANDATORY |
| 5 | Each behavioral has AI-tripwire extension? | ✅ MANDATORY |
| 6 | Follow-up probes for each behavioral? | ✅ MANDATORY |
| 7 | Signal Checklist present? | ✅ MANDATORY |
| 8 | YAML metadata header? | ✅ MANDATORY |
| 9 | Post-Interview → interview-synthesis? | ✅ MANDATORY |

**If ANY item missing, DO NOT deliver.**

---

## Reference Files

| File | Contents |
|------|----------|
| `references/output-template.md` | Full document structure, YAML header, signal checklist |
| `references/questions-and-signals.md` | Behavioral questions with L2 signals/red flags, systems design options, deepening probes |

## Example Usage

```bash
source ~/.codex/.env
# Check for existing prep files
ls "$RECRUITING_DIR/Interview Prep/" | grep -i "lastname"
```

## Cross-References

| Resource | Location |
|----------|----------|
| Phone Screen Prep | `phone-screen-prep/skill.md` |
| Interview Synthesis | `interview-synthesis/skill.md` |
| Debrief Meetings | [wiki](https://wiki.int.callbox.net/doc/interview-de-brief-meetings-W54Bdc0U76) |
| Four Quadrants | [wiki](https://wiki.int.callbox.net/doc/core-behaviors-the-four-quadrants-8d4JNjomwk) |
