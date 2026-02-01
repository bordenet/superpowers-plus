# Guidance Directory

> **Note**: Templates have moved to [golden-agents](https://github.com/bordenet/golden-agents).

This directory contains the Golden Agents Framework for generating project-specific AI guidance files.

## AI Guidance Files

This directory has its own AI guidance (eating our own dog food):

| File | Purpose |
|------|---------|
| `Agents.md` | AI guidance for this directory |
| `CLAUDE.md` | Redirect → Agents.md (Claude Code) |
| `CODEX.md` | Redirect → Agents.md (OpenAI Codex CLI) |
| `GEMINI.md` | Redirect → Agents.md (Google Gemini) |
| `COPILOT.md` | Redirect → Agents.md (GitHub Copilot) |

## Generate Agents.md for other projects

```bash
# Using golden-agents (recommended)
~/.golden-agents/generate-agents.sh --language=go --type=cli-tools --path=./my-project

# Using local seed.sh
./seed.sh --language=shell --type=genesis-tools --path=./my-project
```

## Other Files

| File | Purpose |
|------|---------|
| `seed.sh` | Generator script (local copy) |
| `migrate-agents.sh` | Migrate existing Agents.md to Golden Agents format |
| `TEMPLATE-full.md` | Full template with placeholders |
| `TEMPLATE-minimal.md` | Minimal template (~100 lines) |
| `EVALUATION-REPORT.md` | Framework testing documentation |

## See Also

- [golden-agents](https://github.com/bordenet/golden-agents) - Public repo with all templates
- [obra/superpowers](https://github.com/obra/superpowers) - AI skill framework

