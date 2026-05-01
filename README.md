# superpowers-plus

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

Skills for AI coding assistants that enforce the practices AI would otherwise skip. Extends [obra/superpowers](https://github.com/obra/superpowers). Can be used for non-coding workloads, too!

## Platform Support

| Platform | Status |
|----------|--------|
| **Claude Code** | ✅ Full support — skills, lifecycle hooks (SessionStart, PreCompact, PreToolUse), commit gates, pre-push hooks, and red-autonomy guardrails all install and run cleanly. |
| **Augment Code** | ✅ Full support — skills, routing, commit gates, pre-push hooks, and MCP integrations install and run cleanly. |

## What This Is

AI coding assistants skip the practices that catch bugs before production: they implement the first idea without evaluating alternatives and claim "done" without verification.

Skills are structured procedures that AI agents follow automatically. [obra/superpowers](https://github.com/obra/superpowers) is a framework for teaching AI agents reusable procedures. superpowers-plus adds skills across 9 domains. Start debugging and `systematic-debugging` enforces root-cause investigation before fixes. Commit code and a gate chain blocks the commit until lint, type checks, and security scans pass.

Each skill exists because it caught a real problem.

## Standout Skills

| Skill | What it does |
|-------|-------------|
| [**code-review-battery**](skills/engineering/code-review-battery/skill.md) | Dispatches 5 specialist reviewers in parallel (Defect Finder, Design Critic, Guardian, Standards Enforcer, Performance Analyst) instead of one shallow pass. Slash command: `/sp-cr-battery [min-score]` (optional 1.0–10.0 quality threshold, default 7.0). |
| [**debate**](skills/engineering/debate/skill.md) | Generates 3+ decision options, builds a comparison matrix, then red-teams the winner. Requires adversarial review before committing to an approach. |
| [**progressive-harsh-review**](skills/engineering/progressive-harsh-review/skill.md) | Three escalating critic personas score non-code deliverables (plans, docs, designs) on 5 dimensions. Score below 6 = rejected. |
| [**systematic-debugging**](skills/engineering/systematic-debugging/skill.md) | Enforces root-cause-first investigation: reproduce, hypothesize, isolate, fix. No fixes without completing Phase 1. |
| [**feature-development**](skills/engineering/feature-development/skill.md) | Full lifecycle orchestrator: brainstorm, debate, plan, TDD, review, verify. |
| [**think-twice**](skills/productivity/think-twice/skill.md) | Detects when the AI is stuck in a loop and dispatches a fresh sub-agent with zero shared context. Auto-triggers on circular reasoning. |
| [**detecting-ai-slop**](skills/writing/detecting-ai-slop/skill.md) | Scores text 0-100 for machine-generated patterns across lexical, structural, semantic, and stylometric dimensions. |
| [**wiki-orchestrator**](skills/wiki/wiki-orchestrator/skill.md) | Pipeline for bulk documentation: de-dup, content, coherence, links, secrets, slop detection, fact-check, publish. |
| [**evolution-loop**](skills/observability/evolution-loop/skill.md) | Self-improvement cycle: scans failures for recurring patterns, generates skill updates, tracks metrics over time. |
| [**unified-commit-gate**](skills/engineering/unified-commit-gate/skill.md) | Runs all 5 commit gates in sequence (lint/build/test → style → code review → language → IP audit). Slash command: `/sp-commit`. Deep-dive into any gate via its individual skill. |

## Quick Start

Install ([details below](#installation)):

```bash
git clone https://github.com/bordenet/superpowers-plus.git && cd superpowers-plus && bash install.sh
```

Enable pre-commit gates: `bash tools/install-hooks.sh`

These hooks are required if you want the full commit-gate chain to run locally before `git commit` and `git push`.

Then tell your AI assistant what you're doing:

| You say... | Skill triggered |
|------------|-----------------|
| "Debug this test failure" | `systematic-debugging` enforces root cause before fixes |
| "Build a new feature for X" | `feature-development` orchestrates the full lifecycle |
| "Review this code" or `/sp-cr-battery [min-score]` | `code-review-battery` dispatches 5 parallel reviewers (optional 1.0–10.0 quality threshold, default 7.0) |
| "I keep getting the same error" | `think-twice` dispatches a fresh sub-agent with zero shared context |
| "Check for security issues" | `repo-security-scan` scans secrets, deps, patterns, config |
| "I'm about to commit" | `unified-commit-gate` runs all 5 quality gates before the commit |

**CLI matching** (for debugging): `node ~/.codex/superpowers-augment/superpowers-augment.js match-skills "my tests keep failing"`

## What's Included

**89 skills** across 9 domains:

| Domain | Examples |
|--------|----------|
| **engineering** | Code review battery, debate, TDD, progressive review, systematic debugging, feature lifecycle |
| **productivity** | TODO tracking (see [task tagging taxonomy](skills/productivity/todo-management/references/taxonomy.md)), plan-and-execute, think-twice, adversarial search, domain design |
| **writing** | AI slop detection/elimination, professional-language-audit, table discipline, writing-skills authoring |
| **wiki** | Orchestrator pipeline, link verification, credential scanning, fact-checking |
| **observability** | Completeness checks, evolution loop, audit validation, diagnostics |
| **issue-tracking** | Authoring, editing, verification, link checks, comment debunking |
| **security** | Repo scanning, CVE scanning, IP protection, instruction guard |
| **research** | Perplexity integration, research incorporation, expert interviewing |
| **experimental** | Self-prompting patterns |

**Full skill reference:** [docs/SKILLS.md](docs/SKILLS.md)

## Installation

**Prerequisites:** bash 4+, git, Node.js 18+. npm is only required for the optional MCP server below.

> **macOS note:** macOS ships bash 3.2 (frozen at GPLv2 since 2007). Install modern bash first: `brew install bash`. The installer will detect the old version and tell you exactly how to fix it.

### Choose Your Path

- **Most users:** core install below (`git clone` + `bash install.sh`)
- **Augment Agent only:** one-liner bootstrap for Ubuntu / Debian / WSL
- **Claude Code:** use `install.sh` for complete setup, or `/plugin install` if `obra/superpowers` is already installed
- **Codex / OpenCode / Gemini CLI:** use the platform-specific instructions below
- **Claude Desktop or another MCP client:** do the core install first, then add the optional MCP server

### macOS / Linux / WSL

```bash
git clone https://github.com/bordenet/superpowers-plus.git
cd superpowers-plus
bash install.sh      # use 'bash' explicitly — macOS default shell is zsh; ./install.sh may pick the wrong interpreter
```

The installer:

- Detects wrong shell (sh, zsh, dash) and tells you to use bash
- Detects old bash (3.2) with platform-specific install instructions
- Checks for missing commands (git, node) with remediation steps
- Auto-detects your platform and offers to install missing dependencies
- Auto-fixes Windows CRLF line endings if detected

**Windows/WSL:** Run `wsl --install -d Ubuntu` first, then use the commands above from within WSL. If you cloned superpowers-plus on Windows *before* running the installer, repair line endings with: `bash tools/harsh-review.sh --fix`

**Linux containers (Docker/CI):** Works as root without sudo. The installer detects the environment automatically.

### Augment Agent (One-Liner: Ubuntu / Debian / WSL)

```bash
curl -fsSL https://raw.githubusercontent.com/bordenet/superpowers-plus/main/install-augment-superpowers.sh | bash
```

> **Security note:** Review the script before piping: `curl -fsSL <url> | less` — then re-run with `| bash` once satisfied.

Installs obra/superpowers + the Augment adapter. Does **not** install the full skill suite; use git clone above for that.

### Claude Code

```bash
/plugin install https://github.com/bordenet/superpowers-plus
```

Requires `obra/superpowers` to already be installed. For a complete setup that installs both, use the core `install.sh` path above.

### Codex

```text
Fetch and follow instructions from https://raw.githubusercontent.com/bordenet/superpowers-plus/main/.codex/INSTALL.md
```

### OpenCode

```text
Fetch and follow instructions from https://raw.githubusercontent.com/bordenet/superpowers-plus/main/.opencode/INSTALL.md
```

### Gemini CLI

```bash
gemini extensions install https://github.com/obra/superpowers
gemini extensions install https://github.com/bordenet/superpowers-plus
```

### MCP Server (Optional)

After completing the core install above, you can optionally expose the installed skills over MCP.

Use this only if your client supports MCP and you want `superpowers-plus` skills exposed as MCP tools: `find_skills`, `use_skill`, and `match_skills`.

If you're using the install paths above without an MCP client, you can skip this section.

**Do I need this?**

- **No** — if you're using the CLI or one of the install methods above (git clone + bash)
- **Yes** — if you're using Claude Desktop or another MCP-compatible client and want the skills available as MCP tools
- **Yes** — if you're using Claude Code plugin and want skills exposed as tools (not just rules)

**Requires:** Node.js 18+. Verify: `node --version` (npm is bundled with Node.js — no separate install needed)

> **Security scope:** The MCP server binds to localhost only and exposes no authentication (see `mcp/superpowers-mcp.js` — search for `listen` to verify the bind address). Use it for local single-user development; do not expose the node process to network interfaces in shared or server environments.

1. `cd mcp && npm install` — review `mcp/package-lock.json` for unexpected transitive dependencies before running in sensitive environments
2. Add this to your MCP client configuration. Example for Claude (`~/.claude/settings.json`). Replace `/absolute/path/to/superpowers-plus` with the absolute path from `pwd` in your checkout (no trailing slash, no `~/` shorthand — use the full path):

   ```json
   {
     "mcpServers": {
       "superpowers-plus": {
         "command": "node",
         "args": ["/absolute/path/to/superpowers-plus/mcp/superpowers-mcp.js"]
       }
     }
   }
   ```

3. Restart your client. Verify: run `find_skills` in the MCP client — expected output lists ~89 available skill names.

If `find_skills` returns an error or is missing: check `node --version` (must be 18+), rerun `cd mcp && npm install`, and confirm the args path is absolute (not `~/` or relative).

### Using as a Dependency

See [docs/examples/adopter-install-example.sh](docs/examples/adopter-install-example.sh) for a robust install script template.

### Updating

```bash
bash install.sh --upgrade
```

### Verify Installation

After running `install.sh`, confirm skills loaded successfully:

```bash
node ~/.codex/superpowers-augment/superpowers-augment.js find-skills
# Expected: skill catalog printed without errors (superpowers-plus contributes 89 skills)
```

Run the full 29-check diagnostic:

```bash
bash tools/doctor-checks.sh
# Expected: "All 29 checks passed" (0 critical, 0 errors)
```

If skills aren't loading, see [Troubleshooting](#troubleshooting).

## Configuration

Copy `.env.example` to `~/.codex/.env` for runtime integrations, then set permissions: `chmod 600 ~/.codex/.env`. All variables are optional unless noted. Invalid values for adapter keys cause runtime errors when those features are invoked; check `skills/issue-tracking/_adapters/` and `skills/wiki/_adapters/` for the list of valid values. If `~/.codex/.env` does not exist when a skill tries to read it, the skill will emit a `source: no such file` error — run `bash tools/todo-preflight.sh --create-if-missing` to initialize it.

| Variable | Required? | Purpose |
|----------|-----------|---------|
| `ISSUE_TRACKER_TYPE` | Optional | Adapter key; shipped adapters: `github`, `jira`; see `skills/issue-tracking/_adapters/platform-template.md` for others |
| `WIKI_PLATFORM` | Optional | Adapter key; see `skills/wiki/_adapters/platform-template.md` to add yours |
| `TODO_FILE_PATH` | Optional | Path to your persistent TODO.md file; used by `todo-crud.sh` and all todo-management tools |
| `PERPLEXITY_API_KEY` | Optional | Enables deep research escalation (~$0.01/query); a stuck agent can trigger many queries — monitor spend and disable in shared environments |
| `THINK_TWICE_USE_PERPLEXITY` | Optional | `false` by default; set `true` to let think-twice escalate to Perplexity when stuck |
| `OPENAI_API_KEY` | Optional | Enables embedding-based skill matching; TF-IDF runs without it (free but slower) |

## Skill Coordination

Skills form pipelines with explicit dependencies. Each pipeline has its own dedicated diagram in [docs/SKILL_TAXONOMY.md](docs/SKILL_TAXONOMY.md):

| Pipeline | Diagram | Purpose |
|----------|---------|---------|
| Commit Gates | [Commit Gate Chain](docs/SKILL_TAXONOMY.md#commit-gate-chain) | `/sp-commit` → 5 sequential gates before `git commit` |
| Completion Gate | [Completion Gate](docs/SKILL_TAXONOMY.md#completion-gate) | output-verification or exhaustive-audit → verification-before-completion |
| Wiki Pipeline | [Wiki Pipeline](docs/SKILL_TAXONOMY.md#wiki-pipeline) | 7-stage quality chain → publish → post-publish drift check |
| Debug Flow | [Debug Flow](docs/SKILL_TAXONOMY.md#debug-flow) | debug-conductor → systematic-debugging + 6 internal sub-agents |
| Code Review Chain | [Code Review Chain](docs/SKILL_TAXONOMY.md#code-review-chain) | requesting → battery → receiving → respond |
| Full Dependency Graph | [skill-dependency-graph.md](docs/skill-dependency-graph.md) | All 89 skills with typed edges (enables / escalates-to) |

For how triggers fire, how skill names are resolved, how compression works, and the scoring algorithm behind `match-skills`, see **[docs/DESIGN.md](docs/DESIGN.md)**.

### Quality Gates Policy

The commit-gate chain (`unified-commit-gate` → pre-commit → style → code review → language → IP audit) runs automatically on every `git commit` when hooks are installed. The IP audit blocks commits containing proprietary identifiers, internal hostnames, or credentials. If a push is blocked, run `bash tools/public-repo-ip-check.sh` to see exactly what matched; if it's a false positive, add an exception pattern to `.ip-patterns`.

**`git commit --no-verify` exists but bypassing gates is prohibited.** If a gate is genuinely broken, fix the gate — don't disable it. Changes to `skills/` additionally require a passing `code-review-battery` sentinel before the commit hook allows the commit. The sentinel format is `v1|SHA|VERDICT|TIMESTAMP|min-score=N`; write it only via `tools/run-battery.sh [--min-score N] --verdict PASS`. The primary slash command is `/sp-cr-battery`.

**Skill priority when installed and git-cloned versions coexist:** The agent runtime loads skills from `~/.codex/skills/` (installed copy). If you are developing new skills in the git clone, run `bash install.sh --upgrade` to sync the installed copy, or point `SUPERPOWERS_SKILLS_DIR` to the git checkout for live reloading (see `docs/ARCHITECTURE.md`). If `SUPERPOWERS_SKILLS_DIR` points to a nonexistent or incomplete directory the runtime falls back to `~/.codex/skills/`; verify with `node ~/.codex/superpowers-augment/superpowers-augment.js find-skills` after setting the variable.

> **Token budget:** A wiki-orchestrator pipeline (de-dup → content → coherence → links → secrets → slop → fact-check → publish) typically costs 30–50k tokens per edit. Run `bash tools/skill-cost-analyzer.sh` before scheduling bulk changes to estimate impact.

> **Compression:** Skills are compressed before injection via `lib/compress.js` (20–40% token reduction). Boilerplate sections (`When to Use`, `Examples`, etc.) are stripped. Operative content — `<EXTREMELY_IMPORTANT>` blocks, `Failure Modes`, `Incident Log`, `References`, `Hallucination Prevention` — is preserved unconditionally. Add `compress: false` to a skill's YAML frontmatter to opt out. See `docs/ARCHITECTURE.md § Skill Content Compression` for details.

## Extending

```text
obra/superpowers (framework)
    └── superpowers-plus (this repo)
            └── your-org-skills (private)
```

**Solo developers:** Core skills — `systematic-debugging`, `code-review-battery`, `feature-development`, `think-twice`, `verification-before-completion` — work fully offline with just git and GitHub. No external integrations required.

**Enterprise teams:** `superpowers-plus` is a public foundation. Skills become significantly more powerful when you build a private enterprise repo that overlays, extends, and overloads it with organization-specific integrations:

| Layer | Examples |
|-------|---------|
| **Issue tracking** | Jira, Linear, Azure DevOps work items, GitHub Issues |
| **Version control** | Azure DevOps Repos, GitLab, GitHub |
| **Meeting intelligence** | Fathom, Otter.ai, your enterprise meeting recorder |
| **Knowledge bases** | Confluence, MediaWiki, Outline Wiki |

Private skills can shadow or extend public ones: route `todo-management` tasks to Jira instead of a local file, add company-specific rules to `code-review-battery`, or wire `wiki-orchestrator` directly to your Confluence instance. Give agents MCP server access to these systems and they gain context from your entire stack automatically — issue history, meeting transcripts, internal docs, and your team's conventions all become first-class inputs.

**Enterprise overlay security checklist:**
- Store API keys in `~/.codex/.env` — never hardcode them in skills
- Private skills that call external systems should log API activity for audit trails
- Review private MCP servers before deployment (supply chain risk)
- `PERPLEXITY_API_KEY` and `OPENAI_API_KEY` send context to external APIs — evaluate data classification before enabling in sensitive workflows

See [Enterprise Adopters Guide](docs/ENTERPRISE_ADOPTERS_GUIDE.md).

## Tools

Utility scripts in `tools/`:

| Tool | Purpose |
|------|---------|
| `run-battery.sh` | Runs the automated quality suite (harsh-review, trigger tests, export integrity, skill router tests); writes the `.code-review-cleared` sentinel. Accepts `--verdict PASS\|PASS_WITH_NITS` and optional `--min-score N` (1.0–10.0, default 7.0). |
| `commit-gate.sh` | Runs lint/test/harsh-review and mints a short-lived review token consumed by the pre-commit hook. |
| `doctor-checks.sh` | 29-check diagnostic across all installed skills |
| `harsh-review.sh` | Enforces file endings, shebangs, syntax, ShellCheck |
| `harsh-review-loop.sh` | Iterative harsh review until clean |
| `dangerous-pattern-scan.sh` | Pre-commit scanner for `rm -rf`, `chmod 777`, `curl\|bash` |
| `install-hooks.sh` | Installs git hooks (pre-commit, pre-push) |
| `todo-preflight.sh` | Resolves `TODO_FILE_PATH` from `~/.codex/.env` |
| `todo-lock.sh` | Advisory file locking for TODO.md (cross-machine) |
| `todo-crud.sh` | TODO.md create/read/update/delete operations |
| `todo-maintenance.sh` | Archival and cleanup of completed tasks |
| `investigation-crud.sh` | Investigation state CRUD (hypotheses, evidence, verdicts) |
| `public-repo-ip-check.sh` | Scans for proprietary content before public push |
| `skill-trigger-validator.sh` | Audits trigger overlaps and missing triggers |
| `skill-cost-analyzer.sh` | Reports token cost per skill |
| `generate-skill-dag.js` | Generates skill dependency graph (Mermaid) |
| `skill-metrics-analyzer.sh` | Analyzes skill usage metrics |
| `parse-frontmatter.sh` | Extracts YAML frontmatter from skill files |

## Troubleshooting

| Problem | Fix |
|---------|-----|
| `bash 3.2 is too old` | macOS Apple Silicon: `brew install bash`, then `/opt/homebrew/bin/bash install.sh`. Intel Mac: `/usr/local/bin/bash install.sh` |
| `This script requires bash` | You ran with sh or zsh. Use: `bash install.sh` |
| `Missing required commands: git` | macOS: `xcode-select --install`. Linux: `sudo apt install git` |
| `Missing required commands: node` | macOS: `brew install node`. Linux: `sudo apt install nodejs` |
| Install partially failed | Run `bash install.sh --verbose` to see which step failed; then `bash tools/doctor-checks.sh` for full diagnosis. Re-running `bash install.sh` is safe — it skips already-completed steps. |
| `.env missing / source error` | Run `bash tools/todo-preflight.sh --create-if-missing` to initialize `~/.codex/.env` from `.env.example`. Then `chmod 600 ~/.codex/.env`. |
| Perplexity tools not found | Verify `PERPLEXITY_API_KEY` in `~/.codex/.env`, then run `bash setup/mcp-perplexity.sh` |
| Issue tracking fails | Set `ISSUE_TRACKER_TYPE` in `.env`; verify adapter exists in `skills/issue-tracking/_adapters/` |
| Wiki operations fail | Set `WIKI_PLATFORM` in `.env`; verify adapter exists in `skills/wiki/_adapters/` |
| Push blocked by IP audit | Run `bash tools/public-repo-ip-check.sh` to see what matched; if a false positive, add an exception pattern to `.ip-patterns` |
| CRLF errors on WSL | Cloned on Windows before running installer: `bash tools/harsh-review.sh --fix` |
| Skills not loading | Run `bash tools/doctor-checks.sh` to diagnose; then `bash install.sh --upgrade` if checks fail |
| Stale skill count | `bash install.sh --upgrade`; verify with `node ... find-skills` — catalog should print without errors |
| TODO lock timeout | Another agent holds the lock; `todo-lock.sh steal` |
| Doctor reports drift | `bash tools/doctor-checks.sh --fix-safe` |

## Documentation

[Architecture](docs/ARCHITECTURE.md) · [Full Skill Reference](docs/SKILLS.md) · [Task Tagging Taxonomy](skills/productivity/todo-management/references/taxonomy.md) · [Enterprise Adopters](docs/ENTERPRISE_ADOPTERS_GUIDE.md) · [Contributing](docs/CONTRIBUTING.md) · [Upgrading](UPGRADING.md) · [Changelog](CHANGELOG.md)

## License

MIT
