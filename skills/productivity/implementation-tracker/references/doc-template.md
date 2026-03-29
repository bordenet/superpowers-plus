# Implementation Progress Doc Template

```markdown
---
linear: {PREFIX}-1234
branch: feature/labor-type-scheduling
created: 2026-03-06
last_session: aug_abc123
---

# {PREFIX}-1234: Add laborType to scheduler

## Status
🟡 In Progress | 3/7 tasks complete

## Active Work
- [ ] Current task being worked on
  - Finding: discovered X needs Y
  - Approach: chose Z because...

## Refinements & Decisions
| Session | Decision | Context |
|---------|----------|---------|
| aug_abc123 | Use `.default(null)` not empty string | User corrected: empty string breaks CSV import |

## Completed (Summary)
| Task | Files Modified | Notes |
|------|----------------|-------|
| Add schema field | `scheduler.ts` | Added with `.default(null)` |

## Session History
| Session ID | Date | Summary |
|------------|------|---------|
| aug_abc123 | 2026-03-06 | Initial implementation |

## Wiki Context
| Page | Relevance | Last Checked |
|------|-----------|--------------|
| [Architecture](/doc/[product]-scheduler-xyz) | Data flow | 2026-03-06 |

## Key Insights (User-Confirmed)
- Router at `index.ts:123` constructs `serviceLaborScheduling`

## Open Questions
- [ ] Should laborType be required in CDK payload?
```

---

## Verification Output Template

```markdown
## Verification (aug_abc123 - 2026-03-06 14:32)
✅ Git: 3 files modified (scheduler.ts, index.cfm, [product]_config.js)
✅ Files: All expected files exist
✅ Symbols: `laborType` found in 4 locations
✅ TypeScript: No errors
⚠️ Tests: 2 tests skipped (E2E requires VPN)
```

---

## Wiki Context Gathering

1. `search_documents_outline(query: "{PREFIX}-1234")`
2. `get_document_outline(id: "page-id")`
3. `ask_documents_outline(query: "What is the [Product] scheduler data flow?")`

Store excerpts in `## Wiki Context` section.

---

## Archive Workflow

When work is complete, prompt:

```
Implementation complete for {PREFIX}-1234.
Where should the progress doc live?
1. Delete — Linear ticket has final state
2. Move to archive — docs/plans/_archive/{PREFIX}-1234-progress.md
3. Commit to git — Preserve in repo history
4. Custom location
```

---

## Checklists

### Creating Progress Doc
- [ ] Linear ticket referenced
- [ ] Branch name captured
- [ ] Session ID recorded
- [ ] Plan tasks imported
- [ ] Wiki context gathered
- [ ] Initial verification run

### Updating Progress Doc
- [ ] Mark completed tasks
- [ ] Record refinements/decisions
- [ ] Note new findings
- [ ] Run verification (all 5 methods)
- [ ] Check doc size, condense if needed

### Session Resume
- [ ] Prompt to load existing context
- [ ] Display session history
- [ ] Show open questions
- [ ] Check wiki for updates since last session
- [ ] Verify completed work still accurate

---

## Integration Flow

```
writing-plans → implementation-tracker → work → verify → archive
                                          ↓
                            [product]-data-flow-verification (if scheduler)
```
