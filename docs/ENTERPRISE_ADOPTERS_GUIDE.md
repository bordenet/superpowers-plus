# Enterprise Adopters Guide

How to extend superpowers-plus with organization-specific skills, adapters, and rules.

## Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [The Override Pattern](#the-override-pattern)
3. [The Adapter Pattern](#the-adapter-pattern)
4. [The Fork Pattern](#the-fork-pattern)
5. [The Always-On Rules Pattern](#the-always-on-rules-pattern)
6. [Trigger Validation](#trigger-validation)
7. [Recommended Directory Structure](#recommended-directory-structure)
8. [Install Script Pattern](#install-script-pattern)

---

## Architecture Overview

superpowers-plus is designed as a **generic base layer** that organizations extend with their own private repository containing vendor-specific implementations.

### The Two-Repo Pattern

```
┌─────────────────────────────────────────────────────────────────┐
│                    YOUR ORGANIZATION                            │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│   ┌─────────────────────┐    ┌─────────────────────┐           │
│   │  superpowers-plus   │    │   your-org-skills   │           │
│   │  (PUBLIC / GENERIC) │    │  (PRIVATE / SPECIFIC)│           │
│   ├─────────────────────┤    ├─────────────────────┤           │
│   │ • wiki-editing      │    │ • wiki-editing      │ ← OVERRIDE│
│   │ • wiki-authoring    │    │ • wiki-authoring    │ ← OVERRIDE│
│   │ • issue-authoring   │    │ • jira-issue-auth   │ ← EXTEND  │
│   │ • link-verification │    │ • link-verification │ ← OVERRIDE│
│   │ • _adapters/        │    │ • rules/*.always.md │           │
│   └─────────────────────┘    └─────────────────────┘           │
│            │                          │                         │
│            │ Install 1st              │ Install 2nd             │
│            ▼                          ▼                         │
│   ┌─────────────────────────────────────────────────┐          │
│   │           ~/.augment/skills/                    │          │
│   │  (Later installs OVERRIDE earlier ones)         │          │
│   └─────────────────────────────────────────────────┘          │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### Install Order Matters

```bash
# Step 1: Install generic base layer
cd ~/repos/superpowers-plus && ./install.sh

# Step 2: Install org-specific overlay (MUST be second)
cd ~/repos/your-org-skills && ./install.sh
```

**Skills with the same name in your org repo will OVERWRITE the generic versions.**

### Skill Resolution

When an AI agent invokes a skill, it looks in these locations (in order):

| Location | Purpose | Checked |
|----------|---------|---------|
| `~/.augment/skills/` | Augment Agent skills | First |
| `~/.codex/skills/` | Claude Code skills | Second |
| `~/.codex/superpowers/skills/` | obra/superpowers skills | Third |

Your org's `install.sh` should deploy to `~/.augment/skills/` to ensure your overrides take precedence.

---

## The Override Pattern

Use this pattern when you need to replace a generic skill with a vendor-specific implementation.

### When to Use Override

| Scenario | Pattern |
|----------|---------|
| Generic skill needs platform-specific API calls | Override |
| Generic workflow is correct but needs different tools | Override |
| You need to add org-specific validation steps | Override |

### How to Override

1. **Create a skill with the exact same name** in your org repo
2. **Install your org repo AFTER superpowers-plus**
3. The generic version is replaced by your version

**Example: Overriding `wiki-editing`**

Generic version (superpowers-plus):
```yaml
# skills/wiki/wiki-editing/skill.md
---
name: wiki-editing
source: superpowers-plus
triggers: ["update wiki page", "push to wiki", "edit wiki", "create wiki document"]
description: Generic wiki editing workflow. See _adapters/ for platform setup.
---
```

Your org version (your-org-skills):
```yaml
# skills/wiki/wiki-editing/skill.md
---
name: wiki-editing
source: your-org-skills
overrides: superpowers-plus/wiki-editing
triggers: ["update wiki page", "push to wiki", "edit wiki", "create wiki document"]
description: Wiki editing for YourWikiPlatform. Includes org-specific scope restrictions.
---

# Wiki Editing (YourWikiPlatform)

> **Source:** `your-org-skills` (overrides `superpowers-plus`)

## Org-Specific Configuration
- Base URL: Use `$WIKI_BASE_URL` environment variable
- Scope: Only these collections are writable: [list your collections]
- MCP Tools: your_wiki_create, your_wiki_update, your_wiki_get
...
```

### Override Frontmatter

When overriding a skill, include these fields:

| Field | Value | Purpose |
|-------|-------|---------|
| `source` | `your-org-repo` | Identifies which repo owns this version |
| `overrides` | `superpowers-plus/skill-name` | Declares the override relationship |
| `triggers` | Same or extended array | Inherit or extend trigger phrases |

This enables the trigger validator to audit overrides across repo boundaries.

### Override Checklist

- [ ] Skill name matches exactly (including case)
- [ ] `source:` field set to your org repo name
- [ ] `overrides:` field declares the base skill
- [ ] `triggers:` array includes all base triggers (plus any additions)
- [ ] Your install.sh runs AFTER superpowers-plus
- [ ] Your skill includes all functionality from the generic version
- [ ] Run `./tools/skill-trigger-validator.sh audit` to verify no unexpected overlaps

---

## The Adapter Pattern

Use this pattern when the generic skill should work with multiple platforms, selectable via configuration.

### How Adapters Work

```
skills/
├── wiki/
│   ├── _adapters/
│   │   ├── README.md              # Overview of all adapters
│   │   ├── adapter-interface.md   # Generic interface definition
│   │   ├── outline.md             # Outline-specific config
│   │   ├── confluence.md          # Confluence-specific config
│   │   └── notion.md              # Notion-specific config
│   └── wiki-editing/
│       └── skill.md               # Generic skill, references adapters
```

### Environment Variables


## The Fork Pattern

Use this pattern when your org's workflow diverges significantly from the generic skill, but you still want to track upstream changes.

### When to Fork (vs Override)

| Scenario | Pattern |
|----------|---------|
| Same workflow, different platform | Override |
| Slightly different workflow, same structure | Override |
| **Significantly different workflow** | **Fork** |
| **Different stages, different validations** | **Fork** |

### How to Fork

1. **Copy the skill** from superpowers-plus to your org repo
2. **Modify as needed** for your org's workflow
3. **Document the fork** with upstream version info
4. **Periodically sync** important upstream changes

**Example: Forked skill header**

```yaml
# skills/wiki/wiki-authoring/skill.md
---
name: wiki-authoring
description: Wiki authoring rules for YourOrg. FORK of superpowers-plus wiki-authoring.
---

# Wiki Authoring (YourOrg Fork)

> **Forked from:** superpowers-plus v2.1.0
> **Fork date:** 2024-03-01
> **Reason:** Org-specific formatting rules, internal link patterns

## Differences from Upstream
- Added: Internal wiki link format validation
- Added: Required metadata headers
- Modified: Heading hierarchy rules for our wiki structure
- Removed: Generic anchor format (using platform-specific)
```

### Keeping Forks in Sync

Create a tracking file in your org repo:

```yaml
# .fork-tracking.yaml
forks:
  - skill: wiki-authoring
    upstream_repo: superpowers-plus
    upstream_version: v2.1.0
    fork_date: 2024-03-01
    last_sync: 2024-06-15
    divergence: moderate  # low, moderate, high
    notes: "Custom heading rules, internal link validation"
```

**Sync process:**
1. Check superpowers-plus release notes
2. Review changes to forked skills
3. Cherry-pick relevant improvements
4. Update `.fork-tracking.yaml`

---

## The Always-On Rules Pattern

Rules are **always-active guidance** that apply to ALL conversations, regardless of which skill is invoked. Use rules for org-specific policies that should never be bypassed.

### Rules vs Skills

| Aspect | Skills | Rules |
|--------|--------|-------|
| Invocation | Explicitly invoked or triggered | Always active |
| Purpose | Specific workflows | Global policies |
| Override | Can be overridden | Cannot be bypassed |
| Location | `~/.augment/skills/` | `~/.augment/rules/` |

### Rule File Naming

```
rules/
├── wiki-editing.always.md      # Always-on wiki guidance
├── secrets-policy.always.md    # Secret handling policy
├── code-review.always.md       # Code review requirements
└── pii-protection.always.md    # PII handling rules
```

The `.always.md` suffix indicates these rules are loaded for every conversation.

### Example: Wiki Editing Rule

```markdown
# rules/your-wiki-platform.always.md

# YourWikiPlatform Editing Rules

<EXTREMELY_IMPORTANT>
## Write Scope Restriction

Before ANY wiki write operation, verify the target is within allowed scope.

### Allowed Write Areas
- `/spaces/engineering/` — Engineering documentation
- `/spaces/your-team/` — Your team's space

### Blocked Areas
- `/spaces/hr/` — HR policies (read-only)
- `/spaces/legal/` — Legal docs (read-only)

**Attempting to write outside allowed areas will be blocked.**
</EXTREMELY_IMPORTANT>
```

### When to Use Rules

| Use Case | Pattern |
|----------|---------|
| API authentication guidance | Rule |
| Scope/permission restrictions | Rule |
| PII/secrets handling | Rule |
| Compliance requirements | Rule |
| Platform-specific quirks | Rule |
| Workflow orchestration | Skill |

---

## Trigger Validation

superpowers-plus includes a trigger validator tool that ensures skills don't accidentally collide on trigger phrases. **Your org repo should copy this tool and run it as part of your CI/CD pipeline.**

### Running the Validator

```bash
# Copy from superpowers-plus to your org repo
cp path/to/superpowers-plus/tools/skill-trigger-validator.sh your-org-skills/tools/

# Run full audit
./tools/skill-trigger-validator.sh audit

# Output:
# [OK] No unexpected overlaps (N intentional overlap(s) found)
# [OK] All skills have adequate trigger definitions
# [INFO] Total: XX skills, YYY triggers
```

### Validator Commands

| Command | Purpose |
|---------|---------|
| `audit` | Full audit: overlaps + missing triggers + summary |
| `overlaps` | Check for trigger collisions only |
| `registry` | Generate skill → trigger mapping |

### Configuring Intentional Overlaps

Some skills share triggers intentionally (e.g., `link-verification` fires alongside `wiki-editing`). Declare these in the `ALLOWED_OVERLAPS` array in your copy of the validator:

```bash
# In your-org-skills/tools/skill-trigger-validator.sh
ALLOWED_OVERLAPS=(
    "link-verification:wiki-editing"      # Dependency chain
    "link-verification:wiki-orchestrator" # Dependency chain
    "old-skill:new-skill"                 # Deprecated alias
)
```

### Validating Cross-Repo Triggers

When your org repo overrides superpowers-plus skills, you should validate that:

1. Override skills have the same (or extended) triggers as the base
2. No accidental collisions exist between org-specific and generic skills
3. All skills have machine-readable `triggers:` arrays

```bash
# Audit superpowers-plus
cd path/to/superpowers-plus && ./tools/skill-trigger-validator.sh audit

# Audit your org repo
cd path/to/your-org-skills && ./tools/skill-trigger-validator.sh audit

# Compare registries
diff <(cd superpowers-plus && ./tools/skill-trigger-validator.sh registry) \
     <(cd your-org-skills && ./tools/skill-trigger-validator.sh registry)
```

### CI Integration

Add to your CI pipeline:

```yaml
# .github/workflows/validate-skills.yml
- name: Validate skill triggers
  run: ./tools/skill-trigger-validator.sh audit
  working-directory: your-org-skills
```

---

## Recommended Directory Structure

Your org repo should mirror superpowers-plus structure:

```
your-org-skills/
├── .env.example              # Org-specific env vars template
├── .fork-tracking.yaml       # Track forked skills
├── install.sh                # Install script (runs AFTER superpowers-plus)
├── README.md                 # Setup instructions
│
├── skills/
│   ├── _shared/              # Shared utilities
│   │   └── your-org-utils.md
│   │
│   ├── wiki/                 # Wiki skills (override generic)
│   │   ├── wiki-editing/
│   │   │   └── skill.md      # Platform-specific implementation
│   │   ├── wiki-authoring/
│   │   │   └── skill.md      # Org formatting rules
│   │   └── _adapters/        # Optional: org-specific adapters
│   │       └── internal-wiki.md
│   │
│   ├── issue-tracking/       # Issue tracking skills
│   │   ├── issue-authoring/
│   │   │   └── skill.md      # Org-specific issue templates
│   │   └── _adapters/
│   │       └── your-tracker.md
│   │
│   └── custom/               # Org-specific skills (no generic equivalent)
│       └── deployment-checklist/
│           └── skill.md
│
└── rules/                    # Always-on rules
    ├── your-wiki.always.md
    ├── your-tracker.always.md
    └── secrets-policy.always.md
```

### Key Directories

| Directory | Purpose | Installs To |
|-----------|---------|-------------|
| `skills/` | Skill implementations | `~/.augment/skills/` |
| `skills/_shared/` | Shared utilities | `~/.augment/skills/_shared/` |
| `rules/` | Always-on rules | `~/.augment/rules/` |

---

## Install Script Pattern

Your org's `install.sh` should:
1. Check prerequisites
2. Validate environment variables
3. Install skills (AFTER superpowers-plus)
4. Install rules
5. Report status

### Example Install Script

```bash
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VERSION="1.0.0"

# Target directories
SKILLS_DIR="${HOME}/.augment/skills"
RULES_DIR="${HOME}/.augment/rules"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Check superpowers-plus is installed first
check_prerequisites() {
    if [[ ! -d "${HOME}/.codex/superpowers" ]]; then
        log_error "superpowers-plus not found. Install it first:"
        echo "  git clone https://github.com/yourfork/superpowers-plus"
        echo "  cd superpowers-plus && ./install.sh"
        exit 1
    fi
    log_info "superpowers-plus found ✓"
}

# Validate required environment variables
check_env_vars() {
    local missing=()

    [[ -z "${WIKI_API_TOKEN:-}" ]] && missing+=("WIKI_API_TOKEN")
    [[ -z "${ISSUE_TRACKER_TOKEN:-}" ]] && missing+=("ISSUE_TRACKER_TOKEN")

    if [[ ${#missing[@]} -gt 0 ]]; then
        log_warn "Missing environment variables: ${missing[*]}"
        log_warn "Set these in your .env file for full functionality"
    fi
}

# Install skills
install_skills() {
    log_info "Installing org skills..."

    mkdir -p "$SKILLS_DIR"

    find "$SCRIPT_DIR/skills" -name "skill.md" | while read -r skill_file; do
        skill_dir=$(dirname "$skill_file")
        skill_name=$(basename "$skill_dir")

        cp -r "$skill_dir" "$SKILLS_DIR/"
        log_info "  Installed: $skill_name"
    done
}

# Install rules
install_rules() {
    log_info "Installing org rules..."

    mkdir -p "$RULES_DIR"

    if [[ -d "$SCRIPT_DIR/rules" ]]; then
        cp "$SCRIPT_DIR/rules/"*.md "$RULES_DIR/" 2>/dev/null || true
        log_info "  Rules installed to $RULES_DIR"
    fi
}

# Main
main() {
    echo "Your-Org Skills Installer v${VERSION}"
    echo "======================================"

    check_prerequisites
    check_env_vars
    install_skills
    install_rules

    echo ""
    log_info "Installation complete!"
    echo ""
    echo "Skills installed to: $SKILLS_DIR"
    echo "Rules installed to: $RULES_DIR"
}

main "$@"
```

### Install Script Checklist

- [ ] Check superpowers-plus is installed first
- [ ] Source `.env` file if present
- [ ] Validate required environment variables
- [ ] Install skills (overwriting generic versions)
- [ ] Install rules
- [ ] Support `--upgrade` flag for pulling latest
- [ ] Support `--verbose` flag for debugging
- [ ] Report which skills were installed/overridden

---

## Quick Start Checklist

For a senior engineer setting up superpowers-plus for their organization:

### Day 1: Foundation
- [ ] Fork or clone superpowers-plus
- [ ] Run `./install.sh` to install generic base layer
- [ ] Create your org-skills repo with matching structure
- [ ] Create `install.sh` for your org repo

### Day 2: Core Integrations
- [ ] Identify which generic skills need overriding
- [ ] Create org-specific wiki-editing (for your wiki platform)
- [ ] Create org-specific issue-authoring (for your issue tracker)
- [ ] Add adapters for your platforms

### Day 3: Policies
- [ ] Create always-on rules for org policies
- [ ] Add scope restrictions for sensitive areas
- [ ] Document secret handling requirements

### Day 4: Rollout
- [ ] Document setup process in your org repo README
- [ ] Test install order: superpowers-plus → your-org-skills
- [ ] Verify overrides are working correctly
- [ ] Train team on the two-repo pattern

---

## Troubleshooting

| Issue | Cause | Solution |
|-------|-------|----------|
| Generic skill runs instead of org-specific | Install order wrong | Run org install.sh AFTER superpowers-plus |
| Skill not found | Skill not in correct directory | Check `~/.augment/skills/` for your skill |
| Rule not applying | Missing `.always.md` suffix | Rename to `*.always.md` |
| Override not working | Name mismatch | Ensure exact same skill name |

---

## Further Reading

- [superpowers-plus README](../README.md) — Installation and usage
- [obra/superpowers](https://github.com/obra/superpowers) — Base skill framework
- [Adapter Interface](../skills/wiki/_adapters/adapter-interface.md) — How to create adapters

