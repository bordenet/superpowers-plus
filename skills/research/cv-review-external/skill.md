---
name: cv-review-external
source: superpowers-recruiting
description: "Phase 1a: PARANOID CV review for direct-apply (Paylocity) candidates. Full fraud detection, employer verification, timeline validation. Use when user says 'review this resume', 'screen this candidate', 'direct apply', 'from Paylocity'. NOT for agency candidates."
triggers: ["direct apply", "from Paylocity", "paranoid review", "external candidate review", "Paylocity candidate"]
---

> **⚠️ Environment Required:** This skill needs `$RECRUITING_DIR` and `$RECRUITING_PHONE_SCREENS_DIR`.
> Run `source ~/.codex/.env` before using shell commands. If variables are unset, run `./install.sh` to configure them.

# CV Review: External (Direct-Apply)

> **Pipeline Position:** Phase 1a of 5
> **Posture:** 🚨 EXTREMELY PARANOID — Verify everything, trust nothing
> **Next Phase:** phone-screen-prep (if HIRE/PROBE)

---

## 🚨 WHEN TO USE THIS SKILL

| Source | Use This Skill? | Alternative |
|--------|-----------------|-------------|
| Direct-apply (Paylocity) | ✅ YES | — |
| Agency/recruiter-sourced | ❌ NO | Use `cv-review-agency` |
| Unknown source | ❓ ASK | "Agency or direct-apply?" |

**If user doesn't specify source, ASK before proceeding.**

---

## Required Inputs

1. **Resume** (screenshot, PDF, or text)
2. **Screening answers** (if from Paylocity)
3. **Salary expectation** (required for comp gate)

---

## Verification Checklist (MANDATORY)

**Complete ALL checks before ANY assessment:**

### Identity Verification
- [ ] LinkedIn exists and matches resume
- [ ] Current employer matches across all sources
- [ ] Education verifiable
- [ ] Location consistent

### Employer Verification
- [ ] Current employer exists (web search)
- [ ] Company industry matches resume claims
- [ ] Wayback Machine check for small companies (<100 employees)
- [ ] No other candidates claiming same fabricated employer

### Title Validation
- [ ] Big Tech titles are valid (Amazon: no "Staff"; Google: no "SDE II")
- [ ] Title progression is logical (no regression)
- [ ] Senior-level scope supported by resume content

### Fraud Pattern Checks
- [ ] Check candidate-tracker.csv for prior fraud flags
- [ ] Search "[Name] stolen identity" / "[Name] FBI fraud"
- [ ] Screening answers map to resume bullets
- [ ] No 200+ skill dumps (DPRK/China pattern)

---

## Output Format (BLUF)

```markdown
# [Candidate Name]

## VERDICT: [HIRE | NO HIRE | PROBE]

**Fraud Status:** [✅ CLEAR | ⚠️ UNVERIFIED | 🚨 SUSPECTED]

---

## Signal Table

| Signal | Assessment | Verified? |
|--------|------------|-----------|
| Experience | [X years. Trajectory.] | ✅/⚠️/🚨 |
| Stack fit | [Match to Node.js/TS/AWS] | ✅/⚠️ |
| Scale | [Production metrics, users] | ✅/⚠️ |
| LLM/AI | [RAG, prompt eng, orchestration] | ✅/⚠️ |
| Title | [Current level, progression] | ✅/⚠️ |
| Salary | [$Xk vs $140-180k range] | ✅/⚠️ |

---

## Verified Facts

| Claim | Source | Verification |
|-------|--------|--------------|
| [Employer X] | Resume | ✅ LinkedIn matches |
| [Title Y] | Resume | ✅ Valid for company |

## Unverified Claims

| Claim | Source | Why Unverified |
|-------|--------|----------------|
| [Claim] | Screening | No resume evidence |

---

## Red Flags

| Flag | Severity | Evidence |
|------|----------|----------|
| [Issue] | 🚨/⚠️ | [Details] |

---

## Phone Screen Questions (if HIRE/PROBE)

1. [Question addressing top concern]
2. [Question addressing second concern]
3. [Question addressing third concern]

---

## Rationale

[2-3 sentences explaining verdict]
```

---

## Verdict Definitions

| Verdict | Meaning | Next Step |
|---------|---------|-----------|
| **HIRE** | Verified, meets bar | → phone-screen-prep |
| **PROBE** | Unverified claims, needs clarification | → phone-screen-prep with probes |
| **NO HIRE** | Fraud suspected OR doesn't meet bar | → STOP |

---

## 🚨 POST-SCREENING: Record to candidate-tracker.csv

After EVERY verdict, append to `$RECRUITING_DIR/candidate-tracker.csv`:

```csv
YYYY-MM-DD,FirstName,LastName,email,alt_email,phone,linkedin,github,DIRECT-APPLY,VERDICT,SCREENED,FRAUD_FLAG,notes
```

**This is MANDATORY. Screening is not complete until recorded.**

---

## Cross-References

| Resource | Location |
|----------|----------|
| Fraud Detection Module | `modules/fraud-detection.md` |
| Stack Fit Module | `modules/stack-fit.md` |
| Slop Detection Module | `modules/slop-detection.md` |
| Candidate Tracker | `$RECRUITING_DIR/candidate-tracker.csv` |

---

## Module Loading

| Module | When to Load |
|--------|--------------|
| `fraud-detection.md` | 🔴 ALWAYS for external candidates |
| `stack-fit.md` | After fraud checks pass |
| `slop-detection.md` | For screening answer analysis |

## Failure Modes & Recovery

- **Fraud module fails to load**: If `modules/fraud-detection.md` is missing, apply minimum checks manually — verify employers via web search, check LinkedIn profile age
- **Candidate is agency-sourced**: STOP and redirect to `cv-review-agency` — external review applies stricter fraud detection not needed for agency-vetted candidates
- **Truncated application answers**: If Paylocity screening answers are cut off, flag as incomplete and ask user to provide full responses before scoring

*Last updated: 2026-03-03 | Pipeline overhaul v1*
