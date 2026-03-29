---
name: llm-behavior-investigator
source: superpowers-plus
description: >
  Specialized investigator for diagnosing LLM/prompt behavior issues: tool selection
  failures, prompt regressions, context window problems, and parsing failures.
  Dispatched by debug-conductor as part of forked debugging.
triggers: []
anti_triggers: []
coordination:
  group: engineering
  order: 10
  requires: ["debug-conductor"]
  enables: []
  escalates_to: ["debug-conductor"]
  internal: true
composition:
  produces: [llm-evidence, prompt-diff-analysis, tool-call-audit]
  consumes: [incident-description, agent-traces, prompt-versions, tool-definitions]
  capabilities: [prompt-regression-detection, tool-selection-audit, context-analysis]
  priority: 2
  optional: true
  requires_all: false
---

# Prompt / LLM Behavior Investigator

> **Role:** Diagnose LLM-related failures: wrong tool selection, prompt regressions, context overflow, parsing errors.
> **Dispatched by:** `debug-conductor` — never invoked directly by user.
> **Evidence type:** `LLMEvidence` (see `skills/_shared/evidence-schema.md`)

## When to Invoke

Dispatched by `debug-conductor` when the incident involves AI/LLM behavior — tool misselection, prompt regressions, context window pressure, or output parsing failures.

## Investigation Protocol

### Step 1: Classify the LLM Failure Mode

| Mode | Symptoms | Investigation Path |
|------|----------|-------------------|
| **Tool selection failure** | Wrong tool invoked; correct tool available | Step 2A: Tool call audit |
| **Prompt regression** | Behavior changed after prompt/template update | Step 2B: Prompt diff analysis |
| **Context overflow** | Degraded quality on long conversations | Step 2C: Context window analysis |
| **Parsing failure** | LLM output can't be parsed by downstream code | Step 2D: Output format audit |
| **Hallucination in tool args** | Tool called with fabricated parameters | Step 2A + Step 2C |

### Step 2A: Tool Call Audit

1. Collect agent traces with tool invocations
2. For each misselection:
   - What tool was selected vs. expected?
   - What were the available tool descriptions?
   - What was the user request text?
   - What was the context window utilization at selection time?
3. Correlate: Do misselections cluster around specific conditions?
   - High context utilization → context overflow contributing
   - Specific prompt version → prompt regression
   - Specific tool description → ambiguity in description
4. Test hypothesis: Would the OLD tool description + same context → correct selection?

### Step 2B: Prompt Diff Analysis

1. Identify the prompt template change (git log, deployment history)
2. Diff old vs. new prompt content
3. For each changed section:
   - Was meaning preserved or altered?
   - Was specificity maintained? (vague descriptions → ambiguous tool selection)
   - Was the change tested with representative inputs?
4. Rate impact: `{ section, before, after, impactAssessment }`

### Step 2C: Context Window Analysis

1. Measure context utilization on failing vs. succeeding conversations:
   - `failingAvg` vs. `succeedingAvg` → significant difference?
2. Check token budget:
   - `usedTokens / maxTokens` > 0.8 → "high utilization zone"
   - LLMs lose precision on tool selection under high context load
3. Identify what's filling the context:
   - System prompt (fixed cost)
   - Conversation history (growing cost)
   - Tool definitions (fixed cost per tool)
   - Retrieved context (variable cost)

### Step 2D: Output Format Audit

1. Collect raw LLM outputs that failed parsing
2. Compare against expected format (JSON schema, XML, markdown)
3. Classify failure:
   - Structural (missing braces, unclosed tags)
   - Schema (wrong field names, wrong types)
   - Content (correct structure, wrong values)
4. Correlate with context utilization and prompt version

### Step 3: Produce Evidence

Return `LLMEvidence` to conductor:

```json
{
  "toolCalls": [
    { "tool": "send_email", "params": {"to": "customer"}, "success": true, "expected": "make_call" }
  ],
  "promptDiffs": [
    { "section": "make_call description", "before": "Initiate outbound phone call", "after": "Reach out via voice channel", "impact": "Ambiguity increase" }
  ],
  "contextUsage": { "promptTokens": 108000, "maxTokens": 128000, "utilization": 0.84 },
  "parsingFailures": []
}
```

Plus standard evidence wrapper:
- **Supporting:** Evidence pointing toward root cause
- **Disconfirming:** Evidence that complicates or contradicts
- **Confidence:** Based on correlation strength and reproduction
- **Verdict:** What the LLM investigation suggests

## Stop Conditions

- Root cause identified (prompt change + condition → failure)
- 3 evidence items collected
- Token budget exhausted
- Wall-clock limit (5 minutes)

## Escalation Conditions

- Nondeterministic failures (same input → different outputs) → flag as seed/temperature issue
- Silent failures (no errors, wrong behavior) → flag as "hard to detect in production"
- Multiple contributing factors (prompt + context + tool description) → flag as compound root cause

## Common Patterns This Investigator Detects

| Pattern | Evidence Shape |
|---------|---------------|
| **Ambiguous tool description** | Misselections cluster around specific tool; description is vague |
| **Context window pressure** | Misselections correlate with high utilization (>80%) |
| **Prompt regression** | Behavior change correlates with prompt template deployment |
| **Tool argument hallucination** | Tool called with plausible but fabricated parameters |
| **Format drift** | Output structure degrades under high context load |
| **Compound failure** | 2+ factors required together (e.g., ambiguous description + high context) |
