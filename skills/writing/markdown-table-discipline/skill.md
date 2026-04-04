---
name: markdown-table-discipline
source: superpowers-plus
triggers: ["creating a table", "markdown table", "table formatting", "table vs list", "format as table"]
anti_triggers: ["write a document", "create wiki page", "draft email"]
description: Enforces best practices for Markdown table construction. Invoke when deciding table vs list format, or when formatting multi-column data. Prevents visual noise, redundancy, and accessibility issues.
summary: "Use when: deciding table vs list format or formatting multi-column data."
options:
  allow_primary_column_blank_runs: true
  max_columns: 5
  max_rows: 25
  force_compact: true
  prefer_lists_below_n_items: 3
coordination:
  group: writing
  order: 4
  requires: []
  enables: []
  escalates_to: []
  internal: false
composition:
  consumes: [markdown-content]
  produces: [validated-table]
  capabilities: [validates-markdown]
  priority: 35
---

# Markdown Table Discipline

> **Wrong skill?** AI slop detection → `detecting-ai-slop`. README writing → `readme-authoring`. Plan/roadmap → `plan-quality-gates`.

Enforces best practices for Markdown table construction. This skill auto-triggers when the AI is writing or editing Markdown documents (README.md, wiki pages, skill.md files, documentation).

## Companion Skills

- **eliminating-ai-slop**: Prose quality in table content
- **readme-authoring**: Table usage in README files

## When to Use

- Creating or editing any Markdown table in documentation, wiki, README, or skill files
- Deciding between table vs. list format for structured data
- Reviewing content that contains tables for formatting quality

## Decision Gate: Table vs. List

**BEFORE creating ANY table, evaluate:**

| Condition | Action |
|-----------|--------|
| Fewer than 3 rows AND fewer than 3 columns | Use a bullet list instead |
| One column contains multi-sentence paragraphs | Use headings + bullet lists instead |
| Data is hierarchical (Feature → Pros/Cons/Notes with prose) | Use nested bullets instead |
| User needs to scan/compare items on same attributes | Use a table ✓ |

**Example — Convert tiny table to list:**

❌ Wrong:

```markdown
| Setting | Value |
|---------|-------|
| Timeout | 30s |
```

✅ Correct:

```markdown
- **Timeout:** 30s
```

## Structure Rules (HARD GATES)

### 1. Always Include a Header Row

Headerless tables are **forbidden**. Every table must have a semantic header row.

### 2. Maximum 5 Columns

If more attributes needed:

- Split into multiple tables
- Move minor attributes to bullets below the table

### 3. Primary Key Column

If a column is an obvious identifier (name, ID, domain):

- Sort rows by this column
- Show value only on first row of each group, leave subsequent cells blank

❌ Wrong:

```markdown
| Domain | Skill | Description |
|--------|-------|-------------|
| engineering | blast-radius | Finds callers |
| engineering | pre-commit | Runs checks |
| engineering | rigor | Quality hub |
```

✅ Correct:

```markdown
| Domain | Skill | Description |
|--------|-------|-------------|
| engineering | blast-radius | Finds callers |
| | pre-commit | Runs checks |
| | rigor | Quality hub |
```

### 4. Cell Brevity

Each cell should be a **single short phrase**. If more explanation needed:

- Add footnotes
- Add a "Notes" section below the table

### 5. No Multi-Line Cells

Line breaks inside cells render inconsistently across tools. **Forbidden** unless user explicitly requests.

### 6. No Nested Formatting Chaos

Avoid multiple links, code blocks, AND lists in the same cell. Refactor to prose if needed.

## Visual Clarity Rules

**Alignment**: Text left (`:---`) · numeric right (`---:`) · status/tags center (`:---:`).
**Spacing**: `| Name | Value |` not `|Name|Value|`.
**Vocabulary**: `Yes/No/Partial` · `Low/Medium/High` · `Required/Optional/Deprecated`.

## Semantic Rules

1. **Unambiguous headers** — no generic "Misc" or "Notes" columns
2. **Consistent column types** — don't mix booleans, prose, and numbers
3. **No redundant columns** — if two columns convey the same info, keep one
4. **No derived columns** — derivable from another → drop or move to notes
5. **Tables are for data, not layout**

## Anti-Patterns to Detect and Fix

| Anti-Pattern | Example | Fix |
|--------------|---------|-----|
| Repetitive primary column | `engineering` repeated 6 times | Show once, blank for rest |
| Redundant type column | 38/39 rows have same value | Remove column, add footnote |
| Paragraph in cell | Multi-sentence explanation | Move to notes section below |
| Too many columns | 8+ columns, horizontal scroll | Split into multiple tables |
| Tiny table | 2 rows, 2 columns | Convert to bullet list |
| Inconsistent vocabulary | "Yes/Yep/Sure/Affirmative" | Standardize to "Yes/No" |

## Accessibility (HTML Contexts)

When tables render to HTML:

- Use proper `<th>` headers with `scope` attributes
- Never mix Markdown and HTML table syntax in same block
- First row must be true header, not example data

## Checklist Before Creating a Table

- [ ] Does this need to be a table? (≥3 rows AND ≥3 columns, or comparison needed)
- [ ] ≤5 columns? (split if more)
- [ ] Header row present?
- [ ] Primary key column identified and sorted?
- [ ] Blank runs applied to grouped rows?
- [ ] Each cell is a short phrase? (no paragraphs)
- [ ] Consistent vocabulary across rows?
- [ ] No redundant columns?

## Example

```bash
# Check table column count doesn't exceed 5
awk -F'|' '/^\|/ && NF>7 {print FILENAME":"NR": "NF-1" columns"}' doc.md
```

See [`references/examples.md`](references/examples.md) for good/bad table formatting examples.

## Failure Modes

- **Table when list suffices:** Using a 2-row table for data that reads better as a bullet list
- **Too many columns:** Tables wider than 5 columns become unreadable in most renderers
- **Redundant header column:** First column repeats information already in the section heading
