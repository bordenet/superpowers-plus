---
name: [tracker]-lookup
source: superpowers-[product]
triggers: ["[TRACKER]", "[tracker]", "review categories", "review category", "what categories", "what [TRACKER]s", "[service] categories", "review configuration", "review questions"]
description: Look up [Service] review categories ([TRACKER]s) configured for an account or tracking number. Returns category names, reviewer questions, priority, and pause status. Use when investigating how calls are reviewed for a specific account.
summary: "Use when: looking up [Service] review categories for an account or tracking number."
coordination:
  group: [product]
  order: 1
  requires: []
  enables: []
  escalates_to: []
  internal: false
---

# [TRACKER] Category Lookup

> **Source:** `superpowers-[product]`
> **Domain:** Call Review
> **Created:** 2026-03-18

Look up what [Service] review categories ([TRACKER]s) are configured for an account. Returns the [TRACKER] definitions, the question reviewers answer, priority status, and whether reviews are paused.

## When to Use

- User asks what review categories an account has ("what [TRACKER]s does Viva Nissan have?")
- User asks about review configuration ("how are calls reviewed for lskinid 186043?")
- User wants to know reviewer questions ("what questions do reviewers answer for this account?")
- User asks about paused or priority categories

## How to Execute

### Step 1: Resolve the lskinid

The user may provide:

| Input | How to resolve |
|-------|---------------|
| lskinid (number) | Use directly |
| Account name | Query [[database]-prod]: `SELECT lskinid, refname FROM lskin WHERE refname LIKE '%{name}%'` |
| DNIS (tracking number) | Query [[database]-prod]: `SELECT d.dnisid, d.add_lskinid AS lskinid, l.refname FROM dnis d JOIN lskin l ON d.add_lskinid = l.lskinid WHERE d.lednis = '{dnis}'` |
| callid | Use call-lookup skill first, then extract lskinid from the result |

### Step 2: Query [TRACKER]s by lskinid

Use `query_mssql` with connection `[service]-prod`.

**Account-specific categories:**
```sql
SELECT h.[tracker]id, h.display_name, h.[tracker]_question, hl.make_priority, hl.isPaused
FROM [tracker] h
JOIN [tracker]_lskin hl ON h.[tracker]id = hl.frn[tracker]id
WHERE hl.frn_lskinid = {lskinid} AND hl.frn_lskinid != -1
ORDER BY h.[tracker]id
```

**Global (wildcard) categories** — these apply to ALL accounts:
```sql
SELECT h.[tracker]id, h.display_name, h.[tracker]_question, hl.make_priority, hl.isPaused
FROM [tracker] h
JOIN [tracker]_lskin hl ON h.[tracker]id = hl.frn[tracker]id
WHERE hl.frn_lskinid = -1
ORDER BY h.[tracker]id
```

Run both queries. Present account-specific first, then global defaults separately.

### Step 3: Optionally check DNIS-level overrides

Some categories are configured per-DNIS (tracking number), not per-account. If the user provided a DNIS or you have a dnisid:

```sql
SELECT h.[tracker]id, h.display_name, h.[tracker]_question
FROM [tracker] h
JOIN [tracker]_dnis hd ON h.[tracker]id = hd.frn[tracker]id
WHERE hd.frn_dnisid = {dnisid}
ORDER BY h.[tracker]id
```

### Step 4: Format the Output

```
[TRACKER]s for JDA - Viva Nissan El Paso (lskinid: 186043)

Account-specific:
  [TRACKER] 3: Inbound
    Question: "Was the call handled by a qualified employee or interactive system?"
    Priority: No  |  Paused: No

  [TRACKER] 4: Live conversation - outbound
    Question: "Was the call connected to the intended party?"
    Priority: No  |  Paused: No

  [TRACKER] 7: Dealership Sales Visit
    Question: "Did the caller agree to a new visit to the dealership?"
    Priority: No  |  Paused: No

Global defaults (apply to all accounts):
  [TRACKER] 3: Inbound  |  [TRACKER] 7: Dealership Sales Visit  |  [TRACKER] 16: Appointment booked
```

## Key Tables

| Table | Database | Purpose | Key Columns |
|-------|----------|---------|-------------|
| [tracker] | [service]-prod | Category definitions | [tracker]id, display_name, [tracker]_question |
| [tracker]_lskin | [service]-prod | Per-account config | frn[tracker]id, frn_lskinid, make_priority, isPaused |
| [tracker]_dnis | [service]-prod | Per-DNIS overrides | frn[tracker]id, frn_dnisid |
| lskin | [[database]-prod] | Account names | lskinid, refname |
| dnis | [[database]-prod] | Tracking numbers | dnisid, lednis, add_lskinid |

## Gotchas

1. **frn_lskinid = -1 is a wildcard.** These are global categories that apply to all accounts. Always exclude them from account-specific results (`WHERE frn_lskinid != -1`), then show them separately.
2. **Cross-database lookups.** Account names (lskin) and DNIS data (dnis) are on `[[database]-prod]`. [TRACKER] data is on `[service]-prod`. You need two separate queries — no cross-db JOINs.
3. **isPaused = true means reviews are suspended.** The category still exists but reviewers won't see it. Flag this for the user.
4. **make_priority = true means priority review.** These calls go to the front of the review queue.
5. **DNIS overrides are rare.** Most configuration is at the account (lskinid) level. Only check [tracker]_dnis if the user specifically asks about a tracking number.
6. **`frn[tracker]_optionid` cannot be resolved.** The `xcall_long[tracker]` table stores review answer option IDs, but no `[tracker]_option` lookup table exists in any accessible database (`[[database]-prod]`, `[service]-prod`, `shares-prod`). You can report that a call was reviewed for a specific [TRACKER], but cannot resolve the option ID to a human-readable answer. The option ID is still useful for comparing whether two calls got the same review result.


## Common Failure Modes

- **Wrong environment:** Querying [TRACKER] dev database for production data (or vice versa)
- **Stale cache:** Using cached lookup results when live data has changed
- **Missing relationships:** Looking up [TRACKER] records without following foreign key relationships

## Failure Modes

| Mode | Symptom | Recovery |
|------|---------|----------|
| Account name mismatch | No [TRACKER] results | Try account ID, check aliases |
| Paused categories hidden | Reports no [TRACKER]s | Include paused=true |
