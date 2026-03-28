# Markdown Table Discipline — Examples

## Good: Skills Table with Blank Runs

```markdown
| Domain | Skill | What it does |
|--------|-------|--------------|
| engineering | blast-radius-check | Finds all callers |
| | pre-commit-gate | Runs lint checks |
| | verification | Final checks |
| wiki | wiki-orchestrator | Routes tasks |
| | wiki-orchestrator | Safe updates |
```

## Bad: Every Domain Repeated

```markdown
| Domain | Skill | What it does |
|--------|-------|--------------|
| engineering | blast-radius-check | Finds all callers |
| engineering | pre-commit-gate | Runs lint checks |
| engineering | verification | Final checks |
| wiki | wiki-orchestrator | Routes tasks |
| wiki | wiki-orchestrator | Safe updates |
```

## Good: Bullet List Instead of Tiny Table

```markdown
**Configuration:**
- **Timeout:** 30 seconds
- **Retries:** 3
```

## Bad: Tiny Table

```markdown
| Setting | Value |
|---------|-------|
| Timeout | 30 seconds |
| Retries | 3 |
```
