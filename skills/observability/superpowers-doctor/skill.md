---
name: superpowers-doctor
source: superpowers-plus
triggers: ["superpowers doctor", "skill health", "audit skills", "check skills", "skill diagnostics", "doctor", "skill problems", "broken skills", "skill integrity", "deep clean skills"]
anti_triggers: ["write a skill", "create skill file", "skill format"]
description: "Industrial-grade integrity check for the local skill ecosystem. Iterates across EVERY installed skill with 22 harsh diagnostic checks spanning 4 severity tiers. Finds broken YAML, name mismatches, dead references, trigger collisions, orphaned installs, oversized skills, content corruption, reference file drift, CRLF line endings, UTF-8 BOM, structural defects, stale/dirty managed checkouts, TODO archive regressions, and reviewer-dispatch rendering issues. Modeled after brew doctor."
summary: "Use when: diagnosing skill installation or configuration issues."
coordination:
  group: observability
  order: 2
  requires: []
  enables: []
  escalates_to: []
  internal: false
---

# Superpowers Doctor

> **Modeled after:** `brew doctor` — but meaner.
> **Created:** 2026-03-18 | **Upgraded:** 2026-03-20

> **Wrong skill?** Structural lint only → `skill-health-check`. Writing/authoring skills → `skill-authoring`. Updating skills → `update-superpowers`.

Industrial-grade integrity check. Iterates across **every installed skill** with 25 checks across 4 severity tiers. No skill escapes scrutiny.

## Companion Skills

- **skill-health-check**: Quick structural lint (lighter than doctor)
- **skill-authoring**: Writing new skill files
- **update-superpowers** (upstream): Updating skill installations

## When to Use

- User says "run superpowers doctor" or "check skill health"
- Before releasing a new skill version
- After bulk skill edits to catch regressions
- Periodic deep-clean audit
- After install.sh to verify deployment integrity
- When skills behave unexpectedly (wrong triggers, missing content)
- After cloning on Windows/WSL to detect CRLF or BOM issues


## Scope Exclusions

- Structural lint only → `skill-health-check` (lighter)
- Writing new skills → `skill-authoring`
- Updating skill installations → run `install.sh --upgrade`

## Modes

| Mode | Behavior |
|------|----------|
| Default (no flags) | Report-only — detect and display all findings |
| `--fix-safe` | Fix non-destructive issues only (sync drift, CRLF, BOM, name mismatch, stale checkout) |
| `--fix` | Detect + auto-fix all issues including destructive (junk cleanup) — excludes orphan removal |
| `--fix --yes` | Auto-fix all without confirmation prompt — excludes orphan removal |
| `--fix --purge-orphans` | Also remove orphaned installs (skills not in any source repo) |
| `--summary-only` | One-line pass/fail (used by post-install hook) |

**10 checks are auto-fixable** (3, 8, 9, 12, 14, 16, 17, 18, 19, 20). The remaining 12 require human judgment.

**Graduated intervention:**
- `--fix-safe` fixes: 3 (name), 9 (drift), 16 (ref drift), 17 (CRLF), 18 (BOM), 19 (stale checkout pull) — non-destructive
- `--fix` adds: 12 (deprecated triggers), 14 (junk removal), 20 (dirty checkout stash+clean) — destructive
- `--purge-orphans` adds: 8 (orphan removal) — requires explicit opt-in because locally-created skills are not necessarily garbage

All fixes create backups in `~/.codex/doctor-backups/YYYY-MM-DD_HH-MM-SS-PID/` before modifying anything. Backups are verified for completeness before any fix is applied. <!-- doctor-ignore -->

## How to Execute

```bash
# Run from superpowers-plus repo root
./tools/doctor-checks.sh              # Diagnose only
./tools/doctor-checks.sh --fix-safe   # Fix non-destructive issues
./tools/doctor-checks.sh --fix        # Fix all auto-fixable issues
./tools/doctor-checks.sh --fix --yes  # Fix all without prompts
```

The script auto-discovers source repos via `SPP_SOURCE_DIR` / `SPC_SOURCE_DIR` env vars or well-known paths. See `references/checks.md` for the full check summary table.

## Severity Tiers

| Tier | Meaning | Action |
|------|---------|--------|
| 🔴 CRITICAL | Skill is broken or corrupted | Fix immediately |
| 🟠 ERROR | Skill is degraded | Fix before next release |
| 🟡 WARNING | Quality/hygiene issue | Fix when convenient |
| 🔵 INFO | Recommendation | Consider improving |

## Cross-Platform Notes

- **WSL/Windows:** Doctor detects CRLF line endings (Check 17) and UTF-8 BOM (Check 18). Both are auto-fixable.
- **NTFS mounts:** Doctor warns when skills are installed on `/mnt/c/...` where `chmod` is silently ignored.
- **Prevention:** The repo includes `.gitattributes` enforcing LF line endings. Configure `git config --global core.autocrlf input` on Windows.

## Failure Modes

| Failure | Recovery |
|---------|----------|
| No source repos found | Set `SPP_SOURCE_DIR` / `SPC_SOURCE_DIR` env vars |
| YAML parsing fails | The parse failure IS the finding (Check 1) |
| Network unavailable | Checks 13, 19 skipped — re-run when online |
| Backup fails | Fix is skipped automatically — resolve disk space or permissions |
| Skills on NTFS mount | Move to native Linux path (WSL only) |
| python3 not found | Check 21 (TODO smoke test) skipped |
| node not found | Check 22 (reviewer-dispatch) skipped |
| git < 2.13 | Check 20 stash fallback uses `git stash save` |
