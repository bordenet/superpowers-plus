# Golden Agents Framework

> **Purpose**: Portable, modular AI guidance distilled from all Agents.md files across the workspace.
> **Goal**: Seed new projects with comprehensive AI guidance without context window bloat.

## Quick Start

Generate a project-specific Agents.md:

```bash
# JavaScript web app
./seed.sh --language=javascript --type=web-apps --path=./my-project

# Go CLI tool
./seed.sh --language=go,shell --type=cli-tools --path=./my-cli

# Flutter mobile app
./seed.sh --language=dart-flutter --type=mobile-apps --path=./my-app

# Preview without writing
./seed.sh --language=python --type=genesis-tools --dry-run
```

## Structure

```
guidance/
├── README.md                    # This file
├── seed.sh                      # Generator script
├── TEMPLATE-minimal.md          # Minimal template (~100 lines)
├── TEMPLATE-full.md             # Full template with placeholders
│
├── core/                        # ALWAYS included
│   ├── superpowers.md          # Bootstrap, skills, Perplexity triggers
│   ├── communication.md        # No flattery, evidence-based, direct
│   └── anti-slop.md            # Banned phrases, writing quality
│
├── workflows/                   # Standard development workflows
│   ├── deployment.md           # CI gates, green-before-deploy
│   ├── testing.md              # Coverage thresholds, pre-commit
│   ├── security.md             # Pre-commit hooks, secrets, CVEs
│   ├── session-resumption.md   # .resumption_state.md pattern
│   └── build-hygiene.md        # Never modify source, compile validation
│
├── languages/                   # Language-specific guidance
│   ├── go.md                   # golangci-lint, 80% coverage, go build after lint
│   ├── python.md               # pylint ≥9.5, mypy, type annotations
│   ├── javascript.md           # ESLint 9.x, style guides
│   ├── shell.md                # shellcheck, BSD/GNU, set -euo pipefail
│   └── dart-flutter.md         # AppLogger, widget testing, build timeouts
│
└── project-types/              # Project-specific patterns
    ├── genesis-tools.md        # Reference implementations, setup scripts
    ├── cli-tools.md            # Exit codes, help text, integration tests
    ├── web-apps.md             # Dark mode, event handlers, loading states
    └── mobile-apps.md          # iOS/Android builds, timeouts, Perplexity escalation
```

## File Sizes

All files designed to be context-window friendly:

| Category | Lines | Purpose |
|----------|-------|---------|
| Core files | 50-85 | Essential, always loaded |
| Workflow files | 55-105 | Standard development practices |
| Language files | 85-120 | Language-specific conventions |
| Project-type files | 70-130 | Project pattern guidance |

Generated Agents.md files are typically 300-600 lines depending on options.

## Manual Usage

Copy individual modules into your project as needed:

```bash
# Copy just the core files
cp guidance/core/*.md ./my-project/

# Copy specific language guidance
cp guidance/languages/go.md ./my-project/docs/
```

## Extraction Sources

Guidance distilled from 15+ Agents.md files:

| Source | Key Contributions |
|--------|-------------------|
| `Agents.md` (root) | Superpowers bootstrap |
| `RecipeArchive/Agents.md` | Dart/Flutter, mobile builds, Git workflow, Perplexity escalation |
| `scripts/Agents.md` | Shell conventions, pre-commit checklists |
| `bloginator/Agents.md` | Anti-slop rules, LLM mode |
| `genesis-tools/*/Agents.md` | CI gates, reference implementations, 3-phase workflow |
| `pr-faq-validator/Agents.md` | Go/Python conventions |
| `superpowers-plus/Agents.md` | Banned phrases, skill development |
| `codebase-reviewer/Agents.md` | Session resumption, IP protection |

