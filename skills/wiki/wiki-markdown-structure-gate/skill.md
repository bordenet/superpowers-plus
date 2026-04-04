---
name: wiki-markdown-structure-gate
source: superpowers-plus
triggers: ["wiki table syntax", "fix malformed wiki table", "audit wiki markdown structure", "broken admonition block", "bad code fence in wiki", "heading hierarchy in wiki", "wiki formatting gate", "escaped wiki link artifact"]
anti_triggers: ["database table", "sql table", "schema table"]
description: Deterministic structural markdown gate for wiki publishing. Catches malformed tables, escaped wiki-link artifacts, unbalanced code or callout fences, and heading hierarchy defects before publish.
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

# Wiki Markdown Structure Gate

> **Purpose:** Block structurally broken wiki markdown before publish.
> **Gate:** BLOCK for structural defects. WARN for readability/layout risks.
> **Pipeline:** Stage 5.5 in wiki-orchestrator, after slop review and before fact-check.

## When to Use

- Before publishing bulk or coordinated wiki edits
- When a page contains tables, toggles, callouts, or many internal links
- When users report broken rendering after a wiki update

## Hard-Block Defects

| Check | Block When |
|-------|------------|
| Table structure | Missing separator row, inconsistent cell counts, collapsed rows, stray empty row like `|` |
| Escaped wiki links | `\[title\[/doc/...` or similar escaped internal-link artifacts |
| Code fences | Opening and closing fences are unbalanced |
| Callout fences | `:::info` / `:::warning` / similar blocks are unbalanced |
| Heading hierarchy | H3+ appears before any H2, or headings skip a level |

## Advisory Findings

Warn but do not block on:

- Very wide tables that are likely to wrap badly
- Dense cells containing many links or long inline code spans
- Repeated manual TOCs that should be consolidated

## Procedure

1. Fetch current content or read the generated draft
2. Run a deterministic structural scan over markdown
3. Report line-numbered failures
4. Fix all BLOCK findings before publish
5. Re-run the scan after edits

## Report Format

```markdown
## Markdown Structure Report: [Page Title]

| Line | Severity | Type | Detail |
|------|----------|------|--------|
| 14 | BLOCK | malformed-table | row has 2 cells, expected 3 |
| 43 | BLOCK | escaped-wiki-link | `\[Guide\[/doc/...` |
| 88 | WARN | wide-table | 6 columns, likely to wrap in wiki UI |

Gate: ❌ BLOCKED
```

## Enforcement Notes

- This skill is the structural markdown gate referenced by `wiki-orchestrator` and the README pipeline.
- Platform-specific editors should still run their own post-publish fetch/verify step.
- If the platform has a local sync/push tool, wire this gate into that tool as a fail-closed validator.

## Failure Modes

| Failure | Fix |
|---------|-----|
| Pipeline claims a table gate but no skill exists | Add and install this skill; keep docs and routing aligned |
| Structural checks are advisory only | Treat malformed markdown as BLOCK, not WARN |
| Only links/secrets are checked | Add deterministic structural scanning before publish |

## Companion Skills

- **wiki-orchestrator**: Runs this as Stage 5.5 in the wiki pipeline
- **wiki-content-coherence**: Detects duplication and broader structure problems earlier in the pipeline
- **wiki-debunker**: Fact-checking after structure is clean
