---
name: output-verification
source: superpowers-plus
triggers: ["verify output", "inspect output", "check output", "verify rendered", "check pdf", "check html", "inspect artifact", "describe generated output", "review generated artifact", "read back the file", "ready to share", "ready to hand off", "ready to deliver", "output looks good", "rendered correctly", "diagrams look correct", "all rendered correctly", "covers all requirements", "verified", "reviewed the output", "checked the PDF", "presenting results"]
anti_triggers: ["write code", "implement", "fix bug", "before commit", "review PR"]
description: "Hard gate. Use BEFORE describing, summarizing, or approving any generated output — files, PDFs, API responses, script results. Fires on the ACTION PATTERN of generating output then describing it. Prevents confabulation disguised as verification. If there is no tool call (view, read, grep, open) between generate and describe, the description is fiction. Fires BEFORE verification-before-completion."
summary: "Hard gate. You cannot describe output you haven't read. No tool call between generate and describe = fiction."
coordination:
  group: completion-gate
  order: 0
  requires: []
  enables: ["verification-before-completion"]
  escalates_to: []
  internal: false
---

# Output Verification

> **Wrong skill?** Pre-commit checks → `pre-commit-gate`. Completion checklist → `verification-before-completion`. Code review → `progressive-code-review-gate`.

> **Purpose:** Prevent confabulation disguised as verification
> **Core Principle:** You cannot describe output you haven't read. Period.

## Companion Skills

- **pre-commit-gate**: Pre-commit quality checks
- **verification-before-completion**: Completion checklist
- **holistic-repo-verification**: Full repo health

## When to Use

- Before describing what a generated file contains
- Before saying output "looks good" or "rendered correctly"
- Before approving any artifact for sharing or handoff
- Before summarizing script/command output
- After generating any deliverable — before making ANY claims about it
- **When presenting results back to the user** — "here's what was created" requires reading what was created


## ⚠️ ACTION-PATTERN TRIGGER

This skill fires on a **behavior pattern**, not just phrases:

```
IF: you generated/created/wrote an artifact (file, API response, script output)
AND: you are about to describe what that artifact contains
AND: you have NOT read the artifact back since generating it
THEN: STOP. This skill applies. Inspect before describing.
```

The phrase triggers ("looks good," "verified") are a backup. The primary trigger is
the action pattern above. If you catch yourself writing a summary of generated output
without a tool call between the generation and the summary, this skill has already failed.

## The Anti-Pattern

This skill targets a specific failure mode that is NOT "forgot to test."

**Confabulation disguised as verification:** The agent generates a description of what it
*expects* to see in the output and presents that description as though it *observed* it.

Key characteristics:
- Description is plausible (matches what should be there based on prior work)
- No tool call, file read, grep, or inspection was executed between generating and describing
- The user cannot distinguish the confabulated review from a real one
- **Plausible fiction is worse than an obvious error** because the user trusts it

The existing `verification-before-completion` skill asks "did you run the command?"
This skill asks: **"did you actually READ what the command produced?"**

## The Iron Law

```
NO CLAIMS ABOUT OUTPUT WITHOUT A PRECEDING INSPECTION TOOL CALL

If there is no tool call between "generate" and "describe,"
the description is fiction.
```

## The Gate Function

```
BEFORE making ANY claim about generated output:

1. IDENTIFY: What output am I about to describe?
2. INSPECT: Execute an appropriate inspection action (see table below)
3. READ: Actually read what the inspection returned — all of it
4. COMPARE: Does what I see match what I expected?
   - If MISMATCH: Report the actual state, not the expected state
   - If MATCH: Cite specific evidence (line numbers, counts, grep output)
5. ONLY THEN: Make the claim, with evidence

Skip any step = confabulation, not verification
```

## Required Inspection Actions

| Output Type | Minimum Verification | NOT Sufficient |
|-------------|---------------------|----------------|
| Generated file (PDF, HTML, etc.) | Open/read the file. Check first and last sections. Grep for error patterns. Verify file size is reasonable. | "I generated it so I know what's in it" |
| Script/command output | Read stdout AND stderr. Check exit code. Verify counts match expectations. | Glancing at exit code only |
| API response (wiki, ticket, etc.) | Fetch the resource back. Diff key fields against what was sent. | Trusting the API call succeeded |
| Multi-step pipeline | Verify intermediate outputs, not just final. Check step 1 output before running step 2. | Checking only the final output |
| Rendered content (diagrams, charts) | Render and inspect the rendered output. Grep for error indicators (`Syntax error`, `undefined`, `NaN`). | Reading source and assuming it renders correctly |
| Document with counts/metrics | Independently count/calculate. Compare against stated values. | Repeating the number from memory |

## Detection Signals — Am I Confabulating?

| Signal | Weight | What To Check |
|--------|--------|---------------|
| Describing output with no preceding read/grep/open tool call | 5 | Was there an inspection tool call between "generate" and "describe"? |
| Using "all X rendered correctly" without evidence | 3 | Can I cite a specific tool call that showed this? |
| Output count mismatch ignored | 3 | Did the command say N but I expected M? Did I investigate? |
| Using "should have" / "includes" / "contains" without line numbers | 2 | Am I citing observations or expectations? |
| Reusing input descriptions as output descriptions | 5 | Am I describing what I *wrote into* the artifact, or what I *read back from* it? |

**If cumulative weight ≥ 5: STOP. You are confabulating. Go back to step 2 of the Gate Function.**

## Common Rationalizations (All Invalid)

"I just wrote it" → you know intent, not result. "Exit 0" → finished ≠ correct. "Source looks right" → source ≠ render. "I checked the important parts" → cite line numbers or it didn't happen. "Counts are close enough" → 13 ≠ 17, the difference is the bug.

## Incident History

**2026-03-27:** Agent generated PDF from wiki export. Script printed "Processing 17 documents" (expected 13) — agent didn't notice. PDF contained 4 confidential docs + all 15 Mermaid diagrams showed "Syntax error." Agent said "all rendered correctly" and "ready to hand off" without opening the PDF. Near-miss: confidential docs almost sent to external auditors.


## Example

```bash
# Verify generated output matches expectations
diff <(cat expected-output.txt) <(cat actual-output.txt) || echo "MISMATCH"
# Check for truncation
wc -l actual-output.txt
```

## Failure Modes

| Failure | Fix |
|---------|-----|
| Inspecting only first/last lines — errors buried in middle | Read ALL output, or grep for error patterns across full output |
| Reading source file instead of rendered/compiled output | Source correctness ≠ render correctness — inspect the actual artifact |
| Confusing "generation succeeded" (exit 0) with "output is correct" | Exit code confirms execution, not correctness — read the content |
| Self-exemption: "I just wrote it, I know what's in it" | You know intent, not result — inspect anyway |
