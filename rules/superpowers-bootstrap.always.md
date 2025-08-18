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
| `think-twice` | When stuck, looping, or spiraling (see below) |

**To load a skill:**
```bash
node ~/.codex/superpowers-augment/superpowers-augment.js use-skill <skill-name>
```

**To list all skills:**
```bash
node ~/.codex/superpowers-augment/superpowers-augment.js find-skills
```

## Think-Twice Auto-Detection (ALWAYS MONITOR)

**You MUST continuously monitor for these stuck signals.** When cumulative score reaches 7+, STOP and invoke `think-twice`:

| Signal | Weight |
|--------|--------|
| Same fix pattern tried 3+ times | 3 |
| Circular reasoning (referencing own failed output) | 3 |
| Same error message 3+ times after fixes | 3 |
| "I've tried everything" / exhaustion language | 3 |
| "I'm not sure why" / uncertainty hedging | 2 |
| "Let me try a completely different approach" without rationale | 2 |
| Conversation > 80% context window, no resolution | 2 |

**When threshold met, say:**
> I'm detecting signs we might be stuck. [list signals]. Invoking think-twice for a fresh perspective.

**User triggers:** "think twice", "get unstuck", "I'm stuck", "second opinion", "fresh eyes", "phone a friend"

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
