---
name: recruiting-pipeline
source: superpowers-recruiting
triggers: ["recruiting status", "pipeline status", "where is [name]", "funnel health", "candidate pipeline", "who's in process", "next recruiting action", "pipeline update", "recruiting dashboard", "active candidates"]
description: Unified recruiting pipeline orchestrator. Tracks candidate state across stages (SCREENED → PHONE → LOOP → OFFER), routes to appropriate skills, detects fraud rings, and suggests proactive next actions.
---

> **⚠️ Environment Required:** This skill needs `$RECRUITING_DIR` and `$RECRUITING_PHONE_SCREENS_DIR`.
> Run `source ~/.codex/.env` before using shell commands. If variables are unset, run `./install.sh` to configure them.

# Recruiting Pipeline Orchestrator

## When to Use

- Checking pipeline state, routing to appropriate recruiting skill, or planning next actions
- User asks "where are we with hiring", "pipeline status", "what's next for [candidate]"
- Detects fraud rings, tracks candidate state across stages (SCREENED → PHONE → LOOP → OFFER)

> **Purpose:** Unified view and intelligent routing for the Senior SDE hiring pipeline
> **Domain:** recruiting
> **Integrates with:** candidate-tracker, resume-screening, phone-screen-prep, interview-prep, candidate-outcome
> **Learning:** Records outcomes to `~/.codex/.learning-state.json` via superpowers-plus

**Announce at start:** "I'm using the **recruiting-pipeline** skill to check pipeline state and suggest next actions."

---

## Overview

This orchestrator provides:

1. **Pipeline State View** — Where is each active candidate?
2. **Intelligent Routing** — Invoke the right skill based on context
3. **Proactive Suggestions** — What should you do next?
4. **Fraud Ring Detection** — Pattern matching across candidates
5. **Outcome Recording** — Feed results to candidate-outcome

---

## Modules (Load On-Demand)

| Module | 🔴 When to Load | Command |
|--------|-----------------|---------|
| **state-machine.md** | Understanding stage transitions | `view modules/state-machine.md` |
| **persistence.md** | Recording outcomes, reading history | `view modules/persistence.md` |
| **next-actions.md** | Generating suggestions | `view modules/next-actions.md` |

---

## Quick Reference

### Pipeline Stages

| Stage | Status Code | Next Action |
|-------|-------------|-------------|
| Resume reviewed | `SCREENED` | Schedule phone screen |
| Phone screen scheduled | `PHONE_SCHEDULED` | Prep phone screen sheet |
| Phone screen done | `PHONE_COMPLETE` | Synthesize → decide loop |
| Loop scheduled | `LOOP_SCHEDULED` | Prep interview sheet |
| Loop done | `LOOP_COMPLETE` | Synthesize → decide offer |
| Offer extended | `OFFER_EXTENDED` | Wait for response |
| Terminal | `HIRED` / `REJECTED` / `WITHDREW` | Archive, record outcome |

### Data Sources

| Source | Location |
|--------|----------|
| Central tracker | `$RECRUITING_DIR/candidate-tracker.csv` |
| Agency trackers | `$RECRUITING_PHONE_SCREENS_DIR/{agency}/candidate-reviews.csv` |
| Screening files | `$RECRUITING_DIR/Screenings/` |
| Phone screen notes | `$RECRUITING_DIR/Phone Screens/` |
| Interview sheets | `$RECRUITING_DIR/Interview Prep/` |
| Debriefs | `$RECRUITING_DIR/Debriefs/` |

---

## Entry Points

### 1. "Recruiting status" / "Pipeline update"

Generate full funnel report:

```markdown
## Recruiting Pipeline Status

**Generated:** [timestamp]

### Active Candidates (by stage)

| Candidate | Stage | Days in Stage | Source | Next Action |
|-----------|-------|---------------|--------|-------------|
| [Name] | PHONE_SCHEDULED | 3 | Interlinked | Prep phone screen |
| [Name] | LOOP_SCHEDULED | 1 | Direct | Prep interview sheet |

### Funnel Health

| Stage | Count | Avg Days | Alerts |
|-------|-------|----------|--------|
| SCREENED (awaiting phone) | 2 | 5 | ⚠️ 1 stale (>7 days) |
| PHONE_COMPLETE (awaiting loop decision) | 1 | 2 | ✅ OK |

### Suggested Actions (Priority Order)

1. 🔴 **Prep phone screen for [Name]** — scheduled for tomorrow
2. 🟡 **Follow up on [Name]** — 8 days since screening, no phone scheduled
3. 🟢 **Review agency batch** — 4 new candidates from Interlinked
```

### 2. "Where is [Name]?"

Query specific candidate:

```markdown
## Candidate Status: [Name]

**Current Stage:** PHONE_COMPLETE
**Days in Stage:** 4
**Source:** RECRUITER:Interlinked

### History
- 2026-03-10: Resume screened → HIRE verdict
- 2026-03-12: Phone screen scheduled
- 2026-03-14: Phone screen completed → Positive

### Files
- Screening: `$RECRUITING_DIR/Screenings/[Name]__SrSDE__2026-03-10.md`
- Phone notes: `$RECRUITING_DIR/Phone Screens/[Name]__Phone_Screen__2026-03-14.md`

### Next Action
📋 **Synthesize phone screen** and decide on loop invite
→ Invoke: `phone-screen-synthesis`
```

### 3. "Funnel health" / "Pipeline analytics"

Aggregate metrics with fraud detection:

```markdown
## Funnel Analytics

**Period:** Last 30 days

### Conversion Rates
| Transition | Count | Rate |
|------------|-------|------|
| Screen → Phone | 12/28 | 43% |
| Phone → Loop | 5/12 | 42% |
| Loop → Offer | 2/5 | 40% |

### Source Performance
| Source | Screened | Phone+ | Fraud Rate |
|--------|----------|--------|------------|
| Direct Apply | 15 | 8 | 13% |
| Interlinked | 10 | 3 | 20% |
| Insight Global | 3 | 1 | 33% |

### 🚨 Fraud Ring Alerts
- **Employer "TechVentures LLC"** — Claimed by 3 candidates, 2 confirmed fraudsters
- **Resume pattern match** — [Name1] and [Name2] have identical project descriptions
```

---

## Intelligent Routing

When user provides input, route to appropriate skill:

| Input Pattern | Route To | Pre-Check |
|---------------|----------|-----------|
| Resume text/screenshot | `resume-screening` | Check `candidate-tracker` first |
| "Prep phone screen for [Name]" | `phone-screen-prep` | Verify status = SCREENED |
| "Phone screen done for [Name]" | Update status → suggest `phone-screen-synthesis` | — |
| "Prep interview for [Name]" | `interview-prep` | Verify status = PHONE_COMPLETE |
| "[Name] no-showed / was fraud" | `candidate-outcome` | Update tracker |
| "Move [Name] to loop" | Update status to LOOP_SCHEDULED | Verify PHONE_COMPLETE |

---

## Fraud Ring Detection

**Load module:** `view modules/persistence.md` for full fraud detection logic.

Quick patterns to check:
1. **Same employer** — Multiple candidates claiming same obscure company
2. **Same phone/email domain** — Shared contact patterns
3. **Resume fingerprints** — Identical project descriptions, same typos
4. **Timing clusters** — Multiple applications within 24 hours from "different" people

When fraud detected:
```markdown
🚨 **FRAUD RING ALERT**

**Pattern:** Same employer "CloudScale Technologies"
**Candidates:**
- [Name1] — Screened 2026-03-01, FLAGGED as fraudster
- [Name2] — Screened 2026-03-10, pending
- [Name3] — NEW application

**Recommendation:** Flag [Name2] and [Name3] for enhanced verification.
Invoke `candidate-outcome` to mark if confirmed.
```

---

## Outcome Recording (superpowers-plus Integration)

After any terminal event, record outcome:

```bash
# When candidate hired
node ~/.codex/superpowers-augment/superpowers-augment.js record-outcome recruiting-pipeline success "Hired [Name] via [source]. Pipeline duration: X days."

# When candidate rejected at loop
node ~/.codex/superpowers-augment/superpowers-augment.js record-outcome recruiting-pipeline success "Correctly filtered [Name] at loop stage."

# When fraud detected early
node ~/.codex/superpowers-augment/superpowers-augment.js record-outcome resume-screening success "Caught fraudster [Name] at screening."

# When fraud slipped through to phone
node ~/.codex/superpowers-augment/superpowers-augment.js record-outcome resume-screening failure "Fraudster [Name] not caught until phone screen."
```

---

## Related Skills

| Skill | Relationship |
|-------|--------------|
| `candidate-tracker` | Data source — reads/writes CSV |
| `resume-screening` | Invoked for new candidates |
| `phone-screen-prep` | Invoked at SCREENED → PHONE_SCHEDULED |
| `phone-screen-synthesis` | Invoked after phone screen |
| `interview-prep` | Invoked at PHONE_COMPLETE → LOOP_SCHEDULED |
| `interview-synthesis` | Invoked after interview loop |
| `candidate-outcome` | Invoked for terminal events (records outcomes for learning) |
