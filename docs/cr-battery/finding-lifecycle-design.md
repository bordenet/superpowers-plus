# Code Review Battery -- Finding Lifecycle Design

> Status: **Phase 1 shipped (preservation only). Phases 2-3 deferred.**
> Last reviewed: 2026-06-06.

## Context

After comparing `code-review-battery` against the architecture
described in Snap's CodePal article
(https://eng.snap.com/codepal), a `think-twice` critique
identified the missing piece: CodePal hit 30%->80% recall NOT
because of its verifier or bootstrap multi-pass, but because of
its **Finding Lifecycle / metrics flywheel** -- engineer thumbs-vote
on real-PR findings -> ground-truth corpus -> A/B prompt iteration.

The existing battery has zero measured precision/recall on real
production PRs in the wild. Synthetic exercise metrics (precision
100% on 15 exercises after the most recent additions) do not
predict in-the-wild performance. The graduated patterns have FP
holdouts, but the next missed-finding class miss is still coming
because nothing makes the battery learn from production PRs.

This document captures the design problem, four cumulative rounds
of harsh-review, the rejected options, and the recommended future
path.

## The design problem

Build a flywheel that:

1. Captures cr-battery findings durably (per-engineer, per-run).
2. Lets engineers label findings TP / FP / missed post-merge.
3. Aggregates labels into per-reviewer-dimension precision/recall.
4. Uses the corpus to iterate reviewer prompts against real data.

Constraints:

- No central telemetry infrastructure exists for review findings
  in a typical consuming team's repo.
- `skills/engineering/code-review-battery/skill.md` is at the
  per-skill line budget.
- New shell scripts trigger the consuming team's shell-review
  gate at the documented threshold.
- Reviewer outputs are free-form prose in conversation, not on
  disk.
- The orchestrator cannot reliably enforce side effects beyond a
  single tool invocation; gating sentinels through
  `tools/run-battery.sh` is the only enforcement primitive.
- Engineer identifiers differ across repos (a noreply GitHub
  handle on the public repo vs. a company-domain handle on the
  consuming team's internal repo for the same human).

## Four cumulative rounds of harsh-review

The transcripts are in the upstream design conversation; the
structural conclusions:

### Round 1 -- Option A (three discrete shell scripts)

- `tools/cr-capture-finding.sh` invoked from inside
  `run-battery.sh`, `tools/cr-tag-finding.sh`,
  `tools/cr-findings-summary.sh`.
- **REJECTED.** No "findings" exist at `run-battery.sh` time;
  reviewer outputs are in conversation prose, never on disk. No
  stable finding-id (re-runs / rebases / amends produce
  duplicates). Gitignored per-engineer JSONL defeats the
  shared-corpus goal. "Modify JSONL row in place" was a lie
  (JSONL is append-only). Sentinel-writer contract violation.

### Round 2 -- Option A' (split files, content-addressed id)

- Capture moved to Phase 3 (post-aggregation), not Phase 6.
  finding_id = SHA256(reviewer + file + line + issue[:50]).
  `.cr-battery-findings.jsonl` gitignored per-engineer;
  `.cr-battery-verdicts.jsonl` committed (shared corpus). Tag
  appends a new row with `supersedes:<timestamp>`.
- **REJECTED.** Shared-ground-truth still fails: verdicts.jsonl
  only travels on merged branches; ~95% of throwaway feature
  branches never merge. SHA256 truncation collides on common
  preamble. Crash mid-Phase-3 leaves orphan rows with no
  atomicity. Verdicts without findings (after fresh checkout)
  are un-falsifiable. `supersedes` introduces a clock-race
  between engineers with unsynced laptops. Phase 3 output is
  prose, not the structured tuples A' assumes -- re-introduces
  the parser problem from R1. skill.md line budget breached.

### Round 3 -- Option H (preserve-only)

- skill.md Phase 6 writes aggregated report to
  `.cr-battery-runs/<sha>.json` (gitignored). No tagging, no
  aggregator. Explicit deferral of the lifecycle claim.
- **Survived** as the only honest minimum.

### Round 4 -- Option M (Markdown ledger)

- Append a Markdown table row per finding to
  `docs/cr-battery-history/<engineer-handle>.md` (committed).
  Engineers edit the verdict column. Aggregator reads union.
- **REJECTED.** LLM-discretion failure mode (orchestrator may
  forget to append; no tool enforcement). Self-review pollution
  (engineer reviewing own PR -> untriaged rows on main forever).
  Atomicity gap (crash between sentinel + append = silent data
  loss). Ghost rows (reverts / rebases break SHA references).
  Handle drift across repos. CODEOWNERS deadlock risk.
  Cross-repo aggregation ambiguous. "Only travels when merged"
  applies to Markdown rows too.

## What ships now (Phase 1)

Option K -- preservation only, no lifecycle claim:

- `skill.md` Phase 6 instruction to write aggregated findings to
  `.cr-battery-runs/<HEAD-sha>.json` before invoking
  `tools/run-battery.sh`.
- `.gitignore` excludes `.cr-battery-runs/`.
- `tools/run-battery.sh` preservation gate -- refuses to write
  the sentinel if `.cr-battery-runs/` exists but the per-HEAD
  JSON is missing (graceful degradation when directory absent
  or in --staged mode).
- A bats test suite covering both branches of the gate.
- This file (Option L) documents the four rounds and the
  deferred work so the analysis isn't lost.

This does NOT claim the CodePal flywheel. It gives engineers
durable local copies of their reviews. The corpus exists;
tagging and aggregation are explicitly deferred.

## Recommended future path (Phase 3 -- external lifecycle store)

The CodePal flywheel goal requires central storage most
consuming teams don't have today. Possible external stores:

1. An issue tracker (Linear, Jira, etc.) -- create a parent epic
   with a stable issue prefix and a documented label schema (TP
   / FP / missed / pattern-name).
2. cr-battery Phase 6 (after sentinel write) creates a sub-issue
   per Implement-classified finding via the tracker's API or
   MCP. Issue body = the structured finding (reviewer, severity,
   file:line, issue, durable check).
3. Engineers label findings via the tracker's existing UI
   (labels + comments). No new CLI.
4. A new aggregator skill queries the tracker for finding-
   labeled issues, joins by reviewer dimension, computes
   precision/recall.
5. Iteration: pattern misses surface as `missed`-labeled issues;
   FP regressions surface as `fp`-labeled issues; the
   candidate-pattern pipeline in `gap-analysis.md` consumes the
   corpus instead of synthetic exercises.

### Prerequisites Phase 3 requires (do NOT start until each is in place)

- Tracker API or MCP availability in the orchestrator.
- Parent epic created in the tracker with a documented label
  schema and a single owner authorized to govern the corpus.
- A handle-normalization decision: either single canonical
  handle per human across repos (preferred) or per-repo handle
  mapping documented somewhere stable.
- Phase 1 + Phase 2 shipped and merged with both quality gates
  cleared so the foundation (preserve + document) exists before
  tagging + aggregating land.

### Phase 3 estimated scope

- ~1 week of work split across 3-5 PRs.
- PR 3a: parent epic + label schema documentation in this file.
- PR 3b: tracker integration in cr-battery Phase 6.
- PR 3c: new aggregator skill + tests.
- PR 3d: gap-analysis.md update to consume external corpus
  alongside synthetic exercises.

### Phase 3 sanitization requirement (do NOT skip)

The Phase 6 preservation schema fields `issue`,
`regressions_risked`, and `durable_check` are unsanitized
LLM-emitted prose from the reviewer sub-agents. They may quote
diff content verbatim -- including customer names, hardcoded
URLs, internal API paths, or fragments of secrets the reviewer
is critiquing. In Phase 1, this is acceptable because the JSON
lives in a gitignored per-engineer directory inside the
consuming team's repo. In Phase 3 (external tracker
integration), the same fields will be POSTED to issues where
they become permanent shared artifacts.

Before Phase 3 ships, the integration MUST add a sanitization
pass that:

- Strips strings matching common secret patterns (`Bearer `,
  JWT prefixes like `eyJ`, cloud-provider access key prefixes
  like `AKIA`, etc.).
- Strips customer-identifying strings unless explicitly
  authorized (no customer names, no account IDs).
- Truncates file paths to the basename when they reveal
  directory layouts internal to specific services.

Without this pass, Phase 3 leaks internal data into the
tracker, where it may be visible to a broader audience than the
engineers who authored the review.

## Why Phase 3 is gated, not scheduled

The harsh-review rounds repeatedly surfaced that bolting a
flywheel onto a per-engineer-per-repo skill without central
infra produces either un-falsifiable claims or schema decay.
Using an existing issue tracker is the closest available piece
of central infra; using it requires governance (epic ownership,
label discipline, retention policy) that must be agreed before
the code ships, not after. Until that governance exists, Phase
3 should not start.

## Revision history

- 2026-06-06 -- Initial document, written as part of Phase 1.
