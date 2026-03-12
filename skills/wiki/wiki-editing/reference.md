# Wiki Editing - Reference

> **Parent skill:** [skill.md](./skill.md)
> **Last Updated:** 2026-03-12

Detailed procedures and patterns for wiki editing operations.

---

## Generic Operations → Platform MCP Tools

| Operation | Purpose | See Adapter For |
|-----------|---------|-----------------|
| `get_page` | Fetch document content | Platform-specific tool |
| `update_page` | Update document | Platform-specific tool |
| `create_page` | Create new document | Platform-specific tool |
| `search_pages` | Search documents | Platform-specific tool |
| `list_pages` | List documents | Platform-specific tool |
| `delete_page` | Archive/delete document | Platform-specific tool |

**See `skills/wiki/_adapters/{platform}.md` for your platform's MCP tool mappings.**

---

## API Fallback Pattern

Only use if MCP tools are unavailable. See your adapter for specific endpoints:

```bash
# Generic API fallback pattern

# Step 1: ALWAYS fetch current state first
# Use your adapter's get_page API endpoint

# Step 2: Edit the content locally

# Step 3: Push the updated content
# Use your adapter's update_page API endpoint
```

---

## ❌ NEVER Use Heredocs

**Heredocs (`<< EOF ... EOF`) fail silently in this environment.** They appear to work but produce empty or corrupted output.

**NEVER do this:**
```bash
cat > /tmp/file.md << 'EOF'
content here
EOF
```

**ALWAYS do this instead:**
1. Use `save-file` tool to create temp files
2. Then use MCP tool or read with `cat` and push via API

---

## Content Formatting Rules

### ❌ DO NOT Include H1 Title

Most wiki platforms display the document title in the UI.

**Wrong:**
```markdown
# How We Use Issue Tracking

**Last Updated:** 2026-02-10
```

**Correct:**
```markdown
**Last Updated:** 2026-02-10

This document analyzes...
```

---

## Backup Directory Structure

```
$HOME/.wiki-backups/
├── 2026-03-12_abc123_page-title.md
├── 2026-03-11_def456_another-page.md
└── ...
```

### YAML Frontmatter for Backups

```yaml
---
document_id: "uuid-here"
title: "Page Title"
url: "/path/to/page"
deleted_at: "ISO-timestamp"
collection_id: "collection-uuid"
parent_document_id: null
backup_reason: "Pre-deletion backup"
---

[Original document content here]
```

---

## Recovery Procedures

### Option 1: Platform Trash/Restore

Check if your platform has a trash feature and use `restore` operation.

### Option 2: Recreate from Backup

1. Read backup file
2. Extract content (skip YAML frontmatter)
3. Call adapter's `create_page` with preserved content

---

## Anchor Format Reference

Syntax varies by platform — check your adapter for specifics.

**Common TOC entry:**
```markdown
1. [Section Name](#section-name)
```

**Back-to-top link:**
```markdown
[↑ Back to top](#table-of-contents)
```

---

## Temp File Conventions

Use descriptive temp files:

```
/tmp/wiki-<descriptive-name>.md
```

**Always clean up temp files** after successfully pushing.

---

## Bypass Trigger Phrases

Watch for these phrases that invoke wiki-editing directly, bypassing orchestrator:

| Phrase | Risk |
|--------|------|
| "push to wiki" | Skips all quality gates |
| "edit wiki" | Skips all quality gates |
| "update wiki page" | May skip quality gates |
| "create wiki document" | Skips de-dup check |

### When Bypass Is Acceptable

| Acceptable | Not Acceptable |
|------------|----------------|
| Fixing a typo | Adding new content |
| Updating a date | Adding links or references |
| Minor formatting | Substantive edits |

### Log Bypass Events

```bash
./tools/skill-fire-logger.sh miss wiki-orchestrator "user bypassed pipeline"
```
