# Resume Screening Skill

A [superpowers skill](../install-augment-superpowers.sh) that evaluates Senior SDE candidates against CallBox's hiring bar. Outputs HIRE/NO-HIRE/PROBE with targeted phone screen questions.

> **📚 Wiki:** https://wiki.int.callbox.net/doc/superpowers-skills-cASQJAkNFD

---

## 🤖 AI Instructions

<CRITICAL>
**When modifying this skill, you MUST also update the wiki:**
https://wiki.int.callbox.net/doc/superpowers-skills-cASQJAkNFD

Update the "Recruiting Skills" section with any behavioral changes.
</CRITICAL>

---

## 🔗 Cross-References

| Resource | Location | Update When |
|----------|----------|-------------|
| **This skill source** | `skills/resume-screening/skill.md` | Changing evaluation logic |
| **Wiki LLM Prompt** | [wiki.int.callbox.net](https://wiki.int.callbox.net/doc/llm-prompt-LfFH19Gj0y) | **Source of truth** — check daily |
| **Phone Screen Prep Skill** | `skills/phone-screen-prep/` | Uses concerns from this skill |
| **Phone Screen Template** | `Recruiting/Templates/phone-screen.md` (git-tracked) | Interview structure |
| **Comp Models** | `$RECRUITING_DIR/Team Delta Comp Models.xlsx` | Salary ranges (OneDrive, NOT git) |

### Dependency Chain

```
Wiki LLM Prompt (source of truth for criteria)
       │
       ▼ copy criteria into
resume-screening/skill.md (THIS SKILL)
       │
       ▼ outputs concerns that feed
phone-screen-prep skill (generates prioritized Q1-Q6)
       │
       ▼ creates
$RECRUITING_DIR/Phone Screens/FirstName_LastName__YYYY-MM-DD.md (OneDrive, NOT git)
```

---

## Candidate Source Modes

This skill operates in two modes based on how the candidate was sourced:

| Mode | Trigger | What Changes |
|------|---------|--------------|
| **DIRECT-APPLY** (default) | No trigger needed | Full verification, full comp check |
| **RECRUITER-SOURCED** | "from a recruiter", "recruiter-sourced", "agency candidate" | Skip fraud paranoia, skip comp verification |

### RECRUITER-SOURCED Mode

When user indicates candidate came from a recruiter/agency:

| Skipped | Kept |
|---------|------|
| Fabricated employer detection | Stack fit assessment |
| LinkedIn/resume discrepancy checks | Title progression validation |
| Wayback Machine verification | Experience depth evaluation |
| Stolen identity detection | AI slop detection |
| Compensation verification | Existing candidate record check |

---

## Quick Start

**Direct-Apply (Paylocity):**

```
1. Open Augment chat (Cmd+Shift+I)
2. Say: "Screen at $150k cap"
3. Paste resume + Paylocity screening answers
4. Get: HIRE / NO-HIRE / PROBE with rationale
```

**Recruiter-Sourced:**

```
1. Say: "From a recruiter — screen this candidate"
2. Paste resume
3. Get: Technical fit assessment (no fraud checks)
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

## ⚠️ BE PARANOID — Verification First

**Resume fraud is rampant. Assume nothing. Verify everything.**

Before ANY evaluation, the skill runs mandatory verification:

| Check | What It Does |
|-------|--------------|
| LinkedIn exists | Search `"[Name]" site:linkedin.com` |
| Employer match | LinkedIn current employer = resume current employer |
| Company exists | Web search verifies company is real and matches claimed business |
| Wayback Machine | For small companies, verify candidate appeared on team pages |
| Big Tech titles | Amazon has no "Staff Engineer", Google has no "SDE II" |
| Fraud patterns | Check if other candidates claimed same employer |

**If verification fails → NO HIRE. Do not proceed to evaluation.**

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

- 1.7.0 — 2026-02-13: Added RECRUITER-SOURCED vs DIRECT-APPLY candidate source modes
- 1.6.0 — 2026-02-13: Added BE PARANOID verification mandate, Wayback Machine historical verification
- 1.5.0 — 2026-01-20: Added contractor penalty scoring, cross-references
- 1.4.0 — 2026-01-15: Added PRE-SCREEN REJECT for work sponsorship
- 1.3.0 — 2026-01-15: Added probe triggers (single-employer, stack mismatch, contribution ambiguity)
- 1.2.0 — 2026-01-15: BLUF output format
- 1.1.0 — 2026-01-15: Changed PASS/FAIL to HIRE/NO-HIRE
- 1.0.0 — 2026-01-13: Initial release
