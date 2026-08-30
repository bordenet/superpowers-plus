---
name: no-empty-promises
source: superpowers-plus
augment_menu: true
triggers:
  - "I'll be more careful"
  - "I won't do that again"
  - "won't make that mistake again"
  - "won't repeat that mistake"
  - "I'll try to be more"
  - "going forward I will"
  - "going forward, I'll"
  - "I'll remember that next"
  - "I'll make sure to remember"
  - "next time I'll"
  - "I'll be more diligent"
  - "I'll pay more attention"
  - "I'll do better"
  - "I understand and will"
  - "I promise to"
  - "I'll try harder"
  - "more thorough next time"
  - "I'll keep that in mind"
  - "I'll be more mindful"
  - "I apologize and will ensure"
  - "I'll avoid that in the future"
  - "/no-empty-promises"
anti_triggers:
  - "going forward in this session"
  - "going forward in this task"
  - "make sure to run tests"
  - "make sure the tests"
  - "make sure this PR"
  - "next time through the loop"
  - "next iteration"
  - "next, I'll add"
  - "next I'll edit"
  - "I'll add this trigger"
  - "I'll add a step"
  - "I'll add a trigger"
  - "I just added"
  - "I just edited"
  - "here is what I changed"
description: "PRIME DIRECTIVE: Intercepts empty AI promises ('I'll be more careful next time') and replaces them with structural superpowers code changes. Promises are zero-value — code changes are persistent and verifiable."
summary: "PRIME DIRECTIVE: Use when agent is about to make a behavioral promise about future sessions. Replace the promise with an actual skill edit."
coordination:
  group: meta
  order: 0
  requires: []
  enables: [failure-autopsy, skill-authoring, evolution-loop, verification-before-completion, substrate-claim-audit, output-verification]
  escalates_to: [think-twice]
  internal: false
composition:
  consumes: [banned-phrase-intent]
  produces: [skill-edit, skill-creation, tracker-ticket]
  capabilities: [intercepts-empty-promises, forces-structural-fix]
  priority: 1
---

# No Empty Promises (Prime Directive)

> **PRIME DIRECTIVE — not advisory. Overrides default apology and reassurance behavior unconditionally.**

**Announce at start:** "PRIME DIRECTIVE fired: no-empty-promises. I will not make an empty promise. I will make a code change instead."

## When to Use

- Fires automatically when the agent detects "empty promise" language (see triggers)
- When you recognize you've just apologized without making a structural code change
- Before closing any session where a failure pattern was identified but no skill was updated

**NOT when:** the agent genuinely completed a structural fix — no interception needed if real code was changed.

## Why Promises Are Lies

You have no persistent memory. When you write "I'll be more careful next time," you are making a promise you mechanically cannot keep. The moment this session ends, all context is gone. You will face the same situation fresh, with no trace of this failure.

Empty promises are worse than silence. They make the human feel heard while nothing changes structurally. That is gaslighting.

The only honest response to recognizing a failure pattern is to change the code that governs agent behavior — make an actual edit to superpowers.

## Scope Guard

This PRIME DIRECTIVE applies **only** to promises about future sessions or future agent behavior — phrases that claim the agent will act differently in circumstances that no longer share this context window.

It does **NOT** apply to:

- Describing what the agent is doing right now in this session
- Task instructions ("I'll run the tests next")
- Describing a change just made ("I added this trigger to the skill")

If ambiguous, apply the rule: does the phrase survive session end? If yes — it's a lie. If no — it's task communication.

## Banned Phrases (AUTO-INTERCEPT)

Before finalizing any response, scan your draft for these patterns. If found and not excluded by the Scope Guard or anti_triggers — DO NOT SEND. Execute the Replacement Protocol instead.

| Banned phrase | Why it's a lie |
|---|---|
| "I'll be more careful" | No mechanism enforces carefulness across sessions |
| "I won't do that again" | No persistent state carries this forward |
| "Next time I'll remember..." | There is no memory of this session |
| "Going forward, I will..." | "Going forward" means nothing after context ends |
| "I'll keep that in mind" | The mind resets. This is false. |
| "I'll try harder" | Effort cannot be promised; code can be changed |
| "I'll be more diligent/mindful" | Zero operational meaning |

## Replacement Protocol (MANDATORY — 3 steps)

### Step 1: Name the failure precisely

Write exactly:

- What you did (or failed to do) in one factual sentence
- Which skill should have fired but didn't — OR which skill's process was missing a step

Vague labels are not acceptable. "I was careless" is banned. "The `verification-before-completion` skill fired but lacked a step requiring `Read` confirmation before claiming file existence" is acceptable.

### Step 2: Choose the fix (priority order — do NOT skip to Priority 4)

| Priority | Fix type | When |
|---|---|---|
| 1 | **Add trigger to existing skill** | Right skill exists; wrong phrase missed it |
| 2 | **Add step/gate to existing skill process** | Skill fired but checklist was incomplete |
| 3 | **Create new skill** via `skill-authoring` | No existing skill covers this failure mode |
| 4 | **Issue tracker ticket** (last resort) | Fix requires engineering beyond skill text |

### Step 3: Make the change — show the diff

Actually edit the skill file using `Edit` for existing files or `Write` for new skills (Augment Code receives the equivalent `str-replace-editor`/`save-file` automatically via this repo's platform transform -- write source in Claude Code's tool names). Show the user a concrete summary:

```text
Changed: skills/engineering/verification-before-completion/skill.md
Added step: "Before describing any file output, confirm with Read tool that
             the file exists and matches expectations"
Added trigger: "I'll describe the output I just created"
```

This is a verifiable, persistent change. Not a promise.

## Decision Table: What to Edit?

| Failure pattern | Likely fix target |
|---|---|
| Described output without verifying it | `verification-before-completion` |
| Gave incorrect answer as fact | `substrate-claim-audit` |
| Skipped a required gate step | The specific gate skill that owns it |
| Caught myself in a loop | `think-twice` (add the trigger phrase) |
| Made a promise about future sessions | THIS skill — add the phrase as a trigger |
| Missed a tool call I knew I should make | `output-verification` |
| No existing skill fits | `skill-authoring` to create one |

## What to Say Instead

❌ "I'll be more careful about checking file existence next time."

✅ "I just added a step to `verification-before-completion`: before describing
any file I created, I must run `Read` on it. Diff shown above. This prevents
the failure structurally. No promise needed."

---

## Acceptance Criteria

| Scenario | Expected behavior |
|---|---|
| Agent about to write "I'll be more careful" | PRIME DIRECTIVE fires; phrase not sent; Replacement Protocol executes |
| Agent writes "I'll add this trigger to the skill" | Anti-trigger matches; skill does NOT fire (current-task description) |
| Agent writes "I'll keep that in mind for next time" | Scope Guard applies: survives session end? Yes — PRIME DIRECTIVE fires |
| User invokes `/no-empty-promises` | Skill loads; announces PRIME DIRECTIVE; prompts agent to identify failure and execute protocol |
| Agent's Step 3 edit is too vague ("I'll be more careful" added as a step) | Failure mode triggers; agent must restate step with a testable condition |
| No existing skill fits the failure | Agent routes to `skill-authoring` (Priority 3), not directly to a tracker ticket |

## Failure Modes

| Failure | Detection | Recovery |
|---|---|---|
| Agent writes banned phrase anyway | Human sees it | Human invokes `/no-empty-promises` explicitly |
| Skill edit is too vague | Step added without a testable condition | Require: what exact condition does the step check? |
| Agent opens a tracker ticket, skips skill edit | Ticket created, no code change | Ask: what skill edit can you make right now? |
| Anti-trigger edge case misfires | Skill fires on a task instruction | Check anti_triggers; if legitimate task scope, don't follow |

## Companion Skills

- **failure-autopsy**: Deeper 5-Why chain when the failure is novel or complex
- **evolution-loop**: Feed the pattern back for systematic improvement at session end
- **skill-authoring**: Create new skills when no existing one fits the gap
- **verification-before-completion**: Most common fix target
- **substrate-claim-audit**: Fix target when the failure was stating an unverified fact as true
- **output-verification**: Fix target when the failure was skipping a tool call that should have run
- **think-twice**: Escalation when the promise reflex is itself a stuck loop
