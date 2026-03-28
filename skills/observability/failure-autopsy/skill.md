---
name: failure-autopsy
source: superpowers-plus
triggers:
  - "that was wrong"
  - "I was wrong"
  - "misdiagnosed"
  - "incorrect assumption"
  - "regression"
  - "broke something"
  - "wrong approach"
  - "wasted time"
anti_triggers:
  - "wrong file path"
  - "wrong variable name"
  - "trivial typo"
description: >
  Post-mortem analyzer for incorrect assumptions and failed approaches.
  Produces root cause analysis (5-Why), pattern detection, and preventive
  actions. INVOKE after any approach that turned out wrong.
summary: "Use when: approach failed or assumption wrong. Skip when: trivial typo."
coordination:
  group: quality-feedback
  order: 1
  requires: []
  enables: [quantitative-decision-gate, measurement-integrity]
  escalates_to: [think-twice]
  internal: false
---

# Failure Autopsy

> **Wrong skill?** Still debugging -> systematic-debugging. Stuck -> think-twice. Review feedback -> receiving-code-review.

**Announce at start:** "I am using the **failure-autopsy** skill to analyze what went wrong."

## When to Use

- After an approach turned out wrong or ineffective
- After a metric was reported incorrectly
- After a ceiling or limitation was misdiagnosed
- After a regression was introduced

## Scope Exclusions

- Active debugging -> systematic-debugging
- Stuck in a loop -> think-twice
- Code review comments -> receiving-code-review

---

## The 5-Why Protocol

### Step 1: State the Failure

What happened: [factual description]
Expected: [what should have happened]
Impact: [time wasted, wrong output, user intervention]

### Step 2: 5-Why Chain

| Level | Why? | Answer |
|-------|------|--------|
| 1 | Why did [failure] happen? | [direct cause] |
| 2 | Why [direct cause]? | [deeper cause] |
| 3 | Why [deeper cause]? | [systemic issue] |
| 4 | Why [systemic issue]? | [missing check] |
| 5 | Why [missing check]? | [root gap] |

### Step 3: Pattern Match

| Pattern | Signal | Match? |
|---------|--------|--------|
| False ceiling | "Impossible" proved wrong | ? |
| Incomplete measurement | Metric on data subset | ? |
| Confirmation bias | Evidence sought to confirm | ? |
| Single-method validation | One way to check | ? |

### Step 4: Preventive Action

**Immediate fix** + **Process update** + **Skill update**

---

## Failure Modes

| Failure | Detection | Recovery |
|---------|-----------|----------|
| Stops at Why 2 | <4 levels | Push deeper |
| No preventive action | Step 4 empty | Not done until process update exists |
| Same failure recurs | Pattern 2+ times | Escalate: preventive did not work |
| Blames externals | "API was slow" | Reframe: what could AGENT do? |

## Companion Skills

- **think-twice**: Breaking failure patterns
- **systematic-debugging**: Active debugging (before autopsy)
- **quantitative-decision-gate**: Preventing bad decisions
- **measurement-integrity**: Preventing bad measurements
- **evolution-loop**: Feeding autopsies into improvement
