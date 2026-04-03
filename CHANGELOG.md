# Changelog

All notable changes to superpowers-plus are documented here.

superpowers-plus extends [obra/superpowers](https://github.com/obra/superpowers) by Jesse Vincent.

Format based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
Versioning follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- **update-superpowers skill** - Documents the `sp-update` workflow: three-tier promotion, divergence recovery (auto-reset), cascading installs, and sp-doctor verification. (#447)
- **docs/SKILLS.md** - Full 87-skill reference table organized by domain, moved out of README. (#450)

### Changed

- **README overhaul** - Replaced hardcoded skill counts with dynamic language. Added Standout Skills table (9 key skills), Quick Start with trigger examples, pre-commit hooks note, and token budget advisory. Removed stale Development Process and Semantic Skill Matching sections. Three rounds of PHR, scored 8.5/10. (#450)
- **GitHub repo description** - Fixed "orba" typo, updated to "Skills for AI coding assistants. Extends obra/superpowers."

### Fixed

- **pre-push orphan docs-only exemption** - New branches with no common ancestor and only docs/metadata commits can now push without a code-review sentinel. Previously all no-base branches failed closed unconditionally. Uses `git log --name-only -m` to enumerate reachable history including merge-commit conflict resolutions; code files still cause fail-closed behavior.
- **IP audit hardening** - Strengthened public repo IP guardrails for staged, range-based, and full-file checks. Wired shared audit into pre-commit, pre-push, harsh-review, install, and doctor flows. Added regression tests for diff lines, upstream-only refs, external hooksPath, and bash 3.2 re-exec. (#449)
- **Doctor ahead-commit detection** - Check 19 now flags CRITICAL when the installed copy has local commits not on remote, preventing stale diverged installations. (#445)
- **Trigger collisions** - Collapsed multi-line trigger arrays for `progressive-harsh-review` and `skill-health-check`. Resolved `expert-interviewer` trigger collision with `knowledge-capture`. (#443)
- **Fork reference scrub** - Removed fork-specific references from plan documents. (#444)

### Maintenance

- **Branch cleanup** - Deleted 11 stale remote branches and 7 local branches after verifying all PRs merged.

## [2.6.0] - 2026-03-30

268 commits, 277 files changed, +19,801 / −3,451 lines. Skill count: 61 → 86.

### Added — New Skills (25 new)

- **Code Review Battery** — 5-reviewer sub-agent system plus optional monolith reviewer dispatched by `progressive-code-review-gate`. Versions v2.0–v2.4 shipped across this release cycle. Reviewers: defect-finder (callee trace, adversarial inputs), design-critic, guardian, performance-analyst, standards-enforcer, monolith. Triple-filter synthesis, convergence logic, scoring metrics, and 13 training exercises in `exercises/code-review-battery/`.
- **Forked Debugging (Preview)** — `debug-conductor` orchestrates 5 investigator skills (`infra-config-investigator`, `llm-behavior-investigator`, `reproduction-experiment-investigator`, `state-consistency-investigator`, `timeline-trace-investigator`) and hands findings to `evidence-adjudicator`. Full experiment suite with 5 fixture scenarios in `exercises/forked-debugging/`.
- **Wiki Refactor Pipeline** — 7-phase skill for large-scale wiki restructuring: discovery → deduplication → information architecture → writing plan → rewrite & review → quality metrics → safe delivery. Each phase in `references/`.
- **TypeScript Ecosystem** — `typescript-strict-mode`, `typescript-project-conventions`, `vitest-testing-patterns`.
- **Additional Skills** — 15 additional skills shipped across this cycle: `micro-harsh-review`, `output-verification`, `progressive-harsh-review`, `evolution-loop`, `failure-autopsy`, `measurement-integrity`, `skill-health-check`, `autonomous-chain-controller`, `quantitative-decision-gate`, `todo-guardian`, `cognitive-complexity-refactoring`, `git-branch-conventions`, `implementation-tracker`.

### Added — CLI Tools

- **sp-help** — Redesigned skill browser with credits, overlay indicators, grouped output by domain. Concise default output with grouped domain sections. Bash 3.2 compatible.
- **sp-doctor** — Symlink-aware launcher. Resolves symlink before locating `doctor-checks.sh`. Check 14 skips git-tracked files.
- **sp-update** — Self-updater with actionable diagnostics on merge failures.

- **Auto-symlink** — All `sp-*` CLI commands auto-symlinked during install.

### Added — Infrastructure

- **MCP v3.0.0** — Semantic skill matching, multi-source directory support, content compression. Rewrote smoke test to use real JSON-RPC protocol. Fixed 8 parser bugs: multiline triggers, bracket handling, apostrophe escaping, YAML-list triggers (10 skills were invisible), description unquoting.
- **lib/frontmatter.js** — Shared YAML frontmatter parser with `parseInlineArray`. Unit tests in `test/frontmatter.test.js`.
- **lib/workflow-state.js** — Expanded workflow state machine.
- **test/integration-test.sh** — New integration test suite.
- **anti_triggers** — Wired into skill router as −2.0 penalty. Propagated to CLI, installer, and MCP parser.

### Added — Shared References

- **Shared Schemas** — 10 new shared reference docs in `skills/_shared/`: confidence calibration, duplicate work detection, evidence schema, fork readiness rubric, incident packet schema, multi-agent activation rubric, multi-agent quality standards, multi-agent result/synthesis/task-packet schemas.

### Changed

- **Marathon Skill Overhaul** — Repo-wide skill quality upgrade program: expanded anti-triggers, clarified failure modes, added companion references to coordinate related skills, normalized tone, and enforced skill quality gates on all existing skills.
- **Workflow Rigor** — Stricter default workflow for code changes. All code changes now default into an output-verification and completion-gate chain before being considered "done".
- **innovation** — v2 → v3 rewrite. Removed 35-point scoring rubric, trimmed triggers 22 → 8, added fallback response table for non-answers.
- **Multi-Agent Skill Upgrades** — `brainstorming` gained ensemble mode (lens mandates, synthesis protocol). `plan-and-execute` gained planning council mode (role mandates, synthesis protocol). `subagent-driven-development` gained parallel dispatch mode (isolation analyzer, integration checkpoint). 9 experiment fixtures in `exercises/multi-agent-skills/`.
- **code-review-battery** — Simplified from separate coordinator file into single `skill.md`. Deleted 5 orphan v1 files (−504 lines). Tightened defect-finder preamble (−28 lines).
- **Namespace rename** — `spc:` prefix renamed to `spo:` (superpowers-overlay) throughout.
- **SPC_SOURCE_DIR** → `SP_OVERLAY_SOURCE_DIR` across all references.
- **Documentation Updates** — Multi-agent initiative master plan, forked debugging design spec, operational PHR program, battery Phase 2f spec, regenerated dependency graph, and updated core guidelines (ARCHITECTURE.md, CONTRIBUTING.md, ENTERPRISE_ADOPTERS_GUIDE.md, UPGRADING.md, README.md).

### Fixed

- **TODO.md protection** — 7-layer defense system: OS-level immutability (`chflags uchg`), chmod 444, shadow backup with annihilation detection, honeypot at default path, path obscuring (removed from `.env`), stray path detection, structural validation. Prevents agent-driven data loss (incident 2026-03-23).
- **Proprietary content scrub** — All proprietary references removed from public repo across 4 passes.
- **Markdownlint audit** — 1,757 violations eliminated across the entire repo.
- **YAML parser hardening** — Single-quote doubled-apostrophe escaping, bracket-multiline handling, state-machine trigger parser propagated to accumulator-based consumers (`superpowers-augment.js`, `mcp/superpowers-mcp.js`, `install-augment-superpowers.sh`). `lib/frontmatter.js` uses inline regex matching and does not support bracket-multiline; see its header for details.
- **DAG generator** — Shared `parseInlineArray` from `lib/frontmatter.js`, CRLF normalization, empty array filtering, scalar unquoting.
- **Smoke test** — Fixed process leak, rewrote to use real JSON-RPC protocol.
- **Install** — `install_cli_commands` arithmetic crash under `set -e`. Arithmetic compatible with Bash 3.2.
- **uninstall.sh** — Must never modify `~/.codex/.env`.
- **Push authorization gate** — Added staging→main promotion guard. Compound-question bundling prohibited (incident 2026-03-29).

### Removed

- **telephony-flow-investigator** — Deleted (proprietary skill, not suitable for public repo). All remnants cleaned.
- **PRD-context-optimization.md** — Superseded by shipped features.

## [2.5.1] - 2026-03-16

### Added

- `--yes`/`-y` flag for non-interactive installs; auto-detects piped stdin (#88)
- Ubuntu installation instructions and dependency install template (#87)
- `skill-authoring` skill for skill synthesis (#83)
- Skill auto-composition engine (RFC-001) (#82)
- `markdown-table-discipline` skill (#81)
- Skill dependency graph with coordination schema and DAG visualization (#73)
- **wiki-verify**: Bulk Operations Protocol — 5-page chunking for multi-page wiki operations (#95)

### Fixed

- **todo-management**: Deterministic default path (`$HOME/.codex/TODO.md`) with hard gate (#90)
- **todo-management**: Migration now cleans personal skills dir (`~/.codex/skills/`) (#92)
- **todo-management**: Migration cleanup + upstream recruiting tags (#91)
- Documentation accuracy audit — 8 corrections (#93)
- Node.js package names on Linux (`node` → `nodejs`), added version check (#89)
- Critical audit findings — wire composition, remove dead code (#86)
- README quality, skill priority disambiguation, repository quality audit (#71-79)
- **perplexity-research**: Replace Augment-specific tool names with platform-agnostic descriptions (#95)

### Changed

- Version sync workflow: plugin files now updated in-PR instead of direct push (#94)
- **install.sh**: Decomposed from 1,163 lines into 380-line orchestrator + 6 modules in `lib/install/` (#97)

## [2.5.0] - 2026-03-15

### Changed

- **BREAKING**: Semantic skill router now defaults to local TF-IDF matching
  - Eliminates OpenAI API dependency for skill discovery
  - Works offline with zero external calls
  - OpenAI embeddings still available as optional enhanced mode when `OPENAI_API_KEY` is set

### Added

- **TF-IDF Engine**: Custom implementation with Porter-style stemming and stop-word filtering
- **Query Expansion**: `CONCEPT_EXPANSIONS` map bridges semantic gaps (e.g., "failing" → "debug")
- **Intent Patterns**: `INTENT_PATTERNS` provide high-confidence routing for domain-specific phrases
- `--tfidf` and `--embedding` flags for `match-skills` command to force specific method

### Fixed

- Prototype pollution bug with `constructor` term causing NaN scores and corrupted sort results
- Trigger boost accumulation (now takes best partial match only, not sum of all matches)

## [2.4.2] - 2026-03-15

### Added

- **innovation**: New superpower for radical, high-impact thinking beyond incremental improvements
  - Triggers: "innovate", "moonshot", "10x improvement", "breakthrough idea", etc.
  - Generates 3-5 ranked transformative ideas across categories (technical, UX, architectural)
  - Integrates with brainstorming (downstream) and think-twice (fallback when stuck)
- **skill-effectiveness**: Tracks skill outcomes and learns trigger improvements
  - New CLI commands: `record-outcome`, `analyze-triggers`, `suggest-trigger`, `record-pattern`, `learning-report`, `learning-status`
  - Persistent state at `~/.codex/.learning-state.json`
  - Bootstrap shows learning insights (low performers, top performers)
- **ADR-001**: Formal taxonomy distinguishing superpowers (auto-triggered) from explicit skills
- `find-skills superpowers` and `find-skills explicit` filter modes in `superpowers-augment.js`
- `EXPLICIT_SKILLS` array in `skill-trigger-validator.sh` for intentionally trigger-less skills

### Changed

- **superpowers-augment.js**: Now extracts `triggers` from frontmatter and categorizes skills
- **superpowers-help**: Updated to distinguish superpowers vs explicit skills in output
- **ARCHITECTURE.md**: Added "Terminology" section documenting the taxonomy
- **CONTRIBUTING.md**: Added guidance on when to use triggers vs explicit skills
- **README.md**: Updated skill counts (38 skills: 30 superpowers + 8 explicit) and added type indicators (🦸/🔧)

## [2.3.0] - 2026-03-12

### Changed

- **superpowers-help**: Complete rewrite with accurate skill enumeration
  - Now lists ALL 55 skills (14 core + 41 extended)
  - Added "what are my superpowers" as primary trigger
  - Added missing Experimental category
  - Fixed incorrect counts (was claiming 54/40, now correctly 55/41)
  - Added Quick Reference section mapping common tasks to skills
  - Organized core skills by workflow phase

## [2.2.0] - 2026-03-12

### Added

- Full end-to-end automated version propagation
  - Version bump in `install.sh` triggers complete automation chain
  - Standalone marketplace auto-updates via `repository_dispatch`

### Fixed

- Marketplace workflow registration (GitHub quirk requiring successful run)
- YAML syntax error in marketplace commit message

## [2.1.2] - 2026-03-12

### Fixed

- `version-sync.yml` now handles "no changes to commit" gracefully

## [2.1.1] - 2026-03-12

### Added

- Automated marketplace version sync (#20)
  - `version-sync.yml` dispatches to `superpowers-plus-marketplace` on release
  - Marketplace repo receives dispatch and updates `marketplace.json`
- `superpowers-help` skill for listing available skills and invocation methods

### Changed

- `install.sh --help` now shows all installation methods (direct, curl, releases)
- README: standalone marketplace is now Option A (recommended)

## [2.1.0] - 2026-03-12

### Added

- Mandatory harsh review enforcement system (#13)
  - Pre-commit hooks (`tools/pre-commit`, `tools/install-hooks.sh`)
  - GitHub Actions CI workflow (`.github/workflows/harsh-review.yml`)
  - PR template with quality checklist
  - `tools/harsh-review.sh` master validation script
  - `.editorconfig` for consistent formatting
- Plugin marketplace distribution support (#10)
  - `.claude-plugin/` for Claude Code marketplace
  - `.cursor-plugin/` for Cursor marketplace
  - `.codex/` for Codex distribution
  - `.opencode/` for OpenCode distribution

### Changed

- Split large skills (>500 lines) into modular files (#14)
  - `detecting-ai-slop`: 1040 → 165 lines (+ examples.md, reference.md)
  - `eliminating-ai-slop`: 774 → 159 lines
  - `wiki-authoring`: 649 → 207 lines
  - `reviewing-ai-text`: 599 → 150 lines
  - `wiki-editing`: 524 → 191 lines
- Moved design docs to `skills/writing/_archive/` (#14)
- Removed duplicate cost-conscious search from AGENTS.md (#14)

### Fixed

- Trailing newline issues in 67+ files (#11, #12)
- Broken URLs in `install-augment-superpowers.sh` (#12)
- Shell script shebangs: `#!/bin/bash` → `#!/usr/bin/env bash` (#13)

## [2.0.0] - 2026-03-10

### Added

- Platform-agnostic skill framework
- Adapter pattern for wiki and issue-tracking skills
- `_adapters/` directories with platform-specific configurations

### Changed

- Removed hardcoded issue-tracker and wiki vendor references from shared skills
- Skills now use generic operations that map to platform adapters

### Fixed

- Static analysis issues across all skills (#7)

## [1.5.0] - 2026-03-05

### Added

- Professional language audit skill (profanity detection) (#6)
- Time estimate inflation detection in slop detection (#3)
- `receiving-code-review` skill (#4)

## [1.4.0] - 2026-03-01

### Added

- Windows PowerShell support (`install.ps1`)
- WSL detection and guidance

### Fixed

- WSL distro detection for Docker Desktop (#5)
- macOS/Linux PowerShell edge cases

## [1.0.0] - 2026-02-15

### Added

- Initial release with 35 skills across 9 domains
- Multi-platform installer (`install.sh`)
- Augment adapter (`superpowers-augment.js`)
- Skill trigger validator

---

## Version History Summary

| Version | Date | Skills | Highlights |
|---------|------|--------|------------|
| 2.6.0 | 2026-03-30 | 86 | Code Review Battery, Forked Debugging, Multi-Agent Skills, Innovation v3, MCP v3, CLI tools |
| 2.5.2 | 2026-03-22 | 61 | Internal milestone prior to multi-agent expansion |
| 2.5.1 | 2026-03-16 | 47 | Non-interactive install, skill-authoring, auto-composition, install.sh modularization |
| 2.4.2 | 2026-03-15 | 49 | Innovation skill, skill-effectiveness, taxonomy |
| 2.3.0 | 2026-03-12 | 41 | superpowers-help rewrite, accurate skill counts |
| 2.2.0 | 2026-03-12 | 41 | Full automation chain, marketplace sync |
| 2.1.0 | 2026-03-12 | 41 | Enforcement system, marketplace support |
| 2.0.0 | 2026-03-10 | 39 | Platform-agnostic refactor |
| 1.5.0 | 2026-03-05 | 37 | Profanity detection, code review |
| 1.4.0 | 2026-03-01 | 35 | Windows/WSL support |
| 1.0.0 | 2026-02-15 | 35 | Initial release |

[Unreleased]: https://github.com/bordenet/superpowers-plus/compare/v2.6.0...HEAD
[2.6.0]: https://github.com/bordenet/superpowers-plus/compare/v2.5.2...v2.6.0
[2.5.1]: https://github.com/bordenet/superpowers-plus/compare/v2.4.2...v2.5.1
[2.4.2]: https://github.com/bordenet/superpowers-plus/compare/v2.3.0...v2.4.2
[2.3.0]: https://github.com/bordenet/superpowers-plus/compare/v2.2.0...v2.3.0
[2.2.0]: https://github.com/bordenet/superpowers-plus/compare/v2.1.2...v2.2.0
[2.1.2]: https://github.com/bordenet/superpowers-plus/compare/v2.1.1...v2.1.2
[2.1.1]: https://github.com/bordenet/superpowers-plus/compare/v2.1.0...v2.1.1
[2.1.0]: https://github.com/bordenet/superpowers-plus/compare/v2.0.0...v2.1.0
[2.0.0]: https://github.com/bordenet/superpowers-plus/compare/v1.5.0...v2.0.0
[1.5.0]: https://github.com/bordenet/superpowers-plus/compare/v1.4.0...v1.5.0
[1.4.0]: https://github.com/bordenet/superpowers-plus/compare/v1.0.0...v1.4.0
[1.0.0]: https://github.com/bordenet/superpowers-plus/releases/tag/v1.0.0
