# superpowers-plus

> **Guidelines:** See [CLAUDE.md](./CLAUDE.md) for writing standards.
> **Last Updated:** 2026-02-01

9 skills extending [obra/superpowers](https://github.com/obra/superpowers) for Claude Code, Augment Code, OpenAI Codex CLI, Gemini, and GitHub Copilot.

## What This Does

Detects AI-generated text (300+ patterns, 13 content types), enforces code style before commits, and provides workflow automation for development tasks. See the [Skills Overview](#skills-overview) for the full list.

## Installation

```bash
# Clone this repo
git clone https://github.com/bordenet/superpowers-plus.git
cd superpowers-plus

# Install obra/superpowers (if not present) and all skills
./install.sh
```

The install script:
- Clones obra/superpowers to `~/.codex/superpowers/` if not already installed
- Installs all skills from this repo to `~/.codex/skills/`
- Validates the installation

Use `./install.sh --verbose` for detailed output or `./install.sh --force` to reinstall superpowers.

### Upgrading

To pull the latest updates from obra/superpowers:

```bash
./upgrade.sh
```

This fetches the latest from obra/superpowers and reinstalls all personal skills. Use `--force` to discard any local changes before upgrading.

## Perplexity MCP Integration

The `perplexity-research` skill enables AI assistants to automatically consult Perplexity when stuck.

### Quick Install (New Machine)

```bash
# 1. Clone this repo
git clone https://github.com/bordenet/superpowers-plus.git
cd superpowers-plus

# 2. Install base superpowers and skills
./install.sh

# 3. Configure Perplexity MCP (requires API key)
./setup/mcp-perplexity.sh

# 4. Install the perplexity-research skill
./setup/install-perplexity-skill.sh

# 5. Verify everything works
./setup/verify-perplexity-setup.sh
```

### Automatic Triggers

The skill auto-invokes when:
- **2+ failed attempts** at the same operation
- **Uncertainty/guessing** at an answer
- **Hallucination risk** (unsure about APIs/facts)
- **Outdated knowledge** (post-training topics)

### Manual Override

Say: "Use Perplexity to research X" or "Get unstuck on X"

### Stats Tracking

Stats are tracked in `~/.codex/perplexity-stats.json`:
```bash
cat ~/.codex/perplexity-stats.json | jq .
```

The skill uses a 4-step evaluation loop:
1. **Report** - Summarize Perplexity response
2. **Apply** - Actually use the information
3. **Evaluate** - Judge if it helped (SUCCESS/PARTIAL/FAILURE)
4. **Track** - Record stats only after evaluation

---

## Skills Overview

| Skill | Purpose |
|-------|---------|
| `detecting-ai-slop` | Analyze text and produce slop score scores (0-100) |
| `eliminating-ai-slop` | Rewrite text to remove slop patterns |
| `enforce-style-guide` | Enforce coding standards before commits |
| `golden-agents` | Initialize or upgrade AI guidance in repos (wraps golden-agents framework) |
| `incorporating-research` | Incorporate external research into docs (strips artifacts, preserves voice) |
| `perplexity-research` | Auto-invoke Perplexity when stuck (2+ failures, uncertainty) |
| `readme-authoring` | Author and maintain README.md files with best practices and anti-slop enforcement |
| `reviewing-ai-text` | *(Deprecated)* Use detecting-ai-slop and eliminating-ai-slop instead |
| `security-upgrade` | CVE scanning and dependency upgrade workflow |

---

For detailed skill documentation including goals, success criteria, failure modes, and invocation patterns, see **[docs/SKILLS.md](docs/SKILLS.md)**.

## Golden Agents Framework

The `guidance/` directory generates Agents.md files for new projects, covering superpowers bootstrap, anti-slop rules, and language-specific guidance (Go, Python, JavaScript, Shell, Dart).

### Quick Start

```bash
# Generate Agents.md for a Go CLI project
./guidance/seed.sh --language=go --type=cli-tools --path=./my-project

# Generate for a Flutter mobile app
./guidance/seed.sh --language=dart-flutter --type=mobile-apps --path=./my-app

# Preview without writing
./guidance/seed.sh --language=javascript --type=web-apps --dry-run
```

### What's Included

| Category | Modules |
|----------|---------|
| **Core** | superpowers bootstrap, communication standards, anti-slop rules |
| **Workflows** | deployment, testing, security, session-resumption, build-hygiene |
| **Languages** | Go, Python, JavaScript, Shell, Dart/Flutter |
| **Project Types** | CLI tools, web apps, genesis tools, mobile apps |

Generated files are self-contained (no external references) and typically 300-800 lines depending on selected options.

See [guidance/README.md](./guidance/README.md) for full documentation.

---

## Cross-Machine Sync

The `slop-sync` script synchronizes your slop dictionary across machines via GitHub:

```bash
# Initialize (first time only)
./slop-sync init

# Upload dictionary after changes
./slop-sync push

# Download latest on another machine
./slop-sync pull

# Check sync status
./slop-sync status
```

Uses Last Write Wins conflict resolution based on timestamps.

## Directory Structure

```
superpowers-plus/
├── Agents.md                       # Primary AI guidance
├── CLAUDE.md                       # Redirect → Agents.md
├── CODEX.md                        # Redirect → Agents.md
├── GEMINI.md                       # Redirect → Agents.md
├── COPILOT.md                      # Redirect → Agents.md
├── README.md                       # This file
├── TODO.md                         # Task tracking
├── LICENSE
├── install.sh                      # Install superpowers and skills
├── upgrade.sh                      # Pull latest from obra/superpowers
├── slop-sync                       # Cross-machine dictionary sync script
├── .gitignore
├── docs/
│   ├── Vision_PRD.md               # High-level vision and requirements
│   ├── PRD_detecting-ai-slop.md    # Detector skill requirements
│   ├── PRD_eliminating-ai-slop.md  # Eliminator skill requirements
│   ├── DESIGN.md                   # Technical design
│   └── TEST_PLAN.md                # Test plan (80+ test cases)
├── guidance/                       # 🆕 Golden Agents Framework
│   ├── Agents.md                   # AI guidance for this directory
│   ├── CLAUDE.md                   # Redirect → Agents.md
│   ├── CODEX.md                    # Redirect → Agents.md
│   ├── GEMINI.md                   # Redirect → Agents.md
│   ├── COPILOT.md                  # Redirect → Agents.md
│   ├── README.md                   # Framework documentation
│   ├── seed.sh                     # Generator script
│   ├── TEMPLATE-minimal.md         # Minimal template (~100 lines)
│   ├── TEMPLATE-full.md            # Full template with placeholders
│   ├── core/                       # Core guidance (always included)
│   ├── workflows/                  # Development workflow guidance
│   ├── languages/                  # Language-specific guidance
│   └── project-types/              # Project type guidance
└── skills/
    ├── detecting-ai-slop/          # Analysis and scoring (300+ patterns)
    │   └── SKILL.md
    ├── eliminating-ai-slop/        # Rewriting and prevention (GVR loop)
    │   └── SKILL.md
    ├── enforce-style-guide/
    │   └── SKILL.md
    ├── golden-agents/              # Initialize/upgrade AI guidance in repos
    │   └── SKILL.md
    ├── incorporating-research/     # Incorporate external research (strips artifacts)
    │   └── SKILL.md
    ├── perplexity-research/        # Auto-invoke Perplexity when stuck
    │   └── SKILL.md
    ├── readme-authoring/           # README.md best practices + anti-slop
    │   └── SKILL.md
    ├── security-upgrade/           # CVE scanning and upgrades
    │   └── SKILL.md
    └── reviewing-ai-text/          # Deprecated
        └── SKILL.md
```

## Creating New Skills

1. Create a new directory under `skills/`
2. Add `SKILL.md` with frontmatter (name, description)
3. Run `./install.sh` to deploy
4. Test with `~/.codex/superpowers/.codex/superpowers-codex use-skill <skill-name>`

See [superpowers:writing-skills](https://github.com/obra/superpowers) for skill authoring guidelines.

## Documentation

| Document | Purpose |
|----------|---------|
| [SKILLS.md](./docs/SKILLS.md) | Skill goals, success criteria, failure modes |
| [Vision_PRD.md](./docs/Vision_PRD.md) | High-level vision and requirements |
| [PRD_detecting-ai-slop.md](./docs/PRD_detecting-ai-slop.md) | Detector requirements (13 content types) |
| [PRD_eliminating-ai-slop.md](./docs/PRD_eliminating-ai-slop.md) | Eliminator requirements (11 rewriting strategies) |
| [DESIGN.md](./docs/DESIGN.md) | Technical architecture |
| [TEST_PLAN.md](./docs/TEST_PLAN.md) | Test plan (80+ test cases) |

## Author

Matt J Bordenet (@bordenet)
