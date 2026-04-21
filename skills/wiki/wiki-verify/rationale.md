# wiki-verify — rationale & background

Context for `skill.md`. The procedural skill is self-sufficient; this file
captures **why** the rules exist.

## Why verify codebase claims separately from decisions

`wiki-debunker` handles "who decided what, when" — claims whose authoritative
sources are issue trackers, PRs, and meeting transcripts. `wiki-verify`
handles drift-prone technical details — version numbers, file paths, vendor
names, config values — whose authoritative sources are the codebase itself.
Separating them keeps each skill's source-authority matrix sharp.

## Why a tail-section OR registry fallback

Some wiki pages have verification sources that belong alongside the content
(product-specific pages). Others apply to many pages at once (infrastructure
references) and are easier to maintain centrally. The tail section is
preferred because it lives with the content; `wiki-sources.yaml` is the
fallback when per-page metadata is impractical.

## When to use

- After a service version bump, check every page that references the service
- During periodic wiki health reviews
- When `wiki-orchestrator` triggers the verification stage after a bulk edit
- Any time a config value, vendor choice, or file path has moved

## Default mode: --fix

`wiki-verify` auto-applies all fixes without prompting. This is the default
because most invocations happen in automated pipelines (post-publish drift
checks, orchestrator stages) where interactive prompts stall execution.

Use `--interactive` to review fixes before applying:

```text
⚠️  STALE: Deepgram SDK version
    Wiki says: v3.2.1
    package.json says: v3.4.0
    → [U]pdate / [S]kip / [A]ll / [Q]uit? _
```

All model tiers can use the default. Prefer `--interactive` when the user is
present and changes are high-risk (e.g. live production wiki, no rollback).

## Authoritative-source ordering

If sources conflict, prefer in order:
1. Live API response (for current-state claims)
2. Committed code (`git show` at HEAD)
3. Lock files (`package-lock.json`, `requirements.txt` with pinned versions)
4. Manifests (`package.json` with ranges)
5. Vendor documentation (external)

Never treat a wiki summary as authoritative.

## Companion skills

- **wiki-debunker** — deeper fact-checking for decisions/timelines
- **link-verification** — URL existence
- **wiki-orchestrator** — full edit pipeline (can invoke this skill as a stage)
