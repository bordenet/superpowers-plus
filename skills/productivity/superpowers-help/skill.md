---
name: superpowers-help
source: superpowers-plus
triggers: ["what are my superpowers", "what superpowers do I have", "what skills do I have", "list available skills", "superpowers help", "how do I use skills", "what can you do", "show me your capabilities", "help me understand superpowers", "what workflows are available"]
description: Dynamically enumerates ALL installed skills at runtime, distinguishing superpowers (auto-triggered) from explicit skills. Never stale — always reflects current installation.
---

# 🦸 Superpowers & Skills

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
2. **Implementation superpowers second** (wiki-editing, issue-authoring) — guide execution
3. **Explicit skills on request** — only when user specifically asks

---

## Platform Invocation

### Claude Code

Superpowers auto-trigger via natural language. Explicit skills via slash commands:
```
"help me debug this"              → systematic-debugging auto-fires
/think-twice                      → explicit skill, must invoke
```

### Augment

Bootstrap at session start:
```bash
node ~/.codex/superpowers-augment/superpowers-augment.js bootstrap
```

Commands:
```bash
# List all (categorized as superpowers vs explicit)
node ~/.codex/superpowers-augment/superpowers-augment.js find-skills

# List only superpowers (auto-triggered)
node ~/.codex/superpowers-augment/superpowers-augment.js find-skills superpowers

# List only explicit skills
node ~/.codex/superpowers-augment/superpowers-augment.js find-skills explicit

# Load a specific skill
node ~/.codex/superpowers-augment/superpowers-augment.js use-skill <skill-name>
```

### Cursor

```bash
superpowers-cursor bootstrap
```

### Codex (OpenAI)

```bash
superpowers-codex bootstrap
```

### Gemini CLI

Skills activate via `activate_skill` tool. Gemini loads skill metadata at session start.

---

## Quick Reference: Common Tasks

| Task | Type | Skill(s) |
|------|------|----------|
| "Build a new feature" | 🦸 auto | brainstorming → writing-plans → subagent-driven-development |
| "What's the boldest move?" | 🦸 auto | innovation → brainstorming → writing-plans |
| "Fix this bug" | 🦸 auto | systematic-debugging → test-driven-development |
| "Review this PR" | 🦸 auto | providing-code-review |
| "Create a Linear issue" | 🦸 auto | linear-issue-authoring → linear-link-verification |
| "Update the wiki" | 🦸 auto | wiki-orchestrator → outline-wiki-editing → link-verification |
| "Check my AI writing" | 🦸 auto | detecting-ai-slop → eliminating-ai-slop |
| "Get a second opinion" | 🔧 explicit | think-twice (must invoke by name) |
| "What can you do?" | 🔧 explicit | superpowers-help (this skill) |
| "Upgrade dependencies" | 🔧 explicit | security-upgrade (runs on request) |
| "Refactor complex code" | 🦸 auto | cognitive-complexity-refactoring → blast-radius-check |

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

## Documentation

| Resource | URL |
|----------|-----|
| **Core superpowers** | https://github.com/obra/superpowers |
| **superpowers-plus** | https://github.com/bordenet/superpowers-plus |
| **Architecture** | https://github.com/bordenet/superpowers-plus/blob/main/docs/ARCHITECTURE.md |
| **Contributing** | https://github.com/bordenet/superpowers-plus/blob/main/docs/CONTRIBUTING.md |
