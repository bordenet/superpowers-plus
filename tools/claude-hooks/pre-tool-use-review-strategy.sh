#!/usr/bin/env bash
# Managed by superpowers-plus review-strategy installer.
# Mandatory boundary: CLAUDE_HOOKS_BYPASS does not disable strategy.
set -uo pipefail

deny() {
    printf '%s\n' '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"STOP: review strategy adapter is unavailable"}}'
    exit 0
}

if [[ "${1:-}" == --help || "${1:-}" == -h ]]; then
    echo "PreToolUse review strategy hook; reads one native event from stdin."
    exit 0
fi
command -v python3 >/dev/null 2>&1 || deny
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)" || deny
[[ -f "$SCRIPT_DIR/pre-tool-use-review-strategy.py" ]] || deny
if response=$(python3 "$SCRIPT_DIR/pre-tool-use-review-strategy.py"); then
    printf '%s\n' "$response"
else
    deny
fi
