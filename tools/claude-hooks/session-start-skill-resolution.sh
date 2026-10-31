#!/usr/bin/env bash
# session-start-skill-resolution.sh — replaces the obra/superpowers plugin's
# SessionStart bootstrap. Fires on SessionStart and prints one line (stdout
# becomes additionalContext) telling the model where a skill named <name> or
# superpowers:<name> lives, and to Read it when the Skill tool cannot load it
# (user-only skills such as writing-plans). Kept separate from the integrity
# hook so no integrity check or failure path can suppress it; only the ops
# escape hatch CLAUDE_HOOKS_BYPASS=1 (which skips every hook) does.
# Exit codes: 0 = ok (always).
if [[ "${CLAUDE_HOOKS_BYPASS:-0}" == "1" ]]; then exit 0; fi
echo "[superpowers-plus] A skill named <name> or superpowers:<name> lives at ~/.claude/skills/<name or sp-* alias>/skill.md (find: grep -l '^name: <name>\$' ~/.claude/skills/*/[Ss][Kk][Ii][Ll][Ll].md); if the Skill tool can't load it, Read that file."
exit 0
