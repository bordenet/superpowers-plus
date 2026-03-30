---
name: incorporating-research
source: superpowers-plus
triggers: ["incorporate research", "merge this research", "add this to the doc", "incorporate findings", "add external research"]
anti_triggers: ["research this topic", "find information about", "what does X mean"]
description: Use when user asks to incorporate, merge, or add external research (from Perplexity, web searches, ChatGPT, etc.) into existing documents - prevents misinterpreting "incorporate" as "review", strips artifacts, preserves document voice, and confirms scope before editing.
summary: "Use when: merging external research into existing docs. Skip when: writing from scratch."
coordination:
  group: research
  order: 1
  requires: []
  enables: []
  escalates_to: []
  internal: false
---

# Incorporating Research

> **Guidelines:** See [CLAUDE.md](../../../CLAUDE.md) for writing standards.
> **Last Updated:** 2026-01-26

## Purpose

This skill handles incorporating external research (Perplexity, web searches, ChatGPT outputs, etc.) into existing documents without breaking voice, structure, or adding irrelevant content.

**Core principle:** Triage first, confirm scope, then edit. Strip artifacts, preserve voice.

## When to Use

Invoke when user says:

- "Incorporate this feedback"
- "Merge this into the doc"
- "Add this Perplexity/research output"
- "Update the doc with this"
- User pastes a block of external content after discussing a document

**Red flag:** User says "incorporate" but might mean "review for quality" — clarify if ambiguous.

## The Workflow

### Step 1: Identify Target Document

**Ask if unclear:**

- "Which file should I update with this research?"
- If multiple candidates exist, list them and ask

**Confirm:**

- "I'll incorporate this into `[path/to/file.md]`. Correct?"

### Step 2: Triage the Input

Separate signal from noise:

| Category | What to Look For | Action |
|----------|------------------|--------|
| **New content** | Relevant facts, data, examples | Extract for incorporation |
| **Irrelevant content** | Wrong topic, unrelated sections | Strip completely |
| **Citation artifacts** | `[1][2][3]`, "Sources:", URLs | Strip unless explicitly requested |
| **Formatting quirks** | Perplexity/ChatGPT styling | Normalize to doc style |
| **Hallucinations** | Suspicious claims, outdated info | Flag for user verification |

**Output triage summary:**

```bash
Triage Results:
├── New content: [Brief description]
├── Irrelevant: [What's being stripped]
└── Artifacts: [Citation numbers, source sections, etc.]
```

### Step 3: Map to Existing Structure

Read target document first. Determine: new section, inline addition, appendix, or replacement. Flag conflicts/duplicates.

### Step 4: Confirm Scope Before Editing

**NEVER edit without confirmation.** Show: changes to [file], what to strip, concerns. Wait for approval.

### Step 5: Preserve Voice and Strip Artifacts

**Match**: header levels, list style, tone, code/link formatting.
**Strip**: citation numbers `[1]`, source/reference sections, AI metadata ("Based on X sources", "Here's a summary"), unrelated content.

### Step 6: Post-Incorporation Summary

Report: what was added and where, what was stripped, any concerns.

## Red Flags to Catch

| Red Flag | Example | Action |
|----------|---------|--------|
| **Topic mismatch** | Kamailio versions in hardware procurement doc | Strip completely, ask user |
| **Ambiguous intent** | "Incorporate this" (could mean review) | Clarify: "Add to doc or review for quality?" |
| **Hallucinations** | Outdated versions, wrong dates | Flag: "This claims X, verify?" |
| **Contradictions** | New content conflicts with existing | Flag before incorporating |
| **Duplicate content** | Research repeats what's already there | Ask: "This duplicates section Y. Replace or skip?" |

## Common Mistakes to Avoid

❌ **Reviewing instead of incorporating** — User says "incorporate" but wants quality review
❌ **Breaking document voice** — Pasting ChatGPT-style prose into technical doc
❌ **Leaving citation artifacts** — `[1][2][3]` scattered throughout
❌ **Adding irrelevant content** — Including unrelated sections from paste
❌ **Editing without confirmation** — Making changes before user approves scope

✅ **Triage → Map → Confirm → Edit → Summarize**

## Example Interaction

**User:** "Incorporate this Perplexity output into the hardware doc"

**Agent:**

```javascript
I'll incorporate this into `docs/hardware-procurement.md`. Let me triage the input first.

Triage Results:
├── New content: GPU specs for H100 vs A100
├── Irrelevant: Section on Kamailio SIP server versions (wrong topic)
└── Artifacts: Citation numbers [1][2][3], "Sources" section with 5 URLs

I'll make these changes:

1. Add GPU comparison table to "Hardware Options" section
2. Strip Kamailio section (unrelated to hardware)
3. Strip citation numbers and Sources section

Concerns:
- Claims H100 has 80GB VRAM, but some models have 96GB. Verify?

Proceed?
```

**User:** "Yes, use 80GB for now"

**Agent:** [Makes edits]

```text
Incorporated into docs/hardware-procurement.md:

Added:
- GPU comparison table (H100 vs A100) in "Hardware Options" section

Stripped:
- Kamailio SIP server section (unrelated)
- Citation numbers [1]-[5]
- Sources section with URLs

Concerns:
- None (H100 VRAM confirmed as 80GB for standard model)
```

## Companion Skills

- **eliminating-ai-slop**: Clean up pasted text · **detecting-ai-slop**: Score research quality
- **expert-interviewer**: Structured knowledge extraction · **perplexity-research**: Web research

| Resource | Purpose |
|----------|---------|
| [CLAUDE.md](../../../CLAUDE.md) | Writing standards (no AI slop) |
| `eliminating-ai-slop` | Use after incorporating to clean up pasted text |
| `detecting-ai-slop` | Score research quality before incorporating |

```bash
grep -n "TODO.*verify" draft.md  # find unverified claims before publish
```

## Failure Modes

| Failure | Fix |
|---------|-----|
| Copy-paste without attribution | Cite the source inline |
| Stale sources | Check publication date before incorporating |
| AI-slop injection | Run `eliminating-ai-slop` after pasting |
