---
name: phone-screen-prep
source: superpowers-[product]
description: "Phase 2: Prepare phone screen call script with prioritized questions. TRIGGERS: 'prep phone screen', 'prepare for call', 'phone screen tomorrow'. NEVER fires when Fathom transcript is present."
triggers:
  - "prep phone screen"
  - "prepare for call"
  - "phone screen tomorrow"
  - "phone screen with [name]"
  - "prep for [name]"
anti_triggers:
  - "Fathom transcript"
  - "fathom.video"
  - "just finished"
  - "synthesize"
  - "__SYNTHESIS"
---

> **⚠️ Environment Required:** This skill needs `$RECRUITING_DIR` and `$RECRUITING_PHONE_SCREENS_DIR`.
> Run `source ~/.codex/.env` before using shell commands. If variables are unset, run `./install.sh` to configure them.

# Phone Screen Prep

## When to Use

- Preparing a phone screen call script with prioritized questions
- User says "prep phone screen", "prepare for call", "phone screen tomorrow"
- NEVER fires when Fathom transcript is present (that's phone-screen-synthesis)

> **Pipeline Position:** Phase 2 of 5
> **Input:** CV review output (Phase 1a or 1b)
> **Output:** Structured call script with prioritized questions (`*.md` without `__SYNTHESIS`)
> **Next Phase:** phone-screen-synthesis (after call)

---

## 🚨🚨🚨 THIS IS PREP, NOT SYNTHESIS

<EXTREMELY_IMPORTANT>

**If user has a Fathom transcript, DO NOT USE THIS SKILL.**

| Signal | Wrong Skill | Right Skill |
|--------|-------------|-------------|
| `fathom.video` URL present | ❌ phone-screen-prep | ✅ phone-screen-synthesis |
| Transcript text pasted | ❌ phone-screen-prep | ✅ phone-screen-synthesis |
| "just finished call" | ❌ phone-screen-prep | ✅ phone-screen-synthesis |
| "synthesize" | ❌ phone-screen-prep | ✅ phone-screen-synthesis |

**Incident 2026-03-05:** Agent edited PREP file when user had Fathom transcript. Fathom = post-call = SYNTHESIS.

### File Naming

| Phase | File Pattern |
|-------|--------------|
| PREP (this skill) | `FirstName_LastName__SrSDE__YYYY-MM-DD.md` |
| SYNTHESIS (other skill) | `FirstName_LastName__SrSDE__YYYY-MM-DD__SYNTHESIS.md` |

</EXTREMELY_IMPORTANT>

---

## 🚨 PREREQUISITE: CV Review Must Be Complete

**Before generating phone screen prep, verify:**

| Candidate Source | Required CV Review | How to Check |
|------------------|-------------------|--------------|
| Direct-apply | `cv-review-external` | Fraud status CLEAR or PROBE |
| Agency-sourced | `cv-review-agency` | Stack fit assessed |

**If CV review not done, invoke appropriate skill first.**

---

## 🚨 CRITICAL: Load Modules On-Demand

| Module | 🔴 When to Load | Command |
|--------|-----------------|---------|
| **integrity-policy.md** | Generating ANY phone screen | `view modules/integrity-policy.md` |
| **question-format.md** | Generating Q1-Q4 block | `view modules/question-format.md` |
| **ai-detection-probes.md** | ANY phone screen (pick 3-5 probes) | `view modules/ai-detection-probes.md` |
| **compensation-rules.md** | Determining comp discussion handling | `view modules/compensation-rules.md` |
| **template-rules.md** | Before writing output file | `view modules/template-rules.md` |
| **evidence-tracking.md** | During call note-taking | `view modules/evidence-tracking.md` |

---

## Pipeline Position

```
cv-review-external ─┐
                    ├→ phone-screen-prep → phone-screen-synthesis → loop-prep → loop-synthesis
cv-review-agency ───┘         ↑ YOU ARE HERE
```

**⚠️ PREP ONLY** — This skill creates phone screen scaffolding. Post-call synthesis uses `phone-screen-synthesis`.

---

## Quick Reference (Always Active)

### Candidate Source

| Trigger | Mode | Key Difference |
|---------|------|----------------|
| "from recruiter", "agency" | **AGENCY-SOURCED** | Skip comp discussion entirely (agency handles), skip employer verification |
| Default | **DIRECT-APPLY** | Full comp discussion required, full employer verification |

---

## 🚨 MANDATORY: Check Candidate Register FIRST

<EXTREMELY_IMPORTANT>

**Before creating ANY phone screen prep, ALWAYS check the candidate register:**

```bash
grep -i "CANDIDATE_NAME" "$RECRUITING_DIR/candidate-tracker.csv"
grep -i "CANDIDATE_NAME" "$RECRUITING_DIR/Phone Screens/*/candidate-reviews.csv"
```

**The register tells you:**
- Source: `RECRUITER:Agency` vs `DIRECT` vs `Paylocity`
- Status: `SCREENED` / `PHONE_SCHEDULED` / etc.
- Notes: Key probe areas identified during CV review

**If candidate is in register → use the Source field to determine agency vs direct-apply handling.**

**If candidate is NOT in register → ASK the user: "Is this candidate from an agency or did they apply directly?"**

**NEVER assume direct-apply just because the user pastes a resume.**

</EXTREMELY_IMPORTANT>

---

## 🚨 COMPENSATION DISCUSSION RULES

🔴 **Load module:** `view modules/compensation-rules.md`

**Quick reference:** Agency-sourced → SKIP comp entirely. Direct-apply → MANDATORY comp discussion.

---

## Required Inputs

**This skill requires TWO inputs:**

1. **Screening answers** — Copy-paste from Paylocity (drives Q1-Q6 prioritization)
2. **Full resume** — Screenshot or PDF (not just summary)

Without these, questions will be generic.

---

## 🚨 PII WARNING

| What | Where | Git Status |
|------|-------|------------|
| **Template** | `templates/phone-screen.md` | ✅ Git-tracked |
| **Candidate notes** | `$RECRUITING_DIR/Phone Screens/*.md` | ❌ **NEVER COMMIT** |

---

## 🚨🚨🚨 THE TEMPLATE IS THE OUTPUT — DO NOT STRIP IT 🚨🚨🚨

🔴 **Load module:** `view modules/template-rules.md`

**Quick reference:** READ `templates/phone-screen.md` → COPY wholesale → FILL IN blanks → NEVER DELETE sections.

---

## Workflow Summary

### PREP Mode (Direct-Apply)

1. Run `resume-screening` skill first
2. Load `employer-verification.md` → verify employers/projects
3. **READ the template:** `view templates/phone-screen.md`
4. **COPY the entire template** to: `$RECRUITING_DIR/Phone Screens/FirstName_LastName__SrSDE__YYYY-MM-DD.md`
5. Fill in candidate metadata (name, date, contact, links)
6. Fill in PRE-SCREEN ASSESSMENT from resume analysis
7. Load `question-format.md` → generate Q1-Q6 prioritized by risk, fill into 25-Min Call Flow
8. Load `ai-detection-probes.md` → select 3-5 probes to weave in
9. **Verify all sections present** — Integrity policy, call flow, comp confirmation, loop script

### PREP Mode (Recruiter-Sourced)

1. Load `agency-mode.md` → understand what to skip
2. Run `resume-screening` skill (technical fit only)
3. Skip employer verification
4. **READ the template:** `view templates/phone-screen.md`
5. **COPY the entire template** to: `$RECRUITING_DIR/Phone Screens/FirstName_LastName__SrSDE__YYYY-MM-DD.md`
6. **ADD agency callout box** at top (after integrity policy)
7. Fill in PRE-SCREEN ASSESSMENT
8. Generate Q1-Q6 (comp section notes "N/A — agency-sourced, recruiter handled")
9. **Verify all sections present** — Same structure as direct-apply

### POST-CALL: Use phone-screen-synthesis

**⚠️ After the phone screen, use the `phone-screen-synthesis` skill to create the BLUF debrief record.**

The synthesis workflow produces:
- BLUF verdict (Hire for company? Hire for role? Leveling?)
- Three points FOR / Three points AGAINST
- Interview transcript with `<< >>` observations
- Areas to probe in loop (if HIRE)

---

## Interview Flow (25 min)

1. **Integrity Policy** (MANDATORY) — load `integrity-policy.md`
2. **Opening** — Thanks, introduce as hiring manager
3. **Tell Me About Yourself** — Open-ended
4. **Q1-Q6** — Prioritized by screening concerns
5. **Comp Gate** — Only if still viable (skip for recruiter-sourced)
6. **Their Questions** — Reveals motivation
7. **Loop Expectations** (if advancing) — AI policy, Dallas final

---

## Cross-References

| Resource | Location |
|----------|----------|
| Template | `templates/phone-screen.md` |
| Resume Screening | `skills/recruiting/resume-screening/` |
| Wiki LLM Prompt | [wiki.int.[company].net](https://wiki.int.[company].net/doc/llm-prompt-LfFH19Gj0y) |

---

## Failure Modes & Recovery

If modules fail to load, follow these minimum recovery rules:

1. **Template is MANDATORY** — `view templates/phone-screen.md` and copy wholesale
2. **Integrity Policy is MANDATORY** — Read at start of every call
3. **25-Min Call Flow is MANDATORY** — Scripted sections for every phase
4. **Verdict goes at TOP** in synthesis — Never bury decision
5. **Fraud callout first** — If suspected, state immediately after title
6. **Agency candidates** — Skip comp script, employer verification (but keep section headers)
7. **Direct-apply** — Verify every employer before generating questions
8. **File naming** — `FirstName_LastName__SrSDE__YYYY-MM-DD.md`
9. **Never commit PII** — Phone screen files are OneDrive only

🔴 **Evidence Tracking:** Load `modules/evidence-tracking.md` — Tag notes with `[transcript]`, `[observation]`, `[resume-verify]`, `[resume-unverified]`, or `[question]`.
