# Claude Code Tool Notes

## Resolving a skill another skill names

Skills name each other by canonical name (`writing-plans`); older text may
use `superpowers:writing-plans`. Both mean the superpowers-plus skill, which
deploy installs at `~/.claude/skills/<name>/` or under its `/sp-*` alias
(`writing-plans` → `sp-write-plan`). Resolve with:

```bash
grep -l "^name: writing-plans$" ~/.claude/skills/*/[Ss][Kk][Ii][Ll][Ll].md
```

Invoke it with the `Skill` tool. If the tool cannot load it — it is
user-only (`disable-model-invocation: true`) or not listed — Read that
`skill.md` and follow it. This is the one sanctioned Read of a skill file.

## Code-reviewer dispatch

There is no named `code-reviewer` agent type. Dispatch `general-purpose`
with the filled template from `requesting-code-review/code-reviewer.md`.

## Cheaper orchestration for subagent-driven development

Opt-in, only when the user asks or says the session model is too expensive
for coordination, and only for a whole plan: dispatch ONE orchestrator
subagent on a mid-tier model with the plan path and the instruction to run
`subagent-driven-development` end to end. Nesting depth is capped by the
harness (`CLAUDE_CODE_MAX_SUBAGENT_SPAWN_DEPTH` overrides it). The workspace and
ledger live on disk. Relay its "Rulings I made" list verbatim, not summarized.
