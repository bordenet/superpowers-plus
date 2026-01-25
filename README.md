# superpowers-plus

> **Guidelines:** See [CLAUDE.md](./CLAUDE.md) for writing standards.
> **Last Updated:** 2026-01-25

Personal skills extending [obra/superpowers](https://github.com/obra/superpowers) for Claude Code, Augment Code, and Codex.

## Overview

This repository contains custom AI coding assistant skills that build on the superpowers framework. These personal skills extend the core superpowers with domain-specific capabilities for AI slop detection, resume screening, and code quality enforcement.

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

## Skills

| Skill | Purpose |
|-------|---------|
| `detecting-ai-slop` | Analyze text and produce bullshit factor scores (0-100) |
| `eliminating-ai-slop` | Rewrite text to remove slop patterns |
| `enforce-style-guide` | Enforce coding standards before commits |
| `resume-screening` | Screen Senior SDE candidates against hiring criteria |
| `phone-screen-prep` | Prepare phone screen notes with targeted questions |
| `reviewing-ai-text` | *(Deprecated)* Use detecting-ai-slop and eliminating-ai-slop instead |

### detecting-ai-slop

Analyzes text and produces a bullshit factor score (0-100) with detailed breakdown. Supports 13 content types with type-specific pattern detection.

**Supported content types:** Document, Email, LinkedIn, SMS, Teams/Slack, CLAUDE.md, README, PRD, Design Doc, Test Plan, CV/Resume, Cover Letter

**Invoke:** "What's the bullshit factor on this [content type]?"

### eliminating-ai-slop

Rewrites text to eliminate detected slop patterns using the **Generate-Verify-Refine (GVR) loop**. Operates in two modes:
- **Interactive:** User provides text, skill proposes changes with confirmation
- **Automatic:** Skill prevents slop during content generation (GVR loop, max 3 iterations)

**Features:**
- GVR loop with stylometric threshold checking (sentence σ, TTR, hapax rate)
- User calibration with personal writing samples
- Immediate rescan after adding patterns
- Cross-machine dictionary sync via `slop-sync`

**Invoke:**
- Interactive: "Clean up this email: [text]"
- Automatic: "Write an email to the team about [topic]"
- Calibrate: "Calibrate slop detection with my writing"

### enforce-style-guide

Enforces coding standards before any commit. Checks shebang, error handling, help flags, verbose flags, dry-run flags, line limits, ShellCheck, and syntax.

**Invoke:** Before ANY commit to ANY repository.

### resume-screening

Screens Senior SDE candidates against CallBox hiring criteria. Evaluates experience, stack fit, scale, leadership, contractor patterns, and salary alignment. **Integrates with detecting-ai-slop** for AI-generated resume detection.

**Invoke:**
- "Screen at $[X]k cap" + paste resume
- "What's the bullshit factor on this resume?" (slop analysis)

### phone-screen-prep

Creates phone screen notes files with targeted questions based on screening concerns. **Adds AI slop probing questions** when bullshit factor >50.

**Invoke:** "Prep phone screen for [Name]"

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
├── CLAUDE.md                       # AI agent guidelines and anti-slop rules
├── TODO.md                         # Task tracking
├── README.md                       # This file
├── LICENSE
├── install.sh                      # Install superpowers and skills
├── slop-sync                       # Cross-machine dictionary sync script
├── .gitignore
├── docs/
│   ├── Vision_PRD.md               # High-level vision and requirements
│   ├── PRD_detecting-ai-slop.md    # Detector skill requirements
│   ├── PRD_eliminating-ai-slop.md  # Eliminator skill requirements
│   ├── DESIGN.md                   # Technical design
│   └── TEST_PLAN.md                # Test plan (80+ test cases)
└── skills/
    ├── detecting-ai-slop/          # Analysis and scoring (300+ patterns)
    │   └── SKILL.md
    ├── eliminating-ai-slop/        # Rewriting and prevention (GVR loop)
    │   └── SKILL.md
    ├── enforce-style-guide/
    │   └── SKILL.md
    ├── resume-screening/           # Integrates with detecting-ai-slop
    │   ├── SKILL.md
    │   └── README.md
    ├── phone-screen-prep/          # Adds AI slop probing questions
    │   ├── SKILL.md
    │   └── README.md
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
| [Vision_PRD.md](./docs/Vision_PRD.md) | High-level vision and requirements |
| [PRD_detecting-ai-slop.md](./docs/PRD_detecting-ai-slop.md) | Detector requirements (13 content types) |
| [PRD_eliminating-ai-slop.md](./docs/PRD_eliminating-ai-slop.md) | Eliminator requirements (11 rewriting strategies) |
| [DESIGN.md](./docs/DESIGN.md) | Technical architecture |
| [TEST_PLAN.md](./docs/TEST_PLAN.md) | Test plan (80+ test cases) |

## Author

Matt J Bordenet (@bordenet)
