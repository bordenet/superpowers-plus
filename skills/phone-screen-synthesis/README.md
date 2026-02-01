# Phone Screen Synthesis Skill

Transforms completed phone screen notes into an **actionable HIRE/NO-HIRE decision** with evidence-based rationale.

---

## 🔗 Cross-References

| Resource | Location | Update When |
|----------|----------|-------------|
| **This skill source** | `skills/phone-screen-synthesis/SKILL.md` | Changing synthesis logic |
| **Phone Screen Prep Skill** | `skills/phone-screen-prep/` | Creates the notes to synthesize |
| **Resume Screening Skill** | `skills/resume-screening/` | Original candidate evaluation |

### Dependency Chain

```
resume-screening skill (identifies concerns)
       │
       ▼ feeds into
phone-screen-prep skill (generates targeted STAR questions)
       │
       ▼ creates
Phone Screen Notes/FirstName_LastName__YYYY-MM-DD.md
       │
       ▼ interviewer fills notes during call
       │
       ▼ pastes completed notes to agent
       │
       ▼ THIS SKILL synthesizes
phone-screen-synthesis (produces actionable decision)
```

---

## Quick Start

```
1. Complete phone screen, filling in notes during call
2. Say: "Synthesize these phone screen notes"
3. Paste the completed notes
4. Get: HIRE or NO HIRE with Pros, Cons, Unknowns, and next steps
```

---

## Output Format

**CRITICAL: The output is designed for zero-filler actionable decisions.**

### Line 1: Decision
```
HIRE
```
or
```
NO HIRE
```

Just those words. No candidate name. No "probably" or "lean".

### All Outcomes
- **Pros**: Evidence-based strengths
- **Cons**: Evidence-based weaknesses  
- **Unknowns**: Areas we couldn't assess

### NO HIRE Only
- **Detractors**: Ordered list from worst to least bad

### HIRE Only
- **Follow-up for Interview Loop**: Ordered list of areas to probe in full interview

### Finally
- **Interview Details**: Questions asked and responses received

---

## What's Excluded

- Candidate name in verdict (the document is about the decision)
- Compensation details (unless material to NO HIRE)
- Subjective impressions ("seemed nice", "good culture fit")
- Hedged decisions ("maybe HIRE", "lean NO HIRE")

---

## Invocation

Say one of:
- "Synthesize these phone screen notes"
- "Summarize this phone screen"
- "What's the verdict on this candidate?"

Then paste the completed phone screen notes.

---

## Rubric-to-Decision Guide

| Profile | HIRE Threshold |
|---------|----------------|
| **IC Depth** | ≥1 Strong Yes in Technical Depth + no "No" ratings |
| **Team Lead** | ≥1 Strong Yes in Leadership + Yes in Communication |
| **Cross-Functional** | Yes or better in ≥4 of 6 competencies |

**Automatic NO HIRE:**
- "No" rating in Technical Depth (IC roles)
- "No" rating in Leadership (Team Lead roles)
- "No" rating in Communication (all roles)
- 2+ "No" ratings in any profile

---

## Files

| File | Purpose |
|------|---------|
| `SKILL.md` | Skill definition (Augment reads this) |
| `README.md` | Human documentation (you're reading this) |

---

## Version

- 1.0.0 — 2026-02-01: Initial release with actionable output format

