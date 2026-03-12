---
name: superpowers-help
source: superpowers-plus
triggers: ["what are my superpowers", "what superpowers do I have", "what skills do I have", "list available skills", "superpowers help", "how do I use skills", "what can you do", "show me your capabilities", "help me understand superpowers", "what workflows are available"]
description: Comprehensive guide to ALL superpowers skills — both core (obra/superpowers) and extended (superpowers-plus). Enumerates every skill with triggers, categories, and invocation guidance.
---

# 🦸 Your Superpowers

You have **55 skills** available across two skill libraries:

| Library | Skills | Purpose |
|---------|--------|---------|
| **[obra/superpowers](https://github.com/obra/superpowers)** | 14 | Core workflows: TDD, debugging, planning, code review |
| **[superpowers-plus](https://github.com/bordenet/superpowers-plus)** | 41 | Extended domains: wiki, issues, security, TypeScript, AI writing |

Skills fire **automatically** based on triggers. If there's even a 1% chance a skill applies, **invoke it**.

---

## Core Skills (obra/superpowers) — 14 skills

These are the foundational workflows by Jesse Vincent. **Prerequisite for superpowers-plus.**

### Development Workflow

| Skill | When to Use | Key Behavior |
|-------|-------------|--------------|
| **brainstorming** | Starting ANY new work | Refines ideas through questions, presents design in digestible chunks, saves design doc |
| **writing-plans** | After design approval | Breaks work into 2-5 min tasks with exact file paths, complete code, verification steps |
| **executing-plans** | With approved plan | Batch execution with human checkpoints |
| **subagent-driven-development** | With approved plan | Dispatches fresh subagent per task, two-stage review |
| **using-git-worktrees** | After design approval | Creates isolated workspace on new branch, verifies clean test baseline |
| **finishing-a-development-branch** | When tasks complete | Verifies tests, presents merge/PR/keep/discard options, cleans up |

### Testing & Debugging

| Skill | When to Use | Key Behavior |
|-------|-------------|--------------|
| **test-driven-development** | During implementation | RED-GREEN-REFACTOR: failing test → minimal code → pass → commit. **Deletes code written before tests.** |
| **systematic-debugging** | Fixing bugs | 4-phase root cause process: gather → hypothesize → test → fix |
| **verification-before-completion** | Before claiming "done" | Ensures fix actually works, not just "looks right" |

### Collaboration

| Skill | When to Use | Key Behavior |
|-------|-------------|--------------|
| **requesting-code-review** | Between tasks | Reviews against plan, reports issues by severity, blocks on critical |
| **receiving-code-review** | When review feedback arrives | How to respond to and implement feedback |
| **dispatching-parallel-agents** | Multiple independent tasks | Concurrent subagent workflows |

### Meta

| Skill | When to Use | Key Behavior |
|-------|-------------|--------------|
| **using-superpowers** | Session start | How to find and invoke skills — **invoke before ANY response** |
| **writing-skills** | Creating new skills | Best practices for skill authoring |

---

## Extended Skills (superpowers-plus) — 41 skills

### 🔧 Engineering (5 skills)

| Skill | Triggers On | Purpose |
|-------|-------------|---------|
| **blast-radius-check** | Modifying existing code, refactoring, changing APIs | Identify downstream impacts before changes |
| **engineering-rigor** | Code quality gate requests | Enforce quality standards |
| **pre-commit-gate** | Pre-commit checks, lint/typecheck/test | Gate commits on quality checks |
| **providing-code-review** | Reviewing PRs, code review requests | Structured review methodology |
| **receiving-code-review** | Implementing review feedback | Systematic feedback integration |

### 🧪 Experimental (1 skill)

| Skill | Triggers On | Purpose |
|-------|-------------|---------|
| **experimental-self-prompting** | Complex analysis tasks | Write context-free prompts before analyzing code |

### 📋 Issue Tracking (5 skills)

| Skill | Triggers On | Purpose |
|-------|-------------|---------|
| **issue-authoring** | Creating issues, tickets, bugs | Structured issue creation |
| **issue-comment-debunker** | Before posting issue comments | Verify claims before commenting |
| **issue-editing** | Updating existing issues | Safe issue modification |
| **issue-link-verification** | Adding URLs to issues | Verify all links exist |
| **issue-verify** | Referencing issues in commits/PRs | Confirm issue keys are real |

### 👁️ Observability (4 skills)

| Skill | Triggers On | Purpose |
|-------|-------------|---------|
| **completeness-check** | Detecting incomplete work | Find missing pieces |
| **exhaustive-audit-validation** | Before claiming audits complete | Verify thorough coverage |
| **holistic-repo-verification** | Full repository health checks | End-to-end repo validation |
| **skill-firing-tracker** | Logging skill invocations | Track which skills fired |

### ⚡ Productivity (5 skills)

| Skill | Triggers On | Purpose |
|-------|-------------|---------|
| **enforce-style-guide** | Code style enforcement | Apply project conventions |
| **golden-agents** | Initializing repos with AI guidance | Set up AGENTS.md/CLAUDE.md |
| **superpowers-help** | "what are my superpowers", "what skills do I have" | This guide |
| **think-twice** | Stuck on problems, need fresh approach | Reset and reconsider |
| **todo-management** | Task capture, tracking, triage | Manage TODO items |

### 🔬 Research (2 skills)

| Skill | Triggers On | Purpose |
|-------|-------------|---------|
| **incorporating-research** | Merging external research | Integrate research findings |
| **perplexity-research** | Stuck after 2+ failed attempts | Deep research escalation |

### 🔒 Security (2 skills)

| Skill | Triggers On | Purpose |
|-------|-------------|---------|
| **public-repo-ip-audit** | Auditing public repos for IP | Scan for sensitive content |
| **security-upgrade** | Scanning for CVEs, upgrading deps | Dependency security |

### 📘 TypeScript (5 skills)

| Skill | Triggers On | Purpose |
|-------|-------------|---------|
| **cognitive-complexity-refactoring** | High complexity warnings | Simplify complex code |
| **field-rename-verification** | Renaming fields, API changes | Verify rename completeness |
| **typescript-project-conventions** | Import ordering, file size | TS best practices |
| **typescript-strict-mode** | Type errors, strict checks | Strict type safety |
| **vitest-testing-patterns** | Mock issues, test failures | Vitest-specific patterns |

### 📖 Wiki (7 skills)

| Skill | Triggers On | Purpose |
|-------|-------------|---------|
| **link-verification** | Adding repo/wiki/external links | Verify links before posting |
| **wiki-authoring** | Formatting wiki content | Wiki formatting standards |
| **wiki-debunker** | Verifying factual claims | Fact-check wiki content |
| **wiki-editing** | Editing wiki pages | Safe wiki modification |
| **wiki-orchestrator** | Creating/updating wiki | Default wiki entry point |
| **wiki-secret-audit** | Scanning for exposed secrets | Find leaked credentials |
| **wiki-verify** | Verifying codebase references | Confirm code refs exist |

### ✍️ Writing (5 skills)

| Skill | Triggers On | Purpose |
|-------|-------------|---------|
| **detecting-ai-slop** | "calculate slop score", analyzing AI text | Identify AI writing patterns |
| **eliminating-ai-slop** | "remove slop", rewriting AI text | Remove AI-isms |
| **professional-language-audit** | Profanity/language checks | Professional language |
| **readme-authoring** | Creating/updating READMEs | README best practices |
| **reviewing-ai-text** | Editing AI-generated content | Review AI output |

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
| "Create an issue" | issue-authoring → issue-link-verification |
| "Update the wiki" | wiki-orchestrator → wiki-editing → link-verification |
| "Check my AI writing" | detecting-ai-slop → eliminating-ai-slop |
| "Upgrade dependencies" | security-upgrade |
| "Refactor complex code" | cognitive-complexity-refactoring → blast-radius-check |

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
