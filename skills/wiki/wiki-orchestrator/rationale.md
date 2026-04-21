# wiki-orchestrator — rationale & background

Supporting context for `skill.md`. The procedural skill is self-sufficient; this
file explains **why** the rules exist for readers auditing or modifying them.

## Philosophy

Quality pipeline for complex multi-page operations; proportional overhead for
simple ones. Single-page edits that use the adapter's tools directly are not
required to run the full pipeline.

## Why "download before editing"

Fetching the current state before every write prevents silent overwrites of
concurrent edits — including edits the user has already made to fix the very
issue you're about to address.

## Why "no top-level pages"

Root-level pages bypass the collection-scope model enforced by
`tools/wiki-scope-check.sh`. Every agent-created page must be a child of an
in-scope parent unless the user explicitly approves root placement with the
exact collection identified.

## Why Stage 5.5 is structural, not stylistic

Stage 5 (slop detection) is advisory — prose quality rarely breaks rendering.
Stage 5.5 (structure gate) is a hard block because malformed tables, escaped
wiki-link artifacts, and unbalanced fences cause silent rendering breakage that
users discover after publish. `markdown-table-discipline` helps authoring;
`tools/wiki-markdown-validate.js` is the enforced gate.

## TOC threshold (4 headings)

Derived from usability testing: pages with 4+ H2/H3 headings (outside code
fences) are the threshold at which readers benefit from a TOC. Platforms with
`toc_behavior=auto` render one automatically. Platforms with
`toc_behavior=manual` require the adapter-specific markup. Platforms with
`toc_behavior=unsupported` skip the check.

## Batch operations

For 3+ page edits: discover all target pages → plan the full changeset → execute
in chunks of ≤10 → fetch FRESH content for each chunk (the previous chunk may
have changed sibling pages). See `references/batch-operations.md` if present.

## Rationalizations to reject

| Excuse | Reality |
|--------|---------|
| "Quick update, skip verification" | Quick updates break links too |
| "I know the links are correct" | Memory is unreliable; verify anyway |
| "I'll verify after publishing" | Backwards — verify BEFORE |
| "Pipeline adds friction" | Pipeline exists because each stage has caught regressions |

## Failure recovery

- **Context exhausted mid-pipeline:** The task list preserves state. Resume
  from the last completed stage.
- **Hard gate blocks:** Fix the issue (broken link, secret, structural defect),
  re-run from the failed stage. Never skip.

## Companion skills

- **wiki-content-coherence** — Stage 2.5, duplication detection
- **link-verification** — Stage 3, URL verification (HARD BLOCK)
- **eliminating-ai-slop** — Stage 5, prose quality (advisory)
- **wiki-markdown-structure-gate** — Stage 5.5, structural markdown gate
  (HARD BLOCK)
- **wiki-debunker** — Stage 6, fact-checking (advisory)
- **wiki-verify** — post-publish version drift detection
- **wiki-secret-audit** — secret scanning
