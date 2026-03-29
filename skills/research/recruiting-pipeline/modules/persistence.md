# Persistence & Outcome Recording

> **Module for:** recruiting-pipeline
> **Purpose:** Read pipeline state from CSV, record outcomes to superpowers-plus

---

## Data Sources

### Primary: candidate-tracker.csv

**Location:** `$RECRUITING_DIR/candidate-tracker.csv`

**Read CSV:**
```bash
cat "$RECRUITING_DIR/candidate-tracker.csv"
```

**Parse Structure:**
```csv
date_screened,first_name,last_name,email,email_alt,phone,linkedin_url,github_url,source,verdict,status,fraud_flag,notes
```

**Column Indices (0-based):**
| Index | Column | Used For |
|-------|--------|----------|
| 0 | date_screened | Age calculations |
| 1 | first_name | Candidate lookup |
| 2 | last_name | Candidate lookup |
| 3 | email | Duplicate detection |
| 5 | phone | Duplicate detection |
| 8 | source | Agency vs direct |
| 9 | verdict | HIRE/NO HIRE/PROBE |
| 10 | status | Pipeline stage |
| 11 | fraud_flag | Fraud detection |
| 12 | notes | Context |

### Secondary: Agency Trackers

**Location pattern:** `$RECRUITING_PHONE_SCREENS_DIR/{agencyName}/candidate-reviews.csv`

**Known agencies:**
- `interlinkedRecruitment/`
- `insightGlobal/`
- (add as discovered)

---

## Read Operations

### Get All Active Candidates

```bash
# Non-terminal statuses
grep -E "SCREENED|PHONE_SCHEDULED|PHONE_COMPLETE|LOOP_SCHEDULED|LOOP_COMPLETE|OFFER_EXTENDED" \
  "$RECRUITING_DIR/candidate-tracker.csv"
```

### Get Candidate by Name

```bash
grep -i "firstname.*lastname\|lastname.*firstname" "$RECRUITING_DIR/candidate-tracker.csv"
```

### Get Candidates by Stage

```bash
grep ",PHONE_SCHEDULED," "$RECRUITING_DIR/candidate-tracker.csv"
```

### Get Fraud-Flagged Candidates

```bash
grep -E "FRAUDSTER|NO-SHOW|NEVER-HIRE" "$RECRUITING_DIR/candidate-tracker.csv"
```

---

## Write Operations

### Update Status

Use `str-replace-editor` to modify the CSV in place:

1. Find the row by unique identifier (email preferred)
2. Replace the status column value
3. Verify the edit

**Example:** Change [Name] from SCREENED to PHONE_SCHEDULED
```
Old: 2026-03-10,John,Doe,john@example.com,,555-1234,linkedin.com/in/johndoe,,DIRECT-APPLY,HIRE,SCREENED,,Good candidate
New: 2026-03-10,John,Doe,john@example.com,,555-1234,linkedin.com/in/johndoe,,DIRECT-APPLY,HIRE,PHONE_SCHEDULED,,Good candidate
```

### Add Fraud Flag

When marking as fraudster, update BOTH columns:
- `status` → `REJECTED` (or current terminal)
- `fraud_flag` → `FRAUDSTER`

---

## superpowers-plus Integration

### Recording Outcomes

Outcome data is tracked at:
```
~/.codex/.learning-state.json
```

**Record command:**
```bash
node ~/.codex/superpowers-augment/superpowers-augment.js record-outcome <skill> <success|failure> [evidence]
```

### When to Record

| Event | Skill | Outcome | Evidence Template |
|-------|-------|---------|-------------------|
| Candidate hired | `recruiting-pipeline` | success | "Hired [Name] from [source]. Duration: X days." |
| Candidate rejected (correctly) | `recruiting-pipeline` | success | "Filtered [Name] at [stage]. Reason: [reason]" |
| Fraudster caught at screening | `resume-screening` | success | "Detected fraud: [signals]" |
| Fraudster caught at phone | `resume-screening` | failure | "Fraud not caught until phone: [signals]" |
| Good candidate lost | `recruiting-pipeline` | failure | "Lost [Name] due to [reason]" |

### Recording Commands

```bash
# Successful hire
node ~/.codex/superpowers-augment/superpowers-augment.js record-outcome \
  recruiting-pipeline success \
  "Hired Jane Smith via Interlinked. 18 days screen-to-offer."

# Caught fraudster early
node ~/.codex/superpowers-augment/superpowers-augment.js record-outcome \
  resume-screening success \
  "Detected DPRK fraud pattern: impossible L8 claim, hung up when challenged."

# Missed fraudster
node ~/.codex/superpowers-augment/superpowers-augment.js record-outcome \
  resume-screening failure \
  "Fraudster John Doe passed screening, caught at phone screen."

# Record fraud ring pattern
node ~/.codex/superpowers-augment/superpowers-augment.js record-pattern \
  "Multiple candidates claiming TechVentures LLC" \
  fraud-ring-detection
```

---

## Fraud Ring Detection

### Pattern Storage

Fraud patterns are tracked in two places:

1. **CSV:** `fraud_flag` column + `notes` column (employer name)
2. **Learning state:** Recorded via `record-pattern` command

### Detection Algorithm

```python
def detect_fraud_ring(new_candidate):
    # Step 1: Extract employer claims from resume
    employers = extract_employers(new_candidate.resume)
    
    # Step 2: Check against known fraud cases
    fraudsters = get_flagged_fraudsters()
    
    for employer in employers:
        matches = [f for f in fraudsters if employer in f.notes]
        if matches:
            return FraudRingAlert(
                employer=employer,
                known_fraudsters=matches,
                new_candidate=new_candidate
            )
    
    # Step 3: Check for other patterns
    check_phone_patterns(new_candidate)
    check_resume_fingerprints(new_candidate)
    
    return None
```

### Common Fraud Signals

| Signal | Detection Method |
|--------|------------------|
| Same obscure employer | Search notes column for employer name |
| Same phone area code + timing | Check phone column, date_screened within 48h |
| Identical resume sections | Text similarity check (manual) |
| Impossible titles | "L8 Amazon", "Principal at 3 years exp" |
| Immediate hangup when challenged | Recorded in notes |

---

## Query Learning State

To see recruiting-related outcomes:

```bash
# Full learning report
node ~/.codex/superpowers-augment/superpowers-augment.js learning-report

# Check specific skill success rate
node ~/.codex/superpowers-augment/superpowers-augment.js analyze-triggers | grep recruiting
```

---

## Data Retention

- **Active candidates:** Keep in main tracker indefinitely
- **Terminal candidates:** Keep for fraud detection (never delete)
- **Outcome records:** Persist in `.learning-state.json` indefinitely
