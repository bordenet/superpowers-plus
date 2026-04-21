---
name: wiki-orchestrator
source: superpowers-plus
triggers: ["document X in wiki", "write wiki documentation for", "publish to wiki", "wiki:create", "wiki:update", "wiki:publish", "cross-reference wiki", "bulk wiki update", "update all wiki pages", "add links across wiki", "structure this wiki page"]
anti_triggers: ["verify", "verify this wiki page", "check wiki page", "validate wiki", "wiki verification", "verify wiki URL", "check wiki link", "fact-check wiki", "wiki secret scan", "edit wiki page", "delete wiki page", "update wiki page", "check accuracy", "fact-check", "verify claims", "fix wiki links", "fix broken links", "audit the wiki", "refactor wiki page", "reorganize wiki pages", "reorganize all wiki", "scan wiki for credentials"]
description: "Orchestrates BULK and MULTI-PAGE documentation projects — reorganizing multiple pages, cross-referencing across sections, publishing coordinated updates. Runs quality pipeline (de-dup, link-verification, secret-scan, slop-detection, fact-check). NOT for single-page edits (use platform-specific editing skills from _adapters/)."
summary: "Use when: bulk documentation projects, multi-page reorganization, cross-referencing. Skip when: editing one page, creating one page, deleting one page."
coordination:
  group: wiki-pipeline
  order: 1
  requires: []
  enables: ["link-verification"]
  escalates_to: []
  internal: false
composition:
  consumes: [goal, wiki-content]
  produces: [wiki-plan, updated-wiki-content]
  capabilities: [orchestrates-workflow, sequences-skills]
  priority: 5
---

# Wiki Orchestrator

Route bulk/multi-page wiki edits through the 7-stage pipeline below. Single-page
edits use `tools/wiki-write.sh` directly. Wrong skill? Links → `link-verification`
· Facts → `wiki-debunker` · Drift → `wiki-verify` · Secrets → `wiki-secret-audit`
· Full refactor → `wiki-refactor`. Background: `rationale.md`.

## Step 0 — Load adapter (before any write)

```bash
source ~/.codex/.env 2>/dev/null
: "${WIKI_PLATFORM:?set WIKI_PLATFORM in ~/.codex/.env (e.g. outline)}"
cat "$HOME/.codex/superpowers-plus/skills/wiki/_adapters/${WIKI_PLATFORM}.md"
```

If `WIKI_PLATFORM` is unset and no adapter loads → **STOP. Do not write.**

## The 7-stage pipeline (BLOCK gates halt; fix, resume from failed stage)

| # | Stage | Gate | Command |
|---|-------|------|---------|
| 1 | De-dup | WARN | `tools/wiki-read.sh search "<topic>" --limit 5` |
| 2 | Generate | — | Apply formatting rules below |
| 2.5 | Coherence | ADVISORY | `use-skill wiki-content-coherence` |
| 3 | Links | **BLOCK** | `use-skill link-verification` |
| 4 | Secrets | **BLOCK** | `use-skill wiki-secret-audit` |
| 5 | Slop | ADVISORY | `use-skill eliminating-ai-slop` |
| 5.5 | Structure | **BLOCK** | `node tools/wiki-markdown-validate.js draft.md` |
| 6 | Facts | WARN | `use-skill wiki-debunker` |
| 7 | Publish | — | `tools/wiki-write.sh {create\|update\|move} …` |

## Stage 7 — write via `tools/wiki-write.sh`

```bash
tools/wiki-write.sh create --parent "$PARENT_UUID" --title "$TITLE" --content draft.md
tools/wiki-write.sh update --doc    "$DOC_UUID"                     --content draft.md
tools/wiki-write.sh move   --doc    "$DOC_UUID"    --parent "$NEW_PARENT_UUID"
```

Exit: `0` ok+verified · `1` scope · `2` env/arg · `3` API · `4` verify failed.
**Never create a root page.** On exit `1` stop and ask; do not retry.

## Content formatting (Stage 2)

| Rule | Action |
|------|--------|
| H1 in body | Drop — platform renders title |
| Raw HTML / `&nbsp;` / `> [!info]` | Remove; breaks API round-trip |
| `[ ]` or `&nbsp;` in table cells | Use `Yes/No` or `✓/✗` |
| Code blocks | Always tag language |
| 4+ H2/H3 outside fences, `toc_behavior=manual`, no TOC | Insert adapter `toc_syntax` |

## Pre-write checklist

1. `tools/wiki-read.sh search "<title>" --limit 5` (dedupe)
2. `tools/wiki-read.sh get "<id-or-slug>"` (fetch state / verify parent)
3. Apply Content formatting rules to draft
4. `node tools/wiki-markdown-validate.js draft.md` → exit `0` or fix
5. `tools/wiki-write.sh {create|update} …` → exit `0` or stop

## Pre-delete: backup first

```bash
mkdir -p _deleted_backups && tools/wiki-read.sh get "$DOC_ID" \
  > "_deleted_backups/$(date +%F)_${DOC_ID}.json" \
  || { echo "backup failed, refusing delete"; exit 1; }
# only now invoke the adapter's delete/archive operation
```

## Failure modes

| Failure | Recovery |
|---------|----------|
| Pipeline used for single-page edit | Use `tools/wiki-write.sh` directly |
| Skipped a BLOCK stage | Restart pipeline from that stage |
| `wiki-write.sh` exit 1 | Stop; ask user |
| `wiki-write.sh` exit 4 | Re-run Stage 5.5 on fetched body, fix, retry |

Philosophy, rationalizations, companion-skill list: `rationale.md`.
