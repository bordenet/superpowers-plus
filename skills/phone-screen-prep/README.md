# Phone Screen Prep Skill

A [superpowers skill](../install-augment-superpowers.sh) that generates phone screen notes files with targeted questions based on resume screening concerns.

---

## 🔗 Cross-References

| Resource | Location | Update When |
|----------|----------|-------------|
| **This skill source** | `superpowers-skills/phone-screen-prep/skill.md` | Changing skill logic |
| **Phone Screen Template** | `a.People/Recruiting/Phone Screen Notes/_TEMPLATE.md` | Changing interview structure |
| **Phone Screen Guide** | `a.People/Recruiting/Sr Eng Phone Screen Guide.md` | Changing questions or flow |
| **Resume Screening Skill** | `superpowers-skills/resume-screening/` | Changing what concerns to probe |
| **Completed Examples** | `a.People/Recruiting/Phone Screen Notes/DONE/` | Reference past interviews |
| **Wiki LLM Prompt** | [wiki.int.callbox.net](https://wiki.int.callbox.net/doc/llm-prompt-LfFH19Gj0y) | Source of truth for criteria |

### Dependency Chain

```
resume-screening skill (identifies concerns)
       │
       ▼ feeds into
phone-screen-prep skill (THIS SKILL — generates targeted questions)
       │
       ▼ copies and customizes
_TEMPLATE.md (master template)
       │
       ▼ creates
Phone Screen Notes/FirstName_LastName__YYYY-MM-DD.md
       │
       ▼ interviewer fills, then pastes back for
phone-screen-synthesis skill (produces actionable HIRE/NO-HIRE decision)
```

---

## Quick Start

```
1. Screen candidate first: "Screen at $150k cap" + resume
2. Then say: "Prep phone screen for Alex Tang"
3. Agent creates: a.People/Recruiting/Phone Screen Notes/Alex_Tang__2026-01-20.md
```

---

## What It Does

1. **Runs resume screening** on the candidate to identify concerns
2. **Copies template** from `_TEMPLATE.md`
3. **Creates file** with naming convention: `FirstName_LastName__YYYY-MM-DD.md`
4. **Adds targeted STAR questions** based on screening flags:
   - All questions use STAR format (Situation-Task-Action-Result)
   - Each question includes mandatory follow-ups
   - Probing depth calibrated by severity (1Q / 2-3Q / Deep dive)
5. **Includes interview rubric** with 6 competencies and behavioral anchors
6. **Adds bias audit checklist** for interviewer self-check

---

## Invocation

Say one of:
- "Prep phone screen for [First Last]"
- "Create phone screen file for [Name]"
- "Set up interview notes for [Name]"

Include:
- Resume (required — for screening concerns)
- Paylocity URL (optional)
- LinkedIn URL (optional)
- GitHub URL (optional)

---

## Output

Creates a file like:

```markdown
# Phone Screen: Alex Tang

**Date:** 2026-01-20
**Role:** Senior Software Engineer (Team Delta)
...

## ⚠️ Screening Concerns — Targeted Questions

### 1. 🔴 5-Month Tenure at Rocket Lawyer
**Concern:** Left Amazon L6 after 4.5 years, then only 5 months at Rocket Lawyer.

_"You were at Amazon for 4.5 years at L6 — that's senior. Then you went to 
Rocket Lawyer in July 2025 and left in November. Walk me through what happened."_

### 2. 🟡 Backend → Frontend Pivot
**Concern:** Amazon was Java/Python/Go backend. Rocket Lawyer is Next.js/React frontend.

_"Your Amazon role was distributed backend. Your Rocket Lawyer role is UI components. 
What's going on with your career trajectory?"_
...
```

---

## STAR Question Format

All questions use behavioral STAR format with mandatory follow-ups:

```markdown
**[Flag]** — Severity: [Minor/Moderate/Serious]
_"Tell me about a time when [situation]. What was the challenge?
What action did you take? What was the result?"_
**Follow-up:** _"What would you do differently?"_
```

---

## Common Concerns to Probe (STAR Format)

| Concern | STAR Question |
|---------|---------------|
| Short tenure | _"Tell me about a time you left a role earlier than planned. What was the situation? How did you make the decision? What was the outcome?"_ |
| Frontend-heavy | _"Tell me about a time you built a backend system from scratch. What was the challenge? How did you design the data model? What was the result?"_ |
| Contractor pattern | _"Tell me about a time you maintained ownership in a contract role. What was the situation? How did you ensure quality? What was the outcome?"_ |
| Single employer | _"Tell me about a time you had to build something without established patterns. What was the situation? How did you make decisions? What was the result?"_ |
| AI content concerns | _"Tell me about [specific claim] in your own words. What were the challenges? What would you do differently?"_ |

---

## Interview Rubric (6 Competencies)

| Competency | What to Evaluate |
|------------|------------------|
| **Technical Depth** | Explains architectural decisions at multiple abstraction levels |
| **Systems Thinking** | Considers failure modes, scale, and operational concerns |
| **Problem-Solving** | Breaks down ambiguous problems, considers alternatives |
| **Communication** | Explains complex concepts clearly, adjusts to audience |
| **Leadership/Influence** | Influences without authority, mentors effectively |
| **Learning Agility** | Learns new domains quickly, applies patterns across contexts |

**Rating Scale:** Strong Yes / Yes / Mixed / No

---

## Probing Depth by Severity

| Severity | Probing Depth | Approach |
|----------|---------------|----------|
| Minor (Yellow) | 1 STAR question | Accept reasonable explanation |
| Moderate (Orange) | 2-3 follow-ups | Seek specific examples |
| Serious (Red) | Deep dive | Request references if needed |

---

## After the Phone Screen

1. Fill in notes during the call
2. Paste completed notes back to Augment
3. Say: "Synthesize these notes"
4. Agent invokes `phone-screen-synthesis` skill for actionable decision:
   - **HIRE** or **NO HIRE** (binary, no filler)
   - Pros, Cons, Unknowns
   - Detractors ordered by severity (NO HIRE) or Follow-up questions (HIRE)

---

## Files

| File | Purpose |
|------|---------|
| `skill.md` | Skill definition (Augment reads this) |
| `README.md` | Human documentation (you're reading this) |

---

## Bias Audit Checklist

Interviewers complete before submitting evaluation:

- [ ] Did I evaluate contractor experience in context?
- [ ] Did I focus on capability evidence, not pedigree?
- [ ] Did I distinguish AI polish from fabrication?
- [ ] Did I use structured criteria, not "gut feel"?
- [ ] Did I consider accessibility accommodations?

---

## Version

- 2.0.0 — 2026-02-01: **Major update** — STAR format questions, 6-competency interview rubric, probing depth calibration, contractor assessment protocol, role-specific profiles, accessibility options, bias audit checklist
- 1.1.0 — 2026-01-20: Added cross-references and contractor probes
- 1.0.0 — 2026-01-13: Initial release

