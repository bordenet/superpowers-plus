---
name: enforce-style-guide
source: superpowers-plus
triggers: ["check style", "enforce coding standards", "lint this", "style guide", "commit:style", "commit:lint"]
description: Enforce coding standards before any commit. Checks shebang, error handling, help flags, verbose flags, line limits, ShellCheck compliance, and syntax validation.
summary: "Use when: about to commit shell scripts. Checks shebang, error handling, ShellCheck."
coordination:
  group: commit-gates
  order: 2
  requires: ["pre-commit-gate"]
  enables: ["progressive-code-review-gate"]
  escalates_to: []
  internal: false
---

# enforce-style-guide

> **Wrong skill?** AI slop in prose → `eliminating-ai-slop`. Profanity check → `professional-language-audit`. Pre-commit checks → `pre-commit-gate`.

**MANDATORY**: Use this skill before ANY commit to ANY repository to ruthlessly enforce coding standards.

## When to Use This Skill

**ALWAYS** use this skill before committing code changes. No exceptions.

This skill enforces:

- Repository-specific style guides in `docs/` or root directory
- Shell script standards from <https://github.com/bordenet/scripts/blob/main/STYLE_GUIDE.md>
- Language-specific standards
- Architectural patterns

## How This Skill Works

When invoked, this skill will:

1. **Locate style guides**
   - Search for `STYLE_GUIDE.md` in repository root
   - Search for style guides in `docs/` folder
   - For shell scripts, reference bordenet/scripts STYLE_GUIDE.md (current version)

2. **Ruthlessly audit compliance**
   - Check ALL mandatory requirements
   - Report ALL violations with file:line references
   - No warnings, only errors - everything must pass

3. **Verify fixes**
   - After fixes, re-audit to confirm compliance
   - Repeat until zero violations

## Enforcement Rules

### For Shell Scripts (Bash)

**MANDATORY requirements from bordenet/scripts STYLE_GUIDE.md:**

1. ✅ **Shebang**: `#!/usr/bin/env bash` (first line)
2. ✅ **Error handling**: `set -euo pipefail` (except bu.sh, mu.sh)
3. ✅ **Help flag**: `-h|--help` with man-page style output
4. ✅ **Verbose flag**: `-v|--verbose` with INFO-level logging
5. ✅ **Dry-run flag**: `--what-if` for destructive scripts (git operations, file modifications, system changes)
6. ✅ **Line limit**: Under 400 lines
7. ✅ **ShellCheck**: Zero warnings at `-S warning` level
8. ✅ **Syntax**: `bash -n script.sh` passes

### Verification Commands

For each shell script, run:

```bash
# 1. Check shebang
head -1 script.sh | grep -q "^#!/usr/bin/env bash"

# 2. Check set -euo pipefail (skip for bu.sh, mu.sh)
grep -q "^set -euo pipefail" script.sh

# 3. Check for --help flag
grep -q "^\s*-h|--help)" script.sh

# 4. Check for --verbose flag
grep -q "^\s*-v|--verbose)" script.sh

# 5. Check for --what-if if destructive (git, rm, mv, system changes)
if grep -qE "(git (commit|push|pull|reset|rm)|rm -|mv |curl.*-X (POST|PUT|DELETE)|docker|podman)" script.sh; then
    grep -q "^\s*--what-if)" script.sh
fi

# 6. Check line count
[ $(wc -l < script.sh) -le 400 ]

# 7. Run shellcheck
shellcheck -S warning script.sh

# 8. Validate syntax
bash -n script.sh
```

## Output Format

Report: file, violation, total count. Format: `❌ [file]: [violation]`. Status: ⛔ MUST FIX or ✅ CLEAN.

## Chain Position & Behavior

Gate 2 (after `pre-commit-gate`). Checks: -h/--help, -v/--verbose, --what-if (destructive), `set -euo pipefail`, <400 lines, ShellCheck. ANY fail → STOP → fix → re-audit → 100% clean before gate 3.
4. Re-audit after each fix
5. Repeat until clean

**DO NOT COMMIT** until this skill reports zero violations.

## Reference: Shell Script STYLE_GUIDE.md

For authoritative shell script standards, always reference:
<https://github.com/bordenet/scripts/blob/main/STYLE_GUIDE.md>

Key requirements:

- Required flags: -h/--help, -v/--verbose, --what-if (destructive)
- Error handling: set -euo pipefail
- Line limit: 400 lines max
- Zero ShellCheck warnings
- Man-page style help
- INFO-level verbose logging

**Remember**: This skill exists because 80% of scripts were non-compliant. Never let that happen again.

## Commit Gate Coordination

Multiple skills fire on "before commit". Execute in this order:

| Order | Skill | Purpose | Scope |
|-------|-------|---------|-------|
| 1 | `pre-commit-gate` | Build, lint, typecheck, test | All commits |
| 2 | **enforce-style-guide** (this skill) | Code style compliance | All commits |
| 3 | `progressive-code-review-gate` | Harsh adversarial code review loop | All code commits |
| 4 | `professional-language-audit` | Profanity/language check | User-facing docs |
| 5 | `public-repo-ip-audit` | Proprietary content check | Public repos only |

**Rationale:** Technical checks first, then style enforcement (may change code), then adversarial review (covers all code changes including style fixes), then content gates.

## Failure Modes

| Failure | Recovery |
|---------|----------|
| Fixing style issues without re-running lint | Re-run lint after every fix batch |
| Style fixes breaking functionality | Run tests after style changes |

## Companion Skills

- **pre-commit-gate**: Runs before this gate (lint/tests)
- **progressive-code-review-gate**: Runs after this gate (code review)
- **professional-language-audit**: Runs after code review (language check)
