---
name: golden-agents
source: superpowers-plus
triggers: ["set up AI guidance", "add AGENTS.md", "initialize repo", "upgrade AI guidance", "add CLAUDE.md"]
anti_triggers: ["write a skill", "check skill health", "diagnose skills"]
description: Use when initializing a new git repo with AI guidance, upgrading existing repos with inadequate AI guidance, or when user says "set up AI guidance" or "add AGENTS.md" - detects repo state and offers appropriate workflow.
summary: "Use when: initializing or upgrading AI guidance (AGENTS.md) in a git repo."
coordination:
  group: productivity
  order: 4
  requires: []
  enables: []
  escalates_to: []
  internal: false
---

# Golden Agents

> **Wrong skill?** Writing individual skills → `skill-authoring`. Checking skill health → `skill-health-check`. Runtime diagnostics → `superpowers-doctor`.

> **Last Updated:** 2026-02-01

## Purpose

Initialize or upgrade AI guidance in any repository using the [golden-agents](https://github.com/bordenet/golden-agents) framework. Auto-detects repo state and language, offers appropriate workflow.

**Prerequisite:** Clone golden-agents if not present:

```bash
git clone https://github.com/bordenet/golden-agents.git ~/.golden-agents
```

---

## When to Use

Invoke when:

- Setting up a new repository
- Adding AI guidance to an existing repo
- Upgrading outdated AGENTS.md files
- User says: "set up AI guidance", "add AGENTS.md", "upgrade AI guidance"

---

## Phase 1: Detection

### 1.1 Check Prerequisites

```bash
# Verify golden-agents is installed
if [[ ! -f ~/.golden-agents/generate-agents.sh ]]; then
    echo "Installing golden-agents..."
    git clone https://github.com/bordenet/golden-agents.git ~/.golden-agents
fi

# Sync to latest
~/.golden-agents/generate-agents.sh --sync
```

### 1.2 Detect Git State

```bash
# Check if git repo exists
if [[ ! -d .git ]]; then
    echo "No git repository found."
    # Offer: git init
fi
```

### 1.3 Detect Existing AI Guidance

| File State | Action |
|------------|--------|
| No AGENTS.md | → New generation |
| AGENTS.md WITH markers | → Upgrade path |
| AGENTS.md WITHOUT markers | → Migrate path |
| Only CLAUDE.md (no AGENTS.md) | → Migrate path |

Check for markers:

```bash
if [[ -f AGENTS.md ]]; then
    if grep -q "<!-- GOLDEN:framework:start -->" AGENTS.md; then
        echo "AGENTS.md has markers → Upgrade path"
    else
        echo "AGENTS.md lacks markers → Migrate path"
    fi
fi
```

### 1.4 Auto-Detect Language and Type

Scan for dependency files:

| File | Language |
|------|----------|
| `go.mod` | go |
| `package.json` | javascript |
| `requirements.txt` / `pyproject.toml` | python |
| `pubspec.yaml` | dart-flutter |
| `Cargo.toml` | rust |
| `*.sh` (multiple) | shell |

Scan for project type indicators:

| Indicator | Type |
|-----------|------|
| `cmd/` directory | cli-tools |
| `templates/` + generator scripts | genesis-tools |
| `src/` + `index.html` or framework config | web-apps |
| `ios/` + `android/` directories | mobile-apps |

**Present findings to user for confirmation:**

```
Detected:
  Languages: go, shell
  Type: cli-tools

Proceed with these settings? [Y/n/edit]
```

---

## Phase 2: Execute Workflow

Based on detection results, run the appropriate workflow from `references/workflows.md`:

| Detected State | Workflow | Key Command |
|----------------|----------|-------------|
| No .git | 2.1 New Repository | `git init` + `generate-agents.sh` |
| Git, no AGENTS.md | 2.2 New AI Guidance | `generate-agents.sh --language=X --type=Y --path=.` |
| AGENTS.md with markers | 2.3 Upgrade | `generate-agents.sh --upgrade --path=.` |
| AGENTS.md without markers | 2.4 Migrate | Interactive: Migrate/Replace/Cancel |

---

## Phase 3: Create Redirect Files

After generating AGENTS.md, create redirect files (CLAUDE.md, CODEX.md, GEMINI.md, COPILOT.md) pointing to AGENTS.md. See `references/workflows.md` for templates.

---

## Phase 4: Commit

**Always ask before committing.** Suggest message based on action:

| Action | Commit Message |
|--------|----------------|
| New repo | `feat: Initialize repository with AI guidance` |
| Add to existing | `feat: Add AI guidance files` |
| Upgrade | `chore: Upgrade AI guidance framework` |
| Migrate | `refactor: Migrate to golden-agents framework` |

---

## Command Reference

| Command | Purpose |
|---------|---------|
| `~/.golden-agents/generate-agents.sh --help` | Show all options |
| `~/.golden-agents/generate-agents.sh --sync` | Update templates from GitHub |
| `~/.golden-agents/generate-agents.sh --dry-run` | Preview without writing |
| `~/.golden-agents/generate-agents.sh --upgrade` | Preview upgrade diff |
| `~/.golden-agents/generate-agents.sh --upgrade --apply` | Apply upgrade |
| `~/.golden-agents/generate-agents.sh --compact` | Generate ~130 line version |

---

## Common Mistakes

| Mistake | Fix |
|---------|-----|
| Running without `--path` | Always specify `--path=.` or target directory |
| Upgrading file without markers | Use migrate workflow instead |
| Forgetting redirect files | Always create all 4 (CLAUDE, CODEX, GEMINI, COPILOT) |
| Not syncing before upgrade | Run `--sync` to get latest templates |

---

## Companion Skills

- **readme-authoring**: After setting up AI guidance, update README
- **superpowers:verification-before-completion**: Verify files before committing

## Failure Modes

- **Skipping detection:** Starting a workflow without first running Phase 1 detection to confirm what repos/agents exist
- **Wrong workflow type:** Using "new repo" workflow when "upgrade" was needed (always detect first)
- **Missing redirect files:** Forgetting Phase 3 redirect files, leaving old config paths broken


## References

- [`references/workflows.md`](references/workflows.md) — Phase 2 workflow templates (new/upgrade/migrate), Phase 3 redirect file templates, language detection scripts. Load when executing a workflow.
