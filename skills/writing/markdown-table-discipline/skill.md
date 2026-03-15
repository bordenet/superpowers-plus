---
name: markdown-table-discipline
source: superpowers-plus
triggers: ["writing markdown", "creating a table", "README", "wiki page", "documentation", "skill.md", "markdown table", "adding rows", "table formatting"]
description: Enforces best practices for Markdown table construction. Auto-triggers when writing tables in README, wiki, or documentation files. Prevents visual noise, redundancy, and accessibility issues.
options:
  allow_primary_column_blank_runs: true
  max_columns: 5
  max_rows: 25
  force_compact: true
  prefer_lists_below_n_items: 3
---

# Markdown Table Discipline

Enforces best practices for Markdown table construction. This skill auto-triggers when the AI is writing or editing Markdown documents (README.md, wiki pages, skill.md files, documentation).

---

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

---

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

---

## Visual Clarity Rules

### Column Alignment

| Column Type | Alignment |
|-------------|-----------|
| Text | Left-aligned (`:---`) |
| Numeric | Right-aligned (`---:`) |
| Status/Tags (Yes/No, 🦸/🔧) | Center-aligned (`:---:`) |

### Pipe Spacing

One space around pipes minimum for raw Markdown readability:

❌ `|Name|Value|`
✅ `| Name | Value |`

### Consistent Vocabulary

Use predictable terms:
- `Yes / No / Partial` (not "Yep / Nope / Kinda")
- `Low / Medium / High` (not "Minimal / Moderate / Substantial")
- `Required / Optional / Deprecated`

---

## Semantic Rules

1. **Unambiguous headers** — No generic "Misc" or "Notes" columns unless absolutely necessary
2. **Consistent column types** — Don't mix booleans, prose, and numbers in the same column
3. **No redundant columns** — If "Status" and "Is Complete?" convey the same info, keep only one
4. **No derived columns** — If one column is derivable from another, drop it or move to notes
5. **Tables are for data, not layout** — Don't use tables for visual formatting or pseudo-forms

---

## Anti-Patterns to Detect and Fix

| Anti-Pattern | Example | Fix |
|--------------|---------|-----|
| Repetitive primary column | `engineering` repeated 6 times | Show once, blank for rest |
| Redundant type column | 38/39 rows have same value | Remove column, add footnote |
| Paragraph in cell | Multi-sentence explanation | Move to notes section below |
| Too many columns | 8+ columns, horizontal scroll | Split into multiple tables |
| Tiny table | 2 rows, 2 columns | Convert to bullet list |
| Inconsistent vocabulary | "Yes/Yep/Sure/Affirmative" | Standardize to "Yes/No" |

---

## Accessibility (HTML Contexts)

When tables render to HTML:
- Use proper `<th>` headers with `scope` attributes
- Never mix Markdown and HTML table syntax in same block
- First row must be true header, not example data

---

## Checklist Before Creating a Table

- [ ] Does this need to be a table? (≥3 rows AND ≥3 columns, or comparison needed)
- [ ] ≤5 columns? (split if more)
- [ ] Header row present?
- [ ] Primary key column identified and sorted?
- [ ] Blank runs applied to grouped rows?
- [ ] Each cell is a short phrase? (no paragraphs)
- [ ] Consistent vocabulary across rows?
- [ ] No redundant columns?

---

## Examples

### Good: Skills Table with Blank Runs

```markdown
| Domain | Skill | What it does |
|--------|-------|--------------|
| engineering | blast-radius-check | Finds all callers |
| | pre-commit-gate | Runs lint checks |
| | verification | Final checks |
| wiki | wiki-orchestrator | Routes tasks |
| | wiki-editing | Safe updates |
```

### Bad: Every Domain Repeated

```markdown
| Domain | Skill | What it does |
|--------|-------|--------------|
| engineering | blast-radius-check | Finds all callers |
| engineering | pre-commit-gate | Runs lint checks |
| engineering | verification | Final checks |
| wiki | wiki-orchestrator | Routes tasks |
| wiki | wiki-editing | Safe updates |
```

### Good: Bullet List Instead of Tiny Table

```markdown
**Configuration:**
- **Timeout:** 30 seconds
- **Retries:** 3
```

### Bad: Tiny Table

```markdown
| Setting | Value |
|---------|-------|
| Timeout | 30 seconds |
| Retries | 3 |
```
