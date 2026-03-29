# Next Actions Engine

> **Module for:** recruiting-pipeline
> **Purpose:** Generate proactive suggestions based on pipeline state and elapsed time

---

## Action Priority Framework

| Priority | Color | Meaning | SLA |
|----------|-------|---------|-----|
| 🔴 **P0** | Red | Urgent — candidate at risk | Today |
| 🟠 **P1** | Orange | Important — action needed soon | 1-2 days |
| 🟡 **P2** | Yellow | Normal — scheduled work | This week |
| 🟢 **P3** | Green | Low — can defer | When convenient |

---

## Action Generation Rules

### By Current Stage

#### SCREENED (verdict = HIRE)

| Days Since | Priority | Action |
|------------|----------|--------|
| 0-2 | 🟢 P3 | Schedule phone screen when ready |
| 3-5 | 🟡 P2 | Schedule phone screen — candidate may cool off |
| 6-7 | 🟠 P1 | **Schedule phone screen urgently** — at risk of losing interest |
| 8+ | 🔴 P0 | **STALE CANDIDATE** — Re-engage or close out |

**Action template:**
```markdown
🟠 **Schedule phone screen for [Name]**
- Screened [X] days ago on [date]
- Verdict: HIRE — [brief reason]
- Source: [source]
- → Action: Send calendar invite, then invoke `phone-screen-prep`
```

#### PHONE_SCHEDULED

| Days Until/Since | Priority | Action |
|------------------|----------|--------|
| >2 days until | 🟢 P3 | No action needed |
| 1 day until | 🟡 P2 | Prep phone screen sheet if not done |
| Day of | 🔴 P0 | **Prep NOW** if sheet doesn't exist |
| Overdue | 🔴 P0 | **Update status** — did phone happen? |

**Action template:**
```markdown
🔴 **Prep phone screen for [Name]** — SCHEDULED TOMORROW
- Phone screen: [date/time]
- No prep file found at expected path
- → Invoke `phone-screen-prep` immediately
```

#### PHONE_COMPLETE

| Days Since | Priority | Action |
|------------|----------|--------|
| 0-1 | 🟢 P3 | Synthesize when ready |
| 2-3 | 🟡 P2 | Synthesize — memory fades |
| 4-5 | 🟠 P1 | **Synthesize urgently** — details getting stale |
| 6+ | 🔴 P0 | **STALE** — Decision needed now |

**Action template:**
```markdown
🟠 **Synthesize phone screen for [Name]**
- Phone screen completed [X] days ago
- Notes at: [path]
- → Invoke `phone-screen-synthesis`, then decide: loop or reject?
```

#### LOOP_SCHEDULED

| Days Until/Since | Priority | Action |
|------------------|----------|--------|
| >3 days until | 🟢 P3 | Prep interview sheet when ready |
| 1-3 days until | 🟡 P2 | Prep interview sheet |
| Day of | 🔴 P0 | **Ensure prep is done** |
| Overdue | 🔴 P0 | **Update status** — did loop happen? |

#### LOOP_COMPLETE

| Days Since | Priority | Action |
|------------|----------|--------|
| 0-1 | 🟡 P2 | Collect feedback, synthesize |
| 2 | 🟠 P1 | **Decide NOW** — candidate waiting |
| 3+ | 🔴 P0 | **URGENT DECISION** — losing candidate |

#### OFFER_EXTENDED

| Days Since | Priority | Action |
|------------|----------|--------|
| 0-3 | 🟢 P3 | Await response |
| 4-7 | 🟡 P2 | Follow up on offer |
| 8-14 | 🟠 P1 | **Push for decision** |
| 15+ | 🔴 P0 | **Offer stale** — close or re-negotiate |

---

## Aggregate Actions

Beyond individual candidates, generate pipeline-level actions:

### Weekly Batch Review

```markdown
🟡 **Weekly Agency Review**
- [X] new candidates from Interlinked (unreviewed)
- [Y] new candidates from Insight Global (unreviewed)
- → Invoke `agency-batch-triage` for each agency
```

### Funnel Health Alert

```markdown
🟠 **Funnel Health: Low Phone Conversion**
- Last 30 days: 5/20 screenings → phone (25%)
- Target: >40%
- Possible causes: Too strict at screening? Poor candidate pool?
- → Review recent NO HIRE verdicts
```

### Fraud Pattern Alert

```markdown
🔴 **Fraud Ring Detected**
- 3 candidates claiming "CloudScale Technologies"
- 2 already flagged as fraudsters
- 1 new application today: [Name]
- → Flag [Name] for enhanced verification
```

---

## Output Format

### Daily Summary

```markdown
## Recruiting Actions for Today

### 🔴 P0 — Do Now
1. **Prep phone screen for Alex Chen** — call in 2 hours
2. **Decide on Maria Garcia** — loop was 4 days ago

### 🟠 P1 — Do Today
3. **Synthesize phone screen for James Wilson** — 5 days old
4. **Follow up on offer to Sarah Lee** — 10 days waiting

### 🟡 P2 — This Week
5. Schedule phone screen for Tom Brown (screened 4 days ago)
6. Prep interview sheet for Kim Patel (loop in 3 days)

### 🟢 P3 — When Convenient
7. Review 6 new agency candidates from Interlinked
```

### Action Detail Card

```markdown
## Action: Prep Phone Screen

**Candidate:** Alex Chen
**Priority:** 🔴 P0
**Deadline:** Today, 2:00 PM

**Context:**
- Screened 2026-03-10, verdict HIRE
- Source: Direct Apply
- Key concern: Verify AWS CDK depth (resume claims are vague)

**Files:**
- Screening: `$RECRUITING_DIR/Screenings/Alex_Chen__SrSDE__2026-03-10.md`
- Phone notes: (to be created)

**Command:**
```
Invoke `phone-screen-prep` for Alex Chen
```

---

## Query Examples

### "What should I work on?"

1. Read all active candidates from CSV
2. Calculate days-in-stage for each
3. Apply priority rules
4. Sort by priority (P0 first)
5. Return top 5 actions

### "Any urgent recruiting items?"

1. Filter to P0 and P1 only
2. Return with deadlines

### "Prep everything for tomorrow"

1. Find PHONE_SCHEDULED with date = tomorrow
2. Find LOOP_SCHEDULED with date = tomorrow
3. Generate prep actions for each
