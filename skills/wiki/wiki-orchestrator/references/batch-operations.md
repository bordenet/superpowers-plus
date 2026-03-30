# Wiki Orchestrator — Batch Operations

> Reference material for the `wiki-orchestrator` skill.
> See `skill.md` for core guidance.

## When to Use Batch Workflow

**When editing 3+ wiki pages in one task** (cross-references, bulk updates, terminology standardization), use the batch workflow — NOT individual API calls per page.

### Why Batch Matters

| Approach | API Calls | Risk |
|----------|-----------|------|
| Individual: fetch → edit → push × N pages | 3N calls | Rate limits, context exhaustion, partial updates |
| Batch: sync all → grep locally → plan → push chunk | N+1 calls | Fast discovery, atomic planning, fewer failures |

### Batch Workflow

```bash
Phase 1: DISCOVER (zero write calls)
  └─ Local wiki sync or export          # Download the working set when supported
  └─ grep/rg locally for target terms   # Find all pages that need changes
  └─ Build change manifest              # Page → planned edits

Phase 2: PLAN (zero API calls)
  └─ Review manifest with user
  └─ Group into chunks of 5-10 pages
  └─ Identify link dependencies (edit targets before sources)

Phase 3: EXECUTE (chunked API calls)
  └─ For each chunk:
     ├─ adapter.get_page × N            # Fetch FRESH content (mandatory)
     ├─ Apply planned edits
     ├─ Run pipeline gates (links, secrets, slop)
     └─ adapter.update_page × N         # Push chunk
  └─ Verify chunk before proceeding to next

Phase 4: VERIFY
  └─ Spot-check 2-3 pages via adapter.get_page
  └─ Scan for \[ or broken rendering
  └─ Report summary to user
```

### Key Rules

1. **NEVER skip the fresh fetch in Phase 3.** The local sync is for *discovery only* — always fetch current content before editing.
2. **Group by dependency order.** If page A will link to an anchor on page B, edit page B first (create the anchor), then page A (add the link).
3. **Chunk size: 5-10 pages.** Larger chunks risk context exhaustion. Smaller chunks waste round-trips.
4. **Use task management** to track which chunks are complete. Mark each chunk COMPLETE before starting the next.

### Anti-Patterns

| Anti-Pattern | Why It Fails |
|--------------|-------------|
| Repeated wiki search API queries | Slow, expensive, misses pages |
| Editing from memory without fresh fetch | Overwrites concurrent edits |
| One API call per page with no batching plan | Context exhaustion on page 15 of 30 |
| Pushing all pages then verifying | Can't roll back; broken links cascade |
