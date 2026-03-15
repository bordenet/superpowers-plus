# superpowers-plus

AI slop detection (300+ patterns, 0-100 scoring) and elimination (GVR rewrite loop, 11 strategies) plus 36 skills for wiki management, issue tracking, and security.

**Extends [obra/superpowers](https://github.com/obra/superpowers)** — installed automatically as dependency.

## Quick Start

```bash
git clone https://github.com/bordenet/superpowers-plus.git
cd superpowers-plus
./install.sh
```

## What's Included

**39 skills** (30 superpowers + 9 explicit) across 9 domains:

| Domain | Count | Type | Examples |
|--------|-------|------|----------|
| wiki | 7 | 🦸 auto | Page management, link checks, credential scanning |
| engineering | 6 | 🦸 auto | Pre-commit gates, blast radius, PR review |
| issue-tracking | 5 | 🦸 auto | Create, update, verify tickets |
| writing | 5 | 🦸 auto | Slop detection, profanity gates |
| productivity | 6 | mixed | Innovation, TODO tracking, style enforcement |
| observability | 5 | mixed | Skill effectiveness, completeness checks |
| research | 2 | 🦸 auto | Perplexity integration |
| security | 2 | 🔧 explicit | CVE scanning, IP protection |
| experimental | 1 | 🔧 explicit | Self-prompting patterns |

**Legend:** 🦸 = auto-triggered (superpowers), 🔧 = invoke by name (explicit skills)

## Installation

### Claude Code (Direct)

```bash
/plugin install https://github.com/bordenet/superpowers-plus
```

This installs obra/superpowers automatically as a dependency.

### MCP Server (Any Claude-Compatible Client)

For clients supporting Model Context Protocol:

1. Install dependencies:
   ```bash
   cd mcp && npm install
   ```

2. Add to your client's MCP config (e.g., `~/.claude/settings.json`):
   ```json
   {
     "mcpServers": {
       "superpowers-plus": {
         "command": "node",
         "args": ["/path/to/superpowers-plus/mcp/superpowers-mcp.js"]
       }
     }
   }
   ```

3. Restart your client. Use `find_skills` to list available skills.

### Augment Code

```bash
./install-augment-superpowers.sh
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
| `OPENAI_API_KEY` | Optional: Enhanced semantic skill matching |

## Semantic Skill Matching

Find skills by describing what you need:

```bash
node ~/.codex/superpowers-augment/superpowers-augment.js match-skills "my tests keep failing"
# → systematic-debugging, think-twice, vitest-testing-patterns

node ~/.codex/superpowers-augment/superpowers-augment.js match-skills "review this candidate's resume"
# → cv-review-external, cv-review-agency, resume-screening
```

Works offline using local TF-IDF. No API keys required.

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

### engineering/ (🦸 superpowers)
| Skill | What it does |
|-------|--------------|
| engineering-rigor | Quality philosophy hub |
| pre-commit-gate | Runs lint → typecheck → test |
| blast-radius-check | Finds all callers before edits |
| providing-code-review | Structured PR feedback |
| receiving-code-review | Evaluates incoming feedback |
| verification-before-completion | Final checks before claiming done |

### productivity/ (mixed)
| Skill | Type | What it does |
|-------|------|--------------|
| innovation | 🦸 | Radical, high-impact thinking beyond incremental fixes |
| think-twice | 🔧 | Spawns sub-agent for fresh perspective |
| todo-management | 🦸 | Parses and tracks tasks |
| golden-agents | 🔧 | Bootstraps AGENTS.md |
| enforce-style-guide | 🦸 | Applies project conventions |
| superpowers-help | 🔧 | Lists available skills |

### observability/ (🔧 explicit + 🦸 auto)
| Skill | Type | What it does |
|-------|------|--------------|
| skill-effectiveness | 🦸 | Tracks outcomes, learns trigger improvements |
| skill-firing-tracker | 🔧 | Logs which skills ran |
| exhaustive-audit-validation | 🔧 | Confirms checklist coverage |
| holistic-repo-verification | 🔧 | Checks all CI paths |
| completeness-check | Confirms work is done |

### research/ (🦸 superpowers)
| Skill | What it does |
|-------|--------------|
| perplexity-research | Escalates when stuck |
| incorporating-research | Merges external findings |

### security/ (🔧 explicit)
| Skill | What it does |
|-------|--------------|
| security-upgrade | Scans CVEs, upgrades deps |
| public-repo-ip-audit | Detects proprietary content |

### experimental/ (🦸 superpower)
| Skill | What it does |
|-------|--------------|
| experimental-self-prompting | Context-free analysis (unstable) |

## Skill Coordination

Skills can be coordinated into pipelines with explicit dependencies. View the full [Skill Dependency Graph](docs/skill-dependency-graph.md).

```mermaid
graph LR
  subgraph commit-gates["Commit Gates"]
    pre_commit_gate["pre-commit-gate"] --> enforce_style_guide["enforce-style-guide"]
    enforce_style_guide --> professional_language_audit["professional-language-audit"]
    professional_language_audit --> public_repo_ip_audit["public-repo-ip-audit"]
  end

  subgraph wiki-pipeline["Wiki Pipeline"]
    wiki_orchestrator["wiki-orchestrator"] --> link_verification["link-verification"]
    link_verification --> wiki_editing["wiki-editing"]
  end

  subgraph stuck-escalation["Stuck Escalation"]
    think_twice["think-twice"] ==> perplexity_research["perplexity-research"]
  end
```

| Group | Purpose |
|-------|---------|
| Commit Gates | Quality checks before `git commit` (build → style → language → IP audit) |
| Wiki Pipeline | Wiki authoring quality pipeline (orchestrator → links → edit) |
| Stuck Escalation | Getting unstuck (reasoning first → research if needed) |

### Namespaced Triggers

Skills support namespaced triggers (`domain:action`) for disambiguation:

| Domain | Triggers |
|--------|----------|
| `commit:` | `commit:pre-check`, `commit:style`, `commit:language`, `commit:ip-audit` |
| `wiki:` | `wiki:create`, `wiki:update`, `wiki:edit-internal` |
| `stuck:` | `stuck:reasoning`, `stuck:research` |

Regenerate the graph: `node tools/generate-skill-dag.js`

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
