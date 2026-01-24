# superpowers-plus

Personal skills extending [obra/superpowers](https://github.com/obra/superpowers) for Augment Code.

## Overview

This repository contains custom Claude/Augment skills that build on the superpowers framework. These are personal skills that extend the core superpowers with domain-specific capabilities.

## Prerequisites

- [Superpowers](https://github.com/obra/superpowers) installed via `install-augment-superpowers.sh`
- Augment Code or Claude Code with superpowers enabled

## Installation

```bash
# Clone this repo
git clone https://github.com/bordenet/superpowers-plus.git
cd superpowers-plus

# Install skills to ~/.codex/skills/
./install.sh
```

Or install superpowers from scratch:

```bash
./install-augment-superpowers.sh
./install.sh
```

## Skills

| Skill | Description |
|-------|-------------|
| `reviewing-ai-text` | Detect and eliminate AI slop patterns in text |
| `enforce-style-guide` | Ruthlessly enforce coding standards before commits |
| `resume-screening` | Screen Senior SDE candidates against hiring criteria |
| `phone-screen-prep` | Prepare phone screen notes with targeted questions |

### reviewing-ai-text

Detects and eliminates AI slop: the telltale patterns of machine-like writing including overused boosters, formulaic structure, excessive hedging, and hollow specificity.

**Invoke:** When reviewing AI-generated text or self-auditing responses.

### enforce-style-guide

Ruthlessly enforces coding standards before any commit. Checks shebang, error handling, help flags, verbose flags, dry-run flags, line limits, ShellCheck, and syntax.

**Invoke:** Before ANY commit to ANY repository.

### resume-screening

Screens Senior SDE candidates against rigorous hiring criteria. Evaluates experience, stack fit, scale, leadership, and salary alignment.

**Invoke:** "Screen at $[X]k cap" + paste resume

### phone-screen-prep

Creates phone screen notes files with targeted questions based on screening concerns.

**Invoke:** "Prep phone screen for [Name]"

## Directory Structure

```
superpowers-plus/
├── README.md
├── LICENSE
├── install.sh                      # Install skills to ~/.codex/skills/
├── install-augment-superpowers.sh  # Full superpowers installation
└── skills/
    ├── reviewing-ai-text/
    │   └── SKILL.md
    ├── enforce-style-guide/
    │   └── SKILL.md
    ├── resume-screening/
    │   ├── SKILL.md
    │   └── README.md
    └── phone-screen-prep/
        ├── SKILL.md
        └── README.md
```

## Creating New Skills

1. Create a new directory under `skills/`
2. Add `SKILL.md` with frontmatter (name, description)
3. Run `./install.sh` to deploy
4. Test with `node ~/.codex/superpowers-augment/superpowers-augment.js use-skill <skill-name>`

See [superpowers:writing-skills](https://github.com/obra/superpowers) for skill authoring guidelines.

## Author

Matt J Bordenet (@bordenet)
