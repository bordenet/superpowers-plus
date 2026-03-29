# linear-comment-debunker

> Prevent fabricated or misleading AI comments on Linear tickets.

## Purpose

Stops AI from posting fabricated investigation summaries, status updates, or unverified claims to Linear tickets. Created after the "Investigation Summary (2026-02-18)" incident where AI posted authoritative-looking but fabricated analysis.

## When to Invoke

| Trigger Phrase | Context |
|----------------|---------|
| "Add a comment to Linear" | Before any Linear comment |
| "Update the ticket with findings" | Before posting investigation results |
| "Post status update to DEL-XXX" | Before status updates |
| About to use `add_comment_linear` | Pre-comment gate |
| Drafting ticket summary | Before posting conclusions |

**Invoke BEFORE:**
- Adding any comment to a Linear ticket
- Posting investigation summaries
- Documenting findings or conclusions
- Attributing statements to team members
- Claiming timestamps, metrics, or outcomes

## Key Rules

1. **DO NOT POST CLAIMS YOU CANNOT VERIFY**
2. **No "Investigation Summary" framing** — looks authoritative, pollutes history
3. **Every factual claim needs cited evidence**
4. **Uncertainty must be explicit** — "I'm not sure, but..." is acceptable
5. **Read as observation, not authoritative conclusion**

## Forbidden Patterns

| Pattern | Why It's Dangerous |
|---------|-------------------|
| "Investigation Summary" with details | Looks authoritative, fabricated |
| "Root cause identified as X" without evidence | Misdirects debugging |
| "Confirmed that Y happened at Z time" | Creates false timeline |
| "Team discussed and agreed..." | Fabricates consensus |
| Attributing quotes without source | Puts words in mouths |

## Examples

### ❌ NEVER POST THIS

```markdown
## Investigation Summary (2026-02-18)

After analyzing the system behavior, I've identified:
1. **Root Cause**: The webhook handler was dropping events...
2. **Timeline**: At 14:32, the first error occurred...
3. **Impact**: Approximately 47 requests were affected...
```

### ✅ ACCEPTABLE

```markdown
I looked at the error logs and found:
- `TypeError: Cannot read property 'id' of undefined` at line 47

I'm not certain about:
- Whether this is the root cause or a symptom

Next step: Check if `event.payload` can be null
```

## Pre-Comment Checklist

```
□ Every factual claim has cited evidence
□ No fabricated timestamps or metrics
□ No "investigation summary" framing
□ No attributions without source
□ Uncertainty is explicitly marked
□ Reads as observation, not authoritative conclusion
```

**If ANY box is unchecked → REWRITE before posting.**

## Safe vs. Unsafe Comments

| Safe ✅ | Unsafe ❌ |
|---------|----------|
| "I see this error in the logs: [paste]" | "The error appears to be caused by..." |
| "This commit changed X: [link]" | "Someone recently modified the..." |
| "The code at line 47 does Y" | "After thorough analysis..." |
| "I'm not sure, but it might be..." | "The root cause is definitely..." |
| "Question: Could X cause Y?" | "Investigation confirms X caused Y" |

## Companion Skills

| Skill | Use For |
|-------|---------|
| **wiki-debunker** | Same principles for wiki content |
| **think-twice** | Pause before consequential actions |
| **verification-before-completion** | General verification discipline |

## Installation

Included in `superpowers-callbox/install.sh`. Run:

```bash
cd /path/to/superpowers-callbox && ./install.sh
```

## Source

- **Repo:** [GitLab/superpowers-callbox](https://gitlab.int.callbox.net/mbordenet/superpowers-callbox)
- **Skill file:** `linear/linear-comment-debunker/skill.md`
