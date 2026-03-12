# Architecture

How superpowers-plus skills work and how to extend them.

## Framework Integration

superpowers-plus extends [obra/superpowers](https://github.com/obra/superpowers), a skill framework for AI coding assistants.

```
~/.codex/
├── superpowers/          # obra/superpowers (cloned by install.sh)
│   └── skills/           # Core framework skills
├── skills/               # Your personal skills (this repo)
└── superpowers-augment/  # Wrapper script for skill discovery
```

Skills from both directories are discovered by `superpowers-augment.js`.

## Skill Discovery

The wrapper script finds skills by scanning for `skill.md` files:

```bash
node ~/.codex/superpowers-augment/superpowers-augment.js find-skills
```

Each skill is identified by its directory name, not the filename.

## Skill Structure

A skill is a directory containing `skill.md`:

```
skills/{domain}/{skill-name}/
└── skill.md              # Required: skill definition
```

### skill.md Format

```markdown
---
name: skill-name
source: superpowers-plus
triggers: ["trigger phrase 1", "trigger phrase 2", "trigger phrase 3"]
description: One-line description of what the skill does.
---

# Skill Name

## When to Invoke
[Trigger conditions]

## Procedure
[Step-by-step instructions]

## Output Format
[Expected outputs]
```

### Frontmatter Fields

| Field | Required | Description |
|-------|----------|-------------|
| `name` | Yes | Skill identifier (must match directory name) |
| `source` | Yes | Repository that owns this skill (e.g., `superpowers-plus`) |
| `triggers` | Yes | Array of phrases that should invoke this skill |
| `description` | Yes | One-line description for skill discovery |
| `overrides` | No | If this skill overrides another, specify `repo/skill-name` |

### Downstream Override Declaration

When extending superpowers-plus, downstream repos can declare their override:

```yaml
---
name: link-verification
source: your-org-repo
overrides: superpowers-plus/link-verification
triggers: ["verify links", "check URL", "add code reference"]
description: Org-specific link verification with internal URL patterns.
---
```

This enables tooling to audit which version is active at runtime.

## Trigger Validation

The `tools/skill-trigger-validator.sh` script audits triggers across all skills:

```bash
# Full audit (overlaps, missing triggers, registry summary)
./tools/skill-trigger-validator.sh audit

# Check for trigger collisions only
./tools/skill-trigger-validator.sh overlaps

# Generate skill → trigger mapping
./tools/skill-trigger-validator.sh registry
```

### Intentional Overlaps

Some skills share triggers intentionally (e.g., `link-verification` fires alongside `wiki-editing`). These are declared in the `ALLOWED_OVERLAPS` array in the validator script.

## Multi-Target Deployment

`install.sh` deploys skills to three locations for different AI tools:

| Tool | Install Path | Notes |
|------|--------------|-------|
| Augment Agent | `~/.codex/skills/` | Primary path for superpowers-augment.js |
| Claude Code | `~/.claude/skills/` | Native Skill tool path |
| Augment (alt) | `~/.augment/skills/` | Alternative Augment location |

Note: `superpowers-augment.js` scans `~/.codex/skills/` and `~/.codex/superpowers/skills/`.

## Shared Modules

Reusable patterns live in `skills/_shared/`:

```
skills/_shared/
└── secret-detection.md   # Regex patterns for credential detection
```

Skills reference shared modules via relative paths or copy the content inline.

## Adapter Pattern

The `issue-tracking/` domain uses adapters to support multiple platforms:

```
skills/issue-tracking/
├── _adapters/
│   ├── README.md         # Adapter overview
│   ├── linear.md         # Linear.app configuration
│   ├── github-issues.md  # GitHub Issues configuration
│   ├── jira.md           # Jira configuration
│   └── azure-devops.md   # Azure DevOps configuration
├── issue-authoring/
│   └── skill.md
└── ...
```

Skills read `ISSUE_TRACKER_TYPE` environment variable to select the adapter.

## Extension Points

### Adding a Skill

1. Create `skills/{domain}/{skill-name}/skill.md`
2. Run `./install.sh`
3. Verify with `find-skills`

### Adding a Domain

1. Create `skills/{domain}/` directory
2. Add skills inside
3. No registration required — auto-discovered

### Adding an Adapter

1. Create `skills/{domain}/_adapters/{platform}.md`
2. Document platform-specific configuration
3. Update existing skills to check the environment variable

## Environment Variables

| Variable | Used By | Purpose |
|----------|---------|---------|
| `ISSUE_TRACKER_TYPE` | issue-tracking/* | Select adapter: `linear`, `github`, `jira`, `azure-devops` |
| `PERPLEXITY_API_KEY` | research/perplexity-research | Perplexity MCP authentication |

## Bootstrapping

At conversation start, AI assistants run:

```bash
node ~/.codex/superpowers-augment/superpowers-augment.js bootstrap
```

This loads the `using-superpowers` skill which governs skill invocation.
