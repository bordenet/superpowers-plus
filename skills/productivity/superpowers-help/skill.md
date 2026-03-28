---
name: superpowers-help
source: superpowers-plus
triggers: ["what are my superpowers", "what superpowers do I have", "what skills do I have", "list available skills", "superpowers help", "how do I use skills", "what can you do", "show me your capabilities", "help me understand superpowers", "what workflows are available"]
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

## When to Use

- User asks "what can you do?" or "what skills do you have?"
- Need to enumerate available superpowers or explicit skills at runtime
- Debugging whether a specific skill is installed and active

## Understanding the Distinction

| Term | Definition | How It Works |
|------|------------|--------------|
| **Superpower** | A skill with `triggers: [...]` in frontmatter | Auto-invokes when trigger phrases are detected |
| **Explicit Skill** | A skill without triggers | Must be explicitly invoked by name |

**Example:**
- `brainstorming` is a **superpower** — saying "help me plan this feature" auto-triggers it
- `think-twice` is an **explicit skill** — you must say "invoke think-twice" to use it

---

## MANDATORY: Dynamic Enumeration

**DO NOT rely on any hardcoded skill lists.** Skills change frequently. You MUST enumerate dynamically.

### Responding to "What are my superpowers?"

When the user asks about superpowers specifically, list **only auto-triggered skills**:

```bash
node ~/.codex/superpowers-augment/superpowers-augment.js find-skills superpowers
```

### Responding to "What skills do I have?"

When the user asks about skills generally, list **all skills** (categorized):

```bash
node ~/.codex/superpowers-augment/superpowers-augment.js find-skills
```

### Listing Only Explicit Skills

```bash
node ~/.codex/superpowers-augment/superpowers-augment.js find-skills explicit
```

### Load a Specific Skill

```bash
node ~/.codex/superpowers-augment/superpowers-augment.js use-skill <skill-name>
```

---

## How Superpowers Work (Auto-Triggered)

Superpowers fire when trigger phrases appear. You don't need to explicitly invoke them.

**Example triggers:**
- "help me plan this feature" → `brainstorming` fires
- "fix this bug" → `systematic-debugging` fires
- "update the wiki" → `wiki-orchestrator` fires

### The 1% Rule

> If there's even a 1% chance a superpower might apply, **let it fire**.

Don't suppress: "This is simple, I don't need the skill." Superpowers exist to prevent mistakes.

## How Explicit Skills Work (Manual Invocation)

Explicit skills require you to invoke them by name:
- "invoke think-twice"
- "use superpowers-help"
- "run security-upgrade"

These skills are typically meta-tools (help, observability) or tools that should only run on explicit request.

### Priority When Multiple Apply

1. **Process superpowers first** (brainstorming, debugging) — determine HOW to approach
2. **Implementation superpowers second** (wiki-orchestrator, issue-authoring) — guide execution
3. **Explicit skills on request** — only when user specifically asks

---

## Namespace Shorthands

```bash
sp-doctor    # expands to superpowers-doctor (normal resolution)
spp-doctor   # loads from superpowers-plus source repo directly
spc:skill    # loads from overlay source repo (requires SPC_SOURCE_DIR)
```

---

## Common Task Routing

| Task | Type | Skill(s) |
|------|------|----------|
| "Build a new feature" | 🦸 auto | brainstorming → plan-and-execute |
| "Fix this bug" | 🦸 auto | systematic-debugging → test-driven-development |
| "Review this PR" | 🦸 auto | providing-code-review |
| "Update the wiki" | 🦸 auto | wiki-orchestrator → link-verification |
| "Check my AI writing" | 🦸 auto | detecting-ai-slop → eliminating-ai-slop |
| "Get a second opinion" | 🔧 explicit | think-twice (must invoke by name) |
| "What can you do?" | 🔧 explicit | superpowers-help (this skill) |
| "Check skill health" | 🦸 auto | superpowers-doctor (sp-doctor) |

---

## Installation

### With superpowers already installed

superpowers-plus requires [obra/superpowers](https://github.com/obra/superpowers) as a prerequisite.

```bash
git clone https://github.com/bordenet/superpowers-plus.git
cd superpowers-plus
./install.sh
```

### Check Version

```bash
./install.sh --version
```

---

## Failure Modes

| Failure | Fix |
|---------|-----|
| Reporting skills from memory instead of running discovery | ALWAYS run `find-skills` — never enumerate from memory |
| Missing overlay skills from `SPC_SOURCE_DIR` | Overlay adds skills not in base install — check both sources |
| Confusing superpowers vs explicit skills | Superpowers have `triggers:` (auto-fire); explicit skills must be manually invoked |
| Recommending a skill without checking if it's installed | Run `find-skills {name}` before recommending any skill |

## Documentation

| Resource | URL |
|----------|-----|
| **Core superpowers** | https://github.com/obra/superpowers |
| **superpowers-plus** | https://github.com/bordenet/superpowers-plus |
| **Architecture** | https://github.com/bordenet/superpowers-plus/blob/main/docs/ARCHITECTURE.md |
| **Contributing** | https://github.com/bordenet/superpowers-plus/blob/main/docs/CONTRIBUTING.md |
