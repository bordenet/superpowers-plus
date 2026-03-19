---
name: superpowers-doctor
source: superpowers-plus
triggers: ["superpowers doctor", "skill health", "audit skills", "check skills", "skill diagnostics", "doctor", "skill problems", "broken skills"]
description: "Diagnose skill ecosystem health like brew doctor. Finds oversized skills, missing triggers, deprecated-but-active conflicts, orphaned files, and install staleness. Use when auditing skill quality or before a release."
---

# Superpowers Doctor

> **Modeled after:** `brew doctor`
> **Created:** 2026-03-18

Run 6 diagnostic checks against all installed skills. Report problems with severity, counts, and actionable fixes.

## When to Use

- User says "run superpowers doctor" or "check skill health"
- Before releasing a new skill version
- After bulk skill edits to catch regressions
- Periodic hygiene audit

## How to Execute

Run ALL 6 checks in order. Collect results, then print a single summary report.

### Paths to Scan

```bash
# Auto-detect source directories
SP_PLUS_DIR=$(find ~/GitHub -maxdepth 4 -type d -name "superpowers-plus" 2>/dev/null | head -1)
SP_CALLBOX_DIR=$(find ~/GitHub -maxdepth 4 -type d -name "superpowers-callbox" 2>/dev/null | head -1)
INSTALLED_DIR=~/.codex/skills

# Scan all source directories that exist
SOURCE_DIRS=()
[ -d "$SP_PLUS_DIR/skills" ] && SOURCE_DIRS+=("$SP_PLUS_DIR/skills")
[ -d "$SP_CALLBOX_DIR" ] && SOURCE_DIRS+=("$SP_CALLBOX_DIR")
```

If no source directories found, warn and scan `INSTALLED_DIR` only (reduced checks).

### Check 1: Oversized Skills (🔴 Error)

**Threshold:** 250 lines (hard limit — skills above this get truncated in agent context windows).

```bash
for dir in "${SOURCE_DIRS[@]}"; do
  find "$dir" -name "skill.md" -not -path "*/references/*" -exec sh -c \
    'lines=$(wc -l < "$1"); [ "$lines" -gt 250 ] && echo "$lines $1"' _ {} \;
done | sort -rn
```

**Fix:** Split into `skill.md` (core ≤250) + `references/*.md`

### Check 2: Missing Triggers (🟡 Warning)

Skills without `triggers:` in YAML frontmatter cannot be auto-invoked.

```bash
for dir in "${SOURCE_DIRS[@]}"; do
  for f in $(find "$dir" -name "skill.md" -not -path "*/references/*"); do
    grep -q "^triggers:" "$f" || echo "$(echo "$f" | sed "s|.*/skills/||; s|/skill.md||")"
  done
done
```

**Fix:** Add `triggers: ["phrase1", "phrase2"]` to YAML frontmatter.

### Check 3: Empty or Stub Skills (🔴 Error)

Skills under 10 lines provide no agent guidance.

```bash
for dir in "${SOURCE_DIRS[@]}"; do
  find "$dir" -name "skill.md" -not -path "*/references/*" -exec sh -c \
    'lines=$(wc -l < "$1"); [ "$lines" -lt 10 ] && echo "$lines $1"' _ {} \;
done
```

### Check 4: Deprecated Skills with Active Triggers (🟡 Warning)

```bash
for dir in "${SOURCE_DIRS[@]}"; do
  for f in $(find "$dir" -name "skill.md" -not -path "*/references/*"); do
    head_content=$(head -20 "$f")
    if echo "$head_content" | grep -qi "deprecated\|replaced by" && grep -q "^triggers:" "$f"; then
      echo "$(echo "$f" | sed "s|.*/skills/||; s|/skill.md||")"
    fi
  done
done
```

**Fix:** Remove triggers from deprecated skill or delete it.

### Check 5: Junk Files (🟡 Warning)

Non-skill files in repo root that shouldn't be committed.

```bash
for dir in "${SOURCE_DIRS[@]}"; do
  find "$dir" -maxdepth 1 -type f \
    ! -name "*.md" ! -name "*.sh" ! -name "CODEOWNERS" ! -name ".gitignore" \
    ! -name ".env*" ! -name "*.json" ! -name "*.yaml" ! -name "*.yml"
done
```

### Check 6: Install Staleness (🟡 Warning)

Source files newer than installed copies.

```bash
for dir in "${SOURCE_DIRS[@]}"; do
  for src in $(find "$dir" -name "skill.md" -not -path "*/references/*"); do
    skill=$(basename "$(dirname "$src")")
    installed="$INSTALLED_DIR/$skill/skill.md"
    if [ -f "$installed" ] && [ "$src" -nt "$installed" ]; then
      echo "$skill"
    fi
  done
done
```

**Fix:** Run `./install.sh --verbose --skip-secrets`

## Output Format

Print in `brew doctor` style — problems first, clean checks last:

```
$ superpowers doctor

🔴 3 oversized skills (>250 lines)
  wiki-authoring: 312 lines (1.2× limit)
  Fix: Split into skill.md + references/*.md

🟡 7 skills without trigger definitions
  por-linear-triage, por-project-registry, ...
  Fix: Add triggers: [...] to YAML frontmatter

✅ No empty/stub skills
✅ No deprecated skills with active triggers
✅ No junk files
✅ No stale installs

Your superpowers have 10 issues to address.
```

If all checks pass: `Your superpowers are ready to brew. No issues found.`

## Severity Guide

| Severity | Meaning | Action |
|----------|---------|--------|
| 🔴 Error | Broken or violates hard limits | Fix before next release |
| 🟡 Warning | Works but has quality issues | Fix when convenient |
| ✅ Clean | Check passed | No action needed |

