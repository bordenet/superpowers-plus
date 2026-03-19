---
name: superpowers-doctor
source: superpowers-plus
triggers: ["superpowers doctor", "skill health", "audit skills", "check skills", "skill diagnostics", "doctor", "skill problems", "broken skills", "skill integrity", "deep clean skills"]
description: "Industrial-grade integrity check for the local skill ecosystem. Iterates across EVERY installed skill with 15 harsh diagnostic checks spanning 4 severity tiers. Finds broken YAML, name mismatches, dead references, trigger collisions, orphaned installs, oversized skills, and structural defects. Modeled after brew doctor."
---

# Superpowers Doctor

> **Modeled after:** `brew doctor` — but meaner.
> **Created:** 2026-03-18 | **Upgraded:** 2026-03-19

Industrial-grade integrity check. Iterates across **every installed skill** with 15 checks across 4 severity tiers. No skill escapes scrutiny.

## When to Use

- User says "run superpowers doctor" or "check skill health"
- Before releasing a new skill version
- After bulk skill edits to catch regressions
- Periodic deep-clean audit
- After install.sh to verify deployment integrity
- When skills behave unexpectedly (wrong triggers, missing content)

## How to Execute

### Step 0: Discover Paths

```bash
SP_PLUS_DIR=$(find ~/GitHub -maxdepth 4 -type d -name "superpowers-plus" 2>/dev/null | head -1)
SP_CALLBOX_DIR=$(find ~/GitHub -maxdepth 4 -type d -name "superpowers-example-org" 2>/dev/null | head -1)
INSTALLED_DIR=~/.codex/skills
```

Build a **skill registry** — for each installed skill, record: name, installed path, source path (if found), line count, YAML fields present, trigger list.

### Step 1: Run All 15 Checks

Run every check from `references/checks.md` against every skill in the registry. Collect all findings into a structured results array.

**The 15 checks by severity tier:**

| # | Tier | Check | What It Catches |
|---|------|-------|-----------------|
| 1 | 🔴 CRITICAL | Malformed YAML | Unparseable frontmatter, missing `---` delimiters |
| 2 | 🔴 CRITICAL | Empty/stub skills | <10 lines — zero agent guidance |
| 3 | 🔴 CRITICAL | Name mismatch | `name:` field ≠ directory name |
| 4 | 🔴 CRITICAL | Duplicate names | Same skill in multiple source repos |
| 5 | 🔴 CRITICAL | Broken internal refs | skill.md cites modules/references that don't exist |
| 6 | 🟠 ERROR | Oversized skills | >250 lines — truncated in context windows |
| 7 | 🟠 ERROR | Missing description | Skill router can't discover or match it |
| 8 | 🟠 ERROR | Orphaned installs | Installed but absent from all source repos |
| 9 | 🟠 ERROR | Source-install drift | Source newer than installed copy |
| 10 | 🟡 WARNING | Missing triggers | No triggers array AND not in EXPLICIT_SKILLS |
| 11 | 🟡 WARNING | Trigger overlap | Two+ skills share identical trigger phrases |
| 12 | 🟡 WARNING | Deprecated but active | "deprecated"/"replaced by" text + active triggers |
| 13 | 🟡 WARNING | Dead external refs | Wiki URLs, file paths, or links that don't resolve |
| 14 | 🔵 INFO | Junk files | Non-skill files in repo roots |
| 15 | 🔵 INFO | Structure quality | Missing "When to Use", no examples, no failure modes |

**See `references/checks.md` for detailed procedures for each check.**

### Step 2: Generate Report

Print in `brew doctor` style — worst problems first, clean checks last.

```
🩺 Superpowers Doctor — 87 skills scanned

🔴 CRITICAL — 2 issues (skill is broken)
  ┌ engineering-changelog-enrichment: name mismatch
  │   YAML name: "changelog-enrichment" ≠ dir: "engineering-changelog-enrichment"
  │   Fix: Align name: field with directory name
  └ por-linear-triage: malformed YAML
      Missing closing --- delimiter
      Fix: Add --- after frontmatter block

🟠 ERROR — 3 issues (skill is degraded)
  ┌ wiki-debunker: 538 lines (2.2× limit)
  │   Fix: Split into skill.md (≤250) + references/
  ├ mb-scratchpad-wiki-sync: orphaned install
  │   Installed at ~/.codex/skills/ but not in any source repo
  │   Fix: rm -rf ~/.codex/skills/mb-scratchpad-wiki-sync
  └ think-twice: source-install drift
      Source modified 2026-03-19, installed 2026-03-18
      Fix: Run ./install.sh

🟡 WARNING — 4 issues (quality/hygiene)
  ┌ por-linear-triage: no triggers and not in EXPLICIT_SKILLS
  │   Fix: Add triggers: [...] or add to EXPLICIT_SKILLS in skill-trigger-validator.sh
  └ pre-commit-gate ↔ enforce-style-guide: trigger overlap
      Shared trigger: "before commit"
      Fix: Differentiate triggers or document intentional overlap

✅ No empty/stub skills
✅ No deprecated skills with active triggers
✅ No dead external references
✅ No junk files
✅ All skills have adequate structure

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  2 critical · 3 errors · 4 warnings · 0 info
  Your superpowers need 9 fixes before they're healthy.
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

If all checks pass:
```
🩺 Superpowers Doctor — 87 skills scanned
✅ All 15 checks passed. Your superpowers are in perfect health.
```

## Severity Guide

| Tier | Icon | Meaning | Action |
|------|------|---------|--------|
| CRITICAL | 🔴 | Skill is broken or unusable | Fix immediately |
| ERROR | 🟠 | Skill is degraded or drifted | Fix before next release |
| WARNING | 🟡 | Quality or hygiene issue | Fix when convenient |
| INFO | 🔵 | Recommendation | Consider improving |

## Failure Modes

| Failure | Detection | Recovery |
|---------|-----------|----------|
| No source repos found | Warn, scan installed only (reduced checks) | Clone repos or set paths manually |
| YAML parsing fails | Catch parse error, report as Check 1 finding | Don't skip — the parse failure IS the finding |
| Skill has no frontmatter at all | Treat as malformed YAML (Check 1) | Add YAML frontmatter |
| Network unavailable for URL checks | Skip Check 13, note in report | Re-run when online |
