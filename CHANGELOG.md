# Changelog

All notable changes to superpowers-plus are documented here.

superpowers-plus extends [obra/superpowers](https://github.com/obra/superpowers) by Jesse Vincent.

Format based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
Versioning follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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
- Removed hardcoded vendor references (Linear, Outline, Azure DevOps)
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
| 2.1.0 | 2026-03-12 | 39 | Enforcement system, marketplace support |
| 2.0.0 | 2026-03-10 | 39 | Platform-agnostic refactor |
| 1.5.0 | 2026-03-05 | 37 | Profanity detection, code review |
| 1.4.0 | 2026-03-01 | 35 | Windows/WSL support |
| 1.0.0 | 2026-02-15 | 35 | Initial release |

[Unreleased]: https://github.com/bordenet/superpowers-plus/compare/v2.1.0...HEAD
[2.1.0]: https://github.com/bordenet/superpowers-plus/compare/v2.0.0...v2.1.0
[2.0.0]: https://github.com/bordenet/superpowers-plus/compare/v1.5.0...v2.0.0
[1.5.0]: https://github.com/bordenet/superpowers-plus/compare/v1.4.0...v1.5.0
[1.4.0]: https://github.com/bordenet/superpowers-plus/compare/v1.0.0...v1.4.0
[1.0.0]: https://github.com/bordenet/superpowers-plus/releases/tag/v1.0.0
