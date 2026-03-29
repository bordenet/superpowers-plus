# Wiki Orchestrator — Stage Output Examples

> Reference material for the `wiki-orchestrator` skill.
> See `skill.md` for core guidance.

## Stage Output Templates

Use these templates when reporting pipeline results.

## Stage 3: Link Verification Output

```markdown
## Link Verification Report

| Link | Type | Status |
|------|------|--------|
| /path/to/page | Internal | ✅ PASS |
| /path/to/missing | Internal | ❌ FAIL |

**Gate Status:** ❌ BLOCKED (1 broken internal link)
```

## Stage 4: Secret Scan Output

```markdown
🛑 SECRET DETECTED — Publishing blocked

| Line | Pattern | Match |
|------|---------|-------|
| 47 | SQL Password | Password=j69K... |

**Action Required:** Remove or redact before publishing
```

## Stage 5: Slop Detection Output

```markdown
## Slop Analysis

**Score:** 23/100 (Good)
**Flagged phrases:** 2

| Phrase | Line | Suggestion |
|--------|------|------------|
| "leveraging cutting-edge" | 15 | State specific technology |
| "industry best practices" | 28 | Name the practices |

**Gate Status:** ⚠️ ADVISORY (minor suggestions)
```

## Stage 6: Fact-Check Output

```markdown
## Fact-Check Summary

**Claims:** 8 total | 6 cited | 2 uncited

**Uncited claims requiring attention:**
1. "We decided to use Telnyx in Q4" — needs ticket/PR reference
2. "Performance improved by 40%" — needs benchmark source

**Gate Status:** ⚠️ WARNING (2 uncited claims)
```

## Stage 7: Publish Confirmation

```text
Ready to publish with warnings:
- 2 uncited claims (advisory)
- 1 slop phrase (advisory)

Proceed? [Y/n]
```

Then invoke `wiki-orchestrator`:

- Use adapter's `update_page` for existing pages
- Use adapter's `create_page` for new pages
