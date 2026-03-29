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

## Procedure: Progressive Disclosure

**Default response is guidance, NOT a catalog dump.** Only show the full list if explicitly requested.

### Step 1: Quick Orientation (always start here)

Tell the user:

> You have **[N] skills** installed ([X] auto-triggered, [Y] explicit).
> Most fire automatically when needed — you don't have to remember them.
>
> **Tell me what you want to do** and I'll pick the right skill, or see the workflow guide below.

To get the actual count, run:
```bash
node ~/.codex/superpowers-augment/superpowers-augment.js find-skills 2>&1 | head -5
```

### Step 2: Route by Workflow (primary response)

Present the workflow table from § "Workflow Routing" below. This is the core value of this skill — matching intent to skills.

### Step 3: Drill Down (only if asked)

Only if the user says "show me everything" or "list all skills":

```bash
node ~/.codex/superpowers-augment/superpowers-augment.js find-skills          # all
node ~/.codex/superpowers-augment/superpowers-augment.js find-skills superpowers  # auto-triggered only
node ~/.codex/superpowers-augment/superpowers-augment.js find-skills explicit     # manual only
```

### Loading a Specific Skill

```bash
node ~/.codex/superpowers-augment/superpowers-augment.js use-skill <skill-name>
```

---

## Start Here: 5 Skills That Matter Most

For most users, these 5 skills cover 80% of daily work:

| Skill | When | Auto? |
|-------|------|:-----:|
| `brainstorming` | Before building anything new — explores intent, requirements, design | 🦸 yes |
| `systematic-debugging` | Before fixing any bug — structured reproduce → hypothesize → isolate → fix | 🦸 yes |
| `feature-development` | Full build lifecycle — requirements → design → plan → TDD → verify | 🦸 yes |
| `think-twice` | When stuck, looping, or unsure — breaks analysis paralysis | 🔧 explicit |
| `verification-before-completion` | Before claiming anything is done — final safety net | 🦸 yes |

If the system itself seems unhealthy: `superpowers-doctor` (run as `sp-doctor`).

---

## Understanding the Two Axes

| Axis | Values | What It Means |
|------|--------|---------------|
| **Activation** | 🦸 auto-triggered / 🔧 explicit | Auto-triggered skills fire when trigger phrases are detected. Explicit skills must be invoked by name. |
| **Source** | `superpowers:` (core) / `superpowers-plus:` (extended) | Core skills come from [obra/superpowers](https://github.com/obra/superpowers). Extended skills add domain-specific capabilities. |

**The 1% Rule:** If there's even a 1% chance a superpower applies, let it fire. Don't suppress with "this is simple."

### Priority When Multiple Apply

1. **Process skills first** (brainstorming, debugging) — determine HOW to approach
2. **Implementation skills second** (wiki-orchestrator, issue-authoring) — guide execution
3. **Explicit skills on request** — only when user specifically asks

---

## Workflow Routing

### Building & Designing

| "I want to..." | Skill Chain | Notes |
|-----------------|-------------|-------|
| Build a new feature | `brainstorming` → `plan-and-execute` → `feature-development` | Full lifecycle; brainstorming explores before committing |
| Design a system/component | `brainstorming` → `design-triad` → `domain-design` | 3+ options, comparison matrix, harsh review |
| Write a plan/RFC | `plan-and-execute` → `plan-quality-gates` | Plan-quality-gates catches vague/incomplete plans |
| Validate requirements | `requirements-validation` | Tests for falsifiability, contradictions |

### Debugging & Investigating

| "I want to..." | Skill Chain | Notes |
|-----------------|-------------|-------|
| Fix a bug | `systematic-debugging` → `test-driven-development` | Serial-first: reproduce → hypothesize → isolate → fix |
| Debug a complex distributed issue | `systematic-debugging` → `debug-conductor` | Escalation: only fork to parallel investigators if serial stalls |
| Resume a stalled investigation | `investigation-state` → `think-twice` | Persists hypotheses/evidence across sessions |
| Understand why an approach failed | `failure-autopsy` | Root cause analysis with 5-Why + preventive actions |

### Code Quality & Review

| "I want to..." | Skill Chain | Notes |
|-----------------|-------------|-------|
| Review a PR | `providing-code-review` → `code-review-battery` | Battery runs 5 parallel specialist reviewers |
| Get my code reviewed before pushing | `pre-commit-gate` → `progressive-harsh-review` | Lint → typecheck → test → adversarial review |
| Check blast radius of a change | `blast-radius-check` → `field-rename-verification` | Finds all callers before edits |
| Refactor safely | `subagent-driven-development` | Orchestrates parallel sub-agents for independent tasks |

### Documentation & Wiki

| "I want to..." | Skill Chain | Notes |
|-----------------|-------------|-------|
| Update the wiki | `wiki-orchestrator` → `wiki-content-quality` | Orchestrator routes to appropriate wiki skill |
| Refactor wiki structure | `wiki-refactor` | 7-phase pipeline: audit → deduplicate → rewrite → verify |
| Fix AI-sounding writing | `detecting-ai-slop` → `eliminating-ai-slop` | Catches and rewrites hollow/inflated prose |

### Issue Tracking

| "I want to..." | Skill Chain | Notes |
|-----------------|-------------|-------|
| Create a ticket | `issue-authoring` | Templates with acceptance criteria for GitHub/Jira/Azure DevOps |
| Update an existing ticket | `issue-editing` | Safe update with before/after diff |
| Verify ticket links work | `issue-link-verification` → `issue-verify` | Tests all URLs, confirms references exist |

### Meta & Getting Unstuck

| "I want to..." | Skill Chain | Notes |
|-----------------|-------------|-------|
| Get a second opinion | `think-twice` | 🔧 explicit — must invoke by name |
| Search for counter-evidence | `adversarial-search` | Defeats confirmation bias |
| Check skill system health | `superpowers-doctor` (`sp-doctor`) | 22-check diagnostic |
| See what skills exist | `superpowers-help` (this skill) | You're here |

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
| Dumping 140 skills as first response | Use progressive disclosure — overview first, full list only on request |
| Reporting skills from memory instead of running discovery | Run `find-skills` before answering — never enumerate from memory |
| Missing overlay skills from `SPC_SOURCE_DIR` | Overlay adds skills not in base install — check both sources |
| Confusing superpowers vs explicit skills | Two axes: activation (auto/explicit) and source (core/extended) |
| Recommending a skill without checking if it's installed | Run `find-skills {name}` before recommending any skill |
| Routing table doesn't cover user's task | Fall back to `match-skills <intent>` for fuzzy matching |

## Documentation

| Resource | URL |
|----------|-----|
| **Core superpowers** | https://github.com/obra/superpowers |
| **superpowers-plus** | https://github.com/bordenet/superpowers-plus |
| **Architecture** | https://github.com/bordenet/superpowers-plus/blob/main/docs/ARCHITECTURE.md |
| **Contributing** | https://github.com/bordenet/superpowers-plus/blob/main/docs/CONTRIBUTING.md |
