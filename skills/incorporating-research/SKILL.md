---
name: incorporating-research
description: Use when user asks to incorporate, merge, or add external research (from Perplexity, web searches, ChatGPT, etc.) into existing documents - prevents misinterpreting "incorporate" as "review", strips artifacts, preserves document voice, and confirms scope before editing
---

# Incorporating Research

> **Guidelines:** See [CLAUDE.md](../../CLAUDE.md) for writing standards.
> **Last Updated:** 2026-01-26

## Overview

This skill handles incorporating external research (Perplexity, web searches, ChatGPT outputs, etc.) into existing documents without breaking voice, structure, or adding irrelevant content.

**Core principle:** Triage first, confirm scope, then edit. Strip artifacts, preserve voice.

---

## When to Use

Invoke when user says:
- "Incorporate this feedback"
- "Merge this into the doc"
- "Add this Perplexity/research output"
- "Update the doc with this"
- User pastes a block of external content after discussing a document

**Red flag:** User says "incorporate" but might mean "review for quality" — clarify if ambiguous.

---

## The Workflow

### Step 1: Identify Target Document

**Ask if unclear:**
- "Which file should I update with this research?"
- If multiple candidates exist, list them and ask

**Confirm:**
- "I'll incorporate this into `[path/to/file.md]`. Correct?"

---

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
```
Triage Results:
├── New content: [Brief description]
├── Irrelevant: [What's being stripped]
└── Artifacts: [Citation numbers, source sections, etc.]
```

---

### Step 3: Map to Existing Structure

**Read the target document first** to understand:
- Existing sections and hierarchy
- Voice and tone
- Formatting conventions (headers, lists, code blocks)

**Determine placement:**
- New section?
- Inline addition to existing section?
- Appendix?
- Replaces existing content?

**Flag conflicts:**
- Does new content contradict existing content?
- Does it duplicate existing content?

---

### Step 4: Confirm Scope Before Editing

**NEVER edit without confirmation.**

**Template:**
```
I'll make these changes to [file]:

1. Add [X] to [section Y]
2. Strip [Z] (irrelevant/artifacts)
3. [Replace/Supplement] existing content in [section]

Concerns:
- [Any quality flags, contradictions, or hallucinations]

Proceed?
```

**Wait for user confirmation.**

---

### Step 5: Preserve Voice and Strip Artifacts

**Voice preservation:**
- Match existing header levels (##, ###, etc.)
- Match list style (bullets vs. numbered)
- Match tone (formal vs. conversational)
- Match code block formatting
- Match link style

**Artifacts to strip:**
- Citation numbers: `[1]`, `[2][3]`, `[citation needed]`
- Source sections: "Sources:", "References:", URL lists
- Perplexity metadata: "Based on X sources", "According to..."
- ChatGPT artifacts: "Here's a summary...", "I hope this helps"
- Unrelated content mixed into the paste

**Preserve semantic meaning** while normalizing style.

---

### Step 6: Post-Incorporation Summary

After editing, report:

```
Incorporated into [file]:

Added:
- [What was added and where]

Stripped:
- [What was removed as noise/artifacts]

Concerns:
- [Any quality issues flagged]
```

---

## Red Flags to Catch

| Red Flag | Example | Action |
|----------|---------|--------|
| **Topic mismatch** | Kamailio versions in hardware procurement doc | Strip completely, ask user |
| **Ambiguous intent** | "Incorporate this" (could mean review) | Clarify: "Add to doc or review for quality?" |
| **Hallucinations** | Outdated versions, wrong dates | Flag: "This claims X, verify?" |
| **Contradictions** | New content conflicts with existing | Flag before incorporating |
| **Duplicate content** | Research repeats what's already there | Ask: "This duplicates section Y. Replace or skip?" |

---

## Common Mistakes to Avoid

❌ **Reviewing instead of incorporating** — User says "incorporate" but wants quality review
❌ **Breaking document voice** — Pasting ChatGPT-style prose into technical doc
❌ **Leaving citation artifacts** — `[1][2][3]` scattered throughout
❌ **Adding irrelevant content** — Including unrelated sections from paste
❌ **Editing without confirmation** — Making changes before user approves scope

✅ **Triage → Map → Confirm → Edit → Summarize**

---

## Example Interaction

**User:** "Incorporate this Perplexity output into the hardware doc"

**Agent:**
```
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

```
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

---

## Cross-References

| Resource | Purpose |
|----------|---------|
| [CLAUDE.md](../../CLAUDE.md) | Writing standards (no AI slop) |
| `eliminating-ai-slop` | Use after incorporating to clean up pasted text |
| `detecting-ai-slop` | Score research quality before incorporating |

