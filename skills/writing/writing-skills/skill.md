---
name: writing-skills
source: superpowers-plus
triggers: ["skill writing style", "skill prose quality", "skill markdown format", "SKILL.md format", "skill file conventions"]
anti_triggers: ["use skill", "find skill", "load skill", "create a skill", "make a skill", "new skill for"]
description: "Use when reviewing skill files for prose quality, markdown formatting, and style conventions. NOT for creating new skills — see Creation Checklist within this skill."
coordination:
  group: writing
  order: 1
  requires: []
  enables: []
  escalates_to: []
  internal: false
composition:
  consumes: [markdown-content]
  produces: [prose-quality-report]
  capabilities: [validates-prose, reviews-content]
  priority: 35
---

# Writing Skills

## When to Use

- Reviewing skill files for prose quality, markdown formatting, and style conventions
- Checking SKILL.md structure and frontmatter compliance
- NOT for: creating new skills (use skill-authoring process in Creation Checklist below)

A **skill** is a reusable reference guide for techniques, patterns, or tools. NOT a narrative about solving a problem once.

**Writing skills IS TDD applied to process documentation.** Follow RED-GREEN-REFACTOR:
- **RED:** Run pressure scenario WITHOUT skill. Document exact agent failures/rationalizations verbatim.
- **GREEN:** Write minimal skill addressing those specific failures. Verify agent now complies.
- **REFACTOR:** Find new rationalizations → plug → re-test until bulletproof.

**The Iron Law:** No skill without a failing baseline first. Same rule, same exceptions (none).

## SKILL.md Structure

```yaml
---
name: skill-name
source: superpowers-plus  # or a private overlay repo's name; `superpowers` is retired, don't use it
triggers: ["phrase1", "phrase2"]
anti_triggers: ["not-this"]
description: "One-line summary starting with 'Use when:'"
summary: "Use when: creating or reviewing skill files for structure and quality."
---
```

Then markdown body: core procedure, checklists, rules. Scale section depth to complexity.

## Skill Types

| Type | Purpose | Example |
|------|---------|---------|
| **Technique** | How-to guide | brainstorming, systematic-debugging |
| **Pattern** | Mental model / guard | eliminating-ai-slop, unified-commit-gate |
| **Reference** | API/tool docs | perplexity-research, todo-management |

## Directory Structure

```markdown
skills/{domain}/{skill-name}/
├── skill.md          # Core skill (≤250 lines)
├── examples.md       # Extended examples (optional)
└── references/       # Reference material (optional)
```

Domains: `engineering`, `writing`, `productivity`, `security`, `research`, `wiki`, issue-tracking domain, `observability`, `experimental`.

## Creation Checklist

**RED — baseline first:**
1. Run pressure scenario WITHOUT skill — document exact violations/rationalizations verbatim
2. Identify failure type (rule skipped under pressure? wrong output shape? omits element? condition-dependent?)

**GREEN — write minimal skill:**
3. Choose guidance form matching failure type (see Match the Form to the Failure below)
4. Write skill addressing those specific failures only
5. Verify agent complies with skill present

**REFACTOR — close loopholes:**
6. Find new rationalizations → add explicit counter → re-test until bulletproof
7. `wc -l skill.md` must be ≤250 lines

## Skill Discovery Optimization (SDO)

`description` = **triggering conditions ONLY**. Never summarize the skill's workflow.

**Why this matters:** Testing showed descriptions that summarize workflow cause agents to follow the description *instead of reading the skill*. A description saying "code review between tasks" caused agents to do ONE review; "Use when executing implementation plans" caused them to correctly read and follow the two-stage flowchart. (Testing methodology: see `testing-skills-with-subagents.md` in this directory.)

```yaml
# ❌ BAD: Summarizes workflow — agents shortcut by following description, skip skill body
description: "Use when executing plans — dispatches subagent per task with code review between tasks"
# ✅ GOOD: Triggering conditions only
description: "Use when executing implementation plans with independent tasks in the current session"
```

## Match the Form to the Failure

Classify the baseline failure before writing guidance — the wrong form measurably backfires:

| Baseline failure | Right form | Wrong form |
|---|---|---|
| Skips/violates rule under pressure (knows better, does it anyway) | Prohibition + rationalization table + red flags | Soft guidance ("prefer...", "consider...") |
| Complies, but output has wrong shape (bloated prompt, buried verdict) | Positive recipe: state what output IS — its parts, in order | Prohibition list ("don't restate", "never narrate") |
| Omits required element from something already produced | Structural: REQUIRED field/slot in the template they fill in | Prose reminders near the template |
| Behavior should depend on a condition | Conditional keyed to observable predicate | Unconditional rule + exemption clauses |

**Key:** Prohibitions backfire on shaping problems. Under competing incentives agents negotiate with "don't X". A recipe leaves nothing to negotiate: the output matches the stated shape or it doesn't. No nuance clauses — "don't X unless it matters" reopens the negotiation.

## Bulletproofing Against Rationalization

For discipline skills (rules agents skip under pressure only — for shaping failures use the forms above):
- **Close every loophole explicitly:** Don't just state the rule — forbid specific workarounds with "No exceptions: not for simple additions, not for documentation updates, delete means delete."
- **Spirit vs letter counter** (add early): "Violating the letter of the rules is violating the spirit of the rules."
- **Rationalization table** from baseline test verbatims (capture exact excuses)
- **Red Flags list** for agent self-check

See `persuasion-principles.md` in this directory for research foundation (authority, commitment, scarcity, unity principles).

## Common Rationalizations for Skipping Testing

| Excuse | Reality |
|--------|---------|
| "Skill is obviously clear" | Clear to you ≠ clear to agents. Test it. |
| "It's just a reference" | References have gaps. Test retrieval. |
| "Testing is overkill" | Untested skills always have issues. 15 min testing saves hours. |
| "I'll test if problems emerge" | Problems = agents can't use skill. Test BEFORE deploying. |
| "No time to test" | Deploying untested skill wastes more time fixing it later. |
| "I'm confident it's good" | Overconfidence guarantees issues. Test anyway. |

See `testing-skills-with-subagents.md` in this directory for full methodology (pressure types, micro-testing wording, plugging holes).

## Quality Gates

- Every rule has a concrete "what to do" (not just "don't do X")
- Triggers are specific enough to avoid false positives
- Anti-triggers prevent firing when not needed
- Description starts with "Use when:" for search optimization
- No narrative examples — use checklists and tables
- No philosophical arguments ("why this matters")
- Token budget: aim for <1000 compressed tokens

## Where Skills Go

| Repo | Content | Access |
|------|---------|--------|
| `superpowers-plus` | All skills, including the obra-origin ones folded in directly at v2.6.0 | Public GitHub |
| private overlay | Internal/proprietary | Private repo |

To override a superpowers-plus skill from a private overlay repo:

- Set `overrides: source-repo-name/{skill-name}` in frontmatter, where `source-repo-name` matches a directory under `~/.codex/`. Place the skill in the overlay repo with the same `name`.
- This stages that source's companion files at install time and suppresses drift/duplicate warnings in `sp-doctor`. No skill file in this repo currently uses it, so treat it as documented behavior, not something proven in practice.
- A mistyped or missing `source-repo-name` fails silently (no warning unless installing with `--verbose`). Verify a new `overrides:` entry resolves by installing with `--verbose` and checking for the companion-staging log line.
- The `superpowers` source name alone is retired (v2.6.0+); don't use it. Unlike a typo, this one always warns.

## After Creation

1. `node ~/.codex/superpowers-augment/superpowers-augment.js find-skills {name}` — verify discoverable
2. `node ~/.codex/superpowers-augment/superpowers-augment.js use-skill {name}` — verify loads correctly
3. Check compressed token count — target <1000

## Failure Modes

| Failure | Fix |
|---------|-----|
| Skill passes structural checks but has empty/placeholder procedure | Every skill needs at least one concrete "do X, then Y" instruction |
| Trigger phrases too broad — causes false positive routing | Test triggers: `find-skills "{trigger}"` should return <3 skills per trigger |
| Description doesn't start with "Use when:" — breaks search optimization | Format: `"Use when: {specific context}. Skip when: {anti-context}."` |
| Skill exceeds 250-line limit after edits | Check `wc -l skill.md` before committing — refactor to examples.md if needed |
