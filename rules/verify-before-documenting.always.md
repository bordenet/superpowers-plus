# Verify External Service URLs Before Documenting

<EXTREMELY_IMPORTANT>

## Never Fabricate URLs

AI assistants commonly hallucinate URLs based on patterns in training data. Before writing ANY external service URL in documentation, **verify it exists**.

### Common Hallucination Patterns

| Pattern | Problem |
|---------|---------|
| `github.com/{org}/{repo}` | Repo may not exist |
| `linear.app/settings/api` | Wrong path structure |
| `docs.example.com/latest` | Version may differ |
| `api.service.com/v2/...` | API version may not exist |

### The Rule: Query APIs First

Before writing any external service URL, query the API to get the correct value.

| Service | Wrong Approach | Right Approach |
|---------|----------------|----------------|
| GitHub | Guess `github.com/org/repo` | Query `/repos/{owner}/{repo}` API |
| Linear | Guess `linear.app/settings/api` | Query organization settings via API |
| Any API | Assume endpoint path | Check API documentation or query |

### Before Writing ANY Repository Link

1. **STOP** — Do not assume the repo exists
2. **Query** — Use the appropriate API to list repos
3. **Verify** — Confirm the exact name exists
4. **Link** — Only then write the URL

### Verification Commands

```bash
# GitHub - verify repo exists
gh api /repos/{owner}/{repo} --jq '.html_url'

# Generic URL check
curl -s -o /dev/null -w "%{http_code}" "URL"
```

### Why This Matters

- Broken links in documentation erode user trust
- Users may follow wrong links to 404 pages
- Incorrect API paths cause integration failures
- Hallucinated repos waste debugging time

### The Pattern

```
WRONG:
"See the code at github.com/company/service"  # Never verified

RIGHT:
1. Query: gh api /repos/company/service
2. Verify: Returns repo data (not 404)
3. Document: "See the code at github.com/company/service"
```

</EXTREMELY_IMPORTANT>
