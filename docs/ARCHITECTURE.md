# Architecture

How superpowers-plus skills work and how to extend them.

## Terminology: Skills vs Superpowers

| Term | Definition | Frontmatter | Example |
|------|------------|-------------|---------|
| **Skill** | Generic term for any procedural module (a `skill.md` file) | Any | All of them |
| **Superpower** | A skill with auto-triggers — invokes automatically when phrases match | `triggers: ["phrase", ...]` | `brainstorming`, `wiki-orchestrator` |
| **Explicit Skill** | A skill without triggers — must be invoked by name | `triggers: []` or absent | `superpowers-help`, `security-upgrade` |

**Key distinction:**
- **Superpowers** have `triggers: [...]` → AI auto-invokes when trigger phrases are detected
- **Explicit skills** have no triggers → AI only invokes when user explicitly requests by name

This distinction matters for user queries:
- "What are my superpowers?" → List only auto-triggered skills
- "What skills do I have?" → List all skills (both types)

## Framework Integration

superpowers-plus extends [obra/superpowers](https://github.com/obra/superpowers) by Jesse Vincent, a skill framework for AI coding assistants. The core framework provides brainstorming, systematic-debugging, TDD, and other foundational skills. superpowers-plus adds domain-specific skills for wiki editing, issue tracking, security, and AI text quality.

```
~/.codex/
├── superpowers/          # obra/superpowers (cloned by install.sh)
│   └── skills/           # Core framework skills (mostly superpowers)
├── skills/               # Your personal skills (this repo)
├── superpowers-augment/  # Wrapper script for skill discovery
│   └── lib/              # Shared modules
└── superpowers-plus/
    └── tools/            # Utility scripts (todo-lock.sh, dangerous-pattern-scan.sh, etc.)
```

Skills from both directories are discovered by `superpowers-augment.js`.

### Installer Architecture

`install.sh` is an orchestrator (~600 lines) that sources 6 modules from `lib/install/`:

```
lib/install/
├── logging.sh       # Colors, log_*, error_exit, create_dir
├── platform.sh      # detect_platform, detect_linux_distro, WSL checks
├── deps.sh          # Package manager detection, dependency install, Node.js version check
├── superpowers.sh   # obra/superpowers clone, update, upgrade, version check
├── deploy.sh        # Skill, adapter, rule, template deployment to 3 target dirs
└── migrate.sh       # Post-install migrations (stale overrides, orphaned TODO.md)
```

Modules are sourced in dependency order: `logging` → `platform` → `deps` → `superpowers` → `deploy` → `migrate`. Globals (`VERBOSE`, `FORCE`, `SKILLS_DIR`, etc.) are shared via shell environment.

## Skill Discovery

The wrapper script finds skills by scanning for `skill.md` files:

```bash
node ~/.codex/superpowers-augment/superpowers-augment.js find-skills
```

Each skill is identified by its directory name, not the filename.

## Semantic Skill Matching

Beyond static trigger phrases, superpowers-plus includes a **semantic skill router** that matches natural language queries to skills based on meaning, not just keywords.

### Usage

```bash
# Find skills matching a natural language query
node ~/.codex/superpowers-augment/superpowers-augment.js match-skills "my tests keep failing"

# Force TF-IDF (local, no API) or embedding (OpenAI) method
node ~/.codex/superpowers-augment/superpowers-augment.js match-skills --tfidf "review this PR"
node ~/.codex/superpowers-augment/superpowers-augment.js match-skills --embedding "stuck on a bug"
```

### How It Works

The router uses a **hybrid TF-IDF + Intent Pattern** approach:

| Component | Purpose |
|-----------|---------|
| **TF-IDF Engine** | Matches query terms to skill descriptions using term frequency-inverse document frequency |
| **Stemming** | Reduces words to roots (e.g., "failing" → "fail") for better matching |
| **Query Expansion** | Maps domain concepts (e.g., "stuck" → "think-twice", "debug") |
| **Intent Patterns** | Boosts skills when high-confidence phrases are detected (e.g., "resume" → cv-review skills) |

### Default Behavior

- **Local-first**: Uses TF-IDF by default (no external API calls)
- **Optional enhancement**: If `OPENAI_API_KEY` is set, embeddings are available via `--embedding` flag
- **100% offline**: Works without network connectivity

### Architecture

```
lib/skill-router.js
├── buildTfIdfIndex()      # Builds document index from skill descriptions
├── matchSkillsTfIdf()     # Local TF-IDF matching with intent boosts
├── matchSkillsEmbedding() # OpenAI embedding matching (optional)
└── matchSkills()          # Unified interface (auto-selects method)
```

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
| `triggers` | No | Array of phrases that auto-invoke this skill. **If present and non-empty, the skill is a "superpower" (auto-triggered).** If absent or empty, the skill is "explicit" (must be invoked by name). |
| `description` | Yes | One-line description for skill discovery |
| `overrides` | No | If this skill overrides another, specify `repo/skill-name` |

### Superpower vs Explicit Skill Examples

**Superpower (auto-triggered):**
```yaml
---
name: wiki-orchestrator
source: superpowers-plus
triggers: ["update wiki page", "push to wiki", "edit wiki"]
description: Orchestrates wiki editing workflows — download, edit, publish.
---
```

**Explicit Skill (manual invocation):**
```yaml
---
name: superpowers-help
source: superpowers-plus
triggers: []  # Empty array = explicit
description: Lists available skills.
---
```

Or simply omit triggers entirely:
```yaml
---
name: superpowers-help
source: superpowers-plus
description: Lists available skills.
---
```

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

Some skills share triggers intentionally (e.g., `link-verification` fires alongside `wiki-orchestrator`). These are declared in the `ALLOWED_OVERLAPS` array in the validator script.

## Multi-Target Deployment

`install.sh` (via `lib/install/deploy.sh`) deploys skills to three locations for different AI tools:

| Target | Install Path | Notes |
|--------|--------------|-------|
| Augment Agent | `~/.codex/skills/` | Primary path for superpowers-augment.js |
| Claude Code | `~/.claude/skills/` | Native Skill tool path |
| Rules | `~/.augment/rules/` | Always-on agent rules |
| Tools | `~/.codex/superpowers-plus/tools/` | Utility scripts (todo-lock.sh, etc.) |

Note: `superpowers-augment.js` scans `~/.codex/skills/`, `~/.codex/superpowers/skills/`, and any additional paths configured by the installer.

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
│   ├── platform-template.md # Provider-neutral adapter template
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
| `ISSUE_TRACKER_TYPE` | issue-tracking/* | Select the configured issue-tracker adapter |
| `PERPLEXITY_API_KEY` | research/perplexity-research | Perplexity MCP authentication |

## Bootstrapping

At conversation start, AI assistants run:

```bash
node ~/.codex/superpowers-augment/superpowers-augment.js bootstrap
```

This emits the skill invocation rules (priority ordering, 1% chance rule) directly to the conversation.
