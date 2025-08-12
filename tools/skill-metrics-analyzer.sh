#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# Script: skill-metrics-analyzer.sh
# PURPOSE: Generate skill firing reports from logged metrics. Analyzes skill
#          invocations, missed triggers, and session data to produce weekly
#          reports in markdown or JSON format.
# USAGE: ./skill-metrics-analyzer.sh [--json]
#        (no args)   Output markdown report
#        --json      Output JSON format
# PLATFORM: macOS, Linux, WSL (POSIX-compatible)
# VERSION: 1.0.0
# -----------------------------------------------------------------------------
set -euo pipefail

METRICS_DIR="${SUPERPOWERS_DIR:-.}/.skill-metrics"
FIRED_LOG="$METRICS_DIR/fired.jsonl"
MISSED_LOG="$METRICS_DIR/missed.jsonl"
OUTPUT_FORMAT="${1:-markdown}"

# Ensure metrics directory exists
mkdir -p "$METRICS_DIR"

# Initialize empty logs if they don't exist
touch "$FIRED_LOG" "$MISSED_LOG"

# Count totals
TOTAL_FIRED=$(wc -l < "$FIRED_LOG" | tr -d ' ')
TOTAL_MISSED=$(wc -l < "$MISSED_LOG" | tr -d ' ')
TOTAL_EVENTS=$((TOTAL_FIRED + TOTAL_MISSED))

# Calculate miss rate
if [[ $TOTAL_EVENTS -gt 0 ]]; then
    MISS_RATE=$(echo "scale=2; $TOTAL_MISSED * 100 / $TOTAL_EVENTS" | bc)
else
    MISS_RATE="0"
fi

# Determine health status
if (( $(echo "$MISS_RATE < 2" | bc -l) )); then
    STATUS="✅ Healthy"
    ACTION="No action needed"
elif (( $(echo "$MISS_RATE < 5" | bc -l) )); then
    STATUS="🟡 Monitor"
    ACTION="Review missed triggers weekly"
elif (( $(echo "$MISS_RATE < 10" | bc -l) )); then
    STATUS="🟠 Warning"
    ACTION="Update triggers within 48 hours"
else
    STATUS="🔴 Critical"
    ACTION="Immediate trigger rewrite required"
fi

# Generate report
cat << EOF
# Skill Firing Observability Report

**Generated:** $(date -u +%Y-%m-%dT%H:%M:%SZ)
**Period:** Last 7 days

## Summary

| Metric | Value |
|--------|-------|
| Total Skill Fires | $TOTAL_FIRED |
| Total Missed Fires | $TOTAL_MISSED |
| Miss Rate | ${MISS_RATE}% |
| Status | $STATUS |
| Recommended Action | $ACTION |

## Fire Count by Skill

EOF

if [[ -s "$FIRED_LOG" ]]; then
    echo "| Skill | Fire Count |"
    echo "|-------|------------|"
    jq -r '.skill' "$FIRED_LOG" 2>/dev/null | sort | uniq -c | sort -rn | while read -r count skill; do
        echo "| $skill | $count |"
    done
else
    echo "_No skill fires recorded yet._"
fi

cat << EOF

## Missed Fires by Skill

EOF

if [[ -s "$MISSED_LOG" ]]; then
    echo "| Skill | Miss Count | Top Trigger Phrase |"
    echo "|-------|------------|-------------------|"
    # Group by skill and show most common trigger phrase
    jq -r '[.skill, .user_phrase // "N/A"] | @tsv' "$MISSED_LOG" 2>/dev/null | \
        sort | uniq -c | sort -rn | head -10 | while read -r count skill phrase; do
            echo "| $skill | $count | \"$phrase\" |"
        done
else
    echo "_No missed fires recorded yet. This is good!_"
fi

cat << EOF

## Recommended Trigger Additions

Based on missed fire patterns, consider adding these trigger phrases:

EOF

if [[ -s "$MISSED_LOG" ]]; then
    echo "| Skill | Suggested Trigger Phrase |"
    echo "|-------|-------------------------|"
    jq -r 'select(.user_phrase != null) | [.skill, .user_phrase] | @tsv' "$MISSED_LOG" 2>/dev/null | \
        sort -u | head -10 | while read -r skill phrase; do
            echo "| $skill | \"$phrase\" |"
        done
else
    echo "_No recommendations yet — collect more data._"
fi

cat << EOF

---

## Data Files

- Fired log: \`$FIRED_LOG\`
- Missed log: \`$MISSED_LOG\`

To reset metrics: \`rm $METRICS_DIR/*.jsonl\`
EOF
