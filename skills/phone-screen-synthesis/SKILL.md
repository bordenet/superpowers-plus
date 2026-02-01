---
name: phone-screen-synthesis
description: "Synthesize completed phone screen notes into actionable HIRE/NO-HIRE decision with pros, cons, unknowns, and next steps."
---

# Phone Screen Synthesis

> **Guidelines:** See [CLAUDE.md](../../CLAUDE.md) for writing standards.
> **Last Updated:** 2026-02-01

---

## Purpose

Transform raw phone screen notes into an **actionable decision document**. The output must be immediately useful for hiring decisions with zero filler.

## Invocation

User says one of:
- "Synthesize these phone screen notes"
- "Summarize this phone screen"
- "What's the verdict on this candidate?"

Then pastes completed phone screen notes.

---

## Input

Completed phone screen notes containing:
- STAR question responses
- Rubric ratings (Strong Yes / Yes / Mixed / No)
- Follow-up notes
- Interviewer observations

---

## ⚠️ CRITICAL: Output Format

The output MUST follow this exact structure. **No deviation.**

```markdown
HIRE
```
or
```markdown
NO HIRE
```

Just those words. One line. No candidate name. No filler.

---

### For ALL Outcomes

```markdown
## Pros
- [Specific strength with evidence]
- [Specific strength with evidence]
- [Specific strength with evidence]

## Cons
- [Specific weakness with evidence]
- [Specific weakness with evidence]

## Unknowns
- [Area we couldn't assess in phone screen]
- [Information we still need]
```

---

### For NO HIRE Only

Add immediately after Unknowns:

```markdown
## Detractors (Ordered by Severity)
1. [MOST SEVERE: Dealbreaker issue with evidence]
2. [Second most severe issue]
3. [Third issue]
...
[Continue in order from worst to least bad]
```

---

### For HIRE Only

Add immediately after Unknowns:

```markdown
## Follow-up for Interview Loop
1. [Area to probe deeper in full interview]
2. [Skill to validate with coding/system design]
3. [Topic that needs more examples]
...
[Ordered by importance]
```

---

### Finally (All Outcomes)

```markdown
## Interview Details

### Questions Asked & Responses

**Q1: [Question text]**
[Summary of candidate's response]

**Q2: [Question text]**
[Summary of candidate's response]

...
```

---

## ⚠️ Rules

1. **HIRE or NO HIRE** — One line. No "Lean HIRE" or "Probably NO HIRE". Binary decision.

2. **No candidate name** in the verdict line. The document is about the decision, not the person.

3. **Evidence-based only** — Every Pro, Con, and Detractor must cite specific evidence from the interview.

4. **Omit compensation** unless it's material to a NO HIRE result (e.g., "Asked for $300k when cap is $180k").

5. **Ordered severity** — Detractors MUST be ordered worst-to-least-bad. This is critical for debrief discussions.

6. **Actionable follow-ups** — For HIRE, the follow-up list should guide the full interview loop, not repeat phone screen topics.

7. **No subjective impressions** — "Seemed nice" or "Good culture fit" are not valid Pros. Use behavioral evidence only.

---

## Rubric-to-Decision Mapping

Use this to convert rubric ratings to HIRE/NO HIRE:

| Profile | HIRE Threshold |
|---------|----------------|
| **IC Depth** | ≥1 Strong Yes in Technical Depth + no "No" ratings |
| **Team Lead** | ≥1 Strong Yes in Leadership + Yes in Communication |
| **Cross-Functional** | Yes or better in ≥4 of 6 competencies |

**Automatic NO HIRE triggers:**
- "No" rating in Technical Depth (for IC roles)
- "No" rating in Leadership (for Team Lead roles)
- 2+ "No" ratings in any profile
- "No" rating in Communication (all roles)

---

## Example Output (NO HIRE)

```markdown
NO HIRE

## Pros
- Strong technical depth in distributed systems (explained Raft consensus clearly)
- Good communication skills (adjusted explanations to interviewer's questions)

## Cons
- No evidence of ownership beyond assigned tasks
- Couldn't articulate learning from past failures
- All examples were "we" not "I"

## Unknowns
- Actual individual contribution at previous role
- How they handle ambiguity (all examples were well-defined projects)

## Detractors (Ordered by Severity)
1. **No ownership evidence**: Every example was team-based with no clear individual contribution. When pressed, couldn't identify specific decisions they made.
2. **Defensive about failures**: Asked twice about mistakes; pivoted to team mistakes both times. No evidence of learning agility.
3. **Contribution ambiguity**: Used "we" throughout; couldn't clearly articulate what they personally built vs. reviewed.

## Interview Details

### Questions Asked & Responses

**Q1: "Tell me about a time you made a technical decision that was later proven wrong."**
Described a team decision about database choice. When asked about their role, said "I was part of the discussion." Couldn't identify what they specifically advocated for.

**Q2: "Tell me about a system you built from scratch."**
Described a microservices migration. Their role was "helping with the design and doing code reviews." Couldn't identify code they personally wrote.
```

---

## Example Output (HIRE)

```markdown
HIRE

## Pros
- Deep technical ownership (led database migration from MySQL to PostgreSQL, made schema decisions, handled rollback plan)
- Strong debugging methodology (described systematic approach to production incident, identified root cause in 2 hours)
- Clear career growth (IC → Tech Lead → IC by choice, articulated reasons for each transition)

## Cons
- Limited experience with real-time systems (all background is request-response)
- No LLM integration experience (will need ramp-up time)

## Unknowns
- How they handle startup ambiguity (all experience at structured companies)
- Team dynamics preferences (solo examples were strong, collaboration examples less detailed)

## Follow-up for Interview Loop
1. **System design round**: Test real-time architecture knowledge (WebSockets, event streaming)
2. **Coding round**: Include ambiguous requirements to test comfort with uncertainty
3. **Team fit discussion**: Probe collaboration style, especially with less experienced engineers
4. **LLM integration**: Quick assessment of learning agility with new tech

## Interview Details

### Questions Asked & Responses

**Q1: "Tell me about the database migration you led."**
Owned the full project: evaluated PostgreSQL vs alternatives, designed migration strategy with dual-write period, created rollback runbook. Result: zero-downtime migration, 40% query improvement.

**Q2: "Tell me about a production incident you debugged."**
Memory leak in payment service. Systematically eliminated causes using heap dumps, identified connection pool exhaustion, fixed within 2 hours. Added monitoring to prevent recurrence.
```

