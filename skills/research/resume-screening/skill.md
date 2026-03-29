---
name: resume-screening
source: superpowers-recruiting
description: Use when reviewing resumes, screening candidates, evaluating CVs, or when user shares resume text/screenshot. Triggers on "review this resume", "screen this candidate", "evaluate this CV", "is this person qualified", "should we phone screen", "worth interviewing?". For Senior SDE role against CallBox hiring criteria.
triggers: ["review this resume", "screen this candidate", "evaluate this CV", "is this person qualified", "should we phone screen", "worth interviewing"]
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

# Resume Screening

> **📋 Source:** https://wiki.int.callbox.net/doc/llm-prompt-LfFH19Gj0y

---

## 🚨🚨🚨 FIRST QUESTION — BEFORE ANYTHING ELSE 🚨🚨🚨

<EXTREMELY_IMPORTANT>

**Before processing ANY candidate, you MUST ask:**

> "Is this candidate from an **AGENCY/RECRUITER** or a **DIRECT-APPLY** (Paylocity)?"

**Why this matters:**

| Source | Skill to Use | CSV Location | Fraud Checks |
|--------|--------------|--------------|--------------|
| **AGENCY** | `agency-batch-triage` | `$RECRUITING_PHONE_SCREENS_DIR/{agencyName}/candidate-reviews.csv` | Standard (verify employers) |
| **DIRECT-APPLY** | `resume-screening` + `candidate-tracker` | `$RECRUITING_DIR/candidate-tracker.csv` | Paranoid (full fraud detection) |

**If you don't know the source, ASK. Do not guess. Do not proceed.**

</EXTREMELY_IMPORTANT>

---

## 🚨 ABSOLUTE RULE

**If you are unsure which module to load, load ALL modules for this skill.**
Better to have extra context than miss critical guidance.

---

## 🚨 CRITICAL: Load Modules On-Demand

| Module | 🔴 When to Load | Command |
|--------|-----------------|---------|
| **agency-mode.md** | "recruiter", "agency", "from [name]" | `view ~/.codex/modules/agency-mode.md` |
| **fraud-detection.md** | Direct-apply (Paylocity) candidates | `view modules/fraud-detection.md` |
| **slop-detection.md** | ANY candidate | `view modules/slop-detection.md` |
| **stack-fit.md** | ANY candidate | `view modules/stack-fit.md` |
| **output-formats.md** | Generating final report | `view modules/output-formats.md` |

---

## Quick Reference (Always Active)

**Output:** HIRE / NO HIRE / PROBE — verdict first, questions second, evidence last

**Role:** Senior SDE — Backend TypeScript/Node.js, Telnyx/SIP/WebRTC, LLM orchestration, Kafka/Redis/Postgres, AWS CDK, Docker/K8s

**Hard Gates:**
- 5+ years qualifying SWE experience
- Senior-level title (or clear senior scope)
- No title regression
- LLM/AI experience REQUIRED

**Compensation (direct-apply):** BASE ONLY — 70-110% of salary cap

**Multi-Page Resumes:** If user indicates pages are coming ("page 1", "WAIT FOR", etc.), acknowledge each page and DO NOT generate verdict until all pages received. Say: "Waiting for page [X]..."

**🚨 POST-SCREENING:** After EVERY verdict → append candidate to `$RECRUITING_DIR/candidate-tracker.csv` (see full instructions at end of skill)

---

## 🚨 Resume vs. Interview Evidence

**This skill produces RESUME-BASED assessment only.**

When synthesis skills use this output:
- All claims from this screening MUST be tagged `[resume]` in synthesis
- Claims are NOT confirmed until discussed in call
- Stack fit is CLAIMED, not VERIFIED, until interview

### Language Guidance for Downstream Skills

| ✅ Resume Screening Says | ❌ Synthesis Must NOT Say (unless discussed) |
|--------------------------|---------------------------------------------|
| "Claims 13+ years" | "Has 13+ years" |
| "Resume shows LLM project" | "Has LLM experience" |
| "Lists TypeScript" | "TypeScript expertise" |
| "Served Disney/NBCU (per resume)" | "Served Disney/NBCU" |

**Synthesis MUST distinguish:**
- What candidate CLAIMED on resume
- What candidate DISCUSSED in call
- What interviewer OBSERVED

---

## Mode Detection

| Trigger | Mode | Action |
|---------|------|--------|
| "from a recruiter", "agency candidate", "recruiter-sourced" | **RECRUITER-SOURCED** | Load `agency-mode.md`, skip fraud checks |
| Default (no trigger) | **DIRECT-APPLY** | Load `fraud-detection.md`, full verification |

---

## Pre-Screening (ALWAYS)

1. **Candidate Tracker:** `$RECRUITING_DIR/candidate-tracker.csv` — check for duplicates/fraud flags
2. **Existing Records:** `$RECRUITING_DIR/Phone Screens/`, `Interview Prep/`, `Debriefs/`
3. **Big Tech Titles:** Amazon (no "Staff"), Google (no "SDE"), Microsoft (no L-levels)
4. **Stolen Identity Detection:** Search `"[Name]" stolen identity` / `FBI fraud` — if hits, STOP
5. **DPRK/China IT Fraud:** Watch for 200+ skill dumps, selective audio problems, eyes on second monitor
6. **Wayback Machine:** For small companies (<100 employees), verify candidate appeared on team pages

---

## Multi-Page Resumes

If user says "page 1", "wait for more", "WAIT FOR X page":
- Acknowledge each page
- Do NOT generate verdict until all pages received
- State: "Waiting for page [X]..."

---

## Fail-Over: If Module Loading Fails

**Essential rules if modules unavailable:**

1. **Default to PROBE** — safe middle ground if uncertain
2. **Check candidate-tracker.csv FIRST** — prevent duplicates
3. **Verify LinkedIn matches resume** — basic fraud check
4. **5+ years + Senior title = hard gate** — don't screen mid-level
5. **HIRE/NO HIRE/PROBE** — always provide clear verdict
6. **One candidate per report** — no cross-references
7. **No preamble** — start with `# [Candidate Name]`
8. **🚨 AFTER VERDICT → Record to candidate-tracker.csv** — this is NOT optional

**For direct-apply:** Verify employer exists, check for fabrication
**For agency:** Trust recruiter verification, focus on stack fit

---

## 🚨🚨🚨 MANDATORY POST-SCREENING: Record Candidate 🚨🚨🚨

<EXTREMELY_IMPORTANT>

**After EVERY screening verdict, you MUST:**

1. **Add the candidate to `$RECRUITING_DIR/candidate-tracker.csv`**
2. **Use str-replace-editor** to append a new row
3. **Do not wait** for user to ask — this is automatic

**Row Format:**
```csv
YYYY-MM-DD,FirstName,LastName,email@domain.com,alt_email,phone,linkedin_url,github_url,SOURCE,VERDICT,STATUS,FRAUD_FLAG,brief notes here
```

**Field Values:**
| Field | Value |
|-------|-------|
| `date_screened` | Today's date (YYYY-MM-DD) |
| `source` | `DIRECT-APPLY` or `RECRUITER:Agency` (use agency name if known) |
| `verdict` | `PHONE SCREEN` / `NO HIRE` / `HIRE` |
| `status` | `SCREENED` (always, for initial screening) |
| `fraud_flag` | Leave blank unless candidate is confirmed fraud |
| `notes` | Brief summary: years, key strengths, key gaps, concerns to probe |

**Example:**
```csv
2026-02-26,Alex,Sample,alex.sample@example.com,,,linkedin.com/in/alexsample,github.com/alexsample,RECRUITER:Agency,PHONE SCREEN,SCREENED,,7 yrs - SampleCo 4.5 yrs - TS/Node/AWS/event-driven - no telephony no LLM - probe stealth startup
```

**This is NOT optional. If you fail to record the candidate, you have not completed the screening.**

</EXTREMELY_IMPORTANT>

---

## When to Use

- User shares a resume, CV, or candidate profile for evaluation
- User asks "review this resume", "screen this candidate", "is this person qualified"
- Entry point for direct-apply (Paylocity) candidates; for agency candidates use `cv-review-agency`

## Failure Modes & Recovery

- **Wrong skill routed**: If candidate is from an agency, STOP and redirect to `agency-batch-triage` or `cv-review-agency`
- **Missing env vars**: If `$RECRUITING_DIR` is unset, run `source ~/.codex/.env` before proceeding
- **Fraud false positive**: If fraud signals are ambiguous, load `modules/fraud-detection.md` and apply all checks before rejecting — never reject on a single signal
- **Incomplete CV**: If resume is truncated or screenshot-only, ask user for full text before scoring

## When In Doubt

- **Load ALL modules** rather than guess
- **Default to PROBE** if signals are mixed
- **Ask user** for clarification on source if ambiguous
- **Check LinkedIn** — quick sanity check before any assessment
- **Always record in candidate-tracker.csv** after verdict
