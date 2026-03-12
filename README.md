# superpowers-plus

Skills for AI coding assistants: wiki management, issue tracking, security scanning, TypeScript tooling, and prose quality.

**Requires [obra/superpowers](https://github.com/obra/superpowers)** — installed automatically.

## Quick Start

```bash
git clone https://github.com/bordenet/superpowers-plus.git
cd superpowers-plus
./install.sh
```

## What's Included

**41 skills** across 10 domains:

| Domain | Count | Examples |
|--------|-------|----------|
| wiki | 7 | Page management, link checks, credential scanning |
| issue-tracking | 5 | Create, update, verify tickets |
| writing | 5 | Slop detection, profanity gates |
| typescript | 5 | Strict mode, complexity reduction, Vitest mocks |
| engineering | 5 | Pre-commit gates, blast radius, PR review |
| productivity | 5 | TODO tracking, style enforcement |
| observability | 4 | Invocation logging, completeness checks |
| research | 2 | Perplexity integration |
| security | 2 | CVE scanning, IP protection |
| experimental | 1 | Self-prompting |

## Installation

### Claude Code

```bash
/plugin marketplace add bordenet/superpowers-plus-marketplace
/plugin install superpowers@superpowers-plus-marketplace
/plugin install superpowers-plus@superpowers-plus-marketplace
```

### Cursor

```text
/add-plugin superpowers-plus
```

### Codex / OpenCode

```text
Fetch and follow instructions from https://raw.githubusercontent.com/bordenet/superpowers-plus/main/.codex/INSTALL.md
```

### Gemini CLI

```bash
gemini extensions install https://github.com/obra/superpowers
gemini extensions install https://github.com/bordenet/superpowers-plus
```

### Manual (macOS/Linux/WSL)

```bash
git clone https://github.com/bordenet/superpowers-plus.git
cd superpowers-plus
./install.sh
```

Windows: Use WSL (`wsl --install -d Ubuntu`).

## Configuration

Copy `.env.example` to `.env` for optional integrations:

| Variable | Purpose |
|----------|---------|
| `ISSUE_TRACKER_TYPE` | `linear`, `github`, `jira`, or `azure-devops` |
| `WIKI_PLATFORM` | `outline` (see `skills/wiki/_adapters/`) |
| `PERPLEXITY_API_KEY` | Deep research fallback |

## Updating

```bash
./install.sh --upgrade
```

## Skills

### wiki/
| Skill | What it does |
|-------|--------------|
| wiki-orchestrator | Routes tasks to the right handler |
| wiki-editing | Safe updates with backup |
| wiki-authoring | Creates new pages |
| wiki-verify | Checks links and structure |
| wiki-debunker | Fact-checks content |
| wiki-secret-audit | Finds leaked credentials |
| link-verification | Confirms URLs resolve |

### issue-tracking/
| Skill | What it does |
|-------|--------------|
| issue-authoring | Writes tickets with acceptance criteria |
| issue-editing | Updates existing tickets safely |
| issue-verify | Confirms references exist |
| issue-link-verification | Tests URLs in ticket content |
| issue-comment-debunker | Fact-checks before posting |

### writing/
| Skill | What it does |
|-------|--------------|
| detecting-ai-slop | Scores text 0-100 for machine patterns |
| eliminating-ai-slop | Rewrites stilted prose |
| professional-language-audit | Blocks profanity |
| readme-authoring | Structures documentation |
| reviewing-ai-text | Evaluates generated content |

### typescript/
| Skill | What it does |
|-------|--------------|
| typescript-strict-mode | Eliminates `any` and `!` |
| cognitive-complexity-refactoring | Simplifies dense functions |
| vitest-testing-patterns | SDK mocking patterns |
| typescript-project-conventions | Import ordering |
| field-rename-verification | Cross-file rename safety |

### engineering/
| Skill | What it does |
|-------|--------------|
| engineering-rigor | Quality philosophy hub |
| pre-commit-gate | Runs lint → typecheck → test |
| blast-radius-check | Finds all callers before edits |
| providing-code-review | Structured PR feedback |
| receiving-code-review | Evaluates incoming feedback |

### productivity/
| Skill | What it does |
|-------|--------------|
| think-twice | Spawns sub-agent for fresh perspective |
| todo-management | Parses and tracks tasks |
| golden-agents | Bootstraps AGENTS.md |
| enforce-style-guide | Applies project conventions |
| superpowers-help | Lists available skills |

### observability/
| Skill | What it does |
|-------|--------------|
| skill-firing-tracker | Logs which skills ran |
| exhaustive-audit-validation | Confirms checklist coverage |
| holistic-repo-verification | Checks all CI paths |
| completeness-check | Confirms work is done |

### research/
| Skill | What it does |
|-------|--------------|
| perplexity-research | Escalates when stuck |
| incorporating-research | Merges external findings |

### security/
| Skill | What it does |
|-------|--------------|
| security-upgrade | Scans CVEs, upgrades deps |
| public-repo-ip-audit | Detects proprietary content |

### experimental/
| Skill | What it does |
|-------|--------------|
| experimental-self-prompting | Context-free analysis (unstable) |

## Extending

Layer organization-specific skills on top:

```
obra/superpowers (framework)
    └── superpowers-plus (this repo)
            └── your-org-skills
```

See [Enterprise Adopters Guide](docs/ENTERPRISE_ADOPTERS_GUIDE.md).

## Troubleshooting

| Error | Fix |
|-------|-----|
| "Tool not found: perplexity_*" | Run `./setup/mcp-perplexity.sh` |
| Issue tracking fails | Set `ISSUE_TRACKER_TYPE` in `.env` |
| Wiki operations fail | Set `WIKI_PLATFORM` in `.env` |

## Documentation

- [Architecture](docs/ARCHITECTURE.md)
- [Contributing](docs/CONTRIBUTING.md)
- [Upgrading](UPGRADING.md)

## License

MIT
