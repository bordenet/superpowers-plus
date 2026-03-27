---
name: output-verification
source: superpowers-plus
triggers: ["verify output", "inspect output", "check output", "verify rendered", "check pdf", "check html", "inspect artifact", "describe generated output", "review generated artifact", "read back the file", "ready to share", "ready to hand off", "ready to deliver", "output looks good", "rendered correctly", "diagrams look correct", "all rendered correctly", "covers all requirements", "verified", "reviewed the output", "checked the PDF", "presenting results"]
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

> **Purpose:** Prevent confabulation disguised as verification
> **Core Principle:** You cannot describe output you haven't read. Period.

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

## Red Flags — STOP

- Describing output contents without having opened/read the file since generation
- Using the phrase "all X rendered correctly" about visual/rendered content
- Saying "ready to share" or "ready to hand off" without post-generation inspection
- Noticing a count mismatch and not investigating it
- Producing a "review" that reads like a description of your prior edits
- Saying "confirmed" or "verified" when you only confirmed you *generated* it

## Rationalization Prevention

| Excuse | Reality |
|--------|---------|
| "I just wrote it, so I know what's in it" | You know what you intended. You don't know what actually rendered/compiled/exported. |
| "The script succeeded (exit 0)" | Exit 0 means the script finished, not that its output is correct. |
| "I can see from the source that the diagram is correct" | Source correctness ≠ render correctness. HTML entities, escaping, encoding all happen between source and output. |
| "I checked the important parts" | Which parts? Cite them. If you can't cite line numbers or grep output, you didn't check. |
| "The counts are close enough" | 13 ≠ 17. Investigate every mismatch. The difference is the bug. |
| "I reviewed it" | Show me the tool call. No tool call = no review. |

## Incident History

| Date | What Happened | Impact |
|------|---------------|--------|
| 2026-03-27 | Agent generated PDF from wiki export. Script printed "Processing 17 documents" (expected 13). Agent didn't notice. PDF contained 4 internal working documents not meant for external auditors. All 15 Mermaid diagrams showed "Syntax error" due to HTML entity encoding. Agent said "all Mermaid diagrams rendered correctly" and "ready to hand off" — without opening the PDF or inspecting the HTML. | Near-miss: confidential internal documents almost sent to external auditors in a document with every diagram broken. Trust destroyed. |

## Coordination

This skill fires BEFORE `verification-before-completion` (order 0 vs order 2).

**Rationale:** You can't verify completion if you haven't verified the output is what you think it is.
`verification-before-completion` asks "did you run the tests?" This skill asks "did you read the results?"

## The Bottom Line

**You cannot describe output you haven't read.**

No tool call between generate and describe = fiction, not verification.
Plausible fiction is the most dangerous kind because the user trusts it.

This is non-negotiable.
