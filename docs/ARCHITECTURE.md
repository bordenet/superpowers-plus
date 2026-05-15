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

superpowers-plus builds on [bordenet/superpowers](https://github.com/bordenet/superpowers), a maintained fork of Jesse Vincent's [obra/superpowers](https://github.com/obra/superpowers) (MIT). The fork gives superpowers-plus governance stability — upstream obra improvements are reviewed and merged periodically per [CONTRIBUTING.md](../CONTRIBUTING.md). The core framework provides brainstorming, systematic-debugging, TDD, and other foundational skills. superpowers-plus adds domain-specific skills for wiki editing, issue tracking, security, and AI text quality.

```bash
~/.codex/
├── superpowers/          # superpowers core (fork of obra/superpowers by Jesse Vincent)
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
├── deploy.sh        # Skill, adapter, rule deployment across ~/.codex/skills/, ~/.claude/skills/, ~/.agents/skills/, ~/.augment/rules/
└── migrate.sh       # Post-install migrations (orphaned TODO.md detection, legacy clone removal)
```

Modules are sourced in dependency order: `logging` → `platform` → `deps` → `deploy` → `migrate`. Globals (`VERBOSE`, `SKILLS_DIR`, etc.) are shared via shell environment.

> **v2.6.0:** `lib/install/superpowers.sh` was removed — all 14 obra/superpowers skills are bundled directly in the `skills/` tree. The separate `~/.codex/superpowers/` clone is no longer required and is migrated away on the next install.

## Skill Discovery

The wrapper script finds skills by scanning for `skill.md` files:

```bash
node ~/.codex/superpowers-augment/superpowers-augment.js find-skills
```

Each skill is identified by its directory name, not the filename.

## Semantic Skill Matching

Beyond static trigger phrases, superpowers-plus includes a **semantic skill router** (`lib/skill-router.js`) that matches natural language queries to skills using hybrid TF-IDF + intent pattern scoring. CLI: `superpowers-augment.js match-skills "query"`. For the full algorithm, scoring pipeline, query expansion, and embedding mode, see [DESIGN.md § Semantic Skill Router](DESIGN.md#3-semantic-skill-router).

## Skill Content Compression

Skills are compressed by `lib/compress.js` on load (typically 20–40% token reduction). Add `compress: false` to frontmatter to opt out. For the full two-phase pipeline, stripped sections list, and preserved-content rules, see [DESIGN.md § Compression Pipeline](DESIGN.md#5-compression-pipeline).

### Incident 2026-04-14

`STRIP_SECTIONS` included `Hallucination Prevention`, `References`, and `Incident Log/Record/History`. This deleted URL verification rules from `link-verification` and `issue-link-verification`, deleted pointers to 78 lines of incident history, and deleted recurrence-prevention context. Wiki authoring regressed to producing broken hyperlinks. All three patterns were removed from `STRIP_SECTIONS` and the `<EXTREMELY_IMPORTANT>` pre-extraction mechanism was added as a safety net.

## Skill Structure

A skill is a directory containing `skill.md`:

```
skills/{domain}/{skill-name}/
└── skill.md              # Required: skill definition
```

### skill.md Content Sections

```markdown
# Skill Name

## Procedure
[Step-by-step instructions]

## Output Format
[Expected outputs]

## Failure Modes
[Known failure modes and remediation]
```

For the complete frontmatter schema (`name`, `source`, `triggers`, `augment_menu`, `coordination`, `composition`, and all other fields), see [DESIGN.md § Frontmatter Schema](DESIGN.md#1-frontmatter-schema).

### Downstream Override Declaration

When extending superpowers-plus, downstream repos declare their override in frontmatter:

```yaml
name: link-verification
source: your-org-repo
overrides: superpowers-plus/link-verification
triggers: ["verify links", "check URL"]
description: Org-specific link verification with internal URL patterns.
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

`install.sh` (via `lib/install/deploy.sh`) deploys skills to four locations:

| Target | Install Path | Notes |
|--------|--------------|-------|
| Augment Agent | `~/.codex/skills/` | Primary path for superpowers-augment.js |
| Claude Code | `~/.claude/skills/` | Native Skill tool path |
| Augment slash menu | `~/.agents/skills/` | Skills with `augment_menu: true` in Augment IDE command palette |
| Rules | `~/.augment/rules/` | Always-on agent rules |
| Tools | `~/.codex/superpowers-plus/tools/` | Utility scripts (todo-lock.sh, etc.) |

Note: `superpowers-augment.js` scans `~/.codex/skills/`, `~/.codex/superpowers/skills/`, and any additional paths configured by the installer.

### Augment Slash Menu — Dynamic Discovery

Skills are exported to `~/.agents/skills/` via **explicit opt-in** — no hardcoded list. The rule:

> Any skill installed to `~/.codex/skills/` that declares `augment_menu: true` in its frontmatter is exported to `~/.agents/skills/`. The directory (slash command) name is the first `/sp*` trigger in `triggers:` (covering `/sp-`, `/spr-`, `/spc-` prefixes), falling back to the skill directory name.

```yaml
# This skill will appear as /sp-debug in the Augment command palette
augment_menu: true
triggers: ["/sp-debug", "debug this", "test failure"]
```

This keeps the slash menu curated: skills must explicitly declare intent to appear there. Overlay repos control their own slash menu presence independently, with zero changes to superpowers-plus, as long as:
1. Their installer sets `AUGMENT_MENU_DIR="${HOME}/.agents/skills"` and calls `export_augment_menu_skills "source-name"`
2. Skills they want in the menu carry `augment_menu: true` in their frontmatter

Some overlay repos deploy their skills directly to `~/.agents/skills/` by skill name using their own install mechanism, bypassing `augment_menu: true`. These repos manage their own stale-prune logic independently.

**Stale-prune isolation:** Each installer passes its own `source:` value to `export_augment_menu_skills`. Pruning only removes entries whose `SKILL.md` has a matching `source:` line. Entries from other installers and user-created entries (no `source:` field) are never touched.

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

At conversation start, AI assistants run `superpowers-augment.js bootstrap`, which scans skill directories, deduplicates, writes `~/.codex/.skill-index.json`, and emits the skill invocation rules into the session. For the full sequence diagram and session-staleness logic, see [DESIGN.md § Bootstrap Flow](DESIGN.md#8-bootstrap-flow).
