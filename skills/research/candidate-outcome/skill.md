---
name: candidate-outcome
source: superpowers-[product]
description: Use when recording candidate outcomes — fraud, no-show, rejection, or hire decision. Triggers on "[name] was a fraud", "[name] no-showed", "reject [name]", "we're hiring [name]", "candidate ghosted", "mark as fraudster", "record outcome for [name]". Updates candidate's historic record with standardized outcome section.
triggers: ["was a fraud", "no-showed", "reject candidate", "we are hiring", "candidate ghosted", "mark as fraudster", "record outcome for"]
---

> **⚠️ Environment Required:** This skill needs `$RECRUITING_DIR` and `$RECRUITING_PHONE_SCREENS_DIR`.
> Run `source ~/.codex/.env` before using shell commands. If variables are unset, run `./install.sh` to configure them.

# Candidate Outcome Tracking

## When to Use

- Recording candidate outcomes: fraud, no-show, rejection, or hire decision
- User says "[name] was a fraud", "[name] no-showed", "reject [name]", "we're hiring [name]"
- Updates candidate's historic record with standardized outcome section

## Overview

When user reports a candidate outcome (fraud, no-show, bad interview, rejection reason), update the candidate's historic record with a standardized outcome section.

## Invocation

User says one of:
- "[Name] was a fraud / fraudster / fake"
- "[Name] no-showed"
- "[Name] was rejected because..."
- "[Name] turned out to be [outcome]"
- "Mark [Name] as [outcome]"

## Workflow

### Step 1: Find the Candidate Record

Search these locations for the candidate's file:
```
# 4-Stage Pipeline Directories (current)
$RECRUITING_DIR/Screenings/           # resume-screening output
$RECRUITING_DIR/Phone Screens/        # phone-screen-prep output
$RECRUITING_DIR/Interview Prep/       # interview-prep output
$RECRUITING_DIR/Debriefs/             # interview-synthesis output

# Agency candidates (check agency subdirectories)
$RECRUITING_PHONE_SCREENS_DIR/{agencyName}/

# Legacy directories (deprecated, check for older candidates)
$RECRUITING_DIR/Phone Screen Notes/
$RECRUITING_DIR/Phone Screen Notes/DONE/
```

**Agency directories to check:**
- `$RECRUITING_PHONE_SCREENS_DIR/interlinkedRecruitment/`
- (Add other agencies as they are used)

**Also update the tracking CSV:**

| Source | CSV to Update |
|--------|---------------|
| **Agency candidate** | `$RECRUITING_PHONE_SCREENS_DIR/{agencyName}/candidate-reviews.csv` |
| **Direct-apply** | `$RECRUITING_DIR/candidate-tracker.csv` |

### Step 2: Determine Outcome Type

| Outcome | Tag | Description |
|---------|-----|-------------|
| **FRAUDSTER** | `🚨 FRAUDSTER` | Fabricated credentials, impossible titles, hung up when challenged |
| **NO-SHOW** | `⛔ NO-SHOW` | Failed to appear for scheduled interview(s) |
| **NEVER-HIRE** | `🚫 NEVER-HIRE` | Disqualified permanently (fraud, no-show, egregious behavior) |
| **REJECTED** | `❌ REJECTED` | Did not pass interview loop (normal rejection) |
| **WITHDREW** | `🔙 WITHDREW` | Candidate withdrew from process |
| **OFFER_DECLINED** | `📉 OFFER_DECLINED` | Received offer but declined |

### Step 3: Add Outcome Section

Insert this section immediately after the `## Decision` section:

```markdown
---

## ⚠️ OUTCOME (Post-Process)

**Status:** [FRAUDSTER | NO-SHOW | NEVER-HIRE | REJECTED | WITHDREW | OFFER-DECLINED]
**Date Recorded:** [YYYY-MM-DD]
**Recorded By:** [User name or "Matt Bordenet"]

**Details:**
[What happened — be specific. Include dates, what was discovered, how it was discovered.]

**Fraud Signals (if applicable):**
- [Signal 1]
- [Signal 2]

**Action Taken:**
- [ ] Blocked in email
- [ ] Closed in Paylocity
- [ ] Added to fraud watchlist
- [ ] Rejection email sent

---
```

### Step 4: Update Decision Section

If the original decision was HIRE or PROBE, update it to reflect the outcome:

```markdown
**Recommendation:** ~~HIRE~~ → NEVER-HIRE (see Outcome section)
```

### Step 5: Confirm with User

After updating, show:
1. The file that was updated
2. The outcome section that was added
3. Ask if any additional details should be recorded

## Fraud Watchlist

When marking a candidate as FRAUDSTER, also check:
1. **Same employer claims** — Search for other candidates who claimed the same company/title
2. **Similar resume patterns** — AI-slop, impossible titles, same formatting
3. **Report to user** — "Found X other candidates who claimed [same employer]. Want me to flag them?"

## Examples

### Example 1: Fraud Detection

User: "Roilan Roman was a fraudster — claimed L8 at Amazon and hung up when I asked about it"

Action:
1. Find `Roilan_Roman__SrSDE__2026-01-23.md`
2. Add outcome section with FRAUDSTER status
3. Note: "Claimed 'Staff Software Engineer (L8)' at Amazon. L8 = Distinguished Engineer (~100 people worldwide). Hung up immediately when asked to explain."
4. Search for other Amazon L8 claimants

### Example 2: No-Show

User: "Bin Liu no-showed the interview loop"

Action:
1. Find `Bin_Liu__SrSDE__Interview_Sheet.md`
2. Add outcome section with NO-SHOW status
3. Note: "Failed to join scheduled interview loop. No communication."

### Example 3: Multiple No-Shows

User: "Daniel Lee was a no-show to three slots"

Action:
1. Find candidate record
2. Add outcome section with NO-SHOW status
3. Note: "No-showed 3 scheduled phone screens. Pattern indicates fake persona."
4. Flag as NEVER-HIRE


## Failure Modes & Recovery

- **Candidate not in tracker**: If candidate record doesn't exist, create a minimal entry first via `candidate-tracker`, then record the outcome
- **Duplicate outcome records**: If candidate already has an outcome recorded, confirm with user before overwriting — may indicate a re-application
- **Ambiguous verdict**: If user's intent is unclear (e.g., "we're passing for now"), ask for explicit HIRE/REJECT/HOLD before recording