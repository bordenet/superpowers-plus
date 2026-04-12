---
name: todo-hygiene
source: superpowers-plus
triggers: ["/sp-hygiene", "clean up todos", "review todos", "todo hygiene", "audit todos", "stale todos", "todo review", "scrub todos", "todo maintenance", "are my todos current", "clean up tasks"]
anti_triggers: ["add task", "complete task", "archive todos", "what should I work on"]
description: "Use when: performing routine maintenance across all open TODOs — archiving completed work, fixing stale descriptions, resolving ambiguities, and catching scope drift. Skip when: adding/completing individual tasks or archiving."
summary: "Use when: systematic top-to-bottom review of all open TODOs against real system state."
coordination:
  group: productivity
  order: 1
  requires: ["todo-management"]
  enables: ["todo-archive"]
  escalates_to: ["think-twice"]
  internal: false
composition:
  consumes: [todo-items]
  produces: [todo-items, hygiene-report]
  capabilities: [reviews-tasks, archives-completed, improves-descriptions]
  priority: 14
---

# TODO Hygiene

> **Wrong skill?** Adding tasks → `todo-management`. Archiving history → `todo-archive`. Deferral tracking → `todo-guardian`.

**Announce at start:** "Running **todo-hygiene** — systematic review of all open TODOs."

## Procedure

### Phase 1: Snapshot (read-only)

```bash
~/.codex/superpowers-plus/tools/todo-crud.sh list
```

Record: total count, date distribution, tag distribution, items with no tags.

### Phase 2: Classify each item

For EVERY open TODO, classify into exactly one category by checking source-of-truth systems:

| Category | Criteria | Action |
|----------|----------|--------|
| **A: Completed** | Branch deleted/merged, MR closed, wiki page exists, PR merged | `todo-crud.sh complete` |
| **B: Stale** | >7 days old AND references expired context (PR, branch, deadline passed) | Flag for user decision |
| **C: Drifted** | Description contradicts current state (wrong decision ref, wrong file path, scope changed) | Fix description via complete-and-readd |
| **D: Ambiguous** | Insufficient context to verify — no tags, vague description, orphaned | Ask user |
| **E: Valid** | Verified still actionable, description accurate | No action |

**Verification methods by TODO type:**

| TODO type | How to verify |
|-----------|--------------|
| PR/MR review | Check PR/MR status via API |
| Branch-specific work | `git branch -r` — does it exist? |
| Wiki page creation | Search Outline API — does page exist? |
| File/code changes | Check filesystem — does the file/feature exist? |
| CI/pipeline work | Check CI variables, pipeline status |
| Human-only tasks | Flag as Category D — can't verify |
| Dated deadlines | Compare deadline to today's date |

### Phase 3: Act

**Order matters. Complete first, then fix, then ask.**

1. **Category A (Completed):** Archive via `todo-crud.sh complete --id <ID> --note "<evidence>"`. Always include evidence in the note.

2. **Category C (Drifted):** Since `todo-crud.sh` has no `update` command: `complete` the old one with note "Superseded: <reason>", then `add` a corrected replacement. Preserve the original priority and tags.

3. **Category B (Stale):** Present to user as a batch:
   ```
   STALE ITEMS — need your decision (complete, keep, or update):
   | ID | Age | Description | Why stale |
   ```

4. **Category D (Ambiguous):** Present to user one at a time. Ask: "What is this? Should I keep, complete, or rewrite it?"

5. **Category E (Valid):** No action needed. Report count.

### Phase 4: Improve survivors

For all Category E items, check for:
- **Duplicate tags** (e.g., `#superpowers-plus #architecture #refactor #superpowers-plus #architecture #refactor`) — fix via complete-and-readd
- **Missing tags** — suggest tags based on description content
- **Stale temporal language** ("next week", "tomorrow", "after the meeting") — rewrite with absolute dates or remove
- **Wrong cross-references** (decision refs like D20 that should be D21) — fix

### Phase 5: Report

```
TODO Hygiene Report
═══════════════════
Completed (archived):  N items
Drifted (fixed):       N items  
Stale (needs decision): N items
Ambiguous (asked user): N items
Valid (no change):      N items
Improvements applied:  N fixes (tags, descriptions, refs)
──────────────────────
Before: X total → After: Y total
```

Then run maintenance:
```bash
~/.codex/superpowers-plus/tools/todo-maintenance.sh
```

## Safety Rules

1. **NEVER use `save-file` or `str-replace-editor` on TODO.md** — only `todo-crud.sh`
2. **NEVER complete an item without evidence** — the `--note` must cite what you checked
3. **NEVER silently drop items** — every item gets classified and reported
4. **NEVER guess completion** — if you can't verify, classify as D (Ambiguous)
5. **When in doubt, ask** — user decisions > agent assumptions

## Anti-Patterns

| Anti-Pattern | Detection | Correction |
|--------------|-----------|------------|
| Declaring "all clear" without reading content | Phase 2 skipped or superficial | Must check source-of-truth per item |
| Keyword-matching instead of verification | "Found 'merged' in description" ≠ verified | Call the actual API/git command |
| Batch-completing without evidence | Notes are empty or generic | Each `--note` must cite specific evidence |
| Fixing items the agent doesn't understand | Category D item treated as C | Ask user first |
| Running once and declaring done | Single-pass misses ~40% of issues | Run Phase 2-5 twice minimum |

## Failure Modes

| Failure | Fix |
|---------|-----|
| `todo-crud.sh complete` fails | Check if ID exists: `todo-crud.sh list \| grep <ID>` |
| API rate-limited during verification | Batch verifications, retry with backoff |
| User unavailable for B/D decisions | Park items, report at session end |
| Item count mismatch after changes | Re-run `todo-crud.sh list`, reconcile |
