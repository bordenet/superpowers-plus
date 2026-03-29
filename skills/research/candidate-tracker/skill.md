---
name: candidate-tracker
source: superpowers-recruiting
description: Use BEFORE every resume screening to check for duplicates, repeat fraudsters, and fraud ring patterns. Triggers on "have we seen this candidate before", "check for duplicate", "is this person already screened", "detect fraud ring", "candidate lookup", "search candidate history". Central registry prevents re-screening known applicants.
triggers: ["have we seen this candidate", "check for duplicate", "is this person already screened", "detect fraud ring", "candidate lookup", "search candidate history"]
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

# Candidate Tracker

## When to Use

- BEFORE every resume screening to check for duplicates and repeat fraudsters
- User says "have we seen this candidate before", "check for duplicate", "detect fraud ring"
- Central registry prevents re-screening known applicants

## Overview

Central registry for all screened candidates. **MUST be checked before every resume screening** to detect:
- Duplicate applications (same person, different source)
- Repeat fraudsters trying again
- Agency candidates who already applied directly
- Fraud ring patterns (multiple candidates, same fake employer)

## Data Location

**CSV File:** `$RECRUITING_DIR/candidate-tracker.csv`

---

## ⚠️ THIS IS NOT FOR AGENCY BATCH TRIAGE

<EXTREMELY_IMPORTANT>

**If you are processing agency candidates in batch, use the `agency-batch-triage` skill instead.**

| Workflow | Use This Skill | Log To |
|----------|----------------|--------|
| **Direct-apply candidates** (one at a time) | ✅ `candidate-tracker` | `$RECRUITING_DIR/candidate-tracker.csv` |
| **Agency batch triage** (multiple from recruiter) | ❌ Use `agency-batch-triage` | `$RECRUITING_PHONE_SCREENS_DIR/{agencyName}/candidate-reviews.csv` |
| **Resume screening** (single candidate, any source) | ✅ `candidate-tracker` + `resume-screening` | `$RECRUITING_DIR/candidate-tracker.csv` |

**Why two systems?**
- `candidate-tracker.csv` = Central fraud detection registry with full PII (phone, LinkedIn, fraud flags)
- `{agency}/candidate-reviews.csv` = Lightweight batch tracking for agency candidates

**If you're in an agency batch session and see the `agency-batch-triage` skill invoked, DO NOT log to candidate-tracker.csv.**

</EXTREMELY_IMPORTANT>

---

**Columns:**
| Column | Description |
|--------|-------------|
| `date_screened` | YYYY-MM-DD |
| `first_name` | |
| `last_name` | |
| `email` | Primary email |
| `email_alt` | Alternative emails seen |
| `phone` | Phone number |
| `linkedin_url` | LinkedIn profile URL |
| `github_url` | GitHub profile URL (if available) |
| `source` | `DIRECT-APPLY` or `RECRUITER:[agency name]` |
| `verdict` | `HIRE` / `NO HIRE` / `PROBE` |
| `status` | See status values below |
| `fraud_flag` | `FRAUDSTER` / `NO-SHOW` / `NEVER-HIRE` / blank |
| `notes` | Brief reason for verdict |

**Status Values:**
- `SCREENED` — Resume reviewed, verdict rendered
- `PHONE_SCHEDULED` — Phone screen scheduled
- `PHONE_COMPLETE` — Phone screen done
- `LOOP_SCHEDULED` — Interview loop scheduled
- `LOOP_COMPLETE` — Interview loop done
- `OFFER_EXTENDED` — Offer made
- `HIRED` — Accepted offer
- `REJECTED` — Did not pass
- `WITHDREW` — Candidate withdrew

## Invocation

This skill is **automatically invoked** by:
- `resume-screening` — Before screening, check for existing record
- `phone-screen-prep` — Before creating sheet, verify candidate status
- `candidate-outcome` — After recording outcome, update tracker

**Manual invocation:**
- "Check if [Name] is in the tracker"
- "Add [Name] to candidate tracker"
- "Show all candidates from [source/employer]"
- "Show all fraudsters"

## Workflow: Pre-Screening Check (MANDATORY)

<CRITICAL>
**Before EVERY resume screening, you MUST:**

1. Read `$RECRUITING_DIR/candidate-tracker.csv`
2. Search for matches on: email, phone, name (fuzzy), LinkedIn URL
3. If match found → STOP and report to user

**Match Actions:**
| Match Type | Action |
|------------|--------|
| Exact email match | 🚨 STOP — "This candidate was screened on [date]. Verdict: [X]" |
| Exact phone match | 🚨 STOP — "Phone number matches [Name] screened on [date]" |
| Name + different email | ⚠️ FLAG — "Possible duplicate: [Name] with different email. Verify." |
| `fraud_flag` is set | 🚨 STOP — "KNOWN FRAUDSTER: [Name]. Do not proceed." |
| Same employer as flagged fraud | ⚠️ FLAG — "Candidate claims [Employer] — same as fraudster [Name]" |
</CRITICAL>

## Workflow: Post-Screening Record

After completing a resume screening, add a row to the CSV:

```csv
2026-02-13,Jane,Example,jane.example@example.com,,(555) 867-5309,linkedin.com/in/jane-example,,RECRUITER:Agency,NO HIRE,SCREENED,,<5 years experience - mid-level
```

## Fraud Detection Patterns

### Known Fraudster Registry

When a candidate is marked as FRAUDSTER via `candidate-outcome`, their record is flagged in the tracker. Future applications with matching signals trigger alerts.

**Match signals for fraud detection:**
- Same email (exact)
- Same phone (exact)
- Same name + similar resume structure
- Same fake employer claimed
- Same LinkedIn URL
- Resume formatting/language patterns

### Repeat Offenders

| Name | Email Pattern | Fraud Type | Attempts |
|------|---------------|------------|----------|
| Scott Crawford | varies | DPRK/identity fraud | 3+ |
| [Add as discovered] | | | |

### Fraud Ring Detection

When screening, check if the candidate's claimed employer matches any flagged fraud cases:

```
Search tracker for: fraud_flag = "FRAUDSTER" AND notes contains [employer name]
If matches found → FLAG: "Employer [X] was claimed by known fraudster [Name]"
```

## Integration with Other Skills

### resume-screening calls candidate-tracker

At the start of every screening:
```
1. Parse candidate name, email, phone from resume
2. Call candidate-tracker check
3. If STOP signal → Do not proceed with screening
4. If FLAG signal → Include warning in screening output
5. After screening → Add record to tracker
```

### phone-screen-prep calls candidate-tracker

Before creating phone screen sheet:
```
1. Verify candidate exists in tracker with verdict = "PHONE SCREEN"
2. If not found → "Candidate not in tracker. Run resume-screening first."
3. Update status to PHONE_SCHEDULED after creating sheet
```

### candidate-outcome updates candidate-tracker

When recording an outcome:
```
1. Find candidate in tracker
2. Update fraud_flag if FRAUDSTER/NO-SHOW/NEVER-HIRE
3. Update status to reflect outcome
```

## CSV Operations

### Read CSV
```bash
cat "$RECRUITING_DIR/candidate-tracker.csv"
```

### Search for candidate
```bash
grep -i "powdrill\|dpowdrill" "$RECRUITING_DIR/candidate-tracker.csv"
```

### Add new row
Use str-replace-editor to append to the CSV file.

## Output Format

When checking a candidate:

```markdown
## Candidate Tracker Check: [Name]

**Status:** ✅ NEW CANDIDATE | ⚠️ POSSIBLE DUPLICATE | 🚨 KNOWN FRAUDSTER

**Matches Found:**
- [Match details if any]

**Proceed:** YES / NO / VERIFY FIRST
```


## Failure Modes & Recovery

- **CSV file not found**: If `candidate-tracker.csv` doesn't exist at `$RECRUITING_DIR`, create it with the header row from the template above
- **Duplicate detection miss**: If a candidate slips through as NEW but is later found to be a duplicate, update both records and flag for reconciliation
- **Corrupted CSV**: If the file has formatting issues (mismatched columns), back up the file before attempting any repair
