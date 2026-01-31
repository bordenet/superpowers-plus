---
name: enforce-style-guide
description: "Enforce coding standards before any commit. Checks shebang, error handling, help flags, verbose flags, line limits, ShellCheck compliance, and syntax validation."
---

# enforce-style-guide

**MANDATORY**: Use this skill before ANY commit to ANY repository to ruthlessly enforce coding standards.

## When to Use This Skill

**ALWAYS** use this skill before committing code changes. No exceptions.

This skill enforces:
- Repository-specific style guides in `docs/` or root directory
- Shell script standards from https://github.com/bordenet/scripts/STYLE_GUIDE.md
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

Report violations in this format:

```
STYLE GUIDE VIOLATIONS:

script.sh:
  ❌ Missing -v|--verbose flag (MANDATORY)
  ❌ Missing --what-if flag (destructive script)
  ❌ ShellCheck warning at line 42: SC2155

another-script.sh:
  ❌ Exceeds 400 line limit (currently 456 lines)
  ❌ Missing set -euo pipefail

TOTAL: 5 violations across 2 files
STATUS: ⛔ MUST FIX BEFORE COMMITTING
```

## Fixing Non-Compliance

For each violation:

1. **Read the relevant style guide section**
2. **Understand the requirement**
3. **Implement the fix**
4. **Verify with enforcement commands**
5. **Re-audit until clean**

## Example Usage

```bash
# Before committing
User: "I'm ready to commit my changes"
Assistant: "Let me use the /enforce-style-guide skill first"

# Skill runs audit
# Reports violations
# Fixes violations
# Re-audits
# Only then proceeds with commit
```

## Integration with Pre-Commit Workflow

This skill implements the MANDATORY Step 1 from CLAUDE.md:

```
1. Verify STYLE_GUIDE.md compliance - DO THIS FIRST
   - VERIFY: Script has -h/--help flag
   - VERIFY: Script has -v/--verbose flag
   - VERIFY: Destructive scripts have --what-if flag
   - VERIFY: Script uses set -euo pipefail
   - VERIFY: Script is under 400 lines
   - VERIFY: ShellCheck passes
   - If ANY fail, STOP and fix before proceeding
```

## Skill Behavior

**This skill is AGGRESSIVE and UNCOMPROMISING:**

- Reports ALL violations, no matter how minor
- Does not proceed until 100% compliant
- Does not accept "good enough"
- Does not skip checks
- Does not make exceptions without explicit user approval

## Success Criteria

Skill succeeds when:

✅ Zero style guide violations
✅ All verification commands pass
✅ Code ready for commit

## Failure Response

If violations found:

1. Report violations clearly
2. Offer to fix automatically
3. Fix violations systematically
4. Re-audit after each fix
5. Repeat until clean

**DO NOT COMMIT** until this skill reports zero violations.

---

## Reference: Shell Script STYLE_GUIDE.md

For authoritative shell script standards, always reference:
https://github.com/bordenet/scripts/blob/main/STYLE_GUIDE.md

Key requirements:
- Required flags: -h/--help, -v/--verbose, --what-if (destructive)
- Error handling: set -euo pipefail
- Line limit: 400 lines max
- Zero ShellCheck warnings
- Man-page style help
- INFO-level verbose logging

---

**Remember**: This skill exists because 80% of scripts were non-compliant. Never let that happen again.
