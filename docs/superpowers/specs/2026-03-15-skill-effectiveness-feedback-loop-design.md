# Skill Effectiveness Feedback Loop — Design Spec

> **Created:** 2026-03-15
> **Status:** Approved
> **Author:** AI + User collaboration

## Goal

Create a learning system that tracks skill outcomes (not just invocations), learns trigger effectiveness, and evolves the skill system based on actual usage patterns.

## Architecture

**Phase A (This Implementation):** Local learning file (`~/.codex/.learning-state.json`) that persists outcome data, trigger metrics, and improvement suggestions across sessions.

**Phase C (Future):** Skill synthesis engine that auto-generates new skills from repeated patterns.

## Design Principles

1. **Outcomes over invocations** — Track success/failure, not just "fired"
2. **Evidence-based learning** — Suggestions come from data, not intuition
3. **Non-destructive** — Learning state is advisory; doesn't auto-modify skills
4. **Cross-session persistence** — Survives session boundaries and context resets

## Data Model: `~/.codex/.learning-state.json`

```json
{
  "version": "1.0.0",
  "last_updated": "2026-03-15T10:30:00Z",
  "outcomes": [
    {
      "id": "outcome-001",
      "skill": "systematic-debugging",
      "timestamp": "2026-03-15T09:00:00Z",
      "trigger_phrase": "fix this bug",
      "outcome": "success",
      "evidence": "tests pass, PR merged",
      "session_id": "abc123"
    }
  ],
  "trigger_metrics": {
    "systematic-debugging": {
      "total_fires": 42,
      "successes": 38,
      "failures": 4,
      "success_rate": 0.90,
      "common_triggers": ["debug", "fix bug", "not working"],
      "suggested_triggers": ["broken", "error", "failing"],
      "false_positive_phrases": []
    }
  },
  "skill_suggestions": [
    {
      "type": "new_trigger",
      "skill": "blast-radius-check",
      "suggested": "refactor function",
      "evidence_count": 5,
      "status": "pending"
    }
  ],
  "pattern_observations": [
    {
      "pattern": "User says 'clean up' then edits multiple files",
      "frequency": 8,
      "potential_skill": "bulk-refactor-check",
      "status": "observed"
    }
  ]
}
```

## Components

### 1. Learning State Manager (`lib/learning-state.js`)
- Read/write `~/.codex/.learning-state.json`
- Schema validation
- Atomic writes with backup

### 2. Outcome Recorder (integrated into `superpowers-augment.js`)
- New command: `record-outcome <skill> <success|failure> [evidence]`
- Appends to outcomes array
- Updates trigger_metrics aggregates

### 3. Trigger Analyzer (new command)
- `analyze-triggers` — shows trigger effectiveness report
- Identifies underperforming triggers (low fire rate)
- Suggests new triggers from missed opportunities

### 4. Bootstrap Integration
- On bootstrap, display learning insights
- Show suggested trigger improvements
- Warn about skills with high failure rates

## Success Criteria

| Phase | Criterion | Verification |
|-------|-----------|--------------|
| 1 | Learning state file created with valid schema | `cat ~/.codex/.learning-state.json \| jq .` |
| 2 | Outcomes recorded and persisted | Record 3 outcomes, restart, verify they exist |
| 3 | Trigger metrics aggregated correctly | Check success_rate after 5 outcomes |
| 4 | Bootstrap shows learning insights | Run bootstrap, see "Learning insights" section |
| 5 | End-to-end demo | Full workflow from fire → outcome → suggestion |
