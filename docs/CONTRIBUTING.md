# Contributing

How to add new skills to superpowers-plus.

## Adding a Skill

### 1. Create the Directory

```bash
mkdir -p skills/{domain}/{skill-name}
```

Use an existing domain or create a new one. Current domains:
- `writing/` — text quality, AI slop detection
- `engineering/` — code review, pre-commit gates
- `issue-tracking/` — issue management
- `wiki/` — documentation
- `observability/` — auditing and tracking
- `productivity/` — workflow automation
- `research/` — external research
- `security/` — vulnerability scanning
- `experimental/` — unstable skills

### 2. Create Skill Directory Structure

```bash
mkdir -p skills/{domain}/{skill-name}
touch skills/{domain}/{skill-name}/skill.md
```

**Multi-file skills (for skills >200 lines):**

```
skills/{domain}/{skill-name}/
├── skill.md        # REQUIRED: Core skill with YAML frontmatter
├── examples.md     # OPTIONAL: Extended examples (loaded on demand)
└── reference.md    # OPTIONAL: Detailed reference material
```

The `skill.md` file MUST contain all trigger conditions. Auxiliary files are loaded when the skill references them with `See also:` links.

### 3. Write the Skill

Use this template:

```markdown
---
name: skill-name
source: superpowers-plus
triggers: ["trigger phrase 1", "trigger phrase 2", "another trigger"]
description: One sentence describing what it does.
---

# Skill Name

## When to Invoke

Invoke when:
- [Condition 1]
- [Condition 2]

Do NOT invoke when:
- [Exception 1]

## Procedure

1. [Step 1]
2. [Step 2]
3. [Step 3]

## Output Format

[Describe expected outputs, tables, or artifacts]

## Failure Modes

| Failure | Detection | Recovery |
|---------|-----------|----------|
| [Failure type] | [How to detect] | [How to recover] |
```

### Frontmatter Requirements

| Field | Required | Example |
|-------|----------|---------|
| `name` | ✅ | `link-verification` |
| `source` | ✅ | `superpowers-plus` |
| `triggers` | ⚡ | `["verify links", "check URL"]` (see below) |
| `description` | ✅ | One sentence, no "Triggers on" — triggers are in the array |

### Superpowers vs Explicit Skills

**Choose the right type for your skill:**

| Type | Triggers Field | When to Use |
|------|----------------|-------------|
| **Superpower** | `triggers: ["phrase1", "phrase2"]` | Skill should auto-fire when user says certain phrases |
| **Explicit Skill** | `triggers: []` or omit | Skill should only run when explicitly requested |

**Use superpowers (with triggers) when:**
- The skill applies to a common workflow pattern (e.g., "fix this bug")
- Auto-firing prevents mistakes (e.g., pre-commit checks)
- The skill is part of a dependency chain (e.g., wiki-editing triggers link-verification)

**Use explicit skills (no triggers) when:**
- The skill is a meta-tool (help, observability, metrics)
- Running it has side effects the user should consciously choose (e.g., security-upgrade)
- It's experimental or heavyweight
- It requires context that can't be detected from phrases alone

**Note:** The `triggers` array enables automated auditing via `./tools/skill-trigger-validator.sh`. Skills without triggers should be listed in `EXPLICIT_SKILLS` in the validator to avoid false warnings.

### 4. Validate Triggers

Before committing, run the trigger validator:

```bash
./tools/skill-trigger-validator.sh audit
```

This checks for:
- Missing `triggers` arrays
- Unexpected overlaps with other skills
- Registry completeness

### 5. Install and Verify

```bash
./install.sh
node ~/.codex/superpowers-augment/superpowers-augment.js find-skills | grep skill-name
```

## Skill Writing Guidelines

**Do:**
- Start with "When to Invoke" — AI needs to know when to use it
- Include concrete examples
- Define failure modes
- Keep procedures to 5-10 steps

**Don't:**
- Use vague language ("consider", "might want to")
- Include conditional logic without defaults
- Omit the "Do NOT invoke" section
- Write procedures longer than one screen

## Testing Your Skill

1. Start a new conversation with your AI assistant
2. Run bootstrap: `node ~/.codex/superpowers-augment/superpowers-augment.js bootstrap`
3. Create a scenario that should trigger your skill
4. Verify the skill fires and produces expected output
5. Test edge cases and failure modes

## Submitting Changes

### Before Committing

**Install the pre-commit hook** (recommended):
```bash
./tools/install-hooks.sh
```

This will automatically block commits that violate quality standards.

**Or manually run the harsh review:**
```bash
./tools/harsh-review.sh
```

### Quality Requirements (Enforced by CI)

All PRs must pass these checks:

| Check | Requirement |
|-------|-------------|
| File endings | Exactly one newline at EOF (`0a`) |
| Shell scripts | `#!/usr/bin/env bash` shebang |
| Shell scripts | Pass `bash -n` and `shellcheck` |
| JSON files | Valid syntax |
| Required files | README.md, AGENTS.md, etc. must exist |

**CI will block merge if any check fails.**

### Auto-Fix Available

```bash
./tools/harsh-review.sh --fix
```

This will automatically fix file endings.

### Pull Request Process

1. Fork the repository
2. Create a feature branch
3. Add your skill
4. Run `./tools/harsh-review.sh` (must pass)
5. Submit a pull request with:
   - Skill name and purpose
   - Example trigger scenario
   - Example output
6. Complete the PR checklist (auto-populated from template)

---

## Versioning

superpowers-plus uses [Semantic Versioning](https://semver.org/):

| Change Type | Version Bump | Example |
|-------------|--------------|---------|
| Bug fixes, minor updates | PATCH | 2.1.0 → 2.1.1 |
| New skills, features | MINOR | 2.1.0 → 2.2.0 |
| Breaking changes | MAJOR | 2.1.0 → 3.0.0 |

### Creating a Release

**Most steps are automated, but tag creation requires a manual step due to branch protection.**

#### Step 1: Prepare the Release

1. **Update version in `install.sh`:**
   ```bash
   VERSION="2.3.0"
   ```

2. **Update CHANGELOG.md:**
   - Move `[Unreleased]` items to new version section
   - Add date: `## [2.3.0] - YYYY-MM-DD`

3. **Create PR and merge to main:**
   ```bash
   git checkout -b chore/release-2.3.0
   git add -A
   git commit -m "chore: release v2.3.0"
   git push origin chore/release-2.3.0
   # Create PR, wait for CI, merge
   ```

#### Step 2: Create and Push Tag (Manual)

After the PR is merged to main:

```bash
git checkout main
git pull origin main
git tag -a v2.3.0 -m "Release v2.3.0"
git push origin v2.3.0
```

> **Why manual?** Branch protection requires PRs for all pushes to `main`. PATs cannot bypass this without disabling protection entirely. The 5-second manual tag step preserves branch security.

#### Step 3: Automation Takes Over

Once the tag is pushed, automation handles everything else:

| Step | Automated By | Trigger |
|------|--------------|---------|
| Create GitHub Release | `release.yml` | Tag push (`v*`) |
| Dispatch to standalone marketplace | `release.yml` | Tag push |
| Update `marketplace.json` to new version | marketplace `version-sync.yml` | `repository_dispatch` |

#### What's Still Manual

| Task | Why |
|------|-----|
| Update CHANGELOG.md | Human judgment needed for categorization |
| Create and push git tag | Branch protection prevents automated pushes |
| PR to `obra/superpowers-marketplace` | External repo, requires maintainer approval |

### Version Check

Users can verify their installed version:
```bash
./install.sh --version
# install.sh version 2.3.0
```

### CI Version Consistency Check

CI will warn (not fail) if versions are inconsistent across files. The `version-sync.yml` workflow automatically fixes this on merge to main.
