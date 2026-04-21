---
name: wiki-markdown-structure-gate
source: superpowers-plus
triggers: ["wiki table syntax", "fix malformed wiki table", "audit wiki markdown structure", "broken admonition block", "bad code fence in wiki", "heading hierarchy in wiki", "wiki formatting gate", "escaped wiki link artifact"]
anti_triggers: ["database table", "sql table", "schema table"]
description: Deterministic structural markdown gate for wiki publishing. Catches malformed tables, escaped wiki-link artifacts, unbalanced code or callout fences, heading hierarchy defects, and missing TOC on manual-TOC platforms with 4+ headings before publish.
summary: "Use when: wiki content needs a structural markdown gate before publish."
coordination:
  group: wiki-pipeline
  order: 5.5
  requires: ["wiki-orchestrator"]
  enables: ["wiki-debunker"]
  escalates_to: ["wiki-orchestrator"]
  internal: false
composition:
  consumes: [generated-content, edited-content]
  produces: [markdown-structure-report]
  capabilities: [validates-markdown-structure]
  priority: 18
---

# wiki-markdown-structure-gate

Block structurally broken wiki markdown before publish. Stage 5.5 in
`wiki-orchestrator`. Validator: `tools/wiki-markdown-validate.js`.

## Procedure

```bash
# On generated draft
node tools/wiki-markdown-validate.js draft.md
# On fetched body (pipe stdin, strip YAML if present)
tools/wiki-read.sh get "$PAGE_ID" | jq -r '.text' \
  | node tools/wiki-markdown-validate.js --stdin
```

Exit `0` → pass (publish allowed). Non-zero → BLOCK: read stderr for line
numbers, fix, re-run. Do not publish until exit `0`.

## What the gate blocks

| Check | Block when |
|-------|------------|
| Table structure | Missing separator row, inconsistent cell counts, stray `\|` row |
| Escaped wiki-links | `\[title\[/doc/...` and similar round-trip artifacts |
| Code fences | Unbalanced backtick (`` ``` ``) or tilde (`~~~`) fences |
| Callout fences | Unbalanced `:::info` / `:::warning` / similar |
| Heading hierarchy | H3+ before any H2, or a level skipped |
| Missing TOC | `toc_behavior=manual` **and** ≥4 body H2/H3 (outside fences) **and** no adapter `toc_syntax` |

A generic `Contents` heading does not satisfy the TOC rule — only the
adapter's declared `toc_syntax` counts. Outline example: a `+++` toggle whose
first line contains `Table of contents`. If no adapter config is resolvable,
the gate fails closed as misconfiguration.

## Advisory (WARN, do not block)

Very wide tables · dense cells with many links · duplicate manual TOCs.

## Enforcement notes

- Canonical gate invoked by `wiki-orchestrator` Stage 5.5
- Also runs post-fetch inside `tools/wiki-write.sh` verification step
- Never waive a BLOCK finding — fix or halt

## Failure modes

| Failure | Fix |
|---------|-----|
| Structural checks treated as advisory | Treat BLOCK as halt; only WARN is advisory |
| Only links/secrets checked before publish | Run this gate (Stage 5.5) on every draft |
| Long page published without TOC | Insert adapter `toc_syntax` after intro; re-run |
| Heading count included fenced code | Validator already excludes fences; re-run if you hand-rolled the count |

## Companion skills

wiki-orchestrator (invokes this at Stage 5.5) · wiki-content-coherence ·
wiki-debunker
