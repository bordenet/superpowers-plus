# Design: Reporting Superpower

> **Status:** Draft
> **Last Updated:** 2026-01-31
> **PRD:** [PRD.md](./PRD.md)

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                        Skills Layer                              │
├─────────────────┬─────────────────┬─────────────────────────────┤
│ perplexity-     │ detecting-      │ eliminating-                │
│ research        │ ai-slop         │ ai-slop                     │
└────────┬────────┴────────┬────────┴────────┬────────────────────┘
         │                 │                 │
         │  Report Outcome │                 │
         ▼                 ▼                 ▼
┌─────────────────────────────────────────────────────────────────┐
│                   Reporting Superpower                           │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐              │
│  │ Receive     │→ │ Aggregate   │→ │ Sync        │              │
│  │ Outcome     │  │ Stats       │  │ to GitHub   │              │
│  └─────────────┘  └─────────────┘  └─────────────┘              │
└─────────────────────────────────────────────────────────────────┘
         │                 │                 │
         ▼                 ▼                 ▼
┌─────────────────────────────────────────────────────────────────┐
│                      Storage Layer                               │
├─────────────────┬─────────────────┬─────────────────────────────┤
│ ~/.codex/       │ ~/.codex/       │ superpowers-plus/           │
│ skill-stats/    │ skill-stats/    │ stats/                      │
│ pending.jsonl   │ aggregated.json │ aggregated.json             │
└─────────────────┴─────────────────┴─────────────────────────────┘
```

## Components

### 1. Reporting Superpower (SKILL.md)

**Location:** `skills/reporting/SKILL.md`

**Responsibilities:**
- Receive outcome reports from other skills
- Validate outcome schema
- Append to pending queue
- Trigger sync when threshold reached
- Provide stats summary on request

**Invocation Modes:**
1. **Report** — Skill reports an outcome
2. **Summary** — User requests stats summary
3. **Sync** — Force immediate sync to GitHub

### 2. Pending Queue (pending.jsonl)

**Location:** `~/.codex/skill-stats/pending.jsonl`

**Format:** JSON Lines (one JSON object per line)

```jsonl
{"skill_name":"perplexity-research","timestamp":"2026-01-31T10:30:00Z","outcome":"SUCCESS","outcome_reason":"Fixed issue","trigger":"failed_attempts","metadata":{"tool":"ask"}}
{"skill_name":"detecting-ai-slop","timestamp":"2026-01-31T11:00:00Z","outcome":"SUCCESS","outcome_reason":"Scored document","trigger":"manual","metadata":{"score":47}}
```

**Why JSONL:**
- Append-only (no read-modify-write race conditions)
- Easy to process line-by-line
- Survives partial writes

### 3. Aggregated Stats (aggregated.json)

**Location:** `~/.codex/skill-stats/aggregated.json`

**Format:** See PRD for schema

**Update Process:**
1. Read pending.jsonl
2. Update aggregated.json counters
3. Truncate pending.jsonl
4. If sync threshold reached, push to GitHub

### 4. Sync Script (skill-stats-sync.sh)

**Location:** `scripts/skill-stats-sync.sh`

**Commands:**
- `push` — Commit and push aggregated.json to GitHub
- `pull` — Pull latest from GitHub, merge with local
- `status` — Show pending count and last sync time

**Conflict Resolution:** Last Write Wins (same as slop-sync)

## Data Flow

### Reporting an Outcome

```
1. Skill completes execution
2. Skill evaluates outcome (SUCCESS/PARTIAL/FAILURE)
3. Skill invokes reporting superpower:
   "Report outcome for perplexity-research: SUCCESS - Fixed the issue"
4. Reporting superpower:
   a. Validates schema
   b. Appends to pending.jsonl
   c. Increments pending count in aggregated.json
   d. If pending >= 20, triggers sync
5. Reporting superpower confirms:
   "📊 Recorded: perplexity-research SUCCESS (pending: 5/20)"
```

### Viewing Stats

```
1. User: "Show skill stats"
2. Reporting superpower reads aggregated.json
3. Outputs formatted table:

   Skill Stats Summary
   ═══════════════════════════════════════════════════
   Skill                 Invocations  Success Rate  Last Used
   ───────────────────────────────────────────────────
   perplexity-research          42        90.5%     2h ago
   detecting-ai-slop            15       100.0%     1d ago
   eliminating-ai-slop           8        87.5%     3d ago
   ───────────────────────────────────────────────────
   Pending: 5/20 | Last sync: 2026-01-31T12:00:00Z
```

### Syncing to GitHub

```
1. Pending count reaches threshold (20)
2. Reporting superpower:
   a. Reads pending.jsonl
   b. Updates aggregated.json
   c. Truncates pending.jsonl
   d. Copies aggregated.json to superpowers-plus/stats/
   e. Commits: "chore: sync skill stats"
   f. Pushes to origin
3. Confirms: "📊 Synced 20 reports to GitHub"
```

## File Locations

| File | Location | Purpose |
|------|----------|---------|
| SKILL.md | `skills/reporting/SKILL.md` | Superpower definition |
| pending.jsonl | `~/.codex/skill-stats/pending.jsonl` | Pending outcomes |
| aggregated.json | `~/.codex/skill-stats/aggregated.json` | Local aggregated stats |
| aggregated.json | `stats/aggregated.json` | GitHub-synced stats |
| skill-stats-sync.sh | `scripts/skill-stats-sync.sh` | Sync script |

## Migration Path

### Phase 1: Create Infrastructure
1. Create `skills/reporting/SKILL.md`
2. Create `scripts/skill-stats-sync.sh`
3. Initialize `~/.codex/skill-stats/` directory

### Phase 2: Migrate perplexity-research
1. Update SKILL.md to invoke reporting superpower
2. Remove direct stats file manipulation
3. Migrate existing `~/.codex/perplexity-stats.json` data

### Phase 3: Migrate Other Skills
1. Add reporting to `detecting-ai-slop`
2. Add reporting to `eliminating-ai-slop`
3. Deprecate skill-specific stats files

## Error Handling

| Error | Handling |
|-------|----------|
| Invalid outcome schema | Reject with error message |
| pending.jsonl write fails | Retry once, then warn user |
| aggregated.json corrupted | Rebuild from pending.jsonl |
| GitHub push fails | Queue for retry, warn user |
| Merge conflict | Last Write Wins |

## Security Considerations

- Stats contain no sensitive data (skill names, outcomes, timestamps)
- GitHub repo is private (user's superpowers-plus fork)
- No API keys or credentials in stats files

