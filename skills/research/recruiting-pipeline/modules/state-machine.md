# Pipeline State Machine

> **Module for:** recruiting-pipeline
> **Purpose:** Define valid state transitions and enforce pipeline rules

---

## State Definitions

| State | Code | Description | Valid Next States |
|-------|------|-------------|-------------------|
| **Screened** | `SCREENED` | Resume reviewed, verdict rendered | `PHONE_SCHEDULED`, `REJECTED` |
| **Phone Scheduled** | `PHONE_SCHEDULED` | Phone screen booked | `PHONE_COMPLETE`, `NO_SHOW`, `WITHDREW` |
| **Phone Complete** | `PHONE_COMPLETE` | Phone screen conducted | `LOOP_SCHEDULED`, `REJECTED`, `WITHDREW` |
| **Loop Scheduled** | `LOOP_SCHEDULED` | Interview loop booked | `LOOP_COMPLETE`, `NO_SHOW`, `WITHDREW` |
| **Loop Complete** | `LOOP_COMPLETE` | All interviews conducted | `OFFER_EXTENDED`, `REJECTED` |
| **Offer Extended** | `OFFER_EXTENDED` | Offer made to candidate | `HIRED`, `OFFER_DECLINED` |
| **Hired** | `HIRED` | Candidate accepted, terminal | — |
| **Rejected** | `REJECTED` | Did not pass, terminal | — |
| **Withdrew** | `WITHDREW` | Candidate withdrew, terminal | — |
| **No-Show** | `NO_SHOW` | Failed to appear, terminal | — |
| **Fraudster** | `FRAUDSTER` | Confirmed fraud, terminal | — |

---

## State Transition Diagram

```
                                    ┌─────────────┐
                                    │  FRAUDSTER  │ (terminal)
                                    └──────▲──────┘
                                           │ (fraud detected at any stage)
                                           │
┌──────────┐    ┌─────────────────┐    ┌───┴───────────┐    ┌───────────────┐
│  RESUME  │───▶│    SCREENED     │───▶│PHONE_SCHEDULED│───▶│ PHONE_COMPLETE│
│ RECEIVED │    │                 │    │               │    │               │
└──────────┘    └────────┬────────┘    └───────┬───────┘    └───────┬───────┘
                         │                     │                     │
                         ▼                     ▼                     ▼
                    ┌─────────┐          ┌─────────┐          ┌─────────────────┐
                    │REJECTED │          │ NO_SHOW │          │  LOOP_SCHEDULED │
                    └─────────┘          │ WITHDREW│          │                 │
                                         └─────────┘          └────────┬────────┘
                                                                       │
                                                                       ▼
┌──────────┐    ┌─────────────────┐    ┌───────────────┐    ┌──────────────────┐
│  HIRED   │◀───│ OFFER_EXTENDED  │◀───│ LOOP_COMPLETE │◀───│   (interviews)   │
│(terminal)│    │                 │    │               │    └──────────────────┘
└──────────┘    └────────┬────────┘    └───────┬───────┘
                         │                     │
                         ▼                     ▼
                 ┌───────────────┐       ┌─────────┐
                 │OFFER_DECLINED │       │REJECTED │
                 └───────────────┘       │ WITHDREW│
                                         └─────────┘
```

---

## Transition Rules

### Rule 1: No Skipping Stages

```
INVALID: SCREENED → LOOP_SCHEDULED  (must go through phone)
INVALID: PHONE_SCHEDULED → OFFER_EXTENDED  (must complete phone, then loop)
```

**Exception:** FRAUDSTER and REJECTED can be reached from any non-terminal state.

### Rule 2: Terminal States Are Final

Once in a terminal state (`HIRED`, `REJECTED`, `WITHDREW`, `NO_SHOW`, `FRAUDSTER`), no further transitions allowed.

### Rule 3: Time Constraints

| Transition | Expected Duration | Alert Threshold |
|------------|-------------------|-----------------|
| SCREENED → PHONE_SCHEDULED | 1-3 days | >7 days = stale |
| PHONE_SCHEDULED → PHONE_COMPLETE | 1-5 days | >10 days = at risk |
| PHONE_COMPLETE → LOOP_SCHEDULED | 1-3 days | >5 days = losing candidate |
| LOOP_SCHEDULED → LOOP_COMPLETE | 1-7 days | >14 days = at risk |
| LOOP_COMPLETE → OFFER_EXTENDED | 1-2 days | >3 days = urgent |
| OFFER_EXTENDED → HIRED/DECLINED | 1-7 days | >14 days = stale offer |

---

## State Queries

### Get Candidates by State

```bash
# From candidate-tracker.csv
grep ",PHONE_SCHEDULED," "$RECRUITING_DIR/candidate-tracker.csv"
```

### Count by State

```bash
awk -F',' '{print $11}' "$RECRUITING_DIR/candidate-tracker.csv" | sort | uniq -c
```

### Find Stale Candidates

Look for candidates where:
- State is non-terminal
- `date_screened` + threshold < today

---

## Transition Actions

When transitioning states, these actions are required:

### SCREENED → PHONE_SCHEDULED

1. Update `status` column in tracker CSV
2. Create phone screen calendar invite (manual)
3. Run `phone-screen-prep` to generate notes file

### PHONE_SCHEDULED → PHONE_COMPLETE

1. Update `status` column
2. Ensure phone screen notes are saved
3. Prompt for `phone-screen-synthesis`

### PHONE_COMPLETE → LOOP_SCHEDULED

1. Update `status` column
2. Create loop calendar invites (manual)
3. Run `interview-prep` to generate interview sheet

### LOOP_SCHEDULED → LOOP_COMPLETE

1. Update `status` column
2. Collect all interviewer feedback
3. Prompt for `interview-synthesis`

### Any → FRAUDSTER

1. Update `status` and `fraud_flag` columns
2. Run `candidate-outcome` with fraud details
3. Check for fraud ring patterns
4. Record outcome via candidate-outcome

---

## Validation Function

Before any state transition, validate:

```python
def validate_transition(current_state, new_state, candidate):
    # Check terminal
    if current_state in TERMINAL_STATES:
        raise InvalidTransition(f"Cannot transition from terminal state {current_state}")
    
    # Check valid transitions (except fraud/reject which are always valid)
    if new_state not in ['FRAUDSTER', 'REJECTED', 'WITHDREW']:
        if new_state not in VALID_TRANSITIONS[current_state]:
            raise InvalidTransition(f"Cannot go from {current_state} to {new_state}")
    
    # Check prerequisites
    if new_state == 'PHONE_SCHEDULED' and not candidate.verdict == 'HIRE':
        raise InvalidTransition("Cannot schedule phone for NO HIRE verdict")
    
    return True
```

---

## CSV Column Reference

The `status` column in `candidate-tracker.csv` uses these exact values:
- `SCREENED`
- `PHONE_SCHEDULED`
- `PHONE_COMPLETE`
- `LOOP_SCHEDULED`
- `LOOP_COMPLETE`
- `OFFER_EXTENDED`
- `HIRED`
- `REJECTED`
- `WITHDREW`

The `fraud_flag` column is separate and uses:
- `FRAUDSTER`
- `NO-SHOW`
- `NEVER-HIRE`
- (blank)
