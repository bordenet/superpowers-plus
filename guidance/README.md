# Guidance Directory

> ⚠️ **This is NOT the project's AI guidance.** See [/AGENTS.md](/AGENTS.md) for superpowers-plus project rules.

This directory contains **templates and tools** for generating AI guidance files in other projects. It's part of the [golden-agents](https://github.com/bordenet/golden-agents) framework.

## What's Here

| File | Purpose |
|------|---------|
| `TEMPLATE-full.md` | Full template with placeholders |
| `TEMPLATE-minimal.md` | Minimal template (~100 lines) |
| `migrate-agents.sh` | Migrate existing AGENTS.md to Golden Agents format |
| `EVALUATION-REPORT.md` | Framework testing documentation |
| `AGENTS.md`, etc. | Example guidance files for this directory (demonstration) |

## Generate AGENTS.md for other projects

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
| `migrate-agents.sh` | Migrate existing AGENTS.md to Golden Agents format |
| `TEMPLATE-full.md` | Full template with placeholders |
| `TEMPLATE-minimal.md` | Minimal template (~100 lines) |
| `EVALUATION-REPORT.md` | Framework testing documentation |

## See Also

- [golden-agents](https://github.com/bordenet/golden-agents) - Public repo with all templates
- [obra/superpowers](https://github.com/obra/superpowers) - AI skill framework
