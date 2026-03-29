---
name: por-linear-triage
source: superpowers-cari
description: Classifies Linear issues into PoR business projects. Use when "triage Linear issues", "map issues to PoR", "find orphaned issues", "bucket work items", "which issues belong to [project]".
summary: "Use when: classifying Linear issues into PoR business projects."
triggers: ["triage Linear issues", "map issues to PoR", "find orphaned issues", "bucket work items", "which issues belong to"]
coordination:
  group: por
  order: 1
  requires: []
  enables: ['por-work-audit']
  escalates_to: []
  internal: false
---

# PoR Linear Triage

> **Purpose:** Classify and bucket Linear issues into Plan-of-Record business projects
> **Scope:** Your Linear team (configured via `LINEAR_TEAM_ID` in `~/.codex/.env`)
<!-- Config: linear/_shared/project-config.md -->
> **Prerequisite:** por-project-registry must be configured

---

## When to Invoke

- User says "triage Linear issues" or "map issues to PoR"
- User says "find orphaned issues" or "bucket work items"
- User asks "which issues belong to [project name]"
- Before generating a stakeholder report
- Start of new PoR cycle

---

## Triage Workflow

### Step 1: Load Project Registry

```
Load ~/.augment/por-project-registry.yaml  # doctor-ignore: created at runtime
If missing → invoke por-project-registry skill first
```

### Step 2: Fetch Linear Issues

```
Query parameters:
- Team: `LINEAR_TEAM_ID` from `~/.codex/.env` (default: Team Delta `cf47d4d8-b5e7-4881-ab2d-64b25cd8aebc`)
- Status filter: User-specified or default to all active states. Resolve live — do not hardcode state names.
  State type groups (use these to filter by category):
  - **Intake:** states with type `triage`
  - **Ready:** states with type `backlog` or `unstarted`
  - **Active:** states with type `started`
  - **Complete:** states with type `completed` or `canceled`
- Date range: Optional (e.g., "last 30 days" or "this cycle")
```

Use: `search_issues_linear(teamId: "${LINEAR_TEAM_ID}", ...)`

### Step 3: Classify Each Issue

For each issue, determine project mapping:

```
1. Check existing mapping:
   - Does issue have Linear Initiative matching registry? → MAPPED
   - Does issue have Linear Project matching registry? → MAPPED
   - Does issue have Label matching registry? → MAPPED

2. If not mapped, analyze content:
   - Search title + description for project aliases
   - Check for related ADO repos in linked PRs
   - Assign confidence score

3. Classification output:
   - Project: [best match or "ORPHANED"]
   - Confidence: HIGH (exact match) / MEDIUM (alias match) / LOW (inference)
   - Reason: [why this classification]
```

### Step 4: Generate Triage Report

```markdown
## PoR Linear Triage Report
**Generated:** YYYY-MM-DD HH:MM
**Issues analyzed:** N

### ✅ Already Mapped (N issues)
| Project | Count | Issues |
|---------|-------|--------|
| Cari Reliability & Performance | 23 | DELTA-1175, DELTA-952, ... |
| SMR Launch | 18 | DELTA-1100, ... |

### 🔍 Suggested Mappings (N issues)
| Issue | Title | Suggested Project | Confidence | Reason |
|-------|-------|-------------------|------------|--------|
| DELTA-1175 | Telephony Service Memory Leak | Cari Reliability | HIGH | Title contains "memory leak" alias |
| DELTA-1216 | CDK Labor Types | Integrations | MEDIUM | Label "integration" present |

### ⚠️ Orphaned Issues (N issues)
| Issue | Title | Why Orphaned |
|-------|-------|--------------|
| DELTA-999 | Update ESLint config | Dev tooling — no PoR project match |
```

---

## Classification Confidence Levels

| Level | Criteria | Auto-Apply? |
|-------|----------|-------------|
| **HIGH** | Linear Initiative/Project matches registry OR multiple alias matches | ✅ Yes |
| **MEDIUM** | Single label or alias match | ⚠️ Ask user |
| **LOW** | Inference from description keywords | ❌ No — manual review |
| **ORPHANED** | No match found | ❌ Report only |

---

## Commands

| Command | Action |
|---------|--------|
| `por-linear-triage --report` | Dry run — show suggestions, don't modify Linear |
| `por-linear-triage --interactive` | Prompt user for each uncertain mapping |
| `por-linear-triage --auto` | Apply HIGH confidence mappings automatically |
| `por-linear-triage --project "[name]"` | Focus on issues for one PoR project |
| `por-linear-triage --orphans-only` | Show only unmapped issues |
| `por-linear-triage --status [status]` | Filter by Linear status (live-resolve state names) |

---

## Applying Mappings to Linear

When user confirms a mapping:

1. **If Linear Initiative exists for project:**
   - Add issue to Initiative

2. **If Linear Project exists for project:**
   - Add issue to Project

3. **If only Labels exist:**
   - Ensure label is applied to issue

4. **If no Linear structure exists:**
   - Prompt: "Create new Linear Initiative '[PoR Project Name]'?"

---

## Bulk Operations

<EXTREMELY_IMPORTANT>

**Before bulk-updating Linear:**
1. ALWAYS show preview of changes
2. ALWAYS get explicit user confirmation
3. Use `update_issue_linear` for each change (no batch API abuse)
4. Log all changes made for audit trail

</EXTREMELY_IMPORTANT>

---


## Failure Modes

| Mode | Symptom | Recovery |
|------|---------|----------|
| Skip triage criteria | Mis-routed ticket | Apply defined triage rules |

## Companion Skills

- **por-project-registry**: Source of project definitions (prerequisite)
- **por-work-audit**: Next step for Done issues
- **por-stakeholder-report**: Uses triage data for reports

## Common Failure Modes

- **Triage without context:** Prioritizing issues without understanding the current plan-of-record
- **Scope inflation:** Adding items to the sprint that weren't approved by the PoR owner
- **Missing dependencies:** Triaging work items without checking for blocking relationships
