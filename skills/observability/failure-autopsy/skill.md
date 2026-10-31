---
name: failure-autopsy
disable-model-invocation: true
source: superpowers-plus
augment_menu: true
triggers:
  - /sp-autopsy
  - "that was wrong"
  - "I was wrong"
  - "misdiagnosed"
  - "incorrect assumption"
  - "regression"
  - "broke something"
  - "wrong approach"
  - "wasted time"
  - "what went wrong in this session"
  - "why was that session so expensive"
anti_triggers:
  - "wrong file path"
  - "wrong variable name"
  - "trivial typo"
description: "Post-mortem analyzer for incorrect assumptions and failed approaches. Produces root cause analysis (5-Why), pattern detection, and preventive actions. INVOKE after any approach that turned out wrong."
summary: "Use when: approach failed or assumption wrong. Skip when: trivial typo."
coordination:
  group: quality-feedback
  order: 1
  requires: []
  enables: [quantitative-decision-gate, measurement-integrity]
  escalates_to: [think-twice]
  internal: false
composition:
  consumes: [incident-description]
  produces: [root-cause, retrospective-notes]
  capabilities: [post-mortem-analysis, extracts-lessons]
  priority: 5
---

# Failure Autopsy

> **Wrong skill?** Still debugging -> systematic-debugging. Stuck -> think-twice. Review feedback -> receiving-code-review.

**Announce at start:** "I am using the **failure-autopsy** skill to analyze what went wrong."

## When to Use

- After an approach turned out wrong or ineffective
- After a metric was reported incorrectly
- After a ceiling or limitation was misdiagnosed
- After a regression was introduced

### Example

```bash
# Example: 5-Why for misdiagnosed routing ceiling
echo "What: Routing accuracy stuck at 82%"
echo "Why1: 3 queries return wrong skill"
echo "Why2: TF-IDF scores too close"
echo "Why3: Intent patterns too generic"
echo "Why4: No collision detection in patterns"
echo "Why5: Pattern specificity never tested"
echo "Fix: Add specific patterns before generic ones"
```

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

## Session Transcript Diagnosis

For "what went wrong in that session" (repeated work, ignored plan, a skill
that never fired, too slow, too expensive) — current or past session. Ported
from obra/superpowers 7.0.1 `diagnosing-superpowers`, minus its upstream
issue filing.

1. **Intake first.** One question at a time until you can state: which
   session(s), turn range if known, expected vs actual, and the observable
   they care about. "It took too long" is a complaint, not a statement. An
   already-scoped request is itself the statement.
2. **Locate and confirm.** Claude Code: `~/.claude/projects/<cwd-slug>/<id>.jsonl`
   (+ subagent transcripts); Codex: `~/.codex/sessions/YYYY/MM/DD/*.jsonl`.
   Confirm by quoting the first prompt and timestamp; recency is not
   confirmation. List rejected candidates.
3. **Read safely, read-only.** Measure first (`wc -lc`; lines >100000 chars);
   take line numbers and counts before content; extract small fields from
   specific lines (`sed -n Np | jq -c …`, or `sed -n Np | cut -c1-500` without jq). Never modify a
   session file. Only human prompts are the user's words — hook output,
   reminders, and tool results are not.
4. **Report with evidence.** Every finding cites `path:line`; no citation, no
   finding. Every number comes from the transcript or a command you ran.
   Then run the 5-Why above on the confirmed findings.
5. **Sharing.** Never export transcripts unasked; redact secrets and personal
   data first and show the user exactly what leaves the machine.

---

## Anti-Patterns

| Anti-Pattern | Detection | Correction |
|--------------|-----------|------------|
| Stops at surface | "API was slow" | Push: why was it slow? What could agent do? |
| No preventive action | Step 4 empty | Not done until process update exists |
| Same failure twice | Pattern repeats | Previous preventive action failed — escalate |
| Blames environment | "Network issue" | Reframe: agent-controllable factors |

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
