# Wiki Debunker — Report Format

> Reference material for the `wiki-debunker` skill.
> See `skill.md` for core guidance.

## Fact-Check Report Template

When called by orchestrator, produce this summary:

```
## Fact-Check Report

**Claims Analyzed:** 14
**Verified:** 8 (57%)
**Sourced but Unverified:** 2 (14%)
**Uncited:** 4 (29%)

### Sourced but Unverified (cite from wrong authority)

| # | Claim | Type | Source Used | Authoritative Source | Action |
|---|-------|------|------------|---------------------|--------|
| 1 | "Junyi's funnel metrics queries" | Task ownership | Wiki plan table | Issue tracker assignee | ⚠️🔄 Verify in tracker |
| 2 | "Ships in Sprint 2 per v1 Plan" | Timeline | Wiki roadmap | Git tags, CI deploys | ⚠️🔄 Check actual sprint |

### Uncited Claims (require attention)

| # | Claim | Type | Suggested Source | Action |
|---|-------|------|------------------|--------|
| 1 | "We decided to use Vendor X in Q4 2025" | Decision + Timeline | Issue Tracker, Git | ⚠️ Find ticket/PR |
| 2 | "Person proposed the WebSocket approach" | Attribution | PR #47 | ⚠️ Verify author |
| 3 | "Performance improved significantly" | Vague metric | Benchmarks | ⚠️ Add numbers |
| 4 | "Based on team discussion" | Meeting ref | Meeting transcript | ⚠️ Find transcript |

### Verified Claims

| # | Claim | Source | Citation |
|---|-------|--------|----------|
| 1 | Vendor A for telephony | [TICKET-89]([your-tracker-url]) | ✅ |
| 2 | Vendor B for STT | [PR #52]([your-repo-url]) | ✅ |
| ... | ... | ... | ... |

**Gate Status:** ⚠️ WARNING (4 uncited, 2 sourced-but-unverified)
**Recommendation:** Verify sourced-but-unverified claims against authoritative sources; add citations for uncited claims
```

## Citation Formats

**Inline:**
```markdown
We decided to use Vendor A for telephony [[TICKET-89](https://[your-tracker]/TICKET-89)].
```

**Block quote for key decisions:**
```markdown
> "Let's go with Vendor A — their WebSocket API is cleaner."
> — Team Member, [PR #47]([your-repo-url]/pullrequest/47), 2026-01-15
```

**Meeting transcript citation:**
```markdown
As discussed in the [Team Triage @ 10:45]([meeting-share-url]#t=645) ⏵
```
