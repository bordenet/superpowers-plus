---
name: wiki-prune-audit
source: superpowers-plus
augment_menu: false
triggers: ["/sp-wiki-prune-audit", "prune the wiki", "audit wiki for pruning", "audit the wiki for dead weight", "find the worst wiki pages", "worst wiki pages", "find dead wiki pages", "wiki decay scan", "rank wiki pages by quality", "wiki:prune-audit", "which wiki pages should we delete"]
anti_triggers: ["refactor wiki", "restructure wiki", "wiki overhaul", "reorganize wiki pages", "edit single wiki page", "write wiki page", "update wiki content", "verify wiki page", "fact-check wiki", "publish to wiki", "bulk wiki update", "create wiki page"]
description: "Read-mostly triage scanner: point it at one or more wiki subtree roots and it ranks the least-useful pages (duplication, obsolescence, low signal-to-noise, orphans, structural defects, link-rot), PHR-verifies the worst, publishes a severity-ranked worklist, and applies only safe mechanical fixes. Never deletes/merges/archives."
summary: "Use when: you need to find and rank the worst/least-useful pages in a wiki subtree and safely fix the cheap wins. Skip when: rewriting/reorganizing pages (wiki-refactor) or editing one page."
composition:
  consumes: [wiki-subtree-root]
  produces: [ranked-prune-worklist, refactoring-playbook, safe-fix-log]
  capabilities: [scores-pages, ranks-badness, verifies-via-phr, fixes-linkrot, fixes-structural-defects]
  priority: 45
coordination:
  group: wiki-pipeline
  order: 0.5
  requires: []
  enables: [wiki-refactor]
  escalates_to: [wiki-refactor]
  internal: false
---

# wiki-prune-audit -- triage scanner

Finds and ranks the least-useful pages under a wiki subtree so a human (or `wiki-refactor`) can prune with confidence, and applies only the cheap, reversible mechanical fixes itself. This is the **discovery/triage front-end** -- it does not rewrite pages and it never deletes.

**Required input -- one or more wiki subtree root URLs.** The skill recurses from the page(s) you name and scans every descendant. **If the user names no URL, STOP and ask which subtree(s) to scan** -- never guess a root or default to the whole wiki.

## When to Use

- "Which pages should we prune/delete?", "find the worst wiki pages", "audit the wiki for dead weight"
- Before a `wiki-refactor` overhaul -- produce the ranked target list it consumes
- Periodic wiki hygiene sweeps (decay, link-rot, structural defects)

**Skip when:** rewriting/reorganizing pages (`wiki-refactor`), editing/creating one page (your wiki editing skill), verifying facts, bulk publishing.

## Hard Gates (non-negotiable)

1. **Never delete, merge, move, or archive a page.** Those are *recommendations* in the worklist for a human or `wiki-refactor`. This skill only (a) publishes a report and (b) applies the safe mechanical fixes in Phase 5.
2. **Every write goes through the full gate** (your wiki write tool): scope-check -> snapshot -> secret scan -> language scan -> structural check -> write -> re-fetch verify. No exceptions, including the safe fixes.
3. **PHR the rationale before publishing** (Author=/=Reviewer). A page earns a place on the list only after an independent PHR pass. Floor: PHR >= 9.2.
4. **Re-fetch before every edit.** This is a live, concurrently-edited wiki -- never write from stale/remembered text.

## Pre-flight

1. Resolve tooling: confirm your wiki read API and write tool are available. If your overlay ships a write-gate wrapper, use it -- it must enforce scope checking on every write.
2. Confirm write scope: the subtree root(s) you audit must be within your allowed write scope for any fix or report write.
3. Collect the target root URL(s) from the user. Confirm each resolves. Scope-check each report/fix target before writing. No URL -> ask; do not proceed.

## Phases

### Phase 1 -- Enumerate

Recursively list every descendant of each root via your wiki API, capturing `id, title, url, updatedAt, textLen, text, parentDocumentId`. One list call per parent (not per page); paginate if needed. Run as a background job for large trees. See `references/scoring.md` for a working enumerator. **If enumeration errors occur, re-run rather than publish a partial worklist.**

### Phase 2 -- Score (heuristic, read-only)

Score each page on badness signals (see `references/scoring.md`); higher = worse:

| Signal | Detection |
|--------|-----------|
| Near-empty / thin | `textLen` < 120 / < 350 |
| Obsolescence | `updatedAt` age; self-superseded banners; expired dated deadlines |
| Duplication | k-word shingle Jaccard > ~0.35 between two pages (inverted index, not O(n^2)) |
| Unfinished skeleton | placeholder-field density (`TBD`, `to be filled in`) |
| Structural defect | prose literal `\toc`; escaped `\n` (fence-excluded); leading H1 duplicating title |
| Link-rot | bare short-id links (no slug) |
| Orphan | zero inbound links AND a second defect (orphan alone is NOT badness) |

Emit a ranked candidate list (top ~40-60) with per-signal reasons.

### Phase 3 -- Digest + PHR verify

Pull a head/tail snippet + child count for the top candidates. **Dispatch a PHR panel sub-agent** (Author=/=Reviewer) that independently re-fetches each candidate and answers: *is it as bad as claimed, and is the category right?* The panel prunes false positives and returns a defensible ranked list. Do not pad the list past what evidence supports.

Known false-positive traps the panel must check (see `references/scoring.md`): escaped `\n` inside fenced code blocks, `\toc` inside fenced blocks, orphan pages that are just uncross-linked good content, 0-char pages with children (nav nodes, not dead weight).

### Phase 4 -- Publish the worklist

Write a scope-checked report page (buckets **A** empty/placeholder, **B** duplicate, **C** unfinished skeleton, **D** stale/obsolete, **E** structural/link-rot), ranked descending-severity, each row with a verified rationale and a recommended action. Include the LLM refactoring playbook from `references/playbook.md`.

### Phase 5 -- Safe auto-fix (bounded, reversible only)

Apply ONLY these mechanical fixes, logged in the report. See `references/safe-fixes.md` for exact recipes:

- **Bare-link resolution** -- resolve bare short-id links to full slugs. Never worse than the original.
- **Literal `\toc` repair** -- replace prose `\toc` with a TOC toggle built from H2/H3. If a heading anchor trips the language scanner, strip the `\toc` instead.
- **Escaped `\n` un-escape** -- un-escape prose `\n`/`\uXXXX`/`\*` rendering as raw text; repair single-backtick fences to triple.

Everything else (deletions, merges, archives, rewrites) is a recommendation only.

### Phase 6 -- Handoff

Point the human at the worklist for approval of destructive actions, or hand the ranked target list to `wiki-refactor` for a structural overhaul.

## Failure Modes

| Failure | Symptom | Fix |
|---------|---------|-----|
| Deleted a page | Content loss | Hard gate #1 -- this skill NEVER deletes. Recommend only. |
| Scored orphans as bad | Good uncross-linked pages flagged | Orphan requires a second defect (Phase 2). |
| Mermaid `\n` flagged as defect | False structural finding | Exclude fenced content before counting `\n` (see scoring.md). |
| Padded the list | Unverified pages presented as "worst" | PHR ceiling is honest evidence, not a target count. |
| Wrote from stale context | Clobbered a concurrent human edit | Re-fetch in the same tool sequence as the write (Hard gate #4). |
| Fix write out of scope | Write blocked | Only audit/fix subtrees within your allowed write scope. |

## References

| File | Contents |
|------|----------|
| `references/scoring.md` | Enumerator + scoring heuristics, dup detection, orphan/inbound, structural scan |
| `references/safe-fixes.md` | Bare-link, `\toc`, and escaped-`\n` fix recipes; scanner false-positive handling |
| `references/playbook.md` | The LLM refactoring playbook embedded in every published report |
