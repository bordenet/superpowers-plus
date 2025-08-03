# superpowers-plus

Skills extending [obra/superpowers](https://github.com/obra/superpowers) for Claude, Augment, and other AI coding assistants.

## Quick Start

**Prerequisite:** Install [obra/superpowers](https://github.com/obra/superpowers) first — this repo extends it.

**macOS / Linux / WSL Terminal:**
```bash
git clone https://github.com/bordenet/superpowers-plus.git
cd superpowers-plus
./install.sh
```

**Windows PowerShell:**
```powershell
git clone https://github.com/bordenet/superpowers-plus.git
cd superpowers-plus
.\install.ps1
```
> ⚠️ **Windows users:** Run `.\install.ps1` (not `.\install.sh`). The PowerShell wrapper handles WSL detection and setup.

Skills install to `~/.codex/skills/` and `~/.augment/skills/`. Verify:

```bash
node ~/.codex/superpowers-augment/superpowers-augment.js find-skills
```

## Augment.ai Clients

**Any Augment client works.** Choose what fits your workflow:

| Client | Installation |
|--------|--------------|
| **Auggie CLI** (terminal-first) | `npm install -g @augmentcode/auggie && auggie login` |
| **VS Code Extension** | Extensions → search "Augment" → Install → SSO |
| **Rider/JetBrains Plugin** | Settings → Plugins → "Augment" → Install |
| **Cursor Extension** | Extensions → search "Augment" → Install |

All paths lead to the same superpowers. The install.sh deploys skills to standard paths that all clients read.

## Platform Support

| Platform | Status | Notes |
|----------|--------|-------|
| macOS (Intel) | ✅ Supported | Homebrew for dependencies |
| macOS (Apple Silicon) | ✅ Supported | Homebrew for dependencies |
| Linux (Debian/Ubuntu) | ✅ Supported | apt-get for dependencies |
| Linux (RHEL/Fedora/CentOS) | ✅ Supported | dnf/yum for dependencies |
| Linux (Arch) | ✅ Supported | pacman for dependencies |
| Windows (WSL) | ✅ Supported | Same as underlying Linux distro |
| Windows (native) | ❌ Not supported | Use WSL |

**Prerequisites:**
- `git` — installed automatically if missing (prompts for confirmation)
- [obra/superpowers](https://github.com/obra/superpowers) — install first

## Getting Started

After installation, add this bootstrap command to your project's `AGENTS.md`:

```bash
node ~/.codex/superpowers-augment/superpowers-augment.js bootstrap
```

This loads the skill system at conversation start. See [obra/superpowers](https://github.com/obra/superpowers) for details.

## Configuration

Copy `.env.example` to `.env` and fill in API keys for optional integrations:

```bash
cp .env.example .env
```

| Variable | Required For | Get From |
|----------|--------------|----------|
| `ISSUE_TRACKER_TYPE` | issue-tracking/* | Set to: `linear`, `github`, `jira`, or `azure-devops` |
| `PERPLEXITY_API_KEY` | perplexity-research | https://www.perplexity.ai/settings/api |
| `WIKI_PLATFORM` | wiki/* | Set to: `outline` (more coming). See `skills/wiki/_adapters/` |

For Perplexity MCP setup: `./setup/mcp-perplexity.sh`

## Skills by Domain

| Domain | Skills | Description |
|--------|--------|-------------|
| **writing/** | 4 | Detect and eliminate AI slop, README authoring |
| **typescript/** | 5 | Strict mode, complexity refactoring, Vitest patterns |
| **issue-tracking/** | 5 | Issue authoring/editing/verification (Linear, GitHub, Jira, ADO adapters) |
| **wiki/** | 7 | Wiki editing, authoring, verification, debunking |
| **engineering/** | 4 | Engineering rigor, pre-commit gates, blast radius checks, code review |
| **observability/** | 4 | Skill firing tracker, audit validation, completeness checks |
| **productivity/** | 4 | TODO management, think-twice, golden-agents, style enforcement |
| **research/** | 2 | Perplexity integration, incorporating external research |
| **security/** | 1 | CVE scanning and dependency upgrades |
| **experimental/** | 1 | Self-prompting (not production-ready) |

## Skill Reference

### writing/
- `detecting-ai-slop` — Score text for AI patterns (0-100), 300+ patterns across 13 content types
- `eliminating-ai-slop` — Rewrite AI-like text using Generate-Verify-Refine loop
- `readme-authoring` — Structure READMEs for <5 minute onboarding
- `reviewing-ai-text` — (Deprecated) Use detecting/eliminating-ai-slop instead

### typescript/
- `typescript-strict-mode` — Enforce strict TypeScript, eliminate `any` and `!`
- `cognitive-complexity-refactoring` — Reduce Biome complexity scores
- `vitest-testing-patterns` — SDK mocking, constructor patterns for Vitest
- `typescript-project-conventions` — Import organization, file structure
- `field-rename-verification` — Cross-file field rename validation

### issue-tracking/
- `issue-authoring` — Write issues with [acceptance criteria](https://bordenet.github.io/docforge-ai/assistant/?type=acceptance-criteria), labels, estimates
- `issue-editing` — Update existing issues safely
- `issue-verify` — Validate issue links and references
- `issue-link-verification` — Check URLs in issue content
- `issue-comment-debunker` — Verify claims before posting comments

Requires `ISSUE_TRACKER_TYPE` in `.env`. See `skills/issue-tracking/_adapters/` for platform setup.

### wiki/
- `wiki-orchestrator` — Route wiki tasks to appropriate skills
- `wiki-editing` — Safe wiki updates with backup
- `wiki-authoring` — Create new wiki pages
- `wiki-verify` — Validate wiki links and structure
- `wiki-debunker` — Fact-check wiki content
- `wiki-secret-audit` — Scan for leaked credentials
- `link-verification` — Validate internal/external URLs

Requires `WIKI_PLATFORM` in `.env`. See `skills/wiki/_adapters/` for platform setup.

### observability/
- `skill-firing-tracker` — Log skill invocations for analysis
- `exhaustive-audit-validation` — Validate audit checklists
- `holistic-repo-verification` — Check all CI workflows, not just main
- `completeness-check` — Verify work is actually complete

### productivity/
- `think-twice` — Spawn a sub-agent to review your approach when blocked
- `todo-management` — Parse and track TODO items
- `golden-agents` — Initialize self-managing AGENTS.md via [golden-agents](https://github.com/bordenet/golden-agents)
- `enforce-style-guide` — Validate code against repo style guides

### research/
- `perplexity-research` — Auto-invoke Perplexity when stuck (requires MCP setup)
- `incorporating-research` — Integrate external research into documents

### security/
- `security-upgrade` — Scan for CVEs, upgrade dependencies one at a time

### engineering/
- `engineering-rigor` — Hub skill for engineering rigor philosophy and cross-references
- `pre-commit-gate` — Run lint → typecheck → test locally before every commit
- `blast-radius-check` — Search for ALL usages before modifying existing code
- `providing-code-review` — Apply engineering rigor when reviewing others' PRs

### experimental/
- `experimental-self-prompting` — Write context-free prompts for fresh perspective (not production-ready)

## Upgrading

```bash
./install.sh --upgrade --verbose
```

See [UPGRADING.md](./UPGRADING.md) for details.

## Trigger Validation

Skills include machine-readable `triggers:` arrays for automated auditing:

```yaml
---
name: link-verification
source: superpowers-plus
triggers: ["verify links", "check URL", "add code reference"]
description: Use when adding URLs to documentation...
---
```

Run the trigger validator to audit your skill registry:

```bash
# Full audit (overlaps, missing triggers, registry summary)
./tools/skill-trigger-validator.sh audit

# Check for trigger collisions only
./tools/skill-trigger-validator.sh overlaps

# Generate skill → trigger mapping
./tools/skill-trigger-validator.sh registry
```

### Downstream Overrides

When extending superpowers-plus, downstream skills can declare their override relationship:

```yaml
---
name: link-verification
source: your-org-repo
overrides: superpowers-plus/link-verification
triggers: [...]
---
```

This enables tooling to audit which version is active at runtime.

## Architecture

See [docs/ARCHITECTURE.md](./docs/ARCHITECTURE.md) for how skills work and how to extend them.

## Contributing

See [docs/CONTRIBUTING.md](./docs/CONTRIBUTING.md) for how to add new skills.

## Troubleshooting

| Error | Cause | Fix |
|-------|-------|-----|
| "Tool not found: perplexity_*" | Perplexity MCP not configured | Run `./setup/mcp-perplexity.sh` |
| "Tool not found: linear_*" | Linear MCP not configured | Configure Linear MCP server |
| Issue tracking skills fail | Missing env var | Set `ISSUE_TRACKER_TYPE` in `.env` |
| Wiki skills fail | Wiki API not configured | Set `WIKI_PLATFORM` in `.env`, see `skills/wiki/_adapters/` |

## Extending for Enterprise

> 📖 **Comprehensive Guide:** See [Enterprise Adopters Guide](docs/ENTERPRISE_ADOPTERS_GUIDE.md) for detailed patterns including override, adapter, fork, and rules patterns.

superpowers-plus is designed as a **base layer** that organizations can extend with their own skills.

### Layered Architecture

Built on top of [obra/superpowers](https://github.com/obra/superpowers):

```
obra/superpowers (framework)
    └── superpowers-plus (generic skills - this repo)
            └── your-org-skills (org-specific skills)
```

### How to Extend

1. **Fork or create a separate repo** for organization-specific skills
2. **Install superpowers-plus first** as the base layer (installs to `~/.codex/skills/`)
3. **Install your org skills second** to `~/.codex/superpowers/skills/` — this path takes precedence, so org skills override matching base skill names

### Example: Enterprise Extension

```bash
# Step 1: Install base layer
cd ~/superpowers-plus && ./install.sh

# Step 2: Install org-specific layer (installs to ~/.codex/superpowers/skills/)
cd ~/my-org-skills && ./install.sh
```

Your org's skills can:
- **Override** generic skills with customized versions (same name, different behavior)
- **Add** org-specific skills that don't exist in superpowers-plus
- **Reference** shared modules from superpowers-plus

### What Belongs Where

| superpowers-plus | Your Org Repo |
|------------------|---------------|
| Generic issue tracking (`issue-*`) | Platform-specific (`linear-*`, `jira-*`) |
| Generic wiki editing | Org wiki URLs and workflows |
| TypeScript patterns | Org coding conventions |
| Research skills | Org-specific integrations |

## License

MIT
