---
name: [product]-investigator-maintenance
source: superpowers-[product]
description: Keeps the [product]-investigator skill in sync with the [Product] codebase by scanning git history for changes that affect investigation queries, log messages, constants, and DB schemas.
summary: "Use when: syncing [product]-investigator skill with [Product] codebase changes."
triggers: ["[product] skill maintenance", "maintain [product] skill", "update [product] investigator skill", "sync [product] investigator", "[product] investigator drift check", "check [product] skill for updates", "run [product] maintenance"]
coordination:
  group: [product]
  order: 1
  requires: []
  enables: []
  escalates_to: []
  internal: false
---

# [Product] Investigator Maintenance

> **Source:** superpowers-[product]
> **Type:** Maintenance skill — read-only analysis of [Product] monorepo git history

## When to Use

- Manually: "run [product] maintenance" — before a sprint, after a release, or when investigations return unexpected results
- Auto-suggested: when [product]-investigator loads and detects >10 new commits since `last_maintenance`

## Purpose

Scans [Product] monorepo git history for changes affecting [product]-investigator queries, log patterns, constants, or DB schemas. **NEVER auto-applies changes** — all updates require user approval.

## Prerequisites

- [Product] monorepo cloned locally
- `[PRODUCT]_REPO_PATH` set in `~/.codex/.env`
- Git available in PATH

## Step 1: Resolve Monorepo Path

```bash
source ~/.codex/.env 2>/dev/null
echo "${[PRODUCT]_REPO_PATH:-NOT SET}"
```

If valid → proceed. If not set → ask user for path, verify `.git` exists, save to `~/.codex/.env`. No repo = hard block.

## Step 2: Scan Git History

Read the last maintenance date from the state file:

```bash
source ~/.codex/.env 2>/dev/null
source [product]-investigator-maintenance/.maintenance-state 2>/dev/null \
  || source ~/.codex/skills/[product]-investigator-maintenance/.maintenance-state 2>/dev/null
# $last_maintenance = "2026-03-19"

if [[ -z "${last_maintenance:-}" ]]; then
  echo "🛑 Could not load last_maintenance from .maintenance-state."
  echo "Run from the superpowers-[product] repo root (so [product]-investigator-maintenance/.maintenance-state exists) or re-run install so the skill is present under ~/.codex/skills/."
  exit 1
fi
```

Scan git history from the monorepo root (skip merge commits):

```bash
cd "$[PRODUCT]_REPO_PATH"
git log --no-merges --since="$last_maintenance" --name-only --oneline -- \
  agent-api/ src/ \
  integration-platform/src/ \
  [telephony-service]/src/ \
  config-service/src/ config-service/db/migrations/ \
  reporting-service/src/ reporting-service/db/migrations/ \
  infra/
```

Group results by affected sub-skill using the Watch Path Mapping below.

If zero relevant commits → report "No changes detected" and update `.maintenance-state`. Done.

If >100 relevant commits → warn: "There are N commits since last maintenance. Consider narrowing to the last 2 weeks first."

## Watch Path Mapping

| Monorepo Path | Affected Sub-Skill Files | What to Check |
|---------------|------------------------|---------------|
| `agent-api/` and `src/` (root) | agent-api.md, agent-api-reference.md | Log messages, tool definitions, model config, integration routing, DMS/scheduler handlers |
| `integration-platform/src/` | integration-platform.md, integration-platform-reference.md | SQS types, log messages, constants, metrics, Redis keys, polling logic, DataFeedProvider lifecycle |
| `[telephony-service]/src/` | [telephony-service].md | Log messages, call lifecycle events, SIP patterns, websocket streaming |
| `config-service/src/` | config-service.md | API endpoints, schema types |
| `config-service/db/migrations/` | config-service.md | New columns, renamed columns, new tables |
| `reporting-service/src/` | reporting-service.md, reporting-advanced-queries.md | Query patterns, schema types |
| `reporting-service/db/migrations/` | reporting-service.md, reporting-advanced-queries.md, performance-analytics.md, performance-supplementary.md | New columns, renamed columns, new tables |
| `infra/` | All sub-skills (environment tables) | Log group names, Lambda names, AWS profiles |

## Step 3: Diff Analysis

For each relevant commit, run `git diff <commit>~1 <commit> -- <watched paths>` and classify changes.

**Cross-reference step (mandatory):** For each detected change, grep the old value across all [product]-investigator skill files to find exact line matches:

```bash
grep -rn "<old_value>" [product]-investigator/ [product]-investigator/references/
```

If grep finds matches → **High confidence** (exact string in skill will break).
If grep finds no matches → **Low confidence** (code changed but skill doesn't reference it directly). Report as informational only.

### Change Detection Patterns

| Change Type | Detection Method | Impact |
|-------------|-----------------|--------|
| Log message changed | Diff lines matching `logger.info\|warn\|error` with `-` (removed) and `+` (added) | Queries filtering on old message string will return nothing |
| New log message | New `logger.*` calls in `+` lines only | Informational only — flag as "new log message available" but do NOT propose adding queries (that's a feature, not maintenance) |
| Enum/constant changed | Diff on `enum`, `const`, or UPPER_CASE assignments | Hardcoded values in skill are wrong |
| New enum value | New entry in existing enum | Skill may not know about new message type or status |
| DB migration added | New `.sql` file in `db/migrations/` | SQL queries may reference missing columns or wrong types |
| Column added | `ADD COLUMN` in migration SQL | New data available for queries |
| Column renamed | `RENAME COLUMN` in migration SQL | Existing queries will break |
| Column dropped | `DROP COLUMN` in migration SQL | Existing queries will break |
| Metric added/changed | Diff on `metrics-catalog.ts` or `putMetric` calls | IP9 metrics table incomplete |
| Constants changed | Diff on files in `constants/`, `types/`, or named `*.constants.ts` | Hardcoded values (polling interval, TTLs, thresholds) wrong |
| Redis key pattern changed | Diff on cache key construction | Redis cache structure table outdated |
| Log group name changed | Diff on CDK/CloudFormation stack definitions in `infra/` | Environment tables have wrong log group names |

**Confidence:** High = exact string match in skill. Medium = structural change likely affects skill. Low = indirect, may not matter.

## Step 4: Present Maintenance Report

Table: `| # | File | What Changed | Commit | Confidence |` — group by High/Medium/Low confidence. List "No Action Needed" services with reason. Ask: "Approve all? Review individually? Skip?"

**Wait for user confirmation before ANY edits.**

## Step 5: Apply Approved Changes

For each approved change:

1. Open the affected .md file
2. Find the exact line(s) to update (log message string, enum value, table row, etc.)
3. Make the surgical edit — do NOT rewrite entire sections
4. Show the diff to the user after each edit

After all edits are applied:

1. Run `sp-doctor` on [product]-investigator to verify health
2. Update `.maintenance-state` file: `echo "last_maintenance=$(date +%Y-%m-%d)" > [product]-investigator-maintenance/.maintenance-state`
3. Run `./install.sh` to deploy updated skills

## Step 6: Suggest Push

Report summary (updated/skipped counts) and offer to commit+push. **Do NOT push without explicit user approval.**

## Failure Modes

- **Git log scan misses relevant commits** → Check deeper history or reset `last_maintenance` date
- **Schema change not reflected in queries** → Verify migrations applied to all environments
- **False positive on cosmetic changes** → Review diff context; grep may match comments or logs
