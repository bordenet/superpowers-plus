# Code References Section Template

When adding a "Code References" section to wiki pages:

1. **List repos first** — Query your repository adapter to see what repos exist
2. **Use relative paths** — `src/file.ts` not `repo/src/file.ts` (repo is in link)
3. **Verify files exist** — Confirm file paths via API before linking
4. **Column header = "Repository"** — Platform-agnostic naming

### Template

```markdown
### Code References

| File | Purpose | Repository |
|------|---------|------------|
| `src/path/to/file.ts` | Brief description | [repo-name]([your-repo-url]) |
```
