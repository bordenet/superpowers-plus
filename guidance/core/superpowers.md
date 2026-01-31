# Superpowers Integration

> **Priority**: CRITICAL - Load at conversation start  
> **Source**: Workspace root Agents.md, all project Agents.md files

## Bootstrap Command

At the START of every conversation, run:

```bash
node ~/.codex/superpowers-augment/superpowers-augment.js bootstrap
```

This loads available skills and the `using-superpowers` skill.

## Key Skills Reference

| Skill | When to Use |
|-------|-------------|
| `superpowers:brainstorming` | Before creative/feature work |
| `superpowers:systematic-debugging` | Before fixing bugs |
| `superpowers:test-driven-development` | Before writing implementation |
| `superpowers:verification-before-completion` | Before claiming done |
| `superpowers:writing-plans` | Before multi-step tasks |

## Skill Commands

**Load a skill:**
```bash
node ~/.codex/superpowers-augment/superpowers-augment.js use-skill superpowers:<skill-name>
```

**List all skills:**
```bash
node ~/.codex/superpowers-augment/superpowers-augment.js find-skills
```

## The Rule

> **IF A SKILL APPLIES TO YOUR TASK (even 1% chance), YOU MUST INVOKE IT.**

This is not optional. Skills exist to ensure quality and consistency.

## Skill Locations

| Location | Prefix | Purpose |
|----------|--------|---------|
| `~/.codex/superpowers/skills/` | `superpowers:` | Core framework skills |
| `~/.codex/skills/` | (none) | Personal skills (override superpowers) |
| `.claude/skills/` | (repo-local) | Repo-specific skills |

## Cross-Machine Compatibility

- All paths use `~/` for home directory (works on any machine)
- Superpowers should be installed on all development machines
- Each repo is self-contained and can be cloned independently

