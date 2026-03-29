---
name: por-stakeholder-report
source: superpowers-cari
description: Generates business-ready progress summaries for stakeholder meetings and PowerPoint. Use when "generate stakeholder report", "what did we ship", "PoR progress update", "prepare for leadership update", "summarize [project] status".
summary: "Use when: generating business-ready progress summaries for stakeholder meetings."
triggers: ["generate stakeholder report", "what did we ship", "PoR progress update", "prepare for leadership update", "summarize status"]
coordination:
  group: por
  order: 1
  requires: []
  enables: []
  escalates_to: []
  internal: false
---

# PoR Stakeholder Report

> **Purpose:** Generate business-ready summaries for PoR reviews and leadership updates
> **Scope:** Your Linear team (configured via `LINEAR_TEAM_ID` in `~/.codex/.env`)
<!-- Config: linear/_shared/project-config.md -->
> **Output:** Markdown, PowerPoint bullets, or executive summary
> **Prerequisite:** por-project-registry + por-work-audit for verified claims

---

## When to Invoke

- User says "generate stakeholder report" or "PoR progress update"
- User asks "what did we ship" or "summarize [project] status"
- User says "prepare for leadership update" or "monthly PoR review"
- Ad-hoc: Before any stakeholder meeting

---

## Report Generation Workflow

### Step 1: Identify Scope

```
Ask user:
1. Which PoR project(s)? (or "All")
2. What time period? (e.g., "last month", "Cycle 13", "since Feb 1")
3. What format? (markdown, bullets, executive)
```

### Step 2: Gather Data

```
For each PoR project:
1. Load registry: ~/.augment/por-project-registry.yaml  # doctor-ignore: created at runtime
2. Fetch Linear issues mapped to this project:
   - Done in period → Completed work
   - In Progress → Current work
   - Backlog/Todo → Upcoming work
3. For Done issues, invoke por-work-audit:
   - Get verification status (VERIFIED, PARTIAL, UNVERIFIED)
   - Get PR/deployment evidence
```

### Step 3: Generate Report

Use appropriate template based on format.

---

## Output Formats

### Format: `markdown` (default)

```markdown
## [PoR Project Name]
**Period:** Feb 1 – Mar 1, 2026

### ✅ Completed This Period
- **Memory leak in telephony service** — Fixed services handler leak causing memory growth.
  [DELTA-952] ✓ PR #1234 merged, deployed 2026-02-15
- **TTS failover bug** — Resolved Deepgram → Azure TTS failover.
  [DELTA-1173] ✓ PR #1245 merged, deployed 2026-02-10

### 🔄 In Progress
- **Active memory leak investigation** — Creating heap dump endpoint for analysis.
  [DELTA-1175] ETA: Cycle 14

### 📋 Backlog (Next Up)
1. Recurring alarm tuning [DELTA-1215]
2. Load testing framework [DELTA-679]

### 📊 Metrics (if available)
| Metric | Before | After |
|--------|--------|-------|
| P1 Alarms/week | 12 | 3 |
```

### Format: `bullets` (for PowerPoint paste)

```
CARI RELIABILITY & PERFORMANCE

Completed:
• Fixed memory leak in telephony service (DELTA-952) — deployed Feb 15
• Resolved TTS failover bug (DELTA-1173) — deployed Feb 10

In Progress:
• Investigating remaining memory growth (DELTA-1175) — ETA Cycle 14

Next Up:
• Alarm tuning to reduce noise
• Load testing framework for scale validation
```

### Format: `executive` (TL;DR)

```markdown
## Cari Reliability — Executive Summary

**Status:** 🟢 On Track

**Key Wins:**
- Memory leak fixed — telephony service now stable under load
- TTS failover working — automatic fallback to Azure when Deepgram fails

**Risks:**
- Secondary memory leak still under investigation (not blocking)

**Next Milestone:** Production load testing (Cycle 14)
```

---

## Verification Indicators

<EXTREMELY_IMPORTANT>

**All "Completed" claims MUST include verification status:**

| Status | Display | Meaning |
|--------|---------|---------|
| ✓ PR merged, deployed | ✅ Verified | Full evidence in ADO |
| ⚠️ PR merged, deploy unconfirmed | ⚠️ Partial | May need manual verification |
| ❌ No PR found | ❌ Unverified | Do NOT include in report without explanation |

**Never claim work is "done" without ADO verification.**

</EXTREMELY_IMPORTANT>

---

## Commands

| Command | Action |
|---------|--------|
| `por-stakeholder-report --project "[name]"` | Report for one PoR project |
| `por-stakeholder-report --all` | Report for all PoR projects |
| `por-stakeholder-report --format bullets` | PowerPoint-ready bullets |
| `por-stakeholder-report --format executive` | TL;DR for leadership |
| `por-stakeholder-report --days 30` | Last 30 days |
| `por-stakeholder-report --cycle "Cycle 13"` | Specific cycle |

---

## Stakeholder-Friendly Language

| Tech Term | Stakeholder Translation |
|-----------|------------------------|
| Memory leak | System stability issue |
| TTS failover | Voice quality backup system |
| Latency reduction | Faster response times |
| Tech debt | Maintenance and cleanup |
| Refactor | Code improvements |
| CI/CD | Automated deployment |

---

## Report Checklist

Before delivering report:
- [ ] All "Completed" items have ADO verification
- [ ] Business-friendly language (no jargon)
- [ ] Stakeholder descriptions from registry used
- [ ] Dates and issue keys accurate
- [ ] Risks/blockers clearly stated

---


## Failure Modes

| Mode | Symptom | Recovery |
|------|---------|----------|
| Incomplete metrics | Misleading report | Verify all data sources first |

## Companion Skills

- **por-project-registry**: Source of project definitions
- **por-linear-triage**: Ensures issues are mapped
- **por-work-audit**: Provides verification evidence

## Common Failure Modes

- **Stale data:** Generating reports from cached project state instead of current Linear/wiki data
- **Missing risks:** Reporting on progress without surfacing blockers or delays
- **Wrong audience:** Using technical detail level inappropriate for the stakeholder
