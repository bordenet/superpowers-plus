---
name: por-work-audit
source: superpowers-cari
description: Validates completed Linear issues against Azure DevOps operational history. Use when "audit completed work", "validate work done", "verify Linear issues", "check PR evidence", "what shipped for [project]".
summary: "Use when: validating completed Linear issues against Azure DevOps history."
triggers: ["audit completed work", "validate work done", "verify Linear issues", "check PR evidence", "what shipped for"]
coordination:
  group: por
  order: 1
  requires: ['por-linear-triage']
  enables: ['por-stakeholder-report']
  escalates_to: []
  internal: false
---

# PoR Work Audit

> **Purpose:** Validate that "Done" Linear issues have real evidence in Azure DevOps
> **Scope:** Your Linear team (configured via `LINEAR_TEAM_ID` in `~/.codex/.env`)
<!-- Config: linear/_shared/project-config.md -->
> **Evidence Required:** PR merged to main + deployed to production

---

## When to Invoke

- User says "audit completed work" or "validate work done"
- User says "verify Linear issues" or "check PR evidence"
- User asks "what shipped for [project]" or "what did we actually deliver"
- Before generating a stakeholder report (to verify claims)
- End of PoR cycle / sprint retrospective

---

## Evidence Chain

```
Linear Issue (Done)
        │
        ▼
┌───────────────────────────────────────────────┐
│  AZURE DEVOPS VALIDATION                       │
├───────────────────────────────────────────────┤
│  Step 1: PR Linked?                            │
│  └─ Search: {PREFIX}-XXX in PR title/description  │
│                                                │
│  Step 2: PR Merged to main?                    │
│  └─ Check: PR status = Completed, target = main│
│                                                │
│  Step 3: Build Passed?                         │
│  └─ Check: CI status on merge commit           │
│                                                │
│  Step 4: Deployed to Production?               │
│  └─ Check: Pipeline run with prod deployment   │
│                                                │
│  Step 5: Timeline Matches?                     │
│  └─ Merge date reasonably close to Done date   │
└───────────────────────────────────────────────┘
        │
        ▼
  VERIFICATION STATUS
```

---

## Verification Statuses

| Status | Criteria | Report Icon |
|--------|----------|-------------|
| **VERIFIED** | PR merged + build passed + deployed to prod | ✅ |
| **PARTIAL** | PR merged but missing build/deploy evidence | ⚠️ |
| **UNVERIFIED** | No linked PR OR PR not merged | ❌ |
| **CONFIG-ONLY** | Explicitly marked as non-code (config, doc) | 📝 |

---

## Audit Workflow

### Step 1: Fetch Done Issues

```
Query Linear for Done issues:
- Team: `LINEAR_TEAM_ID` from `~/.codex/.env` (default: Team Delta)
- Status: Done
- Date range: User-specified (e.g., "last 30 days", "Cycle 13")
- Project filter: Optional (from por-project-registry)
```

### Step 2: For Each Issue, Search ADO

```python
For each {PREFIX}-XXX:
  1. Search PRs: repo_list_pull_requests_by_repo_or_project_azure-devops
     - Query: {PREFIX}-XXX in title or description
     
  2. If PR found:
     - Check status: Completed?
     - Check target: main or master?
     - Get merge commit SHA
     
  3. Check build status via commit check runs:
     - Use repo_search_commits_azure-devops to find merge commit
     - Check CI status on the merge commit (GitHub: check-runs, ADO: build history)
     - Verify: Succeeded?
     
  4. Check deployment:
     - Find pipeline run with "prod" or "production" in name
     - Verify: Succeeded after merge?
```

### Step 3: Generate Audit Report

```markdown
## PoR Work Audit Report
**Period:** YYYY-MM-DD to YYYY-MM-DD
**Project:** [PoR Project Name] (or "All Projects")
**Issues audited:** N

### ✅ Fully Verified (N issues)
| Issue | Title | PR | Merged | Deployed |
|-------|-------|-----|--------|----------|
| DELTA-952 | Fix Memory Leak | PR #1234 | 2026-02-15 | 2026-02-15 |
| DELTA-1173 | TTS Failover Bug | PR #1245 | 2026-02-10 | 2026-02-10 |

### ⚠️ Partially Verified (N issues)
| Issue | Title | Missing Evidence |
|-------|-------|------------------|
| DELTA-811 | Remove priorityMessage | PR merged, no prod deploy found |

### ❌ Unverified (N issues)
| Issue | Title | Concern |
|-------|-------|---------|
| {PREFIX}-XXX | [title] | No linked PR found — may be config/doc only |

### 📊 Summary
- **Verification rate:** XX% fully verified
- **Total PRs merged:** N
- **Production deployments:** N
```

---

## ADO Search Patterns

| Search Type | ADO Tool | Query Pattern |
|-------------|----------|---------------|
| Find PR by issue | `repo_list_pull_requests_by_repo_or_project_azure-devops` | Title contains "{PREFIX}-XXX" |
| Find commits | `repo_search_commits_azure-devops` | Message contains "{PREFIX}-XXX" |
| Check PR status | `repo_get_pull_request_by_id_azure-devops` | status = Completed |
| Check build | `repo_search_commits_azure-devops` | Find merge commit, check CI status |

---

## Commands

| Command | Action |
|---------|--------|
| `por-work-audit --days 30` | Audit Done issues from last 30 days |
| `por-work-audit --cycle "Cycle 13"` | Audit specific cycle |
| `por-work-audit --project "[name]"` | Audit specific PoR project |
| `por-work-audit --issue {PREFIX}-XXX` | Audit single issue |
| `por-work-audit --unverified-only` | Show only issues missing evidence |

---

## Handling Exceptions

| Exception | How to Handle |
|-----------|---------------|
| **Config-only change** | User marks issue as CONFIG-ONLY (no PR expected) |
| **Doc-only change** | Same — mark as non-code |
| **PR in different repo** | Search across all team repos |
| **PR not following naming** | Manual lookup by date + author |

---


## Failure Modes

| Mode | Symptom | Recovery |
|------|---------|----------|
| Skip PR verification | Claims unverified work done | Cross-check Linear + ADO PRs |

## Companion Skills

- **por-project-registry**: Defines which repos to search per project
- **por-linear-triage**: Ensures issues are mapped before audit
- **por-stakeholder-report**: Uses audit data for verified claims


## Common Failure Modes

- **Incomplete scope:** Auditing only recent work items and missing older ones in the plan
- **Status mismatch:** Reporting work as complete based on issue status without verifying actual delivery
- **Missing stakeholder context:** Auditing without understanding who needs what by when
