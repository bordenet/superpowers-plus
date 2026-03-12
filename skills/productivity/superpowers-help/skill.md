---
name: superpowers-help
source: superpowers-plus
triggers: ["what are my superpowers", "what superpowers do I have", "what skills do I have", "list available skills", "superpowers help", "how do I use skills", "what can you do", "show me your capabilities", "help me understand superpowers", "what workflows are available"]
description: Dynamically enumerates ALL installed superpowers skills at runtime. Never stale — always reflects current installation.
---

# 🦸 Your Superpowers

## MANDATORY: Dynamic Enumeration

**DO NOT rely on any hardcoded skill lists.** Skills change frequently. You MUST enumerate dynamically.

### Step 1: Count and List ALL Installed Skills (De-duplicated)

Run this command to get the **unique** skill inventory across all install locations:

```bash
echo "=== UNIQUE INSTALLED SKILLS ===" && \
{ \
  ls -1 ~/.codex/superpowers/skills/ 2>/dev/null; \
  ls -1 ~/.codex/skills/ 2>/dev/null; \
  ls -1 ~/.claude/commands/ 2>/dev/null; \
} | grep -v "^_" | sort -u && \
echo "" && \
echo "=== TOTAL UNIQUE SKILLS ===" && \
echo "Count: $({ ls -1 ~/.codex/superpowers/skills/ 2>/dev/null; ls -1 ~/.codex/skills/ 2>/dev/null; ls -1 ~/.claude/commands/ 2>/dev/null; } | grep -v '^_' | sort -u | wc -l | tr -d ' ')"
```

**Why de-duplicate?** Skills may be installed for multiple platforms (Claude Code, Augment, Cursor, etc.). The same skill name in different locations is ONE skill, not multiple.

### Step 2: Get Skill Details (Optional)

For descriptions of each skill:

```bash
node ~/.codex/superpowers-augment/superpowers-augment.js find-skills
```

### Step 3: Load a Specific Skill

```bash
node ~/.codex/superpowers-augment/superpowers-augment.js use-skill <skill-name>
```

---

## How Skills Work

### Automatic Triggering

Skills fire when trigger phrases appear. You don't need to explicitly invoke them.

**Example:** Say "help me plan this feature" → `brainstorming` fires automatically.

### The 1% Rule

> If there's even a 1% chance a skill might apply, **invoke it**.

Don't rationalize: "This is simple, I don't need the skill." Skills exist to prevent mistakes.

### Skill Priority

When multiple skills could apply:
1. **Process skills first** (brainstorming, debugging) — determine HOW to approach
2. **Implementation skills second** (wiki-editing, issue-authoring) — guide execution

---

## Platform Invocation

### Claude Code

Skills auto-load. Use slash commands or natural language:
```
/brainstorming
"help me debug this"
```

### Augment

Bootstrap at session start:
```bash
node ~/.codex/superpowers-augment/superpowers-augment.js bootstrap
```

Load specific skill:
```bash
node ~/.codex/superpowers-augment/superpowers-augment.js use-skill superpowers:skill-name
```

List all skills:
```bash
node ~/.codex/superpowers-augment/superpowers-augment.js find-skills
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

| Task | Skill(s) to Use |
|------|-----------------|
| "Build a new feature" | brainstorming → writing-plans → subagent-driven-development |
| "Fix this bug" | systematic-debugging → test-driven-development |
| "Review this PR" | providing-code-review |
| "Create a Linear issue" | linear-issue-authoring → linear-link-verification |
| "Update the wiki" | wiki-orchestrator → outline-wiki-editing → link-verification |
| "Screen this resume" | candidate-tracker → cv-review-external (or cv-review-agency) |
| "Prep phone screen" | phone-screen-prep |
| "Synthesize interview" | phone-screen-synthesis (or loop-synthesis) |
| "Check my AI writing" | detecting-ai-slop → eliminating-ai-slop |
| "Upgrade dependencies" | security-upgrade |
| "Refactor complex code" | cognitive-complexity-refactoring → blast-radius-check |
| "What shipped this week" | engineering-changelog-enrichment → por-stakeholder-report |

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
