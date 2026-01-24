# Resume Screening Skill

A [superpowers skill](../install-augment-superpowers.sh) that evaluates Senior SDE candidates against CallBox's hiring bar. Outputs HIRE/NO-HIRE/PROBE with targeted phone screen questions.

---

## 🔗 Cross-References

| Resource | Location | Update When |
|----------|----------|-------------|
| **This skill source** | `superpowers-skills/resume-screening/skill.md` | Changing evaluation logic |
| **Wiki LLM Prompt** | [wiki.int.callbox.net](https://wiki.int.callbox.net/doc/llm-prompt-LfFH19Gj0y) | **Source of truth** — check daily |
| **Phone Screen Prep Skill** | `superpowers-skills/phone-screen-prep/` | Uses concerns from this skill |
| **Phone Screen Template** | `a.People/Recruiting/Phone Screen Notes/_TEMPLATE.md` | Interview structure |
| **Comp Models** | `a.People/Recruiting/Team Delta Comp Models.xlsx` | Salary ranges |

### Dependency Chain

```
Wiki LLM Prompt (source of truth for criteria)
       │
       ▼ copy criteria into
resume-screening/skill.md (THIS SKILL)
       │
       ▼ outputs concerns that feed
phone-screen-prep skill (generates targeted questions)
       │
       ▼ creates
Phone Screen Notes/FirstName_LastName__YYYY-MM-DD.md
```

---

## Quick Start

```
1. Open Augment chat (Cmd+Shift+I)
2. Say: "Screen at $150k cap"
3. Paste resume + Paylocity screening answers
4. Get: HIRE / NO-HIRE / PROBE with rationale
```

---

## What It Does

Evaluates candidates on a 100-point scale:

| Category | Max Points |
|----------|------------|
| Experience Depth | 20 |
| Scale/Complexity | 15 |
| Stability | 10 |
| Technical Depth | 15 |
| Debugging Ability | 10 |
| Leadership | 5 |
| Salary Fit | 5 |
| AI Slop Penalty | -20 |
| Contractor Penalty | -35 |

### Verdicts

| Score | Verdict | Action |
|-------|---------|--------|
| ≥75 | **HIRE** | Schedule phone screen, ask all 7 questions |
| 50-74 | **PROBE** | Schedule phone screen, focus on specific flags |
| <50 | **NO-HIRE** | Reject with reason |

---

## Invocation

Say one of:
- "Screen at $150k cap" + paste resume
- "Evaluate this candidate for Senior SDE"
- "Is this resume a fit for Team Delta?"

---

## Key Evaluation Criteria

### Must Have
- 5+ years production software development
- Backend experience (not just frontend)
- Cloud infrastructure (AWS/GCP/Azure)
- Database experience (SQL or NoSQL)
- Scale evidence (DAU, latency, data volume)

### Red Flags (Auto-Reject)
- <5 years experience
- Frontend-only
- Consulting/agency-only (no product ownership)
- 3+ consecutive contractor roles
- AI slop in screening answers (5+ patterns)
- Requires work sponsorship

### Yellow Flags (Need Probing)
- Short tenure pattern (<2 years average)
- Stack mismatch (no Node.js/TypeScript)
- Contribution ambiguity ("we" not "I")
- Single employer entire career

---

## Contractor Scoring

| Pattern | Penalty |
|---------|---------|
| 2 consecutive contracts | -10 |
| 3+ consecutive contracts | -25 |
| >50% career as contractor | -30 |
| Contract at unknown company | -5 |

---

## AI Slop Detection

Patterns that indicate ChatGPT-generated answers:

- "commitment to innovative solutions"
- "values creativity and teamwork"
- "eager to leverage my expertise"
- "drive impactful outcomes"
- No specific company reference (CallBox, automotive, voice AI)

**5+ patterns = -20 points + yellow flag**

---

## Output Format

```markdown
# Resume Screening: [Name]

## [HIRE/NO-HIRE/PROBE]

[1-2 sentence rationale]

## Phone Screen Questions (by priority)
1. 🔴 [Critical concern question]
2. 🟡 [Important concern question]
...

## Scoring Table
| Category | Raw | Adjustments | Final | Max | Notes |
...

## Flags
| Flag | Severity | Covered By |
...
```

---

## Files

| File | Purpose |
|------|---------|
| `skill.md` | Skill definition (Augment reads this) |
| `README.md` | Human documentation (you're reading this) |

---

## Version

- 1.5.0 — 2026-01-20: Added contractor penalty scoring, cross-references
- 1.4.0 — 2026-01-15: Added PRE-SCREEN REJECT for work sponsorship
- 1.3.0 — 2026-01-15: Added probe triggers (single-employer, stack mismatch, contribution ambiguity)
- 1.2.0 — 2026-01-15: BLUF output format
- 1.1.0 — 2026-01-15: Changed PASS/FAIL to HIRE/NO-HIRE
- 1.0.0 — 2026-01-13: Initial release

