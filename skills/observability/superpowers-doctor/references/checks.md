# Superpowers Doctor — Check Reference

All 16 checks are implemented in `tools/doctor-checks.sh`. Run with `--fix` for auto-fixable issues.

```bash
./tools/doctor-checks.sh          # Diagnose
./tools/doctor-checks.sh --fix    # Diagnose + auto-fix
```

## Check Summary

| # | Tier | Check | What It Catches | Auto-fix? |
|---|------|-------|-----------------|-----------|
| 1 | 🔴 CRITICAL | Malformed YAML | Missing `---` delimiters, missing `name:` | ❌ |
| 2 | 🔴 CRITICAL | Empty/stub | <10 lines — zero guidance | ❌ |
| 3 | 🔴 CRITICAL | Name mismatch | `name:` ≠ directory name | ✅ |
| 4 | 🔴 CRITICAL | Duplicate names | Same skill in multiple source repos | ❌ |
| 5 | 🔴 CRITICAL | Broken refs | skill.md cites missing references/ or modules/ | ❌ |
| 6 | 🟠 ERROR | Oversized | >250 lines — truncated in context | ❌ |
| 7 | 🟠 ERROR | Missing description | Router can't discover skill | ❌ |
| 8 | 🟠 ERROR | Orphaned install | Installed but absent from all source repos | ✅ |
| 9 | 🔴 CRITICAL | Content drift | Source ≠ installed (corruption if <30% overlap) | ✅ |
| 10 | 🟡 WARNING | Missing triggers | No triggers AND not in EXPLICIT_SKILLS | ❌ |
| 11 | 🟡 WARNING | Trigger overlap | Two+ skills share identical trigger | ❌ |
| 12 | 🟡 WARNING | Deprecated active | Deprecation language + active triggers | ❌ |
| 13 | 🟡 WARNING | Dead paths | File paths in skill.md don't exist | ❌ |
| 14 | 🔵 INFO | Junk files | Non-skill files in repo roots | ✅ |
| 15 | 🔵 INFO | Structure quality | Missing "When to Use", examples, failure modes | ❌ |
| 16 | 🔴 CRITICAL | Reference drift | Installed references ≠ source (corruption check) | ✅ |

## Severity Guide

| Tier | Meaning | Action |
|------|---------|--------|
| 🔴 CRITICAL | Skill is broken or corrupted | Fix immediately |
| 🟠 ERROR | Skill is degraded | Fix before next release |
| 🟡 WARNING | Quality/hygiene issue | Fix when convenient |
| 🔵 INFO | Recommendation | Consider improving |

## Auto-Fix Behavior

- Backups created at `~/.codex/doctor-backups/YYYY-MM-DD_HH-MM-SS/` before any fix
- Idempotent: running `--fix` twice produces `Fixed: 0` on second run
- Overlay-aware: compares installed against highest-priority source (overlay > plus)
