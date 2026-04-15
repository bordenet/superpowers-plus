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

```bash
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

```markdown
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

Beyond static trigger phrases, superpowers-plus includes a **semantic skill router** that matches natural language queries to skills based on meaning, not just keywords. For the full scoring algorithm (TF-IDF + intent pattern boosts + anti-trigger penalties), see [DESIGN.md § Semantic Skill Router](DESIGN.md#3-semantic-skill-router).

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

```typescript
lib/skill-router.js
├── buildTfIdfIndex()      # Builds document index from skill descriptions
├── matchSkillsTfIdf()     # Local TF-IDF matching with intent boosts
├── matchSkillsEmbedding() # OpenAI embedding matching (optional)
└── matchSkills()          # Unified interface (auto-selects method)
```

## Skill Content Compression

When skills are loaded by `superpowers-augment.js` or `mcp/superpowers-mcp.js`, their content passes through `lib/compress.js` to reduce token cost (typically 20–40% reduction).

### Two-Phase Pipeline

**Phase 1 (structural):** Strips boilerplate sections by heading pattern (`STRIP_SECTIONS`), removes DOT graphs and HTML comments. Sections like `When to Use`, `Examples`, `Anti-Patterns`, `Companion Skills` are stripped — they aid human navigation but not agent execution.

**Phase 2 (density):** Reduces prose verbosity outside code blocks — removes bold/italic markup from headings, collapses whitespace, strips navigation boilerplate.

### Preserved Content

These survive compression unconditionally:

| Content | Why |
|---------|-----|
| `<EXTREMELY_IMPORTANT>` blocks | Operative safety gates (e.g., URL verification rules) |
| `Failure Modes` sections | Runtime error-handling context |
| `Incident Log/Record/History` | Recurrence-prevention context — real past failures |
| `References` sections | Pointers to reference files (e.g., `references/incidents.md`) |
| `Hallucination Prevention` | URL fabrication prevention rules |
| Code blocks, tables, checklists | Procedural content |

`<EXTREMELY_IMPORTANT>` blocks are **extracted before** section stripping and **restored after**, so they survive even when their parent heading is in `STRIP_SECTIONS`. Blocks rescued from stripped sections are appended under `## Critical Rules (preserved from compression)`.

### Opt-out

Add `compress: false` to a skill's YAML frontmatter to skip compression entirely.

### Incident 2026-04-14

`STRIP_SECTIONS` included `Hallucination Prevention`, `References`, and `Incident Log/Record/History`. This deleted URL verification rules from `link-verification` and `issue-link-verification`, deleted pointers to 78 lines of incident history, and deleted recurrence-prevention context. Wiki authoring regressed to producing broken hyperlinks. All three patterns were removed from `STRIP_SECTIONS` and the `<EXTREMELY_IMPORTANT>` extraction mechanism was added as a safety net.

## Skill Structure

A skill is a directory containing `skill.md`:

```markdown
skills/{domain}/{skill-name}/
└── skill.md              # Required: skill definition
```

### skill.md Format

```markdown
---
name: skill-name
source: superpowers-plus
triggers: ["trigger phrase 1", "trigger phrase 2", "trigger phrase 3"]
anti_triggers: ["phrase that should NOT trigger this skill"]
description: One-line description of what the skill does.
coordination:
  group: domain-name
  order: 1
  requires: []
  enables: []
  escalates_to: []
  internal: false
---

# Skill Name

## When to Invoke
[Trigger conditions]

## Procedure
[Step-by-step instructions]

## Output Format
[Expected outputs]

## Failure Modes
[Known failure modes and remediation]
```

### Frontmatter Fields

For the complete field reference including `composition`, `aliases`, `requires_mcp`, `compress`, and `summary`, see [DESIGN.md § Frontmatter Schema](DESIGN.md#1-frontmatter-schema).

| Field | Required | Description |
|-------|----------|-------------|
| `name` | Yes | Skill identifier (must match directory name) |
| `source` | Yes | Repository that owns this skill (e.g., `superpowers-plus`) |
| `triggers` | No | Array of phrases that auto-invoke this skill. **If present and non-empty, the skill is a "superpower" (auto-triggered).** If absent or empty, the skill is "explicit" (must be invoked by name). |
| `anti_triggers` | No | Array of phrases that should NOT trigger this skill |
| `description` | Yes | One-line description for skill discovery |
| `coordination` | No | DAG metadata: `group`, `order`, `internal`, `requires`, `enables`, `escalates_to` |
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

Reusable patterns and shared contracts live in `skills/_shared/`:

```markdown
skills/_shared/
├── README.md                            # Index and usage guide
├── confidence-calibration.md            # Confidence scoring standards
├── duplicate-work-detection.md          # Cross-branch duplicate detection
├── evidence-schema.md                   # Evidence structure for investigations
├── fork-readiness-rubric.md             # When to fork vs stay serial
├── incident-packet-schema.md            # Debugging orchestration packet contract
├── multi-agent-activation-rubric.md     # 5=ask, ≥6=multi-agent eligible
├── multi-agent-quality-standards.md     # Quality gates for multi-agent output
├── multi-agent-result-schema.md         # Branch result contract
├── multi-agent-synthesis-schema.md      # Synthesis output contract
├── multi-agent-task-packet-schema.md    # Dispatch packet contract
└── secret-detection.md                  # Regex patterns for credential detection
```

**Normative shared docs** (multi-agent schemas, activation rubric) define contracts that skills MUST follow. Other shared docs provide reusable patterns that skills MAY reference.

## Adapter Pattern

The `issue-tracking/` domain uses adapters to support multiple platforms:

```markdown
skills/issue-tracking/
├── _adapters/
│   ├── README.md         # Adapter overview
│   ├── platform-template.md # Provider-neutral adapter template
│   ├── github-issues.md  # GitHub Issues configuration
│   ├── jira.md           # Jira configuration
│   └── {platform}.md     # Your platform adapter (from platform-template.md)
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
