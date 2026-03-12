---
name: superpowers-help
source: superpowers-plus
triggers: ["what are my superpowers", "what superpowers do I have", "what skills do I have", "list available skills", "superpowers help", "how do I use skills", "what can you do", "show me your capabilities", "help me understand superpowers", "what workflows are available"]
description: Comprehensive guide to ALL superpowers skills — both core (obra/superpowers) and extended (superpowers-plus). Enumerates every skill with triggers, categories, and invocation guidance.
---

# 🦸 Your Superpowers

You have **106 skills** available across two skill libraries:

| Library | Skills | Purpose |
|---------|--------|---------|
| **[obra/superpowers](https://github.com/obra/superpowers)** | 65 | Core workflows + specialized domains |
| **[superpowers-plus](https://github.com/bordenet/superpowers-plus)** | 41 | Extended domains: wiki, issues, security, TypeScript, AI writing |

Skills fire **automatically** based on triggers. If there's even a 1% chance a skill applies, **invoke it**.

---

## obra/superpowers — 65 skills

### 🧠 Core Development Workflow (8 skills)

| Skill | When to Use |
|-------|-------------|
| **brainstorming** | Starting ANY new work — refines ideas through questions |
| **writing-plans** | After design approval — breaks work into 2-5 min tasks |
| **executing-plans** | With approved plan — batch execution with checkpoints |
| **subagent-driven-development** | Dispatches fresh subagent per task |
| **using-git-worktrees** | Creates isolated workspace on new branch |
| **finishing-a-development-branch** | Verifies tests, presents merge/PR options |
| **implementation-tracker** | Tracks progress across multiple sessions |
| **dispatching-parallel-agents** | Concurrent subagent workflows |

### 🧪 Testing & Debugging (3 skills)

| Skill | When to Use |
|-------|-------------|
| **test-driven-development** | RED-GREEN-REFACTOR before implementation |
| **systematic-debugging** | 4-phase root cause process |
| **verification-before-completion** | Before claiming "done" |

### 👥 Code Review (3 skills)

| Skill | When to Use |
|-------|-------------|
| **providing-code-review** | Reviewing PRs |
| **receiving-code-review** | Implementing review feedback |
| **requesting-code-review** | Between tasks, before merging |

### 📋 Linear Issue Tracking (5 skills)

| Skill | When to Use |
|-------|-------------|
| **linear-issue-authoring** | Creating Linear issues |
| **linear-issue-editing** | Updating Linear issues |
| **linear-issue-verify** | Referencing issues in commits/PRs |
| **linear-link-verification** | Adding URLs to Linear |
| **linear-comment-debunker** | Before posting comments |

### 📖 Wiki (6 skills)

| Skill | When to Use |
|-------|-------------|
| **outline-wiki-editing** | Editing Outline wiki pages |
| **wiki-orchestrator** | Creating/updating wiki pages |
| **wiki-authoring** | Structuring wiki content |
| **wiki-verify** | Verifying codebase references |
| **wiki-debunker** | Fact-checking wiki content |
| **wiki-secret-audit** | Scanning for exposed secrets |

### 🔗 Link Verification (1 skill)

| Skill | When to Use |
|-------|-------------|
| **link-verification** | HARD GATE before wiki writes |

### 👔 Recruiting Pipeline (14 skills)

| Skill | When to Use |
|-------|-------------|
| **resume-screening** | Reviewing resumes, screening candidates |
| **cv-review-external** | PARANOID review for direct-apply candidates |
| **cv-review-agency** | Trusting review for recruiter-sourced |
| **candidate-tracker** | Check for duplicates, fraud rings |
| **candidate-outcome** | Recording hire/reject/fraud outcomes |
| **agency-batch-triage** | Processing multiple agency candidates |
| **phone-screen-prep** | Preparing phone screen call script |
| **phone-screen-synthesis** | Synthesizing call into BLUF debrief |
| **interview-prep** | Preparing behavioral interview loop |
| **interview-sheet-prep** | Hiring manager interview sheet |
| **interview-synthesis** | Creating debrief from interview |
| **loop-prep** | Preparing 1-hour loop session |
| **loop-synthesis** | Synthesizing loop into debrief |
| **fathom-meeting-notes** | Retrieving meeting transcripts |

### 📊 Plan-of-Record (PoR) (4 skills)

| Skill | When to Use |
|-------|-------------|
| **por-project-registry** | Managing PoR project mappings |
| **por-linear-triage** | Classifying issues into PoR projects |
| **por-stakeholder-report** | Generating stakeholder summaries |
| **por-work-audit** | Validating completed work |

### 🔧 Engineering Quality (6 skills)

| Skill | When to Use |
|-------|-------------|
| **blast-radius-check** | Before modifying existing code |
| **engineering-rigor** | Code quality gates |
| **pre-commit-gate** | Pre-commit checks |
| **engineering-changelog-enrichment** | Generating weekly changelogs |
| **exhaustive-audit-validation** | Before claiming audits complete |
| **skill-firing-tracker** | Logging skill invocations |

### 📘 TypeScript (4 skills)

| Skill | When to Use |
|-------|-------------|
| **cognitive-complexity-refactoring** | High complexity warnings |
| **field-rename-verification** | Renaming fields, API changes |
| **typescript-project-conventions** | Import ordering, file size |
| **typescript-strict-mode** | Type errors, strict checks |
| **vitest-testing-patterns** | Mock issues, test failures |

### ✍️ Writing Quality (1 skill)

| Skill | When to Use |
|-------|-------------|
| **professional-language-audit** | Scanning for profanity |

### 🤔 Meta & Productivity (4 skills)

| Skill | When to Use |
|-------|-------------|
| **using-superpowers** | Session start — find and use skills |
| **writing-skills** | Creating new skills |
| **think-twice** | Stuck on problems, need fresh approach |
| **todo-management** | Capturing tasks, tracking work |

### 🏢 CallBox-Specific (5 skills)

| Skill | When to Use |
|-------|-------------|
| **cari-data-flow-verification** | Modifying Cari Scheduler |
| **core-boards** | Creating internal announcements |
| **smr-portal-validation** | Checking SMR portal health |
| **mb-scratchpad-wiki-sync** | Before committing to mb_scratchpad |
| **skills-hierarchy-tuning** | Reviewing skill organization |

---

## superpowers-plus — 41 skills

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
