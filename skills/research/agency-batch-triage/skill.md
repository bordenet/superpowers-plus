---
name: agency-batch-triage
source: superpowers-recruiting
description: Use when processing multiple candidates from a recruiting agency in a single session. Triggers on "agency sent candidates", "triage these agency resumes", "batch screen from [agency]", "process recruiter batch", "agency candidates to review". Uses standard screening (not paranoid), logs to CSV, creates phone screen sheets for HIRE decisions.
triggers: ["agency sent candidates", "triage these agency resumes", "batch screen from", "process recruiter batch", "agency candidates to review"]
coordination:
  group: research
  order: 5
  requires: []
  enables: []
  escalates_to: []
  internal: true
---

# Agency Batch Triage

## When to Use

- Processing multiple candidates from a recruiting agency in a single session
- User says "agency sent candidates", "triage these agency resumes", "batch screen from [agency]"
- Uses standard screening (not paranoid mode), logs to CSV, creates phone screen sheets for HIRE decisions

> **Use when:** Processing multiple candidates from a recruiting agency in a single session.
> **Env required:** `$RECRUITING_PHONE_SCREENS_DIR` — run `source ~/.codex/.env`

---

## Disposition Values (MANDATORY)

| Disposition | Meaning |
|-------------|---------|
| `STRONG-HIRE` | Exceptional, expedite (~1%) |
| `HIRE` | Meets bar, phone screen (~60-70%) |
| `NO-HIRE` | Below bar, reject (~20-30%) |
| `STRONG-NO-HIRE` | Fraud/fabrication (~10%) |

---

## Tracking: Agency-Specific CSV (NOT candidate-tracker.csv)

**File:** `$RECRUITING_PHONE_SCREENS_DIR/{agencyName}/candidate-reviews.csv`
**Schema:** `FName,LName,Email,DateTime,Disposition,Status,Notes`

Log IMMEDIATELY after each decision. Use CSV locking for multi-agent safety. See `references/csv-tracking.md` for locking protocol and schema details.

---

## Agency = Standard Screening

Skip paranoid fraud checks (LinkedIn cross-check, Big Tech title fraud, comp/work-auth verification). **ALWAYS check:**

- ✅ Employer legitimacy (web search — see `references/verification-procedures.md`)
- ✅ 5+ years experience — **HARD GATE**
- ✅ 2+ years at verifiable product company — **HARD GATE**
- ✅ Senior title required — **HARD GATE**
- ✅ LLM/AI experience — **HARD GATE**
- ✅ Node.js/TypeScript OR comparable modern backend
- ✅ GitHub URL validation (read actual URL, don't guess)
- ✅ Level fit (map YoE to [SDE Career Ladder](https://wiki.int.callbox.net/doc/sde-career-ladder-79fARjKXw6))

### Stack Flexibility

| Stack | Decision |
|-------|----------|
| Node.js/TypeScript backend | ✅ HIRE |
| Python/.NET/Go + TS experience | ✅ HIRE |
| Python/.NET only, no TS, borderline | ❌ NO-HIRE |
| Java-only | ❌ NO-HIRE |

---

## Workflow

### Step 1: Initialize

Create/verify `$RECRUITING_PHONE_SCREENS_DIR/{agencyName}/candidate-reviews.csv`

### Step 2: For Each Candidate

1. Duplicate check: `grep -i "lastname\|email" candidate-reviews.csv`
2. Triage against hard gates (all 4 must pass)
3. Decision → log to CSV IMMEDIATELY
4. If HIRE → create phone screen sheet: `{FName}_{LName}__SrSDE__{YYYY-MM-DD}.md`

### Step 3: Phone Screen Sheet (if HIRE)

Include: agency callout, pre-screen assessment, four quadrants, prioritized questions, 25-min call flow.

---

## Hard Gates (ALL must pass)

| Gate | Requirement | Fail = |
|------|-------------|--------|
| Experience | 5+ years | NO-HIRE |
| Senior Title | Must have held Senior+ | NO-HIRE |
| LLM/AI | Any LLM, RAG, GenAI, prompt eng | NO-HIRE |
| Verifiable Tenure | 2+ years at verifiable product company | NO-HIRE |

---

## Decision Criteria

**HIRE:** Passes all hard gates + modern stack + no red flags
**STRONG-HIRE:** All HIRE + direct LLM/RAG production + exact stack match + ownership signals
**NO-HIRE:** Any hard gate failure, Java-only, borderline stack
**STRONG-NO-HIRE:** Fabricated employer, fake GitHub, resume contradicts LinkedIn

**BORDERLINE → Default NO-HIRE.** We have raised the bar.

---

## Output Format

```markdown
## Candidate Triage: [Name]

| Signal | Assessment |
|--------|------------|
| Experience | ✅/⚠️/❌ [details] |
| Level Fit | ✅/⚠️/❌ [X yrs → Level] |
| Current Role | ✅/⚠️/❌ [title @ company] |
| Stack Fit | ✅/⚠️/❌ [languages] |
| LLM/AI | ✅/⚠️/❌ [experience] |
| GitHub | ✅/⚠️/❌/N/A [status] |

### Verdict
| Decision | Confidence |
|----------|------------|
| ✅ PHONE SCREEN / ❌ NO PHONE SCREEN | High/Med/Low |

**Rationale:** [1-2 sentences]
```

---

## Reference Files

| File | Contents |
|------|----------|
| `references/verification-procedures.md` | Employer legitimacy, GitHub validation, level fit assessment |
| `references/csv-tracking.md` | CSV schema, locking protocol, correct file paths |

## Files

| File | Location |
|------|----------|
| CSV Tracker | `$RECRUITING_PHONE_SCREENS_DIR/{agency}/candidate-reviews.csv` |
| Phone Screen Sheets | `$RECRUITING_PHONE_SCREENS_DIR/{agency}/` |
| Template | `../phone-screen-prep/templates/phone-screen.md` |
