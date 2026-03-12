---
name: skill-firing-tracker
source: superpowers-plus
triggers: ["log skill usage", "track skill miss", "skill observability", "which skills fired", "session summary"]
description: Use when logging skill invocations (FIRED) or detecting skill misses (SHOULD_HAVE_FIRED). Invoke automatically at session end to persist metrics.
---

# Skill Firing Observability

## Purpose

Track when skills **fire** vs **should have fired** to detect trust-eroding misses.

> "A skill that FAILS to fire is a complete loss of trust from an adopter standpoint."

## How It Works

### 1. Log FIRED Events (Automatic)

Every time you invoke a skill via `use-skill`, append to the log:

```bash
# $SUPERPOWERS_DIR/.skill-metrics/fired.jsonl
{"timestamp":"2026-02-28T07:23:45Z","skill":"superpowers:resume-screening","trigger":"user shared resume PDF","session":"abc123"}
```

### 2. Log SHOULD_HAVE_FIRED Events (Manual Detection)

When you realize a skill SHOULD have been invoked but wasn't:

```bash
# $SUPERPOWERS_DIR/.skill-metrics/missed.jsonl
{"timestamp":"2026-02-28T07:30:12Z","skill":"superpowers:candidate-tracker","trigger":"processed resume without checking duplicates","user_phrase":"screen this resume","session":"abc123"}
```

### 3. Session Boundary Marker

At conversation end, write:

```bash
# $SUPERPOWERS_DIR/.skill-metrics/sessions.jsonl
{"session":"abc123","started":"2026-02-28T07:00:00Z","ended":"2026-02-28T08:15:00Z","skills_fired":["resume-screening","phone-screen-prep"],"skills_missed":["candidate-tracker"]}
```

## Data Location

```
$SUPERPOWERS_DIR/.skill-metrics/
├── fired.jsonl         # Every skill invocation
├── missed.jsonl        # Detected misses (manual + automated)
├── sessions.jsonl      # Session summaries
└── weekly-report.md    # Generated analysis
```

## Weekly Analysis Process

Run the analyzer script (or invoke this skill with "weekly skill report"):

```bash
$SUPERPOWERS_DIR/tools/skill-metrics-analyzer.sh
```

Generates `weekly-report.md` with:

| Metric | Description |
|--------|-------------|
| Fire Rate by Skill | Which skills are used most/least |
| Miss Rate by Skill | Which skills fail to fire when they should |
| Top Missed Triggers | User phrases that didn't trigger expected skills |
| Recommended Actions | Trigger phrases to add to underperforming skills |

## Self-Detection Patterns (Automated Miss Detection)

Certain action patterns indicate a skill miss. The tracker looks for:

| Pattern Detected | Missed Skill |
|------------------|--------------|
| Wiki edit without `wiki-orchestrator` | `wiki-orchestrator` |
| Resume text processed without `resume-screening` | `resume-screening` |
| Issue comment posted without `issue-comment-debunker` | `issue-comment-debunker` |
| Commit prepared without `link-verification` | `link-verification` |
| Interview notes processed without `interview-synthesis` | `interview-synthesis` |

## Integration Points

1. **Bootstrap Hook** — Add to superpowers bootstrap to initialize session
2. **Session End Hook** — Dump session summary before context exhaustion
3. **Weekly Cron** — Sunday 6pm: generate weekly report, create issue ticket if miss rate >5%

## Action Thresholds

| Miss Rate | Action |
|-----------|--------|
| <2% | ✅ Healthy — no action needed |
| 2-5% | 🟡 Monitor — review missed triggers weekly |
| 5-10% | 🟠 Warning — update triggers within 48 hours |
| >10% | 🔴 Critical — immediate trigger rewrite required |

## Commands

```bash
# Initialize session tracking
echo '{"session":"'"$(uuidgen)"'","started":"'"$(date -u +%Y-%m-%dT%H:%M:%SZ)"'"}' >> "$SUPERPOWERS_DIR/.skill-metrics/sessions.jsonl"

# Log skill fire
echo '{"timestamp":"'"$(date -u +%Y-%m-%dT%H:%M:%SZ)"'","skill":"'"$SKILL"'","trigger":"'"$TRIGGER"'"}' >> "$SUPERPOWERS_DIR/.skill-metrics/fired.jsonl"

# Generate weekly report
$SUPERPOWERS_DIR/tools/skill-metrics-analyzer.sh > "$SUPERPOWERS_DIR/.skill-metrics/weekly-report.md"
```
