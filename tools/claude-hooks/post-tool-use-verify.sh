#!/usr/bin/env bash
# post-tool-use-verify.sh — Item 7. PostToolUse advisory verification hook.
# Fires after Bash tool calls. Emits a brief verification summary as
# additionalContext when the command is a git commit/push/merge or a write
# to a known config path. NEVER exits non-zero (advisory-only).
#
# Item 7 of the Claude Code 12-point guardrails plan.
# Exit codes: 0 always.
set -euo pipefail
if [[ "${CLAUDE_HOOKS_BYPASS:-0}" == "1" ]]; then exit 0; fi
trap 'exit 0' ERR

INPUT="$(cat)"

CMD="$(printf '%s' "$INPUT" | python3 -c "
import sys, json
d = json.load(sys.stdin)
print(d.get('tool_input', {}).get('command', ''))
" 2>/dev/null | tr -d '\n' || true)"

CWD="$(printf '%s' "$INPUT" | python3 -c "
import sys, json
d = json.load(sys.stdin)
print(d.get('cwd', '') or '.')
" 2>/dev/null | tr -d '\n' || true)"

EXIT_CODE="$(printf '%s' "$INPUT" | python3 -c "
import sys, json
d = json.load(sys.stdin)
print(d.get('tool_response', {}).get('exit_code', 0))
" 2>/dev/null | tr -d '\n' || true)"

# Skip if the tool call itself failed — nothing to verify.
case "${EXIT_CODE}" in
    0|"") ;;
    *) exit 0 ;;
esac

# Guard: CWD must be a real directory, otherwise skip to avoid wrong-repo output.
[[ -d "${CWD:-.}" ]] || exit 0

# git commit or merge — emit last-commit stat.
if printf '%s' "$CMD" | grep -qE 'git[[:space:]]+(commit|merge)'; then
    git -C "${CWD:-.}" log -1 --stat 2>/dev/null || true
    exit 0
fi

# git push — verify remote is at local HEAD.
if printf '%s' "$CMD" | grep -qE 'git[[:space:]]+push'; then
    _sha="$(git -C "${CWD:-.}" rev-parse HEAD 2>/dev/null | head -c 8)" || _sha="unknown"
    _ahead="$(git -C "${CWD:-.}" log '@{u}..HEAD' --oneline 2>/dev/null | wc -l | tr -d ' ')" || _ahead="?"
    if [[ "${_ahead}" == "0" ]]; then
        echo "push verified: remote at ${_sha} (0 commits behind local)"
    else
        echo "WARN: ${_ahead} commit(s) still ahead of remote after push — verify manually"
    fi
    exit 0
fi

# settings.json or augment/rules write — validate JSON and count hooks.
if printf '%s' "$CMD" | grep -qE '\.claude/settings\.json|\.augment/rules/'; then
    _f="$HOME/.claude/settings.json"
    if [[ -f "$_f" ]]; then
        python3 -c "
import json, sys
d = json.load(open(sys.argv[1]))
n = sum(len(blk.get('hooks', [])) for event in d.get('hooks', {}).values() for blk in event)
print(f'settings.json valid JSON, hook commands = {n}')
" "$_f" 2>/dev/null || echo "WARN: settings.json failed JSON validation after write"
    fi
    exit 0
fi

exit 0
