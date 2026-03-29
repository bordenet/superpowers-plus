---
name: [por-project]-registry
source: superpowers-[product]
description: Manages Plan-of-Record (PoR) project mappings between PowerPoint business projects and Linear issues. Use when "register PoR projects", "map projects to Linear", "update project registry", "paste PowerPoint bullets", "sync PoR to Linear".
summary: "Use when: managing PoR project mappings between PowerPoint and Linear."
triggers: ["register PoR projects", "map projects to Linear", "update project registry", "paste PowerPoint bullets", "sync PoR to Linear"]
coordination:
  group: por
  order: 1
  requires: []
  enables: []
  escalates_to: []
  internal: false
---

# PoR Project Registry

> **Purpose:** Create and maintain the mapping between PoR business projects and Linear structure
> **Scope:** Current Linear team from `LINEAR_TEAM_NAME` / `LINEAR_TEAM_ID`
> **Source of Truth:** Monthly PoR PowerPoint deck

---

## When to Invoke

- User says "register PoR projects" or "map projects to Linear"
- User pastes PowerPoint bullets from PoR deck
- User says "update project registry" or "sync projects"
- Beginning of a new PoR cycle (monthly)

---

## Interactive Intake Workflow

### Step 1: Request PoR Project List

```
Please paste the project bullets from your current Plan-of-Record PowerPoint deck.

Example format:
• [Product] Reliability & Performance
• Portal Launch
• xTime Integration Phase 2
• Receptionist Report Enhancements

I'll create a project registry mapping these to Linear structure.
```

### Step 2: For Each Project, Gather Metadata

For each pasted project, ask:

```
Project: "[PROJECT NAME]"

1. **Aliases** — What other names/abbreviations might engineers use?
   (e.g., "reliability", "perf", "stability" for "[Product] Reliability & Performance")

2. **Linear Labels** — Which existing Linear labels apply?
   (I'll search for matches: `search_issues_linear(query: "[project]")`)

3. **Linear Project/Initiative** — Does an existing Linear Project or Initiative exist?
   (If not, should we create one?)

4. **ADO Repos** — Which Azure DevOps repos contain related work?
   (e.g., [telephony-service], agent-api, config-service)

5. **Stakeholder Description** — One-sentence business-friendly description for reports
```

### Step 3: Validate Against Linear

For each project, verify:
- [ ] Labels exist in Linear (query if unsure)
- [ ] Project/Initiative exists OR user confirms creation
- [ ] No orphan mapping (at least one linkage)

### Step 4: Save Registry

Save to `~/.augment/[por-project]-registry.yaml`: <!-- doctor-ignore: created at runtime -->

```yaml
# Plan-of-Record Project Registry
# Generated: YYYY-MM-DD
# Source: PoR PowerPoint for [MONTH YEAR]

version: 1
team: team-name-slug
por_month: "March 2026"

projects:
  - name: "[Product] Reliability & Performance"
    aliases: ["reliability", "perf", "stability", "memory leak", "latency"]
    linear:
      labels: ["reliability", "performance", "tech-debt"]
      initiative: "[product]-reliability-2026"  # or null if none
      project: null
    azure_devops:
      repos: ["[telephony-service]", "agent-api"]
    stakeholder_description: "Improving system stability, reducing latency, fixing production bugs"
    
  - name: "Portal Launch"
    aliases: [\"acquisitionportal\", "acquisitionportal", "acquisition", "outbound"]
    linear:
      labels: ["roadmap", \"acquisitionportal\"]
      initiative: null
      project: "acquisitionportal"
    azure_devops:
      repos: ["acquisition-service", "config-service", "[telephony-service]"]
    stakeholder_description: "Outbound AI agent for vehicle acquisition leads"
```

---

## Registry Schema Reference

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `name` | string | ✅ | Exact name from PoR PowerPoint |
| `aliases` | string[] | ✅ | Search terms engineers might use |
| `linear.labels` | string[] | ⚠️ | Linear labels (at least one linkage required) |
| `linear.initiative` | string | ⚠️ | Linear Initiative slug (if exists) |
| `linear.project` | string | ⚠️ | Linear Project slug (if exists) |
| `azure_devops.repos` | string[] | ✅ | ADO repos for work validation |
| `stakeholder_description` | string | ✅ | Business-friendly one-liner |

---

## Commands

| Command | Action |
|---------|--------|
| `[por-project]-registry init` | Interactive wizard to create new registry |
| `[por-project]-registry show` | Display current registry |
| `[por-project]-registry validate` | Check registry against actual Linear labels/projects |
| `[por-project]-registry add [name]` | Add single project interactively |

---

## Validation Rules

<EXTREMELY_IMPORTANT>

Before saving registry:
1. **Each project must have at least one Linear linkage** — label, initiative, or project
2. **Labels must exist** — Query Linear to verify
3. **ADO repos must be valid** — Cross-check with `repo_list_repos_by_project_azure-devops`
4. **No duplicate aliases** — Each alias should map to exactly one project

</EXTREMELY_IMPORTANT>

---


## Failure Modes

| Mode | Symptom | Recovery |
|------|---------|----------|
| Stale registry | Wrong project mapping | Query ADO API, do not hardcode |

## Companion Skills

- **[por-linear]-triage**: Uses registry to classify issues
- **[por-work]-audit**: Uses registry to validate completed work
- **[por-stakeholder]-report**: Uses registry to generate reports

## Common Failure Modes

- **Stale registry:** Not updating project status after milestone completions
- **Missing projects:** Registry doesn't include all active work streams
- **Incorrect ownership:** Listing wrong project leads or stakeholders
