# Superpowers Auto-Load Rule

<EXTREMELY_IMPORTANT>

You have superpowers skills installed. At the START of every conversation, run:

```bash
node ~/.codex/superpowers-augment/superpowers-augment.js bootstrap
```

This loads your available skills and the `using-superpowers` skill that governs how to use them.

## Quick Reference

**Key skills to invoke before work:**

| Skill | When to Use |
|-------|-------------|
| `superpowers:brainstorming` | Before ANY creative/feature work |
| `superpowers:systematic-debugging` | Before fixing bugs |
| `superpowers:test-driven-development` | Before writing implementation |
| `superpowers:verification-before-completion` | Before claiming done |
| `superpowers:writing-plans` | Before multi-step tasks |
| `superpowers:think-twice` | Before major decisions |

**To load a skill:**
```bash
node ~/.codex/superpowers-augment/superpowers-augment.js use-skill superpowers:<skill-name>
```

**To list all skills:**
```bash
node ~/.codex/superpowers-augment/superpowers-augment.js find-skills
```

## The Rule

IF A SKILL APPLIES TO YOUR TASK (even 1% chance), YOU MUST INVOKE IT.

This is not optional. Skills exist to ensure quality and consistency.

## Why This Matters

Without loading skills:
- You miss proven patterns for common tasks
- Quality varies based on what you remember
- Users don't get consistent experience

With skills loaded:
- Systematic approaches to every task type
- Consistent quality across conversations
- Accumulated best practices applied automatically

</EXTREMELY_IMPORTANT>
