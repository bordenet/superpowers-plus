# Changelog

All notable changes to superpowers-plus are documented here.

superpowers-plus extends [obra/superpowers](https://github.com/obra/superpowers) by Jesse Vincent.

Format based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

### Added

- `code-review-battery`: `/sp-cr-battery` slash command (primary, short, easy to type). `/sp-deepreview` retained as legacy synonym.
- `code-review-battery`: optional `[min-score]` argument (1.0–10.0, default 7.0) sets a numeric quality threshold. Score formula: `10.0 − (Critical×2.5) − (Important×1.5) − (Minor×0.25) − (durable<50% ? 0.5 : 0)`, floor 0.0. Score below threshold aborts Phase 6 (no sentinel written). `tools/run-battery.sh` gains `--min-score N` flag; sentinel always records the threshold as field 5 (`min-score=N`).
- `link-verification` golden regression file for compression tests
- **Wiki skills Haiku-runnable standard:** all 8 wiki skills (`wiki-orchestrator`, `wiki-verify`, `wiki-secret-audit`, `link-verification`, `wiki-markdown-structure-gate`, `wiki-content-coherence`, `wiki-refactor`, `wiki-debunker`) rewritten to a procedural contract targeting small-model execution. Contract: `skill.md` ≤100 lines, numbered steps where each step is a concrete shell command / exit-code check / short decision table, overflow to sibling `rationale.md` (existing `references/` pattern). Computable gates delegate to existing tools (`tools/wiki-read.sh`, `tools/wiki-write.sh`, `tools/wiki-scope-check.sh`, `tools/wiki-markdown-validate.js`). Total wiki skill body went from 1,209 → 754 lines (-37%). No YAML frontmatter, trigger, or coordination-graph changes; no behavior changes to the pipeline.
- `skills/wiki/wiki-orchestrator/rationale.md`, `skills/wiki/wiki-verify/rationale.md`, `skills/wiki/wiki-refactor/rationale.md` — sibling files holding philosophy, rationalization-rejection tables, and success-criteria detail extracted from the procedural skill bodies.

### Removed

- **`spc:` / `spc-` skill-loader prefix** removed from the public loader (`superpowers-augment.js`) and `docs/DESIGN.md`. It was a silent alias of `spo:` / `spo-` and carried organization-specific branding that did not belong in the public artifact. The generic overlay route (`spo:` + `SP_OVERLAY_SOURCE_DIR`) is unchanged. **Migration:** in `use-skill <name>` call sites, `s/spc:/spo:/g` and `s/spc-/spo-/g`. Overlay repos wanting custom branding can wrap the loader in their own script that rewrites prefixes before invoking `use-skill`. **Unaffected:** the Augment slash-menu `/spc-*` trigger-extraction subsystem (`lib/install/deploy.sh`, `docs/ARCHITECTURE.md`, ADR-002) is a separate concept — it picks slash-command directory names from `triggers:` frontmatter and has nothing to do with loader namespace resolution.

### Fixed

- **`resolveSkillNamespace` early-error return shape:** the two early-error returns (`SPP_SOURCE_DIR not set`, `SP_OVERLAY_SOURCE_DIR not set`) now include `forceSpp: false, forceSpo: false` to match the documented return contract. Not a live bug (the caller checks `.error` first), but tightens the JSDoc to return-value correspondence.
- **Dormant-skill audit (2026-04-17):** repaired `compat.sh` `--help` leak in sourced-mode scripts (`todo-crud`, `skill-cost-analyzer`, `test-content-coherence`); corrected stale `sp-deepreview` references in `sp-bughunt` to `code-review-battery`; added `--help` handling to `loose-ends`, `run-battery`, `backfill-composition`, `wiki-read`, `wiki-write`, `parse-frontmatter`, `test-content-coherence`; restored executable bit on `test_frontmatter_parsers.sh`; removed deprecated `~/.claude/skills/` path from `update-superpowers`.
- **Compression safety (incident 2026-04-14):** `STRIP_SECTIONS` was deleting operative safety content — `Hallucination Prevention` sections (containing `<EXTREMELY_IMPORTANT>` URL verification rules), `References` sections (pointers to `references/incidents.md`), and `Incident Log/Record/History` sections. All three are now preserved. Wiki authoring was producing broken hyperlinks as a result.
- **`<EXTREMELY_IMPORTANT>` block extraction:** Blocks are now extracted before section stripping and restored after, so they survive even if their parent heading is stripped. Blocks rescued from stripped sections are appended under a `## Critical Rules (preserved from compression)` synthetic heading. Code blocks containing EI tags are protected from extraction.
- **Pre-push mirror policy:** `git fetch origin` now runs before SHA comparison on private-remote pushes to prevent stale-ref bypass. Fetch failure blocks the push (`exit 1`).
- **Stale JSDoc:** `superpowers-augment.js` compression comment now points to `lib/compress.js` as authoritative source.
- **GitLab mirror policy:** Added to `.ai-guidance/invariants.md` (repo-level, always in agent context).

## [1.0.0] - 2026-04-13

### Added

- Skill discovery module, composition engine, workflow state machine, skill router — all with unit tests (227 total)
- CI pipeline with 3 job types: Node.js tests, shell tests (BATS + doctor), quality gates
- Code Review Battery — 5-reviewer sub-agent system with triple-filter synthesis
- Forked Debugging (Preview) — conductor + 5 investigator skills + evidence adjudicator
- Wiki Refactor Pipeline — 7-phase skill for large-scale wiki restructuring
- TypeScript Ecosystem — strict-mode, project-conventions, vitest-testing-patterns
- MCP v3.0.0 — semantic skill matching, multi-source directory support, content compression
- TF-IDF engine for offline skill matching (eliminates OpenAI API dependency)
- 25+ new skills across engineering, productivity, security, and writing domains
- sp-help, sp-doctor, sp-update CLI tools with auto-symlink during install
- Skill auto-composition engine (RFC-001), dependency graph, coordination schema
- Plugin marketplace distribution (.claude-plugin/, .cursor-plugin/, .codex/, .opencode/)
- Mandatory harsh review enforcement system with pre-commit hooks and CI workflow
- Non-interactive install (--yes/-y flag), Ubuntu/WSL support, Windows PowerShell support
- Platform-agnostic skill framework with adapter pattern for wiki and issue-tracking
- Professional language audit, time estimate inflation detection, receiving-code-review skill
- 10 shared reference schemas in skills/_shared/

### Changed

- Parser consolidation — single canonical parser in lib/frontmatter.js
- Doctor script refactored from 1300-line monolith into 8 modules
- install.sh decomposed from 1,163 lines into 380-line orchestrator + 6 modules
- Skill router: named boost constants, deduplicated intent patterns, documented scoring
- README overhaul: dynamic skill counts, Standout Skills table, Quick Start
- Issue-tracking adapter contract: structured output contracts, tri-state exists field
- AGENTS.md promotion model with cadence column and authorization expiry
- Wiki adapter publish contract: executable pre-write validation + post-write verification
- Split large skills (>500 lines) into modular files
- Removed hardcoded vendor references from shared skills

### Removed

- azure-devops issue tracker adapter (recreate from platform-template.md)
- tools/wiki-snapshot.sh (use direct Outline API calls)
- telephony-flow-investigator (proprietary)

### Fixed

- TODO.md protection — 7-layer defense system preventing agent-driven data loss
- IP audit hardening across staged, range-based, and full-file checks
- YAML parser hardening — apostrophe escaping, bracket-multiline handling
- Prototype pollution bug with constructor term causing NaN scores
- Markdownlint audit — 1,757 violations eliminated
- Proprietary content scrub — all proprietary references removed across 4 passes
- Pre-push orphan docs-only exemption for new branches
- Doctor ahead-commit detection for diverged installations
- Trigger collisions resolved
- todo-management deterministic path with hard gate
- Trailing newline issues in 67+ files
- Shell script shebangs standardized

[1.0.0]: https://github.com/bordenet/superpowers-plus/releases/tag/v1.0.0
