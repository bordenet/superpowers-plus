# superpowers-plus

Extended skills for AI coding assistants: wiki editing, issue tracking, security audits, TypeScript patterns, and writing quality tools.

**Requires [obra/superpowers](https://github.com/obra/superpowers)** — installed automatically by `./install.sh`.

## Quick Start

```bash
git clone https://github.com/bordenet/superpowers-plus.git
cd superpowers-plus
./install.sh
```

The installer handles prerequisites, detects your platform, and deploys to all supported AI assistants.

## What's Included

**41 skills** across 10 domains:

| Domain | Count | Examples |
|--------|-------|----------|
| wiki | 7 | Editing, verification, secret audit, fact-checking |
| issue-tracking | 5 | Authoring, editing, link verification |
| writing | 5 | AI slop detection, professional language audit |
| typescript | 5 | Strict mode, complexity refactoring, Vitest patterns |
| engineering | 5 | Pre-commit gates, blast radius checks, code review |
| productivity | 5 | TODO management, think-twice, style enforcement |
| observability | 4 | Skill firing tracker, audit validation |
| research | 2 | Perplexity integration |
| security | 2 | CVE scanning, IP audit |
| experimental | 1 | Self-prompting |

## Platform Installation

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

Windows users: Use WSL (`wsl --install -d Ubuntu`).

## Configuration

Copy `.env.example` to `.env` for optional integrations:

| Variable | Purpose |
|----------|---------|
| `ISSUE_TRACKER_TYPE` | `linear`, `github`, `jira`, or `azure-devops` |
| `WIKI_PLATFORM` | `outline` (see `skills/wiki/_adapters/`) |
| `PERPLEXITY_API_KEY` | Research skill integration |

## Updating

```bash
./install.sh --upgrade
```

## Skill Reference

### wiki/
| Skill | Purpose |
|-------|---------|
| wiki-orchestrator | Route wiki tasks to appropriate skills |
| wiki-editing | Safe wiki updates with backup |
| wiki-authoring | Create new wiki pages |
| wiki-verify | Validate wiki links and structure |
| wiki-debunker | Fact-check wiki content |
| wiki-secret-audit | Scan for leaked credentials |
| link-verification | Validate internal/external URLs |

### issue-tracking/
| Skill | Purpose |
|-------|---------|
| issue-authoring | Write issues with acceptance criteria |
| issue-editing | Update existing issues safely |
| issue-verify | Validate issue links and references |
| issue-link-verification | Check URLs in issue content |
| issue-comment-debunker | Verify claims before posting comments |

### writing/
| Skill | Purpose |
|-------|---------|
| detecting-ai-slop | Score text for AI patterns (0-100) |
| eliminating-ai-slop | Rewrite AI-like text |
| professional-language-audit | Gate for profanity before wiki/commit |
| readme-authoring | Structure READMEs |
| reviewing-ai-text | Review AI-generated content |

### typescript/
| Skill | Purpose |
|-------|---------|
| typescript-strict-mode | Enforce strict TypeScript |
| cognitive-complexity-refactoring | Reduce complexity scores |
| vitest-testing-patterns | SDK mocking for Vitest |
| typescript-project-conventions | Import organization |
| field-rename-verification | Cross-file rename validation |

### engineering/
| Skill | Purpose |
|-------|---------|
| engineering-rigor | Engineering quality philosophy |
| pre-commit-gate | Lint → typecheck → test before commit |
| blast-radius-check | Find all usages before modifying code |
| providing-code-review | Review others' PRs |
| receiving-code-review | Evaluate review feedback |

### productivity/
| Skill | Purpose |
|-------|---------|
| think-twice | Sub-agent review when blocked |
| todo-management | Parse and track TODOs |
| golden-agents | Initialize AGENTS.md |
| enforce-style-guide | Validate against style guides |
| superpowers-help | List available skills |

### observability/
| Skill | Purpose |
|-------|---------|
| skill-firing-tracker | Log skill invocations |
| exhaustive-audit-validation | Validate audit checklists |
| holistic-repo-verification | Check all CI workflows |
| completeness-check | Verify work is complete |

### research/
| Skill | Purpose |
|-------|---------|
| perplexity-research | Auto-invoke Perplexity when stuck |
| incorporating-research | Integrate external research |

### security/
| Skill | Purpose |
|-------|---------|
| security-upgrade | Scan CVEs, upgrade dependencies |
| public-repo-ip-audit | Audit for proprietary IP |

### experimental/
| Skill | Purpose |
|-------|---------|
| experimental-self-prompting | Context-free prompts (not production-ready) |

## Extending

Organizations can layer custom skills on top:

```
obra/superpowers (framework)
    └── superpowers-plus (this repo)
            └── your-org-skills
```

See [Enterprise Adopters Guide](docs/ENTERPRISE_ADOPTERS_GUIDE.md) for patterns.

## Troubleshooting

| Error | Fix |
|-------|-----|
| "Tool not found: perplexity_*" | Run `./setup/mcp-perplexity.sh` |
| Issue tracking skills fail | Set `ISSUE_TRACKER_TYPE` in `.env` |
| Wiki skills fail | Set `WIKI_PLATFORM` in `.env` |

## Documentation

- [Architecture](docs/ARCHITECTURE.md)
- [Contributing](docs/CONTRIBUTING.md)
- [Upgrading](UPGRADING.md)

## License

MIT
