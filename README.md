# superpowers-plus

[![Tests](https://github.com/bordenet/superpowers-plus/actions/workflows/test.yml/badge.svg?branch=main)](https://github.com/bordenet/superpowers-plus/actions/workflows/test.yml)
[![Release](https://img.shields.io/github/v/release/bordenet/superpowers-plus)](https://github.com/bordenet/superpowers-plus/releases)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

AI coding assistants skip the practices that keep bugs out of production. They implement the first idea without weighing alternatives, patch symptoms instead of finding root causes, and declare work done without verifying it. Asking them to behave better in a system prompt doesn't hold: under context pressure, the instructions get forgotten.

superpowers-plus is 125 skills that make an assistant follow those practices, plus the machinery that enforces them from outside the model. Skills give the assistant a procedure: reproduce before fixing, generate three designs before picking one, send a diff to parallel specialist reviewers. Lifecycle hooks and git commit gates check the result. Git runs those gates whether or not the assistant remembers to ask for review.

It builds on Jesse Vincent's [obra/superpowers](https://github.com/obra/superpowers). Superpowers teaches an agent how to work; superpowers-plus adds more skills and the hooks and gates that make the work hard to skip. It also covers non-coding work: documents, wikis, issue tracking, research.

## Quick Start

Requires bash 4+, git, and Node.js 18+. macOS ships bash 3.2, so run `brew install bash` first.

```bash
git clone https://github.com/bordenet/superpowers-plus.git && cd superpowers-plus
bash install.sh                 # skills, hooks, and runtime
bash tools/install-hooks.sh     # git commit and push gates
```

Then tell your assistant what you're doing:

| You say... | What happens |
|------------|--------------|
| "Debug this test failure" | `systematic-debugging` requires a root cause before any fix |
| "Build a new feature for X" | `feature-development` runs brainstorm, debate, plan, TDD, review, verify |
| "Review this code" or `/sp-cr-battery` | `code-review-battery` starts with one combined reviewer and dispatches up to 7 parallel reviewers when the diff calls for specialists |
| "I keep getting the same error" | `think-twice` hands the problem to a fresh sub-agent with no shared context |
| "Check for security issues" | `repo-security-scan` covers secrets, dependencies, risky patterns, and config |
| "I'm about to commit" | `unified-commit-gate` runs lint/build/test, style, review, language, and IP audit |

Full install options (Claude Code plugin, Codex, OpenCode, MCP server, Windows, WSL) are in [docs/INSTALLATION.md](docs/INSTALLATION.md).

### Windows (native, no WSL)

Superpowers runs its hooks and helper scripts with bash. On Windows that bash is Git Bash (part of Git for Windows), the same shell Claude Code uses on Windows. Requires Windows PowerShell 5.1 or PowerShell 7 and winget. In PowerShell:

```powershell
git clone https://github.com/bordenet/superpowers-plus.git $HOME\superpowers-plus
cd $HOME\superpowers-plus
powershell -ExecutionPolicy Bypass -File .\install.ps1
```

`install.ps1`:

1. Installs missing Python 3 (`Python.Python.3.12`) and jq (`jqlang.jq`) with winget. If Git for Windows (`Git.Git`) or Node.js LTS (`OpenJS.NodeJS.LTS`) is missing, it stops and prints the `winget install` command to run from an elevated PowerShell. No git yet? Install it that way, or download the repo ZIP from GitHub, extract it, and run `install.ps1` from the extracted `superpowers-plus-main` folder once Git and Node.js are installed.
2. Writes `python3` and `python3.cmd` shims to `~\.local\bin` (Python on Windows ships only `python.exe`) and puts `~\.local\bin` first on your user `PATH`.
3. Sets the user environment variables `CLAUDE_CODE_GIT_BASH_PATH` (where Claude Code finds Git Bash) and `PYTHONUTF8=1`.
4. Runs `install.sh` under Git Bash. You get the same install as on macOS and Linux: skills, Claude Code hooks, git commit and push gates, tools, rules, and templates.

Open a new terminal afterwards so the `PATH` and environment changes take effect, then restart your AI tool.

| Option | Effect |
|--------|--------|
| `-Categories engineering,writing` | Install only those top-level `skills/` folders |
| `-SkipAugment` | Install to `~\.claude\skills` only. Skips `~\.codex\skills`, `~\.agents\skills` (also read by Codex), the Augment adapter, and Augment rules |
| `-Force` | Overwrite a different superpowers ecosystem recorded in `~\.codex\.superpowers-ecosystem`. Only bypasses that check; it does not pass `install.sh --force`, so local commits and untracked files in `~\.codex\superpowers-plus` are left alone. To also reset that checkout to `origin/main`, run `install.sh --force` yourself |
| `-Uninstall` | Run `uninstall.sh` under Git Bash and remove the `python3` shims and `sp-*` wrappers in `~\.local\bin`. Installs nothing. Leaves the `~\.local\bin` PATH entry, `CLAUDE_CODE_GIT_BASH_PATH`, `PYTHONUTF8`, and winget packages in place |
| `-NoPrereqInstall` | Don't run winget; stop if something is missing |

Run `install.ps1` from a normal PowerShell; it refuses to run elevated, because it executes scripts from a checkout a non-admin can modify. Git for Windows and Node.js install machine-wide, so if either is missing the script stops and prints the `winget install` command to run from an elevated PowerShell first. Existing `CLAUDE_CODE_GIT_BASH_PATH` and `PYTHONUTF8` values are kept (with a warning) unless unset or pointing at a path that no longer exists. Python must be 3.8+ and Node.js 18+.

Earlier versions of `install.ps1` were a WSL wrapper. It now installs natively into your Windows profile.

If WSL is also installed, `bash` typed in PowerShell or CMD starts WSL, not Git Bash, because `C:\Windows\System32\bash.exe` comes first on the system `PATH`. To open Git Bash, use Git Bash from the Start menu or run `& $env:CLAUDE_CODE_GIT_BASH_PATH`. Claude Code is not affected because it uses `CLAUDE_CODE_GIT_BASH_PATH`. On macOS and Linux, `install.ps1` runs `bash install.sh` with the same options.

## Claude Desktop

The Claude Desktop app has three tabs. `bash install.sh` sets up the Code tab and builds the skill ZIPs for Chat and Cowork, which you upload once.

| Tab | What you get | Extra steps |
|-----|--------------|-------------|
| **Code** | Everything Claude Code gets: all 125 skills, lifecycle hooks, and approval guardrails | None beyond the [Quick Start](#quick-start). The Code tab runs the same engine as the Claude Code CLI and reads the same `~/.claude/` skills, hooks, and settings |
| **Chat** and **Cowork** | Eleven of the skills, the ones whose core steps work without a shell or this repo: brainstorming, debate, plan writing, AI slop detection and rewriting, and others | Upload the ZIPs that `install.sh` builds (below) |
| **Chat** (optional) | Read access to all 125 skills through the `find_skills`, `use_skill`, and `match_skills` tools | Add the [MCP server](docs/INSTALLATION.md#mcp-server-optional) to `claude_desktop_config.json`. Skills that run repo scripts or depend on hooks won't fully work in Chat |

**Code tab.** Local sessions load `~/.claude/skills/` and the hooks in `~/.claude/settings.json`, so they behave the same as Claude Code in a terminal. The git commit and push gates run in any repo where `tools/install-hooks.sh` has installed them, whichever app made the commit. Cloud sessions don't read `~/.claude/`, and an SSH session reads the remote machine's copy, so run `install.sh` there too.

**Chat and Cowork.** These tabs load skills from your claude.ai account instead of `~/.claude/skills/`. claude.ai has no upload API, so uploading is the one manual step:

1. Run `bash install.sh` (or `bash tools/package-for-claude.sh` on its own). It writes one ZIP per skill to `~/superpowers-plus-claude-desktop/`.
2. In the Desktop app, open **Customize** in the sidebar (or go to [claude.ai/customize/skills](https://claude.ai/customize/skills)) and upload each `.zip`.
3. Turn each skill on.

The packager applies claude.ai's upload rules for you. It names the file `SKILL.md`, includes each skill's reference files, and keeps only the six frontmatter fields claude.ai accepts, because any other field makes the upload fail. It also adds a note telling Claude to skip any step that needs this repo's scripts, since Chat and Cowork don't have a copy of the repo. After `bash install.sh --upgrade`, the output names the ZIPs that changed. Upload only those again, replacing the older copies in Customize.

Uploaded skills follow your claude.ai account into Chat, Cowork, cloud sessions, and Claude Code sessions signed in with that account. On a machine where `install.sh` already put the same skills in `~/.claude/skills/`, Claude Code loads both copies. It uses the local one and keeps the uploaded one as `/anthropic-skills:<name>`, and both take up context and compete for the same prompts. If you mostly work in the Code tab, leave the uploaded copies off.

The other skills aren't packaged because their main steps call other skills, run scripts from this repo, or depend on hooks and git gates. The list is in [`tools/claude-desktop-skills.json`](tools/claude-desktop-skills.json).

## What Changes

```text
"This test started failing after yesterday's change. Fix it."

Without:  edit code -> test passes -> "Done."
With:     reproduce -> find the root cause -> test hypotheses -> isolate
          -> smallest fix -> verify -> review the diff -> commit gates
```

## Enforcement Outside the Model

Most skill libraries are prompt text. If the model drops the instruction, nothing notices. superpowers-plus puts the checks where the model can't skip them:

- **Git hooks** run the commit gate chain on every `git commit` and `git push`. Changes to `skills/` need a passing code-review sentinel tied to the reviewed content before the commit goes through.
- **Claude Code lifecycle hooks** (including SessionStart, UserPromptSubmit, PreCompact, and PreToolUse) route prompts to skills, save a resume prompt before context compaction, block pushes and branch deletions until a human approves them in the session, and stop commits made under the wrong git identity.
- **CI** repeats the IP scan on the PR title and body, because a squash merge builds its commit message from those fields, not from any local commit.

## The AI-Harness: Instruction Context as a Budget

Every skill an agent loads stays in its context window and is re-sent on every model call. superpowers-plus treats that context as a budgeted resource and runs a closed loop over it:

| Stage | Artifact | Role |
|-------|----------|------|
| **Sensor** | [`tools/skill-size-audit.sh`](tools/skill-size-audit.sh) | Ranks every `skill.md` by size and fails when one exceeds the fleet threshold |
| **Actuator** | [`kernel-split`](skills/engineering/kernel-split/skill.md) | Splits a large skill into a small always-loaded kernel and an on-demand reference |
| **Regulator** | [`artifact-budgets`](docs/harness/artifact-budgets.md) | Byte budgets against a committed baseline, so a skill that shrank today can't quietly regrow |

Measured results so far, from the [reduction ledger](docs/harness/reduction-history.md):

| Skill | Before | Kernel after | Reduction |
|-------|-------:|-------------:|----------:|
| progressive-harsh-review | 18,018 B | 8,493 B | 52% |
| debate | 13,660 B | 7,703 B | 43% |
| context-ferry | 10,688 B | 7,122 B | 33% (below the 40% target; safety rules kept resident) |

One rule outranks the byte savings: hard gates and "never" rules always stay in the kernel. That rule is enforced by review, not assumed: review caught all three of these splits moving or deleting safety content (anti-rubber-stamping rules, a required search step, a write-back procedure), and each was restored. Design: [docs/harness/README.md](docs/harness/README.md).

## Standout Skills

| Skill | What it does |
|-------|--------------|
| [**code-review-battery**](skills/engineering/code-review-battery/skill.md) | Starts with one combined reviewer (defects, guardrails, standards) and dispatches up to 7 specialist reviewers in parallel when the diff signals design, performance, security, or shell risk. A bug-path verifier joins in bug-fix mode. Configurable quality bar |
| [**debate**](skills/engineering/debate/skill.md) | Three or more options, a comparison matrix, then a red-team pass on the winner before committing to a design |
| [**systematic-debugging**](skills/engineering/systematic-debugging/skill.md) | Reproduce, hypothesize, isolate, fix. No fix until the investigation is complete |
| [**feature-development**](skills/engineering/feature-development/skill.md) | The full lifecycle as one orchestrated sequence, so no phase gets skipped |
| [**llm-skill-review**](skills/engineering/llm-skill-review/skill.md) | Reviews skills as infrastructure that models execute: determinism, shell portability, tool contracts, cross-agent behavior |
| [**context-ferry**](skills/productivity/context-ferry/skill.md) | Writes a self-contained resume prompt before context compaction, so long sessions keep their state |
| [**detecting-ai-slop**](skills/writing/detecting-ai-slop/skill.md) | Scores text 0-100 for machine-generated patterns across lexical, structural, semantic, and stylometric signals |
| [**evolution-loop**](skills/observability/evolution-loop/skill.md) | Scans failures for recurring patterns and proposes skill updates |

All 125 skills: [docs/SKILLS.md](docs/SKILLS.md). How they connect: [docs/SKILL_TAXONOMY.md](docs/SKILL_TAXONOMY.md).

## Platform Support

| Platform | Support |
|----------|---------|
| **Claude Code** | Full: skills, lifecycle hooks, commit and push gates, approval guardrails |
| **Augment Code** | Full: skills, routing, commit and push gates, MCP integrations |
| **Codex, OpenCode** | Skills, via the [platform install guides](docs/INSTALLATION.md). Git gates work with any assistant because git runs them; Claude Code lifecycle hooks do not apply |
| **Windows** | Full install through [`install.ps1`](#windows-native-no-wsl), which runs `install.sh` under Git Bash. WSL also works |
| **Gemini CLI** | No installer. `GEMINI.md` points Gemini at the repo's agent guidance |
| **Claude Desktop** | Code tab: same as Claude Code. Chat and Cowork: eleven uploadable skills. Chat can also reach all skills through the MCP server. See [Claude Desktop](#claude-desktop) |
| **Other MCP clients** | Skills exposed as `find_skills`, `use_skill`, and `match_skills` tools |

## What's Included

| Domain | Examples |
|--------|----------|
| **engineering** | Code review battery, debate, TDD, systematic debugging, feature lifecycle, commit gates |
| **productivity** | Task tracking, plan-and-execute, think-twice, adversarial search, context-ferry |
| **writing** | AI slop detection and rewriting, professional-language audit, table discipline, plain-language explanations |
| **wiki** | Publishing pipeline with link verification, credential scanning, and fact-checking |
| **observability** | Completeness checks, evolution loop, audit validation, diagnostics |
| **issue-tracking** | Authoring, editing, verification, link checks |
| **security** | Repo scanning, CVE scanning, IP protection, instruction guard |
| **research** | Research integration, expert interviewing |
| **experimental** | Self-prompting patterns |

## Building on It

```text
obra/superpowers (Jesse Vincent, MIT)
    └── superpowers-plus (this repo)
            └── your-org-skills (private overlay)
```

All 14 obra/superpowers skills are bundled here, nine of them hardened with extra enforcement gates; upstream changes are merged periodically. Teams can add a private repo on top that shadows or extends these skills with their own issue tracker, wiki, and conventions. See the [Enterprise Adopters Guide](docs/ENTERPRISE_ADOPTERS_GUIDE.md), including its security checklist for overlays.

## Documentation

| Topic | Where |
|-------|-------|
| Install, configure, troubleshoot | [docs/INSTALLATION.md](docs/INSTALLATION.md) |
| Tools and quality-gate policy | [docs/TOOLS.md](docs/TOOLS.md) |
| Architecture and design | [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md), [docs/DESIGN.md](docs/DESIGN.md) |
| AI-Harness | [docs/harness/README.md](docs/harness/README.md) |
| Skill reference | [docs/SKILLS.md](docs/SKILLS.md) |
| Writing a new skill | [docs/CONTRIBUTING.md](docs/CONTRIBUTING.md) |
| Upstream sync and PR gates | [CONTRIBUTING.md](CONTRIBUTING.md) |
| Upgrading, changes, security | [UPGRADING.md](UPGRADING.md), [CHANGELOG.md](CHANGELOG.md), [SECURITY.md](SECURITY.md) |

## License

MIT
