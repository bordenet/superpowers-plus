# Changelog

All notable changes to superpowers-plus are documented here.

superpowers-plus extends [obra/superpowers](https://github.com/obra/superpowers) by Jesse Vincent.

Format based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

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
