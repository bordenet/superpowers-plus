#!/usr/bin/env bash
# pre-compact-context-ferry.sh — PreCompact hook for the context-ferry skill.
# Fires before Claude Code context compaction. Captures lightweight git state,
# writes a scaffold file, and instructs the model to run context-ferry NOW.
# Exit: always 0 (advisory — never blocks compaction).
set -euo pipefail
if [[ "${CLAUDE_HOOKS_BYPASS:-0}" == "1" ]]; then exit 0; fi

TIMESTAMP="$(date -u +%Y%m%dT%H%M%SZ)"
OUTFILE="$HOME/context-ferry-${TIMESTAMP}.md"
CWD="${PWD}"

# Read hook event JSON from stdin; extract cwd if jq is available.
INPUT="$(cat)"
if command -v jq &>/dev/null; then
    _cwd="$(jq -r '.cwd // empty' <<<"$INPUT" 2>/dev/null || true)"
    [[ -n "$_cwd" ]] && CWD="$_cwd"
fi

# Write scaffold file with git state (stat only, capped at 30 lines each).
{
    printf '## CONTEXT FERRY SCAFFOLD — %s\n\n' "$TIMESTAMP"
    printf 'Scaffold file: %s\n\n' "$OUTFILE"
    if git -C "$CWD" rev-parse --is-inside-work-tree &>/dev/null 2>&1; then
        printf '### Key Files & Diffs (git state at compact time)\n'
        printf '```\n'
        git -C "$CWD" status --short 2>/dev/null | head -30 || true
        printf '\n'
        git -C "$CWD" diff --stat HEAD 2>/dev/null | head -30 || true
        printf '```\n'
    else
        printf '### Key Files & Diffs\n'
        printf '_No git repository at %s. List relevant files from conversation memory._\n' "$CWD"
    fi
} > "$OUTFILE" 2>/dev/null || true

# Instruct the model to run context-ferry immediately.
cat <<MSG
[context-ferry] PreCompact hook fired. Context compaction is imminent.

** EXECUTE THE CONTEXT-FERRY SKILL NOW. Do not wait for user input. **

Git state scaffold written to: ${OUTFILE}
Use that file's "Key Files & Diffs" section to populate the ferry prompt.
MSG

exit 0
