---
name: superpowers-doctor
source: superpowers-plus
triggers: ["superpowers doctor", "skill health", "audit skills", "check skills", "skill diagnostics", "doctor", "skill problems", "broken skills", "skill integrity", "deep clean skills"]
description: "Industrial-grade integrity check for the local skill ecosystem. Iterates across EVERY installed skill with 16 harsh diagnostic checks spanning 4 severity tiers. Finds broken YAML, name mismatches, dead references, trigger collisions, orphaned installs, oversized skills, content corruption, reference file drift, and structural defects. Modeled after brew doctor."
---

# Superpowers Doctor

> **Modeled after:** `brew doctor` — but meaner.
> **Created:** 2026-03-18 | **Upgraded:** 2026-03-19

Industrial-grade integrity check. Iterates across **every installed skill** with 16 checks across 4 severity tiers. No skill escapes scrutiny.

## When to Use

- User says "run superpowers doctor" or "check skill health"
- Before releasing a new skill version
- After bulk skill edits to catch regressions
- Periodic deep-clean audit
- After install.sh to verify deployment integrity
- When skills behave unexpectedly (wrong triggers, missing content)

## Modes

| Mode | Behavior |
|------|----------|
| Default (no flags) | Report-only — detect and display all findings |
| `--fix` | Detect + auto-fix safe issues. Prompts for confirmation before applying. |
| `--fix --yes` | Detect + auto-fix without confirmation prompt. |

**5 checks are auto-fixable** (3, 8, 9, 14, 16). The remaining 11 require human judgment.
All fixes create backups in `~/.codex/doctor-backups/YYYY-MM-DD_HH-MM-SS/` before modifying anything.

## How to Execute

```bash
# Run from superpowers-plus repo root
./tools/doctor-checks.sh          # Diagnose only
./tools/doctor-checks.sh --fix    # Diagnose + auto-fix safe issues
```

The script auto-discovers source repos via `SPP_SOURCE_DIR` / `SPC_SOURCE_DIR` env vars or well-known paths. See `references/checks.md` for the full check summary table.

## Severity Tiers

| Tier | Meaning | Action |
|------|---------|--------|
| 🔴 CRITICAL | Skill is broken or corrupted | Fix immediately |
| 🟠 ERROR | Skill is degraded | Fix before next release |
| 🟡 WARNING | Quality/hygiene issue | Fix when convenient |
| 🔵 INFO | Recommendation | Consider improving |

## Failure Modes

| Failure | Recovery |
|---------|----------|
| No source repos found | Set `SPP_SOURCE_DIR` / `SPC_SOURCE_DIR` env vars |
| YAML parsing fails | The parse failure IS the finding (Check 1) |
| Network unavailable | Check 13 skipped — re-run when online |
