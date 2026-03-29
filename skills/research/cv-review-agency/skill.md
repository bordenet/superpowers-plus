---
name: cv-review-agency
source: superpowers-recruiting
description: "Phase 1b: Trusting CV review for agency/recruiter-sourced candidates. Skip fraud detection, focus on stack fit and leveling. Use when user says 'from recruiter', 'agency candidate', 'from [agency name]'. NOT for direct-apply."
triggers: ["from recruiter", "agency candidate", "from agency", "recruiter-sourced", "trusting review"]
coordination:
  group: research
  order: 5
  requires: []
  enables: []
  escalates_to: []
  internal: true
---

> **⚠️ Environment Required:** This skill needs `$RECRUITING_DIR` and `$RECRUITING_PHONE_SCREENS_DIR`.
> Run `source ~/.codex/.env` before using shell commands. If variables are unset, run `./install.sh` to configure them.

# CV Review: Agency (Recruiter-Sourced)

> **Pipeline Position:** Phase 1b of 5
> **Posture:** 🤝 TRUST RECRUITER VETTING — Focus on content fit
> **Next Phase:** phone-screen-prep (if HIRE/PROBE)

---

## 🤝 Agency Candidate Assumptions

Recruiters have already verified:
- ✅ Identity (real person)
- ✅ Employment history (background check)
- ✅ Work authorization
- ✅ Compensation expectations (recruiter handles comp negotiation)

**Focus this review on:** Stack fit, experience relevance, leveling, role alignment

---

## 🚨 WHEN TO USE THIS SKILL

| Source | Use This Skill? | Alternative |
|--------|-----------------|-------------|
| Agency/recruiter-sourced | ✅ YES | — |
| Direct-apply (Paylocity) | ❌ NO | Use `cv-review-external` |
| Unknown source | ❓ ASK | "Agency or direct-apply?" |

---

## Required Inputs

1. **Resume** (screenshot, PDF, or text)
2. **Agency name** (for tracking)
3. **Recruiter notes** (if available)

**NOT required:** Salary expectation (recruiter handles)

---

## Output Format (BLUF)

```markdown
# [Candidate Name]

## VERDICT: [HIRE | NO HIRE | PROBE]

**Source:** [Agency Name]

---

## Signal Table

| Signal | Assessment |
|--------|------------|
| Experience | [X years. Company trajectory. Relevant domains.] |
| Stack fit | ✅/⚠️/❌ [Node.js/TS/Python match. Gaps.] |
| Scale | [Production metrics. User counts. On-call.] |
| LLM/AI | ✅/⚠️/❌ [RAG, orchestration, prompt eng experience] |
| Title | [Current level. Progression. Senior-level scope?] |
| Telephony | ✅/⚠️/❌ [SIP, WebRTC, real-time audio experience] |

---

## Stack Fit Analysis

### Strong Matches
- [Technology] — [Evidence from resume]
- [Technology] — [Evidence from resume]

### Gaps to Probe
- [Technology] — [No evidence, or weak evidence]
- [Technology] — [Adjacent but not direct]

### Transferable Skills
- [Skill] — [How it maps to our stack]

---

## Leveling Assessment

**Target Level:** Senior SDE (L2)

| Dimension | Evidence | Level |
|-----------|----------|-------|
| Scope | [E2E ownership? Cross-team impact?] | L1/L2/L3 |
| Independence | [Self-directed? Ambiguity tolerance?] | L1/L2/L3 |
| Leadership | [Mentorship? Technical leadership?] | L1/L2/L3 |
| Impact | [Metrics moved? Business outcomes?] | L1/L2/L3 |

**Leveling Concerns:** [Any flags about level fit]

---

## Four Quadrants Pre-Assessment

| Quadrant | Evidence |
|----------|----------|
| **Company** (ownership) | [E2E systems, production depth] |
| **Core Skills** (technical) | [Architecture, tradeoffs, scale] |
| **Mindset** (adaptability) | [Startup experience, growth signals] |
| **Behaviors** (collaboration) | [Leadership, mentorship, bar-raising] |

---

## Phone Screen Questions (if HIRE/PROBE)

1. [Question addressing stack gap]
2. [Question probing LLM/AI depth]
3. [Question validating ownership claims]

---

## Rationale

[2-3 sentences on stack fit, leveling, and role alignment]
```

---

## Verdict Definitions

| Verdict | Meaning | Next Step |
|---------|---------|-----------|
| **HIRE** | Strong fit, proceed | → phone-screen-prep |
| **PROBE** | Mixed signals, needs phone screen | → phone-screen-prep with probes |
| **NO HIRE** | Poor stack fit OR level mismatch | → STOP, feedback to recruiter |

---

## 🚨 POST-SCREENING: Record to agency CSV

After EVERY verdict, append to `$RECRUITING_PHONE_SCREENS_DIR/{agencyName}/candidate-reviews.csv`:

```csv
FName,LName,Email,DateTime,Disposition,Status,Notes
```

**This is MANDATORY. Screening is not complete until recorded.**

---

## Cross-References

| Resource | Location |
|----------|----------|
| Stack Fit Module | `modules/stack-fit.md` |
| Career Ladder | [wiki](https://wiki.int.callbox.net/doc/sr-sde-career-ladder-xMt5Ry9Jwp) |
| Four Quadrants | [wiki](https://wiki.int.callbox.net/doc/core-behaviors-the-four-quadrants-8d4JNjomwk) |

## Failure Modes & Recovery

- **Wrong agency directory**: If `$RECRUITING_PHONE_SCREENS_DIR/{agencyName}/` doesn't exist, create the directory and initialize `candidate-reviews.csv` with the standard header
- **Candidate is direct-apply**: STOP and redirect to `cv-review-external` — agency review skips fraud checks that direct-apply requires
- **Missing stack-fit module**: If `modules/stack-fit.md` can't be loaded, assess technical fit manually against the Senior SDE career ladder requirements

*Last updated: 2026-03-03 | Pipeline overhaul v1*
