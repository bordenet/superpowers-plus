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
| `superpowers:verification-before-completion` | Before committing, creating PRs, or claiming done |
| `superpowers:writing-plans` | Before multi-step tasks |
| `superpowers:perplexity-research` | When stuck or uncertain (see below) |
| `enforce-style-guide` | Before committing shell scripts |

## 🔍 Perplexity Research - Automatic Invocation

**CRITICAL**: This skill has AUTOMATIC triggers. You MUST invoke `superpowers:perplexity-research` when:

| Trigger | Action |
|---------|--------|
| **2+ Failed Attempts** | Same operation failed twice → invoke Perplexity |
| **Uncertainty/Guessing** | About to guess at an answer → invoke Perplexity |
| **Cutting Corners** | About to violate Agents.md guidance → invoke Perplexity |
| **Hallucination Risk** | Unsure about API/library/fact → invoke Perplexity |
| **Outdated Knowledge** | Post-training-cutoff topic → invoke Perplexity |
| **Unknown Errors** | Can't interpret error message → invoke Perplexity |

**Decision tree**:
- Personal preference question? → Ask the user
- Broader/extrinsic research needed? → Invoke Perplexity

**Manual override**: User can always say "Use Perplexity to research X"

**ALWAYS announce**: `🔍 **Consulting Perplexity**: [topic] - Reason: [trigger]`

**Stats tracking**: Update `~/.codex/perplexity-stats.json` after every invocation

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

