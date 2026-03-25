# Superpowers Doctor — Check Reference

All 22 checks are implemented in `tools/doctor-checks.sh`.

```bash
./tools/doctor-checks.sh              # Diagnose only
./tools/doctor-checks.sh --fix-safe   # Fix non-destructive issues (sync, CRLF, BOM, stale pull)
./tools/doctor-checks.sh --fix        # Fix all auto-fixable issues
./tools/doctor-checks.sh --fix --yes  # Fix all without prompts
./tools/doctor-checks.sh --summary-only  # One-line pass/fail
```

## Check Summary

| # | Tier | Check | What It Catches | Auto-fix? | Fix Tier |
|---|------|-------|-----------------|-----------|----------|
| 1 | 🔴 CRITICAL | Malformed YAML | Missing `---` delimiters, missing `name:` | ❌ | — |
| 2 | 🔴 CRITICAL | Empty/stub | <10 lines — zero guidance | ❌ | — |
| 3 | 🔴 CRITICAL | Name mismatch | `name:` ≠ directory name | ✅ | safe |
| 4 | 🔴 CRITICAL | Duplicate names | Same skill in multiple source repos | ❌ | — |
| 5 | 🔴 CRITICAL | Broken refs | skill.md cites missing references/ or modules/ | ❌ | — |
| 6 | 🟠 ERROR | Oversized | >250 lines — truncated in context | ❌ | — |
| 7 | 🟠 ERROR | Missing description | Router can't discover skill | ❌ | — |
| 8 | 🟡 WARNING | Orphaned install | Installed but absent from all source repos | ✅ | `--purge-orphans` only |
| 9 | 🔴 CRITICAL | Content drift | Source ≠ installed (corruption if >70% changed) | ✅ | safe |
| 10 | 🟡 WARNING | Missing triggers | No triggers AND not in EXPLICIT_SKILLS | ❌ | — |
| 11 | 🟡 WARNING | Trigger overlap | Two+ skills share identical trigger | ❌ | — |
| 12 | 🟡 WARNING | Deprecated active | Deprecation language + active triggers | ✅ | moderate |
| 13 | 🟡 WARNING | Dead paths | File paths in skill.md don't exist | ❌ | — |
| 14 | 🔵 INFO | Junk files | Non-skill files in repo roots | ✅ | moderate |
| 15 | 🔵 INFO | Structure quality | Missing "When to Use", examples, failure modes | ❌ | — |
| 16 | 🔴 CRITICAL | Reference drift | Installed references ≠ source (corruption check) | ✅ | safe |
| 17 | 🟠 ERROR | CRLF line endings | Windows line endings in skill.md or references | ✅ | safe |
| 18 | 🟡 WARNING | UTF-8 BOM | Byte order mark breaks YAML parsing | ✅ | safe |
| 19 | 🟠 ERROR | Stale checkout | Managed `~/.codex/superpowers-plus` behind origin/main | ✅ | safe |
| 20 | 🟠 ERROR | Dirty checkout | Uncommitted changes in managed checkout | ✅ | moderate |
| 21 | 🟠 ERROR | TODO archive smoke | Small-but-valid TODO fails to archive or produces bloated result | ❌ | — |
| 22 | 🟡 WARNING | Reviewer-dispatch | Stale code-reviewer rendering patterns in installed skills | ❌ | — |

**Pre-check:** WSL + NTFS mount detection — warns when skills are on `/mnt/c/...` where `chmod` is silently ignored.

## Graduated Fix Tiers

| Tier | Flag | Checks Fixed | Risk |
|------|------|-------------|------|
| Safe | `--fix-safe` | 3, 9, 16, 17, 18, 19 | Non-destructive (sync, normalize, pull) |
| Moderate | `--fix` | All of safe + 12, 14, 20 | Destructive (stash, clearing) |
| Purge | `--fix --purge-orphans` | All of moderate + 8 | Removes orphaned installs (explicit opt-in) |

## Severity Guide

| Tier | Meaning | Action |
|------|---------|--------|
| 🔴 CRITICAL | Skill is broken or corrupted | Fix immediately |
| 🟠 ERROR | Skill is degraded | Fix before next release |
| 🟡 WARNING | Quality/hygiene issue | Fix when convenient |
| 🔵 INFO | Recommendation | Consider improving |

## Auto-Fix Behavior

- Backups created at `~/.codex/doctor-backups/YYYY-MM-DD_HH-MM-SS-PID/` before any fix
- Backup integrity verified (file count) before applying any fix
- Symlinks preserved in backups (`cp -PR`)
- Idempotent: running `--fix` twice produces `Fixed: 0` on second run
- Overlay-aware: compares installed against highest-priority source (overlay > plus)
- Diff-based drift detection (replaces comm-based overlap for accuracy)


## Platform Compatibility

| Platform | Notes |
|----------|-------|
| macOS (Homebrew) | All checks work. `timeout` via coreutils; falls back gracefully if absent |
| macOS (vanilla) | All checks work. Fetch timeout skipped if `timeout`/`gtimeout` unavailable |
| Linux (Ubuntu/Debian) | All checks work. `git stash push` requires git 2.13+; fallback to `git stash save` |
| WSL (Ubuntu) | All checks work. Same as Linux; also detects NTFS mount issues (pre-check) |

**Optional dependencies for checks 21–22:**
- `python3` — required for Check 21 (TODO archive smoke test). Skipped with INFO if absent.
- `node` — required for Check 22 (reviewer-dispatch verification). Skipped with WARNING if absent.
