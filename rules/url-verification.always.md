# URL Verification Rule

<EXTREMELY_IMPORTANT>

## Verify All URLs Before Committing

Before committing ANY file containing URLs (especially `.sh`, `.md`, `README.md`), you MUST verify all URLs are reachable.

### Files That Require URL Verification

| File Type | Priority | Examples |
|-----------|----------|----------|
| `install.sh` | **CRITICAL** | User-facing installer scripts |
| `README.md` | **HIGH** | First thing users see |
| `skill.md` | **HIGH** | Skill documentation |
| `*.md` in `skills/` | **MEDIUM** | All skill documentation |
| Other `.md` files | **MEDIUM** | General documentation |

### Verification Process

Before committing, run this check for each URL:

```bash
# Quick status check (returns HTTP code)
curl -s -o /dev/null -w "%{http_code}" --connect-timeout 5 "URL"
```

Or use `web-fetch` tool for full content retrieval.

### Expected Results

| Status | Meaning | Action |
|--------|---------|--------|
| `200` | OK | ✅ Proceed |
| `301/302` | Redirect | ⚠️ Update to final URL |
| `401/403` | Auth required | ✅ OK if internal |
| `404` | Not Found | ❌ **FIX BEFORE COMMIT** |
| `000` / timeout | Network error | ⚠️ Check connectivity |

### The Rule

1. **Before ANY commit** containing URLs in user-facing docs:
   - Extract all URLs from changed files
   - Verify each returns 200 (or expected auth error)
   - Log which URLs were checked and their status
   
2. **If URL returns 404**: STOP. Fix it before committing.

3. **Report format** (include in commit process):
   ```
   URL Verification:
   ✅ https://example.com/valid (200)
   ✅ https://internal.example.com/... (401 - auth required, expected)
   ❌ https://example.com/broken (404) — FIXED
   ```

</EXTREMELY_IMPORTANT>
