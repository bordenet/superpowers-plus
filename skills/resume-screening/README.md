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
| Credibility Assessment | +15 to -15 |
| Contractor Evaluation | Context-aware |

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
- Job-hopping: 3+ roles under 18 months each
- AI-fabricated content (hollow, unverifiable claims)
- Requires work sponsorship
- Low credibility score with serious concerns

### Yellow Flags (Need Probing)
- Short tenure pattern (<2 years average)
- Stack mismatch (no Node.js/TypeScript)
- Contribution ambiguity ("we" not "I")
- Single employer entire career (8+ years)
- Multiple short contract gigs (<3 months each)
- Medium credibility score

---

## Contractor Evaluation (Context-Aware)

> **⚠️ BIAS WARNING:** Contractor bias may correlate with demographic discrimination.

| Pattern | Scoring | Action |
|---------|---------|--------|
| Long-term contractor (2+ years same client) | **+5 pts** | Positive signal |
| Specialist consultant (infra/security/data) | **Neutral to +5** | Probe depth |
| Contract-to-hire that converted | **No penalty** | Positive signal |
| 5 different clients, 1 year each | **Neutral** | Probe depth vs breadth |
| 2 consecutive contracts | **-5 pts** | PROBE: motivation |
| Short gigs (<3 months) | **-10 pts** | PROBE: learning |

---

## Credibility Assessment

Evaluates positive signals, not just weaknesses:

| Signal | Weight |
|--------|--------|
| Quantified achievements | +15 pts |
| Technical depth progression | +10 pts |
| Specific implementation details | +10 pts |
| Learning from failures | +10 pts |
| Coherent career narrative | +10 pts |

**Credibility Score:** High (60+ pts) / Medium (30-59 pts) / Low (<30 pts)

---

## AI Content Assessment

> **Key distinction:** AI-assisted polish (no penalty) ≠ AI-fabricated content (flag)

| Category | Action |
|----------|--------|
| **AI-Assisted Polish** | No penalty — smart tool use |
| **AI-Enhanced Claims** | Flag for verification — probe depth |
| **AI-Fabricated Content** | Serious concern — deep verification |

**Focus on VERIFIABILITY, not polish level.**

---

## Output Format

```markdown
# [Candidate Name]

## HIRE | NO HIRE | PROBE

---

## Phone Screen Questions (STAR Format)

1. **[Critical flag]** — [Severity: Minor/Moderate/Serious]
   _"Tell me about a time when [situation]. What was the challenge?
   What action did you take? What was the result?"_
   **Follow-up:** _"What would you do differently?"_

---

## Credibility Assessment

**Positive Signals:** [List specific signals found]
**Concerns:** [List specific concerns]
**Credibility Score:** [High/Medium/Low]

---

## Flags

| Flag | Severity | Probing Depth | STAR Question |
|------|----------|---------------|---------------|
| [Concern] | Red/Yellow/Low | [1Q / 2-3Q / Deep dive] | Phone Q# |

---

## ✅ Bias Audit Checklist

- [ ] Contractor evaluation: context-aware scoring?
- [ ] Gap evaluation: circumstance, not commitment?
- [ ] Pedigree bias: capability evidence, not prestige?
- [ ] AI content: polish vs fabrication distinguished?
- [ ] Skills vs evidence: verified against work history?
```

---

## Files

| File | Purpose |
|------|---------|
| `skill.md` | Skill definition (Augment reads this) |
| `README.md` | Human documentation (you're reading this) |

---

## Version

- 2.0.0 — 2026-02-01: **Major update** — Context-aware contractor evaluation, credibility assessment with positive signals, AI content assessment (polish vs fabrication), STAR format questions, bias audit checklist
- 1.5.0 — 2026-01-20: Added contractor penalty scoring, cross-references
- 1.4.0 — 2026-01-15: Added PRE-SCREEN REJECT for work sponsorship
- 1.3.0 — 2026-01-15: Added probe triggers (single-employer, stack mismatch, contribution ambiguity)
- 1.2.0 — 2026-01-15: BLUF output format
- 1.1.0 — 2026-01-15: Changed PASS/FAIL to HIRE/NO-HIRE
- 1.0.0 — 2026-01-13: Initial release

