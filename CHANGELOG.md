# Changelog

All notable changes to superpowers-plus are documented here.

superpowers-plus extends [obra/superpowers](https://github.com/obra/superpowers) by Jesse Vincent.

Format based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
Versioning follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- **Forked Debugging Orchestration (PREVIEW)** — conductor-led parallel investigation for complex distributed system incidents:
  - `debug-conductor`: Orchestrates parallel investigator branches with fork-readiness rubric and operator checkpoint
  - `evidence-adjudicator`: Synthesizes branch evidence into ranked root-cause verdicts with adversarial disconfirmation pass (Step 5b)
  - 6 domain-specific investigators: timeline-trace, llm-behavior, telephony-flow, state-consistency, infra-config, reproduction-experiment
  - Shared contracts: `evidence-schema.md` (killed-branch support), `fork-readiness-rubric.md`, `confidence-calibration.md`
  - Experiment harness: `exercises/forked-debugging/run-experiment.sh` with input validation and run isolation
- **wiki-refactor** skill — 7-phase wiki restructuring pipeline with discovery, dedup, IA, rewrite, review, delivery, and drift detection

### Changed

- **Multi-agent activation threshold**: score = 5 is now borderline (asks user); score ≥ 6 auto-activates. Previously ≥ 5 auto-activated. Updated in shared rubric, brainstorming, plan-and-execute, subagent-driven-development, and all strategy docs.
- **Silence policy**: All multi-agent systems now default to conservative (stay serial) when the operator doesn't respond, instead of auto-approving.
- **`writing-plans` → `plan-and-execute`**: Renamed across all active skill files, shared standards, cross-references, and docs. Design documents retain historical name.
- **`harsh-review.sh`**: Fixed file discovery — default mode was using `find -name` with regex patterns (silently found 0 files). Now uses `find | grep -E`. Also: `--changed-only` mode dynamically resolves diff base (tracking branch → origin/dev → origin/main).
- **`skill-metrics-analyzer.sh`**: Implemented real `--json` output; requires `SUPERPOWERS_DIR` (no longer defaults to `./`); rejects unknown flags.
- **`migrate.sh`**: Worktree detection uses `-e` instead of `-d` for `.git` (supports git worktrees where `.git` is a file).
- **Evidence schema examples**: Aligned all investigator examples with canonical schema (removed non-schema fields: `source` in timeline, `timestampA`/`timestampB` in state, config-shaped records in infra `deployments`, `impactAssessment` → `impact` in LLM).
- **Conductor delegation boundary**: All "synthesize" actions now explicitly dispatch `evidence-adjudicator`. Phase 6 writes `adjudication`, `budget`, `nextSteps` to incident packet. Adjudicator-failure row added to failure table.

### Fixed

- **7 autonomy skills** (65→72 total) — Quantitative decision-making, failure analysis, metric validation, TODO enforcement, workflow orchestration, self-improvement, and per-batch code review:
  - **quantitative-decision-gate**: Decision matrix with 4 weighted dimensions before any user question. Auto-selects when margin >10%.
  - **failure-autopsy**: 5-Why post-mortem protocol for wrong approaches and misdiagnosed limitations.
  - **measurement-integrity**: Cross-validation enforcement before reporting any metric or percentage.
  - **todo-guardian**: Continuous TODO enforcement — stale detection, completion gate, session-end sweep.
  - **autonomous-chain-controller**: Meta-orchestrator that auto-detects and executes multi-skill chains with quality gates.
  - **evolution-loop**: Self-improvement cycle — scans failure patterns, generates skill updates.
  - **micro-harsh-review**: 3-critic adversarial review (Nitpick, ArchSoundness, ProdBattleTest) for per-batch code changes.
- **40 new intent patterns** in skill-router.js for all 7 autonomy skills
- **21 bidirectional back-references** across existing skills (think-twice, brainstorming, plan-and-execute, etc.)
- **10 deep integration refs** in existing skills (feature-development, TDD, completeness-check, etc.)
- **6 new routing regression tests** in test_trigger_routing.sh (now 15/15)

### Changed

- **design-triad: completion gate** — Added hard gate after Step 2 (Compare) to prevent agents from stopping at a recommendation without completing Steps 3-5 (Harsh Review, Edge Cases, Iterate). This was the single most common failure mode observed in practice.
- **design-triad: trigger discoverability** — Added 2 validated trigger phrases (`design options with adversarial review`, `generate options compare and red team`) that reliably route to design-triad as top match via embedding-mode match-skills. Removed 5 candidate phrases that routed to wrong skills.
- **design-triad: rationalization table** — Added "I produced a recommendation" as an explicit rationalization to reject.
- **design-triad: preflight anti-stall** — Replaced narrative-style preflight with a 3-path routing decision (known/investigate/low-stakes) and a 30-second time-box. The previous preflight told agents to "complete requirements-validation and engineering-rigor first" which caused infinite regress — agents loaded those skills without executing them and stalled before Step 1.

### Fixed

- **Installer cross-platform hardening** — 14 bug classes fixed across 6 installer files (#234)
  - CRLF self-heal: recursive scan of all `.sh` files, `perl` primary + `tr` fallback with permission preservation
  - `.env` subshell isolation: prevents `.env` from mutating installer shell state (`set -e`, `PATH`, `IFS`)
  - `_sudo_prefix()`: handles root (no sudo needed), sudo with TTY, `sudo -n` headless, no-sudo-available
  - Git worktree support: `-e .git` instead of `-d .git` throughout; `_is_git_repo()` validates HEAD
  - `git reset --hard` guarded: requires `--force` flag to prevent silent data loss
  - `sed -i` portability: cross-platform BSD/GNU detection + metacharacter escaping
  - Node version check: enforces v18+ not just presence
  - Trailing newline ensured before appending to `.env` files
  - Target matrix: stock macOS (Bash 3.2), Linux containers (root/no-sudo), WSL-Ubuntu, headless CI, git worktrees
- **Cross-platform portability pass 2** — `echo -e` → `printf`, `xxd` removed, `date` portability (#236)
- **Defensive driving guards** across all 40 shell scripts (#237)
  - Shell guard: detect `/bin/sh`, `dash`, `zsh` with fix instructions
  - Bash version gate: rich box-drawing error with `brew install bash` / `apt install bash`
  - Early prerequisite check: git + node checked before sourcing modules
  - Source guard: lib modules detect direct execution and tell you to run `install.sh`
- **Documentation audit** — purged ghost skill references (`wiki-editing`/`wiki-authoring` → `wiki-orchestrator`), fixed `.codex/INSTALL.md` and `.opencode/INSTALL.md` install mechanisms, updated plugin metadata to 58 skills / v2.5.2 (#238)

### Added

- `skills/productivity/plan-and-execute/` — General-purpose orchestrator: challenge → plan → stress-test → phased TODO execution with structured retrospectives and continuous improvement between phases (#257)
- **superpowers-doctor** expanded to 22 checks with 4 new environment-health checks (#217)
  - Check 19: Stale managed checkout detection (behind `origin/main`), safe auto-fix via `--fix-safe`
  - Check 20: Dirty managed checkout detection (user vs generated artifacts), moderate auto-fix via `--fix`
  - Check 21: TODO archive fixture-based smoke test (catches small-TODO regression)
  - Check 22: Reviewer-dispatch rendering verification (detects stale code-reviewer patterns)
  - Cross-platform: portable `timeout` fallback, `git stash save` fallback for git < 2.13, graceful skip when `python3`/`node` absent
  - 8 new regression tests in `tools/tests/test_doctor_checks.sh`

- **Feature Development Engine** — 4-phase workflow for pre-code validation (#182)
  - `skills/engineering/design-triad/` — Enforces 3+ design options with comparison matrix and harsh review
  - `skills/engineering/requirements-validation/` — Tests requirements for falsifiability, detects contradictions
  - `skills/productivity/fallback-planning/` — Generates contingency TODOs from identified risks
- `skills/security/wiki-instruction-guard/` — Blocks prompt injection in wiki content (#104)
- `skills/productivity/adversarial-search/` — Defeats confirmation bias in analysis (#107)
- `skills/productivity/thinking-orchestrator/` — Hub router for metacognition skills (#110)
- `skills/wiki/wiki-content-coherence/` — Detects duplication and structural defects (#127)
- `skills/security/repo-security-scan/` — Full repo security scan across 4 categories (#132)
- `skills/productivity/todo-archive/` — Archive completed tasks from TODO.md to monthly satellite files (#133)
- `tools/dangerous-pattern-scan.sh` — Pre-commit scanner for `rm -rf`, `chmod 777`, `curl|bash` (#123)
- `tools/todo-lock.sh` — Advisory file locking for TODO.md with cross-machine support (#120)
- `tools/todo-preflight.sh` — Single-command TODO.md path resolution and validation (#117)
- `tools/skill-cost-analyzer.sh` — Token cost analysis for skill loading (#159)
- One-time high-cost skill warning on first load (#160)
- `spp:` and `spo:` namespace prefixes for cross-repo skill resolution (#151)
- `sp-`/`spp-`/`spo-` dash shorthands for fewer keystrokes (#152)
- `superpowers-doctor` expanded to 18 checks with `--fix` mode and graduated fix tiers (#141, #145, #146, #169)
- WSL compatibility handling in installer (#163)
- Depth Challenge Gate for rigorous analysis requests (#112)
- Bootstrap-first discipline enforcement in `use-skill` (#130)
- Batch operations workflow in wiki-orchestrator (#129)
- wiki-debunker Source Authority Matrix for source-laundered attributions (#138)

### Changed

- `engineering-rigor` — Added Architecture Testing section (#182)
- `todo-management` — Added Context-Aware TODO Standard with length limits (#182)
- `adversarial-search` — Triggers deduplicated (orchestrator owns shared triggers); IP/Redaction hard gate added (#182)
- `think-twice` — Reclassified from explicit to auto-triggered; triggers narrowed to 4 unique phrases (#182)
- `thinking-orchestrator` — Dropped 25+ generic triggers to reduce token overhead from misfires (#182)
- `harsh-review.sh` — Added CHECK 8b: fails if any skill.md exceeds 250 lines (#182)
- `public-repo-ip-check.sh` — Prints file paths only by default; `--verbose` opt-in; loads `.ip-check-patterns`; history audit reclassified as advisory (#182)
- `skill-trigger-validator.sh` — Pipeline guards for `set -euo pipefail`; temp file cleanup fix (#182)
- `public-repo-ip-audit` skill — History audit reclassified from mandatory gate to advisory diagnostic (#182)
- 9 oversized skills split to ≤250 lines with `references/` directories (#143)
- Efficiency optimization across 6 skills — net −794 lines (#162)
- README overhauled: updated counts, reduced length 18%, eliminated duplication (#158)
- 5 generic engineering skills restored from orphan cleanup (#105)
- Vestigial `~/.augment/skills/` deployment path removed (#106)

### Fixed

- Security scrub: removed all proprietary references from public repo (#154)
- Ghost command and dead URL removed from superpowers-help (#155, #156)
- Doctor: overlay awareness, subshell counter bugs, false positive reduction (#147, #166–#170)
- Doctor: resolved 82 trigger collision warnings (#168)
- Cross-platform hardening + `--help` for all standalone scripts (#165)
- POSIX-compatible CRLF detection — dropped `grep -P` (#164)
- Shell compatibility fixes: SC2064, SC2155, SC2162, SC2038 (#125, #137, #161)
- TODO.md data loss prevention with safety gate and section-survival validation (#135, #136)
- todo-lock.sh: `rm -rf` safeguards, `$PPID` for PID tracking, cross-platform hardening (#121, #122)
- todo-management: HARD GATE rewritten to use preflight script (#117)
- pre-commit-gate: added Step 0 dangerous pattern scan (#123)
- Stale skill count references corrected across all distribution files

### Removed

- `lib/learning-state.js` — skill metrics tracking (zero organic data produced) (#113)
- `tools/skill-fire-logger.sh` — shell fire logging wrapper (#113)
- `skills/observability/skill-firing-tracker/` — fire tracking skill (#113)
- `skills/observability/skill-effectiveness/` — outcome tracking skill (#113)
- 12 metrics CLI commands from `superpowers-augment.js` (#113)
- MANDATORY Skill Outcome Tracking from bootstrap rule (#113)
- Net skill count: 47 (added 5 new skills, removed 2 metric skills)

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
| 2.5.1 | 2026-03-16 | 47 | Non-interactive install, skill-authoring, auto-composition, install.sh modularization |
| 2.4.2 | 2026-03-15 | 49 | Innovation skill, skill-effectiveness, taxonomy |
| 2.3.0 | 2026-03-12 | 41 | superpowers-help rewrite, accurate skill counts |
| 2.2.0 | 2026-03-12 | 41 | Full automation chain, marketplace sync |
| 2.1.0 | 2026-03-12 | 41 | Enforcement system, marketplace support |
| 2.0.0 | 2026-03-10 | 39 | Platform-agnostic refactor |
| 1.5.0 | 2026-03-05 | 37 | Profanity detection, code review |
| 1.4.0 | 2026-03-01 | 35 | Windows/WSL support |
| 1.0.0 | 2026-02-15 | 35 | Initial release |

[Unreleased]: https://github.com/bordenet/superpowers-plus/compare/v2.5.1...HEAD
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
