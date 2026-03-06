#!/bin/bash
# perplexity-stats.sh - Safe stats file updater for perplexity-research skill
# Prevents JSON corruption from manual AI edits
#
# Usage:
#   perplexity-stats.sh add --trigger=manual --tool=ask --query="..." --outcome=SUCCESS --reason="..."
#   perplexity-stats.sh show
#   perplexity-stats.sh reset

set -euo pipefail

STATS_FILE="${HOME}/.codex/perplexity-stats.json"

# Ensure jq is available
if ! command -v jq &>/dev/null; then
    echo "Error: jq is required. Install with: brew install jq" >&2
    exit 1
fi

# Initialize stats file if missing or invalid
init_stats() {
    if [[ ! -f "$STATS_FILE" ]] || ! jq empty "$STATS_FILE" 2>/dev/null; then
        cat > "$STATS_FILE" << 'EOF'
{
  "total_invocations": 0,
  "successful": 0,
  "unsuccessful": 0,
  "success_rate": 0,
  "last_invocation": null,
  "by_trigger": {},
  "by_tool": {},
  "recent": []
}
EOF
    fi
}

show_stats() {
    init_stats
    jq . "$STATS_FILE"
}

reset_stats() {
    cat > "$STATS_FILE" << 'EOF'
{
  "total_invocations": 0,
  "successful": 0,
  "unsuccessful": 0,
  "success_rate": 0,
  "last_invocation": null,
  "by_trigger": {},
  "by_tool": {},
  "recent": []
}
EOF
    echo "Stats reset successfully"
}

add_entry() {
    local trigger="" tool="" query="" outcome="" reason=""
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --trigger=*) trigger="${1#*=}" ;;
            --tool=*) tool="${1#*=}" ;;
            --query=*) query="${1#*=}" ;;
            --outcome=*) outcome="${1#*=}" ;;
            --reason=*) reason="${1#*=}" ;;
            *) echo "Unknown option: $1" >&2; exit 1 ;;
        esac
        shift
    done
    
    # Validate required fields
    if [[ -z "$trigger" || -z "$tool" || -z "$outcome" ]]; then
        echo "Error: --trigger, --tool, and --outcome are required" >&2
        echo "Usage: perplexity-stats.sh add --trigger=manual --tool=ask --outcome=SUCCESS [--query=\"...\"] [--reason=\"...\"]" >&2
        exit 1
    fi
    
    # Validate outcome
    if [[ "$outcome" != "SUCCESS" && "$outcome" != "PARTIAL" && "$outcome" != "FAILURE" ]]; then
        echo "Error: --outcome must be SUCCESS, PARTIAL, or FAILURE" >&2
        exit 1
    fi
    
    init_stats
    
    local timestamp
    timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    local successful_bool="true"
    [[ "$outcome" == "FAILURE" ]] && successful_bool="false"
    
    # Build the new entry
    local new_entry
    new_entry=$(jq -n \
        --arg ts "$timestamp" \
        --arg tr "$trigger" \
        --arg tl "$tool" \
        --arg q "$query" \
        --argjson s "$successful_bool" \
        --arg o "$outcome" \
        --arg r "$reason" \
        '{timestamp: $ts, trigger: $tr, tool: $tl, query_summary: $q, successful: $s, outcome: $o, outcome_reason: $r}')
    
    # Update stats atomically using temp file
    local tmp_file
    tmp_file=$(mktemp)
    trap 'rm -f "$tmp_file"' EXIT
    
    jq --argjson entry "$new_entry" \
       --arg trigger "$trigger" \
       --arg tool "$tool" \
       --arg ts "$timestamp" \
       --argjson is_success "$successful_bool" '
        .total_invocations += 1 |
        .last_invocation = $ts |
        (if $is_success then .successful += 1 else .unsuccessful += 1 end) |
        .success_rate = (if .total_invocations > 0 then (.successful / .total_invocations | . * 1000 | floor / 1000) else 0 end) |
        .by_trigger[$trigger] = ((.by_trigger[$trigger] // 0) + 1) |
        .by_tool[$tool] = ((.by_tool[$tool] // 0) + 1) |
        .recent = ([$entry] + .recent | .[0:10])
    ' "$STATS_FILE" > "$tmp_file"
    
    mv "$tmp_file" "$STATS_FILE"
    echo "Stats updated: $outcome for $tool via $trigger"
}

case "${1:-show}" in
    add) shift; add_entry "$@" ;;
    show) show_stats ;;
    reset) reset_stats ;;
    *) echo "Usage: perplexity-stats.sh {add|show|reset}" >&2; exit 1 ;;
esac

