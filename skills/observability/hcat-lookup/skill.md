---
name: hcat-lookup
source: superpowers-cari
triggers: ["HCAT", "hcat", "review categories", "review category", "what categories", "what HCATs", "humanatic categories", "review configuration", "review questions"]
description: Look up Humanatic review categories (HCATs) configured for an account or tracking number. Returns category names, reviewer questions, priority, and pause status. Use when investigating how calls are reviewed for a specific account.
summary: "Use when: looking up Humanatic review categories for an account or tracking number."
coordination:
  group: cari
  order: 1
  requires: []
  enables: []
  escalates_to: []
  internal: false
---

# HCAT Category Lookup

> **Source:** `superpowers-cari`
> **Domain:** Call Review
> **Created:** 2026-03-18

Look up what Humanatic review categories (HCATs) are configured for an account. Returns the HCAT definitions, the question reviewers answer, priority status, and whether reviews are paused.

## When to Use

- User asks what review categories an account has ("what HCATs does Viva Nissan have?")
- User asks about review configuration ("how are calls reviewed for lskinid 186043?")
- User wants to know reviewer questions ("what questions do reviewers answer for this account?")
- User asks about paused or priority categories

## How to Execute

### Step 1: Resolve the lskinid

The user may provide:

| Input | How to resolve |
|-------|---------------|
| lskinid (number) | Use directly |
| Account name | Query callmeasurement-prod: `SELECT lskinid, refname FROM lskin WHERE refname LIKE '%{name}%'` |
| DNIS (tracking number) | Query callmeasurement-prod: `SELECT d.dnisid, d.add_lskinid AS lskinid, l.refname FROM dnis d JOIN lskin l ON d.add_lskinid = l.lskinid WHERE d.lednis = '{dnis}'` |
| callid | Use call-lookup skill first, then extract lskinid from the result |

### Step 2: Query HCATs by lskinid

Use `query_mssql` with connection `humanatic-prod`.

**Account-specific categories:**
```sql
SELECT h.hcatid, h.display_name, h.hc_question, hl.make_priority, hl.isPaused
FROM hcat h
JOIN hcat_lskin hl ON h.hcatid = hl.frn_hcatid
WHERE hl.frn_lskinid = {lskinid} AND hl.frn_lskinid != -1
ORDER BY h.hcatid
```

**Global (wildcard) categories** — these apply to ALL accounts:
```sql
SELECT h.hcatid, h.display_name, h.hc_question, hl.make_priority, hl.isPaused
FROM hcat h
JOIN hcat_lskin hl ON h.hcatid = hl.frn_hcatid
WHERE hl.frn_lskinid = -1
ORDER BY h.hcatid
```

Run both queries. Present account-specific first, then global defaults separately.

### Step 3: Optionally check DNIS-level overrides

Some categories are configured per-DNIS (tracking number), not per-account. If the user provided a DNIS or you have a dnisid:

```sql
SELECT h.hcatid, h.display_name, h.hc_question
FROM hcat h
JOIN hcat_dnis hd ON h.hcatid = hd.frn_hcatid
WHERE hd.frn_dnisid = {dnisid}
ORDER BY h.hcatid
```

### Step 4: Format the Output

```
HCATs for JDA - Viva Nissan El Paso (lskinid: 186043)

Account-specific:
  HCAT 3: Inbound
    Question: "Was the call handled by a qualified employee or interactive system?"
    Priority: No  |  Paused: No

  HCAT 4: Live conversation - outbound
    Question: "Was the call connected to the intended party?"
    Priority: No  |  Paused: No

  HCAT 7: Dealership Sales Visit
    Question: "Did the caller agree to a new visit to the dealership?"
    Priority: No  |  Paused: No

Global defaults (apply to all accounts):
  HCAT 3: Inbound  |  HCAT 7: Dealership Sales Visit  |  HCAT 16: Appointment booked
```

## Key Tables

| Table | Database | Purpose | Key Columns |
|-------|----------|---------|-------------|
| hcat | humanatic-prod | Category definitions | hcatid, display_name, hc_question |
| hcat_lskin | humanatic-prod | Per-account config | frn_hcatid, frn_lskinid, make_priority, isPaused |
| hcat_dnis | humanatic-prod | Per-DNIS overrides | frn_hcatid, frn_dnisid |
| lskin | callmeasurement-prod | Account names | lskinid, refname |
| dnis | callmeasurement-prod | Tracking numbers | dnisid, lednis, add_lskinid |

## Gotchas

1. **frn_lskinid = -1 is a wildcard.** These are global categories that apply to all accounts. Always exclude them from account-specific results (`WHERE frn_lskinid != -1`), then show them separately.
2. **Cross-database lookups.** Account names (lskin) and DNIS data (dnis) are on `callmeasurement-prod`. HCAT data is on `humanatic-prod`. You need two separate queries — no cross-db JOINs.
3. **isPaused = true means reviews are suspended.** The category still exists but reviewers won't see it. Flag this for the user.
4. **make_priority = true means priority review.** These calls go to the front of the review queue.
5. **DNIS overrides are rare.** Most configuration is at the account (lskinid) level. Only check hcat_dnis if the user specifically asks about a tracking number.
6. **`frn_hcat_optionid` cannot be resolved.** The `xcall_long_hcat` table stores review answer option IDs, but no `hcat_option` lookup table exists in any accessible database (`callmeasurement-prod`, `humanatic-prod`, `shares-prod`). You can report that a call was reviewed for a specific HCAT, but cannot resolve the option ID to a human-readable answer. The option ID is still useful for comparing whether two calls got the same review result.


## Common Failure Modes

- **Wrong environment:** Querying HCAT dev database for production data (or vice versa)
- **Stale cache:** Using cached lookup results when live data has changed
- **Missing relationships:** Looking up HCAT records without following foreign key relationships

## Failure Modes

| Mode | Symptom | Recovery |
|------|---------|----------|
| Account name mismatch | No HCAT results | Try account ID, check aliases |
| Paused categories hidden | Reports no HCATs | Include paused=true |
