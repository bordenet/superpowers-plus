# PRD: Reporting Superpower

> **Status:** Draft
> **Author:** Matt J Bordenet
> **Last Updated:** 2026-01-31

## Problem Statement

Each superpowers skill currently implements its own telemetry:
- `perplexity-research` writes to `~/.codex/perplexity-stats.json`
- `detecting-ai-slop` could track detection counts
- `eliminating-ai-slop` could track rewrite success rates

This approach has problems:
1. **Coupling** — Telemetry logic mixed with core skill functionality
2. **Inconsistency** — Each skill invents its own stats format
3. **No aggregation** — Can't analyze patterns across skills
4. **No sync** — Stats are machine-local, not visible across devices
5. **Maintenance burden** — Adding metrics requires modifying each skill

## Solution

A dedicated **reporting superpower** that acts as a bookkeeper agent:
- Skills report outcomes to the reporting superpower
- Reporting superpower aggregates, compiles, and syncs to GitHub
- Decouples telemetry from core skill logic

## Goals

| Goal | Success Metric |
|------|----------------|
| **Decouple telemetry** | Skills contain zero stats-writing code |
| **Standardize format** | All skills use identical outcome schema |
| **Enable aggregation** | Single command shows all skill stats |
| **Cross-machine sync** | Stats visible on any machine after sync |
| **Batch efficiency** | Sync occurs every N reports, not every invocation |

## Non-Goals

- Real-time dashboards (batch sync is sufficient)
- Cloud storage (GitHub is the sync mechanism)
- Historical trend analysis (future enhancement)
- Alerting on degraded success rates (future enhancement)

## User Stories

### US-1: Skill Reports Outcome
**As a** skill author,
**I want to** report outcomes without managing stats files,
**So that** I can focus on core skill logic.

**Acceptance Criteria:**
- Skill invokes reporting superpower with: skill_name, outcome, metadata
- Reporting superpower handles all persistence
- Skill code contains no file I/O for stats

### US-2: View Aggregated Stats
**As a** user,
**I want to** see stats for all skills in one place,
**So that** I can identify which skills are effective.

**Acceptance Criteria:**
- Single command: `./scripts/skill-stats.sh`
- Output shows: skill name, invocations, success rate, last invocation
- Sorted by invocation count (most used first)

### US-3: Sync Stats to GitHub
**As a** user,
**I want to** sync stats to GitHub periodically,
**So that** I can see them on any machine.

**Acceptance Criteria:**
- Sync triggers after N reports (configurable, default: 20)
- Stats stored in `~/.codex/skill-stats/` directory
- GitHub sync via existing `slop-sync` pattern
- Conflict resolution: Last Write Wins

### US-4: Migrate Existing Skills
**As a** maintainer,
**I want to** migrate `perplexity-research` to use reporting superpower,
**So that** it demonstrates the pattern for other skills.

**Acceptance Criteria:**
- `perplexity-research` SKILL.md updated to invoke reporting
- Existing `~/.codex/perplexity-stats.json` migrated to new format
- Backward compatibility: old stats preserved

## Outcome Schema

```json
{
  "skill_name": "perplexity-research",
  "timestamp": "2026-01-31T10:30:00Z",
  "outcome": "SUCCESS",
  "outcome_reason": "Fixed the ignore pattern issue",
  "trigger": "failed_attempts",
  "metadata": {
    "tool": "ask",
    "query_summary": "ESLint 9.x flat config"
  }
}
```

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `skill_name` | string | Yes | Name of the reporting skill |
| `timestamp` | ISO8601 | Yes | When the outcome occurred |
| `outcome` | enum | Yes | SUCCESS, PARTIAL, FAILURE |
| `outcome_reason` | string | Yes | Why this outcome |
| `trigger` | string | No | What triggered the skill |
| `metadata` | object | No | Skill-specific data |

## Aggregated Stats Format

```json
{
  "last_sync": "2026-01-31T12:00:00Z",
  "pending_reports": 3,
  "sync_threshold": 20,
  "skills": {
    "perplexity-research": {
      "total": 42,
      "successful": 38,
      "success_rate": 0.905,
      "last_invocation": "2026-01-31T10:30:00Z"
    },
    "detecting-ai-slop": {
      "total": 15,
      "successful": 15,
      "success_rate": 1.0,
      "last_invocation": "2026-01-30T14:20:00Z"
    }
  }
}
```

## Invocation Protocol

Skills report outcomes by invoking the reporting superpower:

```
📊 **Reporting Outcome**: perplexity-research
- Outcome: SUCCESS
- Reason: Fixed the ignore pattern issue
- Trigger: failed_attempts
```

The reporting superpower then:
1. Appends to `~/.codex/skill-stats/pending.jsonl`
2. Increments pending count
3. If pending >= threshold, triggers sync

## Sync Mechanism

```bash
# Manual sync
./scripts/skill-stats-sync.sh push

# Auto-sync (triggered by reporting superpower)
# Commits to superpowers-plus repo: stats/aggregated.json
```

## Dependencies

- Git (for sync)
- jq (for JSON manipulation)
- Existing `slop-sync` pattern (for conflict resolution)

## Risks

| Risk | Mitigation |
|------|------------|
| Skills forget to report | Linting/review checklist |
| Sync conflicts | Last Write Wins (same as slop-sync) |
| Stats file corruption | JSON validation before write |
| GitHub rate limits | Batch sync (every 20 reports) |

## Timeline

| Phase | Deliverable | Estimate |
|-------|-------------|----------|
| 1 | PRD, Design, Test Spec | Done |
| 2 | Reporting superpower SKILL.md | 1 session |
| 3 | Stats aggregation script | 1 session |
| 4 | Migrate perplexity-research | 1 session |
| 5 | GitHub sync integration | 1 session |

