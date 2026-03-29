# CSV Tracking for Agency Batch Triage

## Correct File

```
$RECRUITING_PHONE_SCREENS_DIR/{agencyName}/candidate-reviews.csv
```

**NOT** `$RECRUITING_DIR/candidate-tracker.csv` — that's a different skill with a different schema.

## Schema

```csv
FName,LName,Email,DateTime,Disposition,Status,Notes
```

**Status values:**
- `CV Screened` — Reviewed, rejected
- `Candidate Invited` — Passed, phone screen sheet created
- `Candidate Applied through Paylocity` — Accepted invite
- `Candidate Interviewed` — Phone screen completed

## CSV Locking (Multi-Agent Safety)

```bash
LOCK_TOOL="$HOME/.codex/superpowers-plus/tools/csv-lock.sh"
CSV_FILE="$RECRUITING_PHONE_SCREENS_DIR/{agencyName}/candidate-reviews.csv"

# 1. ACQUIRE LOCK (waits up to 60s)
$LOCK_TOOL acquire "$CSV_FILE"

# 2. WRITE (append candidate row — header already exists)
echo 'Jane,Example,jane@example.com,2026-03-15 14:30,HIRE,Candidate Invited,"Strong TS/Node background"' >> "$CSV_FILE"

# 3. RELEASE (ALWAYS, even if write fails)
$LOCK_TOOL release "$CSV_FILE"
```

Lock expires after 2 minutes. Stale locks auto-overwritten.

## Verification

After EVERY candidate:
```bash
tail -1 "$RECRUITING_PHONE_SCREENS_DIR/{agencyName}/candidate-reviews.csv"
```

## Wrong Files (DO NOT USE)

| Wrong File | Why |
|------------|-----|
| `$RECRUITING_DIR/candidate-tracker.csv` | Different schema (13 columns) |
| `candidate-tracker.csv` anywhere | Different skill entirely |
| Any file without agency name in path | Agency candidates go in agency dirs |

## Two Tracking Systems

| System | File | Schema |
|--------|------|--------|
| **Agency batch** (this skill) | `{agency}/candidate-reviews.csv` | 7 columns |
| **Candidate tracker** (other skill) | `candidate-tracker.csv` | 13 columns |
