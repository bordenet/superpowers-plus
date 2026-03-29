---
name: superpowers-help
source: superpowers-plus
triggers: ["what are my superpowers", "what superpowers do I have", "what skills do I have", "list available skills", "superpowers help", "how do I use skills", "what can you do", "show me your capabilities", "help me understand superpowers", "what workflows are available", "what skills are available", "list skills", "which skills"]
anti_triggers: ["write code", "fix bug", "implement feature", "debug this"]
description: Dynamically enumerates ALL installed skills at runtime, distinguishing superpowers (auto-triggered) from explicit skills. Never stale — always reflects current installation.
summary: "Use when: user asks about superpowers system, how to use skills, or needs skill recommendations."
coordination:
  group: meta
  order: 0
  requires: []
  enables: []
  escalates_to: []
  internal: false
---

# 🦸 Superpowers & Skills

> **Wrong skill?** Checking skill health → `superpowers-doctor`. Writing new skills → `skill-authoring` / `writing-skills`. Updating skills → `update-superpowers`.

## Companion Skills

- **superpowers-doctor**: Runtime diagnostics
- **skill-authoring**: Creating new skills
- **skill-health-check**: Structural lint

## When to Use

- User asks "what can you do?" or "what skills do you have?"
- User needs routing to the right skill for their task
- Debugging whether a specific skill is installed and active

---

## Procedure: Everything Is Dynamic

**NEVER hardcode skill names, counts, or routing.** All data comes from runtime discovery.

### Step 1: Discover What's Installed

Run this FIRST — every time, no exceptions:

```bash
node ~/.codex/superpowers-augment/superpowers-augment.js find-skills
```

From the output, extract:
- Total skill count (auto-triggered + explicit)
- Breakdown by activation type

Present as a brief summary:

> You have **[N] skills** installed ([X] auto-triggered, [Y] explicit).
> Auto-triggered skills fire when needed — you don't have to remember them.
> **Tell me what you want to do** and I'll match you to the right skill.

### Step 2: Route by Intent (primary value)

If the user describes a task or asks "what should I use for X?", use `match-skills`:

```bash
node ~/.codex/superpowers-augment/superpowers-augment.js match-skills "<user's intent>"
```

This returns the top 5 matching skills ranked by relevance with scores. Present the top 3 with their descriptions (pulled from the `find-skills` output, not from memory).

### Step 3: Filter by Type (if asked)

```bash
node ~/.codex/superpowers-augment/superpowers-augment.js find-skills superpowers  # auto-triggered only
node ~/.codex/superpowers-augment/superpowers-augment.js find-skills explicit     # manual only
```

### Step 4: Load a Specific Skill

```bash
node ~/.codex/superpowers-augment/superpowers-augment.js use-skill <skill-name>
```

---

## Understanding the Two Axes

| Axis | Values | What It Means |
|------|--------|---------------|
| **Activation** | 🦸 auto-triggered / 🔧 explicit | Auto-triggered skills fire when trigger phrases are detected. Explicit skills must be invoked by name. |
| **Source** | `superpowers:` (core) / `superpowers-plus:` (extended) | Core skills come from [obra/superpowers](https://github.com/obra/superpowers). Extended skills add domain-specific capabilities. |

**The 1% Rule:** If there's even a 1% chance a superpower applies, let it fire. Don't suppress with "this is simple."

### Priority When Multiple Apply

1. **Process skills first** — determine HOW to approach (look for skills with triggers matching brainstorm/plan/debug)
2. **Implementation skills second** — guide execution (look for skills matching the specific domain)
3. **Explicit skills on request** — only when user specifically asks

---

## Presenting Results

When showing skills to the user, organize dynamically using the data from `find-skills`:

### For General "What Can You Do?" Questions

1. Show count summary (from Step 1)
2. Ask what they want to accomplish
3. Run `match-skills` with their answer
4. Present top 3 matches with descriptions

### For "Show Me Everything" Requests

Run `find-skills` and present the full output. It's already categorized (auto-triggered vs explicit) and alphabetized.

### For "What's Good For [task]?" Questions

Run `match-skills "<task>"` and present the ranked results. The matching engine uses trigger phrases and descriptions to find relevant skills — it knows things this skill file doesn't.

---

## Namespace Shorthands

```bash
sp-doctor    # expands to superpowers-doctor (normal resolution)
spp-doctor   # loads from superpowers-plus source repo directly
spc:skill    # loads from overlay source repo (requires SPC_SOURCE_DIR)
```

---

## Failure Modes

| Failure | Fix |
|---------|-----|
| Hardcoding skill names, counts, or routing tables | ALL data must come from `find-skills` / `match-skills` at runtime |
| Reporting skills from memory instead of running discovery | Run `find-skills` before answering — never enumerate from memory |
| Dumping the full catalog as first response | Start with count summary + "what do you want to do?" |
| Missing overlay skills from `SPC_SOURCE_DIR` | Overlay adds skills not in base install — `find-skills` covers both sources |
| Confusing superpowers vs explicit skills | Two axes: activation (auto/explicit) and source (core/extended) |
| Recommending a skill without confirming it's installed | Run `find-skills {name}` or `match-skills` before recommending |
| Stale skill descriptions in output | If `find-skills` shows `>` as description, the installed copy needs re-syncing — run `install.sh` |

## Documentation

| Resource | URL |
|----------|-----|
| **Core superpowers** | https://github.com/obra/superpowers |
| **superpowers-plus** | https://github.com/bordenet/superpowers-plus |
| **Architecture** | https://github.com/bordenet/superpowers-plus/blob/main/docs/ARCHITECTURE.md |
| **Contributing** | https://github.com/bordenet/superpowers-plus/blob/main/docs/CONTRIBUTING.md |
